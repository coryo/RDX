-- Windows.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Reusable code for windowing.
--
VFL.debug("[RDX5] Loading Windows.lua", 2);
if not RDX.Windows then RDX.Windows = {}; end

----------------------
-- GENERALIZED WINDOW: LAYOUT AND SUPPORT CODE
----------------------
if not RDX.Window then RDX.Window = {}; end
-- Imbue a window
function RDX.Window.Imbue(self)
	local n = self:GetName();
	-- Imbue data
	self.text = getglobal(n.."TitleText");
	self.text:SetFont(VFL.GetFontFile(), 10);
	self.icon = getglobal(n.."TitleIcon");
	self.btnI = getglobal(n.."I");
	self.btnClose = getglobal(n.."Close");
	self.btnFilter = getglobal(n.."Filter");
	-- Imbue functionality
	self.Accomodate = RDX.Window.Accomodate;
	self.SetSize = RDX.Window.SetSize;
	self.SetPurpose = RDX.Window.SetPurpose;
	self.FilterOn = RDX.Window.FilterOn;
	self.FilterOff = RDX.Window.FilterOff;
	-- Initial repurposing
	self:SetFrameLevel(1);
	self.btnClose:SetFrameLevel(2);
	self.btnFilter:SetFrameLevel(2);
	self:SetPurpose(1);
end

-- Resize the window to accomodate an object of the given extents
function RDX.Window:Accomodate(dx, dy)
	self:SetSize(dx+10, dy+28);
end

-- Set the size of the window
function RDX.Window:SetSize(dx, dy)
	if(self:GetWidth() == dx) and (self:GetHeight() == dy) then return; end
	self:SetWidth(dx); self:SetHeight(dy);
	RDX.Window.Repurpose[self.purpose](self);
end

-- Set the purpose of the window
function RDX.Window:SetPurpose(n)
	if self.purpose ~= n then
		self.purpose = n;
		RDX.Window.Repurpose[n](self);
	end
end

function RDX.Window:FilterOn()
	self.btnFilter:LockHighlight();
end
function RDX.Window:FilterOff()
	self.btnFilter:UnlockHighlight();
end

-- LAYOUT CONTROL/PURPOSING
RDX.Window.Repurpose = {};
-- Purpose 1: No icon, title only
RDX.Window.Repurpose[1] = function(self)
	local dx,dy = self:GetWidth(), self:GetHeight();
	-- Manage icon
	self.icon:Hide();
	-- Reanchor text; pin it to the left
	self.text:ClearAllPoints();
	self.text:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -4);
	self.text:SetWidth(dx - 10); self.text:SetHeight(16);
	-- Hide all buttons
	self.btnClose:Hide(); self.btnFilter:Hide();
	-- Manage interaction btn
	self.btnI:ClearAllPoints();
	self.btnI:SetPoint("TOPLEFT", self, "TOPLEFT");
	self.btnI:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, -21);
end
-- Purpose 2: Title icon, text, no ibtns
RDX.Window.Repurpose[2] = function(self)
	local dx,dy = self:GetWidth(), self:GetHeight();
	-- Show icon
	self.icon:Show();
	-- Reanchor text to the icon
	self.text:ClearAllPoints();
	self.text:SetPoint("TOPLEFT", self, "TOPLEFT", 19, -4);
	self.text:SetWidth(dx - 22); self.text:SetHeight(16);
	-- Hide all buttons
	self.btnClose:Hide(); self.btnFilter:Hide(); 
	-- Manage interaction btn
	self.btnI:ClearAllPoints();
	self.btnI:SetPoint("TOPLEFT", self, "TOPLEFT");
	self.btnI:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", 0, -21);
end
-- Purpose 3: Title icon, text, both ibtns
RDX.Window.Repurpose[3] = function(self)
	local dx,dy = self:GetWidth(), self:GetHeight();
	-- Show icon
	self.icon:Show();
	-- Reanchor text; pin it to the left
	self.text:ClearAllPoints();
	self.text:SetPoint("TOPLEFT", self, "TOPLEFT", 19, -4);
	self.text:SetWidth(dx - 48); self.text:SetHeight(16);
	-- Show all buttons
	self.btnClose:ClearAllPoints();
	self.btnClose:SetPoint("TOPRIGHT", self, "TOPRIGHT", -7, -6);
	self.btnClose:Show(); 
	self.btnFilter:ClearAllPoints();
	self.btnFilter:SetPoint("RIGHT", self.btnClose, "LEFT");
	self.btnFilter:Show();
	-- Manage interaction btn
	self.btnI:ClearAllPoints();
	self.btnI:SetPoint("TOPLEFT", self, "TOPLEFT");
	self.btnI:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -33, -21);
end
-- Purpose 4: No title icon, close btn only
RDX.Window.Repurpose[4] = function(self)
	local dx,dy = self:GetWidth(), self:GetHeight();
	-- Hide icon
	self.icon:Hide();
	-- Reanchor text; pin it to the left
	self.text:ClearAllPoints();
	self.text:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -4);
	self.text:SetWidth(dx - 22); self.text:SetHeight(16);
	-- Show close button only
	self.btnClose:ClearAllPoints();
	self.btnClose:SetPoint("TOPRIGHT", self, "TOPRIGHT", -7, -6);
	self.btnClose:Show(); self.btnClose:SetFrameLevel(3);
	self.btnFilter:Hide();
	-- Manage interaction btn
	self.btnI:ClearAllPoints();
	self.btnI:SetPoint("TOPLEFT", self, "TOPLEFT");
	self.btnI:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -19, -21);
end
-- Purpose 5: No title icon, filter btn only
RDX.Window.Repurpose[5] = function(self)
	local dx,dy = self:GetWidth(), self:GetHeight();
	-- Hide icon
	self.icon:Hide();
	-- Reanchor text; pin it to the left
	self.text:ClearAllPoints();
	self.text:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -4);
	self.text:SetWidth(dx - 22); self.text:SetHeight(16);
	-- Show filter btn only
	self.btnClose:Hide();
	self.btnFilter:ClearAllPoints(); 
	self.btnFilter:SetPoint("TOPRIGHT", self, "TOPRIGHT", -7, -6);
	self.btnFilter:Show(); self.btnFilter:SetFrameLevel(3);
	-- Manage interaction btn
	self.btnI:ClearAllPoints();
	self.btnI:SetPoint("TOPLEFT", self, "TOPLEFT");
	self.btnI:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -19, -21);
end
----------------------
-- SUPPORTING CODE FOR WINDOW CREATION
----------------------
-- Create the "window" and "grid" elements of a window object.
-- Also creates a unitframe acquisition function that reparents the
-- acquired frames to the window.
function RDX.Window.MakeContainer(self, wPurpose)
	-- The window
	self.window = RDX.windowPool:Acquire();
	self.window:SetParent(UIParent);
	self.window:SetPurpose(wPurpose);
	-- The grid
	self.grid = VFL.Grid:new();
	self.grid:SetGridAnchor(self.window, "TOPLEFT", 5, -23);
	self.grid.OnRelease = function(self,x) RDX.UnitFramePool:Release(x); end
	-- Data acquisition
	self.fnAcquireCell = function()
		local f = RDX.UnitFramePool:Acquire();
		f:SetParent(self.window);
		return f;
	end
end

-- Destroy any and all resources appropriated to a container
-- created by MakeContainer
function RDX.Window.DestroyContainer(self)
	self.grid:Destroy(); self.window:Hide();
	RDX.windowPool:Release(self.window); self.window = nil;
	self.grid = nil; self.fnAcquireCell = nil;
end


-----------------
-- MANAGER
-- All windows have a latched updating mechanism. An update is scheduled based
-- on an impulse describing the level of update required. The highest level of
-- update necessary is the one perfromed.
--
-- A window can acknowledge 3 basic update impulses:
--
-- 3. SHAPE - More things are added to the window. This also involves sorting.
-- 2. SORT - The things in the window need to be reordered.
-- 1. DATA - The data about one of the things changed, but not in a way that.
--            would require resorting.
--
-- Generically (and inefficiently), a window could treat everything that would
-- change its content as a SHAPE event, simply rebuilding itself each time.
-- (All RDX4 windows worked this way) However, a truly efficient module should
-- have different code for each impulse.
function RDX.ManagerImbue(self)
	-- Internal update status
	self.updateLevel = 0;
	self.updateLatch = VFL.PeriodicLatch:new(self.Update, self);
	self.updateLatch:SetPeriod(RDXG.perf.uiWindowUpdateDelay);
	self.TriggerUpdate = RDX.ManagerTriggerUpdate;
end

function RDX.ManagerTriggerUpdate(self, n)
	-- Change the update level if needed
	if n and (self.updateLevel < n) then self.updateLevel = n; end
	-- Trip the latch
	self.updateLatch:execute();
end

--------------------------------------------
-- GENERIC DATA APPLICATION FUNCTIONS FOR UNIT FRAMES
--------------------------------------------
-- Data application (unit name only)
-- TEMP DEBUG - replace by dynamic generation
function RDX.Windows.ApplyDataNameOnly(u,c)
	c:SetPurpose(4);
	c.text1:SetText(u:GetProperName()); c.text1:SetTextColor(1,1,1);
	-- Clear onclick handler
	c.OnClick = nil;
end

--------------------------------------------
-- LAYOUT ENGINE
--------------------------------------------
-- Generic engine to layout the interior of a container frame
-- based on a unit list.
-- INPUTS:
-- fnAcquireCell = Cell allocation function
-- numUnits = Number of units that will be displayed
-- truncate = Truncation limitation on the list
-- axis = 0, paint horiz expand vert; 1, paint vert expand horiz
-- minorSize = Maximal size along minor (paint) axis.
-- self.grid = VFL grid
-- self.window = Container window
-- OUTPUTS:
-- self.displayed = Number of frames actually displayed
function RDX.LayoutRDXWindow(self, numUnits, axis, minorSize, truncate, fnAcquireCell)
	-- Determine truncated size
	local fulln = numUnits;
	local n = fulln;
	if(truncate) then n = math.min(truncate, n); end
	-- Store the number of entries actually displayed
	self.displayed = n;
	-- Now determine the new grid size
	local maj = math.ceil(n/minorSize);
	-- VFL.debug("--- minorSize " .. minorSize .. " majorSize " .. maj, 10);
	-- Rebuild the grid
	if(axis == 0) then
		self.grid:Size(minorSize, maj, fnAcquireCell);
	else
		self.grid:Size(maj, minorSize, fnAcquireCell);
	end
	self.grid:Layout();
	-- Resize the container to match the grid
	local dx,dy = self.grid:GetExtents();
	if(dx == 0) or (dy == 0) then
		dy = 1; dx = self.grid.defCW;
	end
	self.window:Accomodate(dx,dy);
end

-- Paint data into an RDX window
function RDX.PaintRDXWindow(self, units, axis, nDisp, fnApplyData)
	-- Iterate over cells, applying unit data to each cell in turn
	local iter,cell = self.grid:ExternalIterator(axis),nil;
	for i=1,nDisp do
		cell = iter(); cell:Show();
		fnApplyData(units[i], cell);
	end
	-- Hide any remaining cells
	cell = iter();
	while cell do cell:Hide(); cell = iter(); end
end
-- Paint data into an RDX window from a unit set.
function RDX.PaintRDXWindowFromSet(self, set, axis, nDisp, fnApplyData)
	local iter,cell,i = self.grid:ExternalIterator(axis),nil,1;
	for k,v in set.members do if v then
		cell = iter(); cell:Show(); fnApplyData(RDX.unit[k], cell);
		i=i+1; if(i > nDisp) then break; end
	end end
	cell = iter(); while cell do cell:Hide(); cell = iter(); end
end

--------------------------------------------
-- INIT - POPULATE WINDOW FRAMEPOOLS
--------------------------------------------
function RDX.Windows.Init()
	VFL.debug("RDX.Windows.Init()", 2);
	-- Create window frame pool
	RDX.windowPool = VFL.Pool:new();
	RDX.windowPool.OnRelease = function(pool, f)
		-- Clear interaction button callbacks
		f.btnI.OnMouseDown = nil; f.btnI.OnMouseUp = nil;
		f.btnI.OnEnter = nil; f.btnI.OnLeave = nil;
		-- Undock frame
		f:ClearAllPoints(); f:SetScale(1.0); f:Hide();
	end
	RDX.windowPool:Fill("RDXWin");
end

