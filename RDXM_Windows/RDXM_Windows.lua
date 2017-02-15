-- RDXM_Windows.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Code for custom windows.
-- 
if not RDXM.Windows then RDXM.Windows = {}; end

---------------------------------
-- WINDOW
---------------------------------
if not RDXM.Window then RDXM.Window = {}; end
RDXM.Window.__index = RDXM.Window;

function RDXM.Window:new()
	local self = {};
	setmetatable(self, RDXM.Window);
	-- Is the window in use?
	self.inUse = false;
	-- Internal update status
	self.updateLevel = 0;
	self.updateLatch = VFL.PeriodicLatch:new(RDXM.Window.Update, self);
	self.updateLatch:SetPeriod(RDXG.perf.uiWindowUpdateDelay);
	-- The set for this window
	self.set = RDX.Set:new();
	-- A cached internal unit list
	self.units = nil;
	-- UI: Container
	self.window = RDX.windowPool:Acquire();
	self.window:SetParent(UIParent);
	self.window:SetPurpose(4);
	self.window.btnClose.OnClick=function() 
		self:Close(); 
	end
	self.window.btnI:RegisterForClicks("LeftButtonUp","RightButtonUp");
	self.window.btnI.OnMouseUp = function() self:IButtonUp(arg1); end
	self.window.btnI.OnMouseDown = function() self:IButtonDown(arg1); end
	local tc = RDXG.vis.cWindowTitle;
	getglobal(self.window:GetName().."TitleBkg"):SetGradient("HORIZONTAL",tc.r,tc.g,tc.b,0,0,0);
	-- UI: Grid
	self.grid = VFL.Grid:new();
	self.grid:SetGridAnchor(self.window, "TOPLEFT", 5, -23);
	self.grid.OnRelease=function(self,x) RDX.UnitFramePool:Release(x); end
	-- UI: Cell Manipulation
	self.fnAcquireCell = function()
		local f = RDX.UnitFramePool:Acquire();
		f:SetParent(self.window);
		return f;
	end
	self.fnApplyData = nil;
	return self;
end

-- Deallocate, release, and destroy a window
function RDXM.Window:Destroy()
	self:Deallocate();
	RDX.windowPool:Release(self.window);
	self.window = nil; self.grid = nil; self.set = nil; self.updateLatch = nil;
	self.fnApplyData = nil; self.fnAcquireCell = nil;
end

-- Completely deallocate a window
function RDXM.Window:Deallocate()
	self:Hide();
	if(self.descName) then
		RDXM.Windows.nwt[self.descName] = nil;
		self.descName = nil;
	end
	self.inUse = false;
end

-- Hide and eliminate all content for a window
function RDXM.Window:Hide()
	self.vis = nil;
	self.window:Hide();
	self.grid:Destroy();
	self.set:RemoveAllMembers(); self.units = nil; self.vis = nil;
	self:UnbindEvents();
end

-- Show and build window content
function RDXM.Window:Show()
	self.window:Show();
	self.window:SetFrameLevel(1);
	self.vis = true;
	self:TriggerUpdate(4);
	self:BindEvents();
end

function RDXM.Window:RefreshAlpha()
	local alphalevel = self.window:GetAlpha()
	if alphalevel == 0 then
		self.window:SetAlpha(1)
		self.window:SetAlpha(alphalevel)
	else
		self.window:SetAlpha(0)
		self.window:SetAlpha(alphalevel)
	end
end

-- Set the window descriptor for a window
function RDXM.Window:SetDescriptor(desc)
	RDX.descself = self;
	RDX.desc = desc;
	-- Destroy our current content
	self:Hide();
	self.descName = desc.name;
	self.title = desc.cfg.title;
	-- Load filter metadata
	self.filterFiltersMana = desc.filterDesc:FiltersMana();
	self.filterFiltersHP = desc.filterDesc:FiltersHealth();
	self.filterFiltersGC = desc.filterDesc:FiltersGroupsAndClasses();
	self.filterFiltersDead = desc.filterDesc:FiltersDead();
	self.filterFiltersFollowDistance = desc.filterDesc:FiltersFollowDistance();
	self.filterFunc = RDX.MakeFilterFromDescriptor(desc.filterDesc);
	-- Load sort metadata
	self.sortSortsHP = nil; self.sortSortsMana = nil; self.sortFunc = nil; self.sortDeadBottom = nil;
	if(desc.cfg.sort == 2) then -- Somewhat kludgy; map sort functions
		self.sortSortsHP = true;
	elseif(desc.cfg.sort == 3) then
		self.sortSortsMana = true;
	end
	if(desc.cfg.deadbottom) then
		self.sortDeadBottom = true;
	end
	self.sortFunc = desc:GenSortFunc();
	-- Load layout metadata
	if(desc.cfg.truncate) then self.truncate = desc.cfg.truncate; else self.truncate = nil; end
	if(desc.cfg.layout == 1) then -- Vert layout
		self.axis = 0; self.minorSize = 1;
	elseif(desc.cfg.layout == 2) then
		self.axis = 0; self.minorSize = desc.cfg.layoutDimension;
	else
		self.axis = 1; self.minorSize = desc.cfg.layoutDimension;
	end
	-- Select column widths/row heights
	self.grid:SetColumnPadding(0); self.grid:SetRowPadding(0);
	if desc.cfg.width then
		self.cellWidth = desc.cfg.width;
	else
		self.cellWidth = 105;
	end
	if desc.cfg.height then
		self.cellHeight = desc.cfg.height;
	else
		self.cellHeight = 15;
	end
	self.grid:SetDefaultRowHeight(self.cellHeight);
	self.grid:SetDefaultColumnWidth(self.cellWidth);

	-- Load display metadata
	self.showsHP = nil; self.showsMana = nil;
	if(desc.cfg.disp == 1) then -- HP
		self.showsHP = true;
	elseif(desc.cfg.disp == 2) then -- Mana
		self.showsMana = true;
	else -- HP/Mana
		self.showsHP = true; self.showsMana = true;
	end
	-- Scaling
	if(desc.cfg.scale) then
		self.window:SetScale(desc.cfg.scale);
	else
		self.window:SetScale(1.0);
	end
	-- Alpha
	if (desc.cfg.alpha) then
		self.window:SetAlpha(desc.cfg.alpha)
	else
		self.window:SetAlpha(1.0);
	end
	-- Select data application function
	self.fnApplyData = desc:GenFnApplyData();
end

-- Open the edit box for the current window descriptor
function RDXM.Window:EditDescriptor()
	if not self.descName then return; end
	if not RDXM.Windows.descriptors[self.descName] then return; end
	RDXM.Windows.desc:SetConfig(self.descName, RDXM.Windows.descriptors[self.descName]);
	-- Show the config dialog
	RDXM.Windows.desc:ShowConfigDialog(function() self:EditedDescriptor(); end);
end
-- Rehash the contents of this window because it's been edited
function RDXM.Window:EditedDescriptor()
	self:Hide();
	RDXM.Windows.desc:SetConfig(self.descName, RDXM.Windows.descriptors[self.descName]);
	self:SetDescriptor(RDXM.Windows.desc);
	self:Show();
	-- Save the changed descriptors!
	RDXM.Windows.SaveAllDescriptors();
end

-- Bind this window to the RDX event pipelines needed
function RDXM.Window:BindEvents()
	self:UnbindEvents();
	if(self.showsHP) or (self.sortSortsHP) or (self.filterFiltersHP) then
		RDX.SigUnitHealth:Connect(self, RDXM.Window.OnUnitHealth);
	end
	if(self.showsMana) or (self.sortSortsMana) or (self.filterFiltersMana) then
		RDX.SigUnitMana:Connect(self, RDXM.Window.OnUnitMana);
	end
	if(self.filterFiltersGC) then
		RDX.SigRaidRosterMoved:Connect(self, RDXM.Window.OnRaidRosterMove);
	end
	if(self.filterFiltersDead) then
		RDX.SigUnitDeath:Connect(self, RDXM.Window.OnUnitDeathChange);
	end
	if(self.filterFiltersFollowDistance) then
		RDX.SigUnitFollowDistance:Connect(self, RDXM.Window.OnUnitFollowDistanceChange);
	end
	RDX.SigUnitIdentitiesChanged:Connect(self, RDXM.Window.OnIdentityChange);
end

-- Unbind this window from all RDX event pipelines
function RDXM.Window:UnbindEvents()
	RDX.SigUnitIdentitiesChanged:DisconnectObject(self);
	RDX.SigRaidRosterMoved:DisconnectObject(self);
	RDX.SigUnitHealth:DisconnectObject(self);
	RDX.SigUnitMana:DisconnectObject(self);
end

--------------------------------
-- WINDOW: EVENT BINDS/EVENT HANDLING
---------------------------------
-- Respond to a UNIT_HEALTH event
function RDXM.Window:OnUnitHealth(un, u)
	-- If our filter filters by HP...
	if(self.filterFiltersHP) then
		-- Reexamine the unit
		self:Examine(un, u);
		-- If we're dirty, trip the dirty-level update
		if self.set:IsDirty() then self:TriggerUpdate(3); return; end
	end
	-- If the unit's not a member of our set now, we need do nothing.
	if not self.set:GetMember(un) then return; end
	-- If we sort by health, trip a resort, else trip a simple data update.
	if(self.sortSortsHP) then
		self:TriggerUpdate(2);
	else
		self:TriggerUpdate(1);
	end
end

-- Respond to a UNIT_MANA event
function RDXM.Window:OnUnitMana(un, u)
	-- If our filter filters by HP...
	if(self.filterFiltersMana) then
		-- Reexamine the unit
		self:Examine(un, u);
		-- If we're dirty, trip the dirty-level update
		if self.set:IsDirty() then self:TriggerUpdate(3); return; end
	end
	-- If the unit's not a member of our set now, we need do nothing.
	if not self.set:GetMember(un) then return; end
	-- If we sort by health, trip a resort, else trip a simple data update.
	if(self.sortSortsMana) then
		self:TriggerUpdate(2);
	else
		self:TriggerUpdate(1);
	end
end

-- Respond to a unit identity change
function RDXM.Window:OnIdentityChange()
	self:TriggerUpdate(4);
end

-- Respond to a minor change in unit structure
function RDXM.Window:OnRaidRosterMove()
	self:TriggerUpdate(4);
end

function RDXM.Window:OnUnitFollowDistanceChange(un, u)
	if not self then
		return;
	end
	if (self.filterFiltersFollowDistance) then
		-- Reexamine the unit
		self:Examine(un, u);
		-- If we're dirty, trip the dirty-level update
		if self.set:IsDirty() then self:TriggerUpdate(3); return; end
	end
end

function RDXM.Window:OnUnitDeathChange(un, u)
	if (self.filterFiltersDeath) then
		-- Reexamine the unit
		self:Examine(un, u);
		-- If we're dirty, trip the dirty-level update
		if self.set:IsDirty() then self:TriggerUpdate(3); return; end
	end
	-- If the unit's not a member of our set now, we need do nothing.
	if not self.set:GetMember(un) then return; end
	-- If we sort by dead, trip a resort, else trip a simple data update.
	if(self.sortDeadBottom) then
		self:TriggerUpdate(2);
	else
		self:TriggerUpdate(1);
	end
end

-- Examine a unit and update its set status
function RDXM.Window:Examine(un, u)
	if(self.filterFunc(u)) then
		self.set:SetMember(un, true);
	else
		self.set:SetMember(un, nil);
	end
end

-----------------------------------
-- WINDOW: BUILD PHASES
-----------------------------------
-- LEVEL 4: Full rebuild stage
-- Examine each unit in the raid group; filter it via the filter; add it to the set
function RDXM.Window:RebuildStage()
	VFL.debug("RDXM.Window:RebuildStage()", 10);
	-- Clear the set
	self.set:RemoveAllMembers(); self.set.dirty = true;
	-- Reexamine all raid units
	for i=1,40 do
		local u = RDX.GetUnitByNumber(i);
		if not u:IsValid() then break; end
		self:Examine(i, u);
	end
end

-- LEVEL 3: "Dirty" stage
-- If the underlying set is dirty, rebuild the internal set and the window.
function RDXM.Window:DirtyStage()
	if self.set:IsDirty() then
		VFL.debug("RDXM.Window:DirtyStage() -- dirty", 10);
		-- Rebuild the internal unit array
		self.units = {};
		local n = 0;
		for k,v in self.set.members do if v then
			n=n+1;
			table.insert(self.units, RDX.GetUnitByNumber(k));
		end end
		table.setn(self.units, n);
		-- Layout the window
		RDX.LayoutRDXWindow(self, n, self.axis, self.minorSize, self.truncate, self.fnAcquireCell);
		-- Refresh the alpha values since it added to the container frame
		self:RefreshAlpha()
		-- Set the window title
		if(self.displayed < n) then
			self.window.text:SetText("[" .. self.displayed .. "/" .. n .. "]"..self.title);
		else
			self.window.text:SetText("["..n.."]"..self.title);
		end
		-- Clean the set
	
		self.set:Clean();
	end
end

-- LEVEL 2: Resort stage
-- Sort the unit array using the sort function
function RDXM.Window:ResortStage()
	if self.sortFunc then
		VFL.debug("RDXM.Window:ResortStage() -- sorting", 10);
		table.sort(self.units, self.sortFunc);
	end
end

-- LEVEL 1: "Data" stage
-- Apply data to window.
function RDXM.Window:DataStage()
	RDX.PaintRDXWindow(self, self.units, self.axis, self.displayed, self.fnApplyData);
end

-- Triggers an update of the given level
function RDXM.Window:TriggerUpdate(lvl)
	-- Change the update level if needed
	if (self.updateLevel < lvl) then self.updateLevel = lvl; end
	-- Trip the latch
	self.updateLatch:execute();
end

-- Master update routine
function RDXM.Window:Update()
	VFL.debug("RDXM.Window:Update("..self.updateLevel..")", 10);
	-- Don't update invisible windows
	if not self.vis then return; end
	-- Run updates
	if self.updateLevel == 4 then
		self:RebuildStage(); self:DirtyStage(); self:ResortStage(); self:DataStage();
	elseif self.updateLevel == 3 then
		self:DirtyStage(); self:ResortStage(); self:DataStage();
	elseif self.updateLevel == 2 then
		self:ResortStage(); self:DataStage();
	else
		self:DataStage();
	end
	-- Reset update level
	self.updateLevel = 0;
end

---------------------------------------
-- WINDOW: LAYOUT
---------------------------------------
-- Handle interaction button click
function RDXM.Window:IButtonDown(btn)
	if(btn == "LeftButton") then
		if IsShiftKeyDown() then
			self:StartMoving();
		end
	end
end
function RDXM.Window:IButtonUp(btn)
	if(btn == "LeftButton") then
		self:StopMoving();
	else
		-- Edit window descriptor
		self:EditDescriptor();
	end
end
-- Master layout routine
function RDXM.Window:Layout()
	VFL.debug("RDXM.Window:Layout()", 10);
	self.window:ClearAllPoints();
	-- Get layout entry
	local ltbl = RDXM.Windows.lt;
	local le = ltbl[self.descName];
	-- If no layout entry, anchor to center
	if not le then
		VFL.debug("-- No layout found", 10);
		self.window:SetPoint("TOPLEFT", UIParent, "CENTER");
		return;
	end
	-- If we have a dock, set it up
	if le.dockTarget then
		VFL.debug("-- Dock target found", 10);
		if self:DockImpl(le.dockTarget, le.dockPoint) then return; end
	end
	-- Otherwise, go by x/y coords
	if le.x and le.y then
		VFL.debug("-- Coords found", 10);
		self.window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", le.x, le.y);
		return;
	end
	-- Default to center
	self.window:SetPoint("TOPLEFT", UIParent, "CENTER");
	return;
end

-- Dock implementation: set internal docking state, attempt the dock, return false if failed
function RDXM.Window:DockImpl(dockTarget, dockPoint)
	VFL.debug("RDXM.Window:DockImpl("..dockTarget..","..dockPoint..")", 5);
	-- If the dock target is available...
	local targWin = RDXM.Windows.nwt[dockTarget];
	if(targWin) then
		self.docked = true; self.dockTarget = dockTarget; self.dockPoint = dockPoint;
		self.window:SetPoint("TOPLEFT", targWin.window, dockPoint);
		return true;
	end
	return false;
end

-- Undock
function RDXM.Window:Undock()
	self.dockTarget = nil; self.dockPoint = nil; self.docked = false;
	local x,y = self.window:GetLeft(),self.window:GetTop();
	self.window:ClearAllPoints();
	self.window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y);
end

-- Try to dock this window with another, visible window
function RDXM.Window:TryDock(w)
	local dist = function(x1,y1,x2,y2) local dx,dy=x2-x1,y2-y1; return math.sqrt(dx*dx+dy*dy); end
	if(w == self) then return false; end
	if (not self.vis) or (not w.vis) or (not w.descName) then return false; end
	-- Check if my topleft is near his bottomleft
	local db = dist(self.window:GetLeft(), self.window:GetTop(), w.window:GetLeft(), w.window:GetBottom());
	if(db < 20) then self:DockImpl(w.descName, "BOTTOMLEFT"); return true; end
	-- Topleft vs topright
	local db = dist(self.window:GetLeft(), self.window:GetTop(), w.window:GetRight(), w.window:GetTop());
	if(db < 20) then self:DockImpl(w.descName, "TOPRIGHT"); return true; end
	return false;
end
function RDXM.Window:CheckDocking()
	VFL.debug("RDXM.Window:CheckDocking()", 5);
	for i=1,10 do
		if self:TryDock(RDXM.Windows.wt[i]) then break; end
	end
end

-- Save current layout to layout table
function RDXM.Window:SaveLayout(shown)
	VFL.debug("RDXM.Window:SaveLayout()", 5);
	local ltbl = RDXM.Windows.lt;
	local le = nil;
	if ltbl[self.descName] then
		le = ltbl[self.descName];
	else
		le = {}; ltbl[self.descName] = le;
	end
	if(shown ~= nil) then le.shown = shown; end
	-- Save docking
	le.dockTarget = self.dockTarget; le.dockPoint = self.dockPoint;
	-- Save xy
	le.x = self.window:GetLeft(); le.y = self.window:GetTop();
end

-- Move routine
function RDXM.Window:StartMoving()
	self.moving = true;
	self:Undock();
	self.window:StartMoving();
end
function RDXM.Window:StopMoving()
	if self.moving then
		self.moving = nil;
		self.window:StopMovingOrSizing();
		self:CheckDocking();
		RDXM.Windows.SaveAllLayouts();
	end
end

-- Close routine
function RDXM.Window:Close()
	self:SaveLayout(false);
	RDXM.Windows.SaveAllLayouts();
	self:Deallocate();
end




---------------------------------
-- GLOBAL WINDOWING ENGINE
-- Keep a layout table.
-- The layout table IS the per encounter data.
-- On encounter change, just clearall and rerun layout engine
-- Layout engine:
--   - map all shown frames to windows
--   - layout undocked windows
--   - make layout passes until all laid out
-- Make sure all windows save their positions anytime they may change
--   - eg, when any window moves, save all positions
-- Remember to honor dismiss, scaling
---------------------------------
-- Allocate a window.
function RDXM.Windows.AllocateWindow()
	for i=1,10 do
		if not RDXM.Windows.wt[i].inUse then return RDXM.Windows.wt[i]; end
	end
	return nil;
end

-- Release a window
function RDXM.Windows.ReleaseWindow(w)
	w:Deallocate();
end
function RDXM.Windows.ReleaseAll()
	for i=1,10 do RDXM.Windows.wt[i]:Deallocate(); end
end

-- Save all window descriptors
function RDXM.Windows.SaveAllDescriptors()
	RDX.SaveGMPrefs("windows", RDXM.Windows.descriptors);
end

-- Save the layouts of all active windows
function RDXM.Windows.SaveAllLayouts()
	-- Save all window layouts
	for i=1,10 do
		if RDXM.Windows.wt[i].inUse then
			RDXM.Windows.wt[i]:SaveLayout();
		end
	end
	-- Now remap layout cache onto encounter
	RDX.SaveUEMPrefs(RDX.GetVirtualEncounter(), "windows", RDXM.Windows.lt);
end

function RDXM.Windows.Save()
	RDXM.Windows.SaveAllLayouts();
end

-- "Sweep" the layout table, eliminating any entry that doesnt' have a corresponding descriptor
function RDXM.Windows.SweepLayoutTable()
	for k,v in RDXM.Windows.lt do
		if not RDXM.Windows.descriptors[k] then RDXM.Windows.lt[k] = nil; end
	end
end

-- Layout all active windows
function RDXM.Windows.LayoutAll()
	VFL.debug("RDXM.Windows.LayoutAll()", 8);
	-- BUGFIX: Before running layout passes, clear all layout info.
	for i=1,10 do
		if RDXM.Windows.wt[i].inUse and RDXM.Windows.wt[i].vis then
			RDXM.Windows.wt[i].window:ClearAllPoints();
		end
	end
	-- Run two layout passes to ensure all dock dependencies are satisfied.
	RDXM.Windows.LayoutPass();
	RDXM.Windows.LayoutPass();
end
function RDXM.Windows.LayoutPass()
	for i=1,10 do
		if RDXM.Windows.wt[i].inUse and RDXM.Windows.wt[i].vis then
			RDXM.Windows.wt[i]:Layout();
		end
	end
end

-- Allocate a window, applying the descriptor with the given name.
function RDXM.Windows.AllocateByDescriptor(name)
	local desc = RDXM.Windows.descriptors[name];
	if not desc then return false; end
	local w = RDXM.Windows.AllocateWindow();
	if not w then return false; end
	RDXM.Windows.desc:SetConfig(name, desc);
	w.inUse = true;
	w:SetDescriptor(RDXM.Windows.desc);
	RDXM.Windows.nwt[name] = w;
	return w;
end

-- Apply the current vis settings settings
function RDXM.Windows.ReallocateAll()
	-- First be sure we don't get anything bad
	RDXM.Windows.SweepLayoutTable();
	-- Now run an allocation pass
	local w = nil;
	for k,v in RDXM.Windows.lt do if v.shown then
		w = RDXM.Windows.AllocateByDescriptor(k);
		w:Show();
	end end
	-- Now layout the shown windows
	RDXM.Windows.LayoutAll();
end

-- Change the active encounter
function RDXM.Windows:LoadEncounter(newenc)
	VFL.debug("RDXM.Windows.LoadEncounter("..newenc..")", 1);
	-- Load the preferences for this encounter
	RDX.MapUEMPrefs(newenc, "windows", RDXM.Windows.lt);
	-- Destroy all extant windows
	RDXM.Windows.ReleaseAll();
	-- Reallocate all windows based on layout table
	RDXM.Windows.ReallocateAll();
end

-- Show a window descriptor by window descriptor name.
function RDXM.Windows.Show(name)
	local w = RDXM.Windows.AllocateByDescriptor(name);
	if not w then return false; end
	w:Show(); w:Layout(); w:SaveLayout(true);
end

-- Hide a window descriptor by window descriptor name
function RDXM.Windows.Hide(name)
	local w = RDXM.Windows.nwt[name];
	if not w then return true; end
	w:Close();
end

-- Determine if a window is shown, by window descriptor name
function RDXM.Windows.IsShown(name)
	local le = RDXM.Windows.lt[name];
	if not le then return false; end
	if(le.shown) then return true; else return false; end
end

-- Reset UI, moving all windows back to center.
function RDXM.Windows:ResetUI()
	-- Clear all docking and positioning information
	for k,v in RDXM.Windows.lt do
		v.dockTarget = nil; v.dockPoint = nil; v.x = nil; v.y = nil;
	end
	-- Apply and save layouts
	RDXM.Windows.LayoutAll();
	RDXM.Windows.Save();
end

----------------------------------
-- MENU TREE
----------------------------------
-- Root menu
function RDXM.Windows.Menu(module, tree, frame)
	local mnu = {};
	-- Headers
	table.insert(mnu, { text = "New Window...", OnClick = function() tree:Release(); RDXM.Windows.NewWindow(); end });
--	table.insert(mnu, { text = "Manage", isSubmenu = true, OnClick = function(c) RDXM.Windows.ManageMenu(tree, c); end});
	-- Window list
	for k,v in pairs(RDXM.Windows.descriptors) do
		local dname = k;
		local isShown = RDXM.Windows.IsShown(dname);
		table.insert(mnu, { text = v.title, isSubmenu = true, hlt = isShown, OnClick = function() RDXM.Windows.WindowMenu(tree, this, dname); end });
	end
	tree:Expand(frame, mnu);
end

-- Per-window menu
function RDXM.Windows.WindowMenu(tree, frame, dname)
	local mnu = {};
	-- Show/hide
	local isShown = RDXM.Windows.IsShown(dname);
	local text = nil;
	if isShown then text = "Hide"; else text = "Show"; end
	table.insert(mnu, { text = text, OnClick = function() tree:Release(); RDXM.Windows.ToggleShow(dname); end });
	-- Clone
	table.insert(mnu, { text = "Clone...", OnClick = function() tree:Release(); RDXM.Windows.CloneDescriptor(dname); end });
	-- Delete
	table.insert(mnu, { text = "Delete", OnClick = function() tree:Release(); RDXM.Windows.DeleteDescriptor(dname); end });
	tree:Expand(frame, mnu);
end

-- Show/hide toggle
function RDXM.Windows.ToggleShow(name)
	if RDXM.Windows.IsShown(name) then
		RDXM.Windows.Hide(name);
	else
		RDXM.Windows.Show(name);
	end
	-- BUGFIX: Be sure that we save back to the encounter's layout cache
	-- when we display a window for the first time
	RDXM.Windows.SaveAllLayouts();
end

-- New window creation
function RDXM.Windows.NewWindow()
	-- Pop up a name prompt
	VFL.CC.Popup(RDXM.Windows.NewWindowCallback, "New Window", "Enter the name of the new window", "");
end
function RDXM.Windows.NewWindowCallback(flg, name)
	-- They clicked " cancel", just ignore
	if not flg then return; end
	-- Ignore invalid names
	if not VFL.isValidName(name) then return; end
	local title = name; name = string.lower(name);
	-- Ignore preexisting names
	if RDXM.Windows.descriptors[name] then return; end
	-- OK, create the descriptor
	local t = {}; t.name = name; t.title = title;
	RDXM.Windows.descriptors[name] = t;
	RDXM.Windows.desc:SetConfig(name, t);
	RDXM.Windows.desc:SetDefaults();
	-- Show the window
	RDXM.Windows.Show(name);
	-- Now save to the RDX global table
	RDX.SaveGMPrefs("windows", RDXM.Windows.descriptors);
end

-- Descriptor cloning
function RDXM.Windows.CloneDescriptor(desc)
	VFL.CC.Popup(function(flg, name) RDXM.Windows.CloneDescriptorCallback(desc, flg, name); end, 
		"Clone Descriptor: " .. desc, "Enter name for copy of '" .. desc .. "':", "");
end
function RDXM.Windows.CloneDescriptorCallback(desc, flg, name)
	-- Ignore on user cancel
	if not flg then return; end
	-- Ignore invalid names
	if not RDXM.Windows.descriptors[desc] then return; end
	if not VFL.isValidName(name) then return; end
	local title = name; name = string.lower(name);
	if RDXM.Windows.descriptors[name] then return; end
	-- Copy the descriptor
	local t = VFL.copy(RDXM.Windows.descriptors[desc]);
	t.name = name; t.title = title;
	RDXM.Windows.descriptors[name] = t;
	-- Save to the RDX global table
	RDX.SaveGMPrefs("windows", RDXM.Windows.descriptors);
end

-- Descriptor deletion
function RDXM.Windows.DeleteDescriptor(desc)
	VFL.CC.Popup(function(flg) RDXM.Windows.DeleteDescriptorCallback(desc, flg); end, 
		"Delete Descriptor: " .. desc, "Are you sure you want to delete '" .. desc .. "'?");
end
function RDXM.Windows.DeleteDescriptorCallback(desc, flg)
	-- Ignore on user cancel
	if not flg then return; end
	-- Destroy the descriptor
	RDXM.Windows.descriptors[desc] = nil;
	RDX.SaveGMPrefs("windows", RDXM.Windows.descriptors);
	-- Destroy all extant windows
	RDXM.Windows.ReleaseAll();
	-- Reallocate all windows based on layout table
	RDXM.Windows.ReallocateAll();
end

----------------------------------
-- MODULE INIT/REGISTRATION
----------------------------------
function RDXM.Windows.Init()
	VFL.debug("RDXM.Windows.Init()", 1);
	-------------
	-- GLOBAL RESOURCES
	-------------
	-- Window descriptor
	RDXM.Windows.desc = RDXM.WindowDesc:new();
	-- Active window table
	RDXM.Windows.wt = {};
	for i=1,10 do
		local w = RDXM.Window:new();
		w:Hide();
		RDXM.Windows.wt[i] = w;
	end
	-- Name-to-active-window mapping
	RDXM.Windows.nwt = {};

	-- Layout table (per-enc)
	-- (wdesc name) ---maps to---> (shown, windowX, windowY, windowAnchor, windowAnchorPoint, layoutFlag)
	RDXM.Windows.lt = {}

	-- Window descriptor table (global)
	RDXM.Windows.descriptors = {};
	
	-- Map window descriptor table
	RDX.MapGMPrefs("windows", RDXM.Windows.descriptors);
end


RDXM.Windows.module = RDX.RegisterModule({
	name = "windows";
	title = "Windows";
	DeferredInit = RDXM.Windows.Init;
	Menu = RDXM.Windows.Menu;
	LoadEncounter = RDXM.Windows.LoadEncounter;
	SaveCurrentEncounter = RDXM.Windows.Save;
	ResetUI = RDXM.Windows.ResetUI;
});
