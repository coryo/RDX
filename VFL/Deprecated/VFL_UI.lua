-- VFL
-- Generic, portable UI components.
--

VFL.UI = {
	-- Virtualization of an anchor.
	Anchor = {};
	-- Listbox.
	List = {};
	-- Portable popup menu
	PopMenu = {};
	-- Portable list box
	ListBox = {};
	-- Dropdown list based on ListBox
	DropDown = {};
};

-- Anchor class.
-- Create a new anchor
function VFL.UI.Anchor:new(p)
	local o = p or {};
	setmetatable(o, self);
	self.__index = self;
	return o;
end;

function VFL.UI.Anchor:Set(sourcePoint, targetFrame, targetPoint, offX, offY)
	self.sourcePoint = sourcePoint;
	self.targetFrame = targetFrame;
	self.targetPoint = targetPoint;
	self.offX = offX; self.offY = offY;
end;

-- Apply an anchor
function VFL.UI.Anchor:Apply(frame)
--	VFL.debug("Applying to frame " .. frame:GetName() .. " the anchor " .. self.sourcePoint .. "," .. self.targetFrame .. "," .. self.targetPoint .. "," .. self.offX .. "," .. self.offY);
	frame:SetPoint(self.sourcePoint, self.targetFrame, self.targetPoint, self.offX, self.offY);
end;

-------------------------------------
-- DYNAFRAME
-- An encapsulation of a relocatable World of Warcraft frame.
-- Used to make up for the lack of dynamically-creatable controls in the WOW UI engine.
-------------------------------------
VFL.UI.DynaFrame = {};

-- Construct a dynamic frame.
function VFL.UI.DynaFrame:new(f)
	-- Set up dynamic frame data structure.
	df = {};

	-- If a valid frame is passed, call internal init
	if(f) then VFL.UI.DynaFrame._init(df, f); end

	-- Object setup
	setmetatable(df, self);
	self.__index = self;
	return df;
end;

-- Internal initializer
function VFL.UI.DynaFrame._init(df, f)
	df.frame = f;
	df.frame.dynaframe = df; -- Back-associate the WOW UI obj. with this obj.
	df.id = f:GetID();
	-- Layout - describes the positioning and visibility of the parent dynaframe.
	df.layout = {};
	df.layout.dirty = true;
	df.layout.anchor1 = VFL.UI.Anchor:new({sourcePoint="TOPLEFT",targetFrame="UIParent",targetPoint="TOPLEFT",offX=0,offY=0});
	df.layout.anchor2 = nil;
	df.layout.height = nil; df.layout.width = nil; df.layout.scale=nil;
	df.visible = false;
	-- Data - describes the ultimate content of the dynaframe.
	df.data = {};
end;

-- Get the WOW frame associated with a dynaframe.
function VFL.UI.DynaFrame:GetFrame()
	return self.frame;
end;

-- Visibility controls
function VFL.UI.DynaFrame:IsVisible()
	return self.visible;
end;
function VFL.UI.DynaFrame:Show()
	self.visible = true;
end;
function VFL.UI.DynaFrame:Hide()
	self.visible = false;
end;
function VFL.UI.DynaFrame:ForceHide()
	self.visible = false;
	self.frame:Hide();
end;

-- Set the main anchor of the frame.
function VFL.UI.DynaFrame:SetAnchor(x1, x2, x3, x4, x5)
	self.layout.anchor1:Set(x1, x2, x3, x4, x5);
	self.layout.dirty = true;
end;

-- Apply layout, if necessary.
function VFL.UI.DynaFrame:ApplyLayout()
	if not self.layout.dirty then return; end
	self.frame:ClearAllPoints();
	self.layout.anchor1:Apply(self.frame);
	if(self.layout.anchor2) then self.layout.anchor2:Apply(self.frame); else
		if(self.layout.width) then self.frame:SetWidth(self.layout.width); end
		if(self.layout.height) then self.frame:SetHeight(self.layout.height); end
	end
	if(self.layout.scale) then self.frame:SetScale(self.layout.scale); end
	self.layout.dirty = false;
end;

-- Apply visibility, if necessary.
function VFL.UI.DynaFrame:ApplyVisibility()
	if self.frame:IsVisible() then
		if not self.visible then self.frame:Hide(); end
	else
		if self.visible then self.frame:Show(); end
	end
end;

-- Apply style, if necessary.
-- INTENDED TO BE OVERRIDDEN IN CHILD CLASS
function VFL.UI.DynaFrame:ApplyStyle()
	VFL.debug("DynaFrame:ApplyStyle() should never be called.");
end;

-- Apply data.
-- INTENDED TO BE OVERRIDDEN IN CHILD CLASS
function VFL.UI.DynaFrame:ApplyData()
	VFL.debug("DynaFrame:ApplyData() should never be called.");
end;

-- Generic update. Calls all other apply functions
function VFL.UI.DynaFrame:Update()
--	VFL.debug("Dynaframe:Update() for frame: " .. self.frame:GetName());
	self:ApplyVisibility();
	if(self.visible) then
		self:ApplyLayout();
		self:ApplyStyle();
		self:ApplyData();
	end
end;

-----------------------------
-- A pooled group of Dynaframes that orients itself vertically.
-- Also automatically releases unused frames into the parent pool.
-----------------------------
VFL.UI.Scaffold = VFL.Pool:new();

-- Construct a new scaffold with the given container frame.
function VFL.UI.Scaffold:new(container, parentPool)
	if(not container) then
		VFL.debug("Scaffold:new : scaffold may not have a nil container.");
		return nil;
	end
	local o = VFL.Pool.new(VFL.UI.Scaffold); -- Inherit
	o.container = container;
	o:SetParentPool(parentPool);
	return o;
end;

-- Construct a static scaffold of preexisting controls.
function VFL.UI.Scaffold:Static(container, ty, prefix, n, allowCompress)
	local o = VFL.UI.Scaffold:new(container, nil);
	-- Put the static controls into the scaffold
	for i=1,n do
		o:Release(ty:new(getglobal(prefix .. i)));
	end
	-- Disable compression
	if not allowCompress then
		o._findCompressIndex = function(self)
			return self:GetSize();
		end;
	end
	-- Lay out the scaffold
	o:ApplyLayout();
	return o;
end;

-- Update the layouts of all frames in the Scaffold.
function VFL.UI.Scaffold:ApplyLayout()
	if not self.pool[1] then return; end -- nothing to do
	self.pool[1]:SetAnchor("TOPLEFT", self.container:GetName(), "TOPLEFT", 0, 0);
	for i=2,self:GetSize() do
		self.pool[i]:SetAnchor("TOPLEFT", self.pool[i-1]:GetFrame():GetName(), "BOTTOMLEFT", 0, 0);
	end
end;

-- Overridden resize routine -- if the size changes, then update the layouts.
function VFL.UI.Scaffold:Size(n)
	local x = VFL.Pool.Size(self, n); -- call parent
	if x and (x > 0) then
		-- We've acquired some new frames, reanchor them.
		self:ApplyLayout();
	end
	return x;
end;

-- Compress a Scaffold down to the minimum necessary size.
function VFL.UI.Scaffold:_findCompressIndex()
	local i=1;
	while true do
		if not self.pool[i] then do break end end
		if not self.pool[i]:IsVisible() then return i-1; end
		i = i + 1;
	end
	return i-1;
end;
function VFL.UI.Scaffold:Compress()
	self:Size(self:_findCompressIndex());
end;

-- Update a Scaffold.
function VFL.UI.Scaffold:Update()
	local w,h;
	local ci = self:_findCompressIndex();
	-- Compress the pool, hiding unused frames.
	self:Size(ci);
	if(ci < 1) then return; end -- nothing to do
	self.pool[1]:Update();
	w = self.pool[1]:GetFrame():GetWidth();
	h = self.pool[1]:GetFrame():GetHeight();
	for i=2,ci do
		self.pool[i]:Update();
		h = h + self.pool[i]:GetFrame():GetHeight();
	end
	for i=ci+1,table.getn(self.pool) do
		self.pool[i]:ForceHide();
	end
	-- Resize the container frame.
	self.container:SetWidth(w);
	self.container:SetHeight(h);
end;

-- Forcefully hide all frames in a scaffold.
function VFL.UI.Scaffold:HideAll()
	for i=1,self:GetSize() do
		self.pool[i]:Hide();
		self.pool[i]:Update();
	end
end;

---------------------------------------
-- Generic selectable dynaframe.
-- Implements the XML buttonclass VFLListEntryT.
-- Intended to be used with the VFL.UI.List class
---------------------------------------
VFL.UI.ListEntry = VFL.UI.DynaFrame:new();

function VFL.UI.ListEntry:new(f)
	local o = VFL.UI.DynaFrame.new(VFL.UI.ListEntry, f); -- superclass new
	return o;
end;

-- List entries have no style params
function VFL.UI.ListEntry:ApplyStyle()
end;

-- Apply the entry text to the text box.
function VFL.UI.ListEntry:ApplyData()
	if not self.data.entry or not self.data.entry.text then
		return; -- No data to display.
	end
	if self.data.selected then
		getglobal(self.frame:GetName().."Sel"):Show();
		getglobal(self.frame:GetName().."Sel"):SetVertexColor(1,1,1,0.5);
	else
		getglobal(self.frame:GetName() .. "Sel"):Hide();
	end
	self.frame:SetText(self.data.entry.text);
end;

--------------------------------------
-- A list box.
-- Number of visible entries is fixed at creation time.
-- Entries are drawn from a scaffold.
-- Dynaframes in the underlying scaffold have their DATA.ENTRY
-- field set to the corresponding list entry before rendering is performed.
--------------------------------------
function VFL.UI.List:new(o)
	local l = o or {};
	setmetatable(l, self);
	self.__index = self;
	return l;
end;

function VFL.UI.List:init(scaf, vis, scroller)
	self.scaffold = scaf;
	self.vis = vis;
	self.offset = 0;
	self.entries = {};
	self.scroll = scroller;
	if(self.scroll) then self.scroll:Hide(); end
end;

-- Clear the list
function VFL.UI.List:Clear()
	self.entries = {};
end;

-- Get the size of the list
function VFL.UI.List:GetSize()
	return table.getn(self.entries);
end;

-- Add an entry to the end of the list.
function VFL.UI.List:Add(entry)
	entry.list = self;
	table.insert(self.entries, entry);
end;

-- Add an entry at a position.
function VFL.UI.List:AddAt(pos, entry)
	entry.list = self;
	table.insert(self.entries, pos, entry);
end;

-- Remove an entry from the list by number.
function VFL.UI.List:Remove(pos)
	table.remove(self.entries, pos);
end;

-- Remove an entry from the list by pointer comparison.
function VFL.UI.List:RemoveEntry(e)
	local p = VFL.table.find(e, self.entries)
	if p then table.remove(self.entries, p); end
end;

-- Swap the positions of two entries already in the list.
function VFL.UI.List:SwapEntries(i, j)
	-- Check existence
	if (not self.entries[i]) or (not self.entries[j]) then return false; end
	-- Swap pointers
	local p1 = self.entries[j];
	self.entries[j] = self.entries[i];
	self.entries[i] = p1;
end;

-- Enable scroll bar; anchor appropriately to the side of the list.
function VFL.UI.List:ShowScrollBar()
	if not self.scroll then return; end -- no scrollbar, nothing to do
	if self.scroll:IsVisible() then return; end -- scrollbar already visible
	-- Anchor scrollbar to list edge
	self.scroll:ClearAllPoints();
	self.scroll:SetPoint("TOPLEFT", self.scaffold.container:GetName(), "TOPRIGHT", 0, -16);
	self.scroll:SetPoint("BOTTOMLEFT", self.scaffold.container:GetName(), "BOTTOMRIGHT", 0, 16);
	-- Set scroll callback
	local q = self;
	self.scroll.onScroll = function(n) q:_Scroll(n); end
	-- Show it
	self.scroll:Show();
end;

function VFL.UI.List:HideScrollBar()
	if not self.scroll then return; end
	self.scroll:Hide();
end;

-- Update in response to change of list contents. Enables scrollbar if needed.
function VFL.UI.List:Update()
	if(self.scroll) and (table.getn(self.entries) > self.vis) then
		self:ShowScrollBar();
		self.scroll:SetMinMaxValues(0, 10 * table.getn(self.entries));
		self.scroll:SetValue(self.offset * 10);
	else
		self:HideScrollBar();
	end
	self:RenderEntries();
end;

-- Scroll bar callback.
function VFL.UI.List:_Scroll(n)
	self.offset = math.floor( (n / 10.0) + 0.5 );
	self:RenderEntries();
end;

-- On-click callback for the list. Intended to be overridden.
function VFL.UI.List:onClick(df, btn)
end;

-- A version of onclick that selects the entry.
function VFL.UI.List.selectOnClick(self, df, btn)
	self.selected = df.data.entry;
	self:RenderEntries();
end;

-- Render list entries
function VFL.UI.List:RenderEntries()
	local df, n;
	for i=1,self.vis do
		df = self.scaffold:Get(i);
		n = i + self.offset;
		if not self.entries[n] then
			df.data.entry = nil;
			df:Hide();
		else
			df.list = self; -- back-associate the dynaframe with the list...
			df.data.entry = self.entries[n];
			if(self.selected) and (self.selected == self.entries[n]) then
				df.data.selected = true;
			else
				df.data.selected = nil;
			end
			df:Show();
		end
	end
	self.scaffold:Update();
end;

-- Helper routine - automatically set up an XML list box with its scaffold.
function VFL.UI.List._buildFromXML(name, n)
	local o = VFL.UI.List:new();
	local scaf = VFL.UI.Scaffold:Static(getglobal(name .. "L"), VFL.UI.ListEntry, name .. "LB", n, false);
	o:init(scaf, n, getglobal(name .. "Scroll"));
	return o;
end;
function VFL.UI.List.ListBoxFromXML(name)
	return VFL.UI.List._buildFromXML(name, 10);
end;
function VFL.UI.List.BigListBoxFromXML(name)
	return VFL.UI.List._buildFromXML(name, 20);
end;

-- Helper routine - move an entry from one list to another.
function List_MoveSelectedEntry(from, to)
	local m = from.selected;
	if not m then return; end -- nothing selected
	-- Remove the selected buff from the all list.
	from:RemoveEntry(m);
	from.selected = nil;
	-- Add it to the selected list
	to:Add(m);
	-- Redraw both lists.
	from:Update();
	to:Update();
end;

------------------
-- PopMenu - a non-scrollbar list that resizes its parent to the current list size.
------------------
VFL.UI.PopMenu = {};

-- Internal pool of popup menus.
VFL.UI.PopMenu.pool = VFL.Pool:new();
-- Set the internal pool to destroy/hide on release.
VFL.UI.PopMenu.pool:DoOnRelease(function(o)
	o.list.entries = {}; -- besure to release entries for dynabuilt menus
	o:Hide();
end)

function VFL.UI.PopMenu:new(o)
	local x = o or {};
	setmetatable(x, self);
	self.__index = self;
	return x;
end;

function VFL.UI.PopMenu.onClick(list, df, btn)
	-- If there is no onClick routine, then they clicked an inactive "separator" -- forget it
	if not df.data.entry.onClick then
		return;
	end
	-- If the item clicked is not a submenu, destroy all submenus.
	if not df.data.entry.submenu then
		df.list.popmenu:ReleaseAll();
	end;
	-- Activate the onclick routine if it exists
	df.data.entry.onClick(df,btn);
end;

function VFL.UI.PopMenu:init(f)
	self.frame = f;
	self.submenu = nil;
	self.parent = nil;
	self.list = VFL.UI.List:new();
	self.list.popmenu = self;
	self.list.onClick = VFL.UI.PopMenu.onClick;
	local scaf = VFL.UI.Scaffold:Static(getglobal(f:GetName().."L"), VFL.UI.ListEntry, f:GetName().."LB", 20, true);
	self.list:init(scaf, 1, nil);
end;

-- Repoint the entry list for the popup menu.
function VFL.UI.PopMenu:SetEntries(e)
	self.list.entries = e;
end;

-- Update the menu on screen.
function VFL.UI.PopMenu:Update()
	-- Render list.
	self.list.vis = self.list:GetSize();
	self.list:RenderEntries();
	-- Resize parent window to the list height.
	self.frame:SetHeight(self.list.scaffold.container:GetHeight() + 23);
end;

-- Show the popup menu; render entries
function VFL.UI.PopMenu:Show()
	self.frame:Show();
	self:Update();
	-- Determine if after showing the menu, we moved off the screen...
	if self.frame:GetBottom() <= 0 then
		-- Move us up by exactly enough to keep it onscreen...
		self.frame:SetPoint("TOPLEFT", "UIParent", "BOTTOMLEFT", self.frame:GetLeft(), self.frame:GetHeight());
	end
end;

-- Hide the popup menu, destroying junk
function VFL.UI.PopMenu:Hide()
	self.list.scaffold:HideAll();
	self.frame:Hide();
end;

-- Release this popup menu back into the pool.
function VFL.UI.PopMenu:Release()
	self.list.entries = nil; -- Free any closures
	VFL.UI.PopMenu.pool:Release(self);
end;

-- Release recursively
function VFL.UI.PopMenu:ReleaseRecursive()
	if(self.submenu) then self.submenu:ReleaseRecursive(); end
	self:Release();
end;

-- Hide all menus in this hierarchy
function VFL.UI.PopMenu:ReleaseAll()
	local t = self;
	while(t.parent) do t=t.parent; end
	t:ReleaseRecursive();
end;

-- Helper function: show submenu
function ShowSubMenu(df, btn)
	local menu = df.list.popmenu;
	local smentries = VFL.func.callIfFunction(df.data.entry.submenu);
	local sm = VFL.UI.PopMenu.pool:Acquire();
	if not sm then
		VFL.debug("Ran out of popup menus.");
		return;
	end
	-- Register the menu as a child
	menu.submenu = sm;
	sm.parent = menu;
	-- Setup the entries
	sm:SetEntries(smentries);
	-- Anchor the submenu
	sm.frame:SetPoint("TOPLEFT", df:GetFrame():GetName(), "TOPRIGHT", 0, 0);
	-- Show it
	sm:Show();
end;

-- Show popup menu with the given anchor setup
VFL.UI._popMenu = nil;
function VFL.UI.ShowPopupMenu(entries, aPoint, aRel, aRelPoint, ax, ay)
	-- If nothing to do, do nothing
	if (not entries) or (table.getn(entries) == 0) then return false; end
	-- If there was already a root menu, destroy it
	if(VFL.UI._popMenu) then
		VFL.UI._popMenu:ReleaseAll();
	end
	VFL.UI._popMenu = VFL.UI.PopMenu.pool:Acquire();
	if (not VFL.UI._popMenu) then
		VFL.debug("Ran out of popup menus.");
		return false; 
	end
	VFL.UI._popMenu:SetEntries(entries);
	VFL.UI._popMenu.frame:SetPoint(aPoint, aRel, aRelPoint, ax, ay);
	VFL.UI._popMenu:Show();
end;

-------------------------------------------
-- Supporting functions for dropdown list.
-------------------------------------------
VFL.UI.DropDown = {};
VDD.list = VFL.UI.List.ListBoxFromXML("VDD");

function VFL.UI.DropDown_OnClick(self, df, btn)
	self.dropdown.selected = df.data.entry;
	self.dropdown:Update();
	VDD:Hide();
end;

VDD.list.onClick = VFL.UI.DropDown_OnClick;

function VFL.UI.DropDown_Update(self)
	if not self.selected then
		self.textBox:SetText("");
	else
		self.textBox:SetText(self.selected.text);
		if(self.callback) then
			self.callback(self.callbackObj, self.selected);
		end
	end
end;

function VFL.UI.DropDown_Toggle(self)
	-- If the dropdown was already open for this frame, vanish it.
	if(VDD:IsVisible()) and (VDD.list.dropdown == self) then
		VDD:Hide();
		return;
	end
	-- Reanchor the dropdown to this frame
	VDD:SetPoint("TOPLEFT", self:GetName(), "BOTTOMLEFT", 0, 0);
	-- Reset the entries
	VDD.list.dropdown = self;
	VDD.list.entries = self.entries;
	-- SHow and update the dropdown
	VDD:Show();
	VDD.list:Update();
end;

function VFL.UI.DropDown_Select(self, field, value)
	self.selected = nil;
	for _,v in self.entries do
		if v[field] and v[field]==value then
			self.selected = v;
			break;
		end
	end
	self:Update();
end;

-----------------------------------
-- Supporting functions for checkbox frame
-----------------------------------
function BooleanToCheck(bln, checkName)
	check = getglobal(checkName .. "Chk");
	if(bln) then check:SetChecked(true); else check:SetChecked(false); end
end;

function BooleanFromCheck(checkName)
	check = getglobal(checkName .. "Chk");
	return check:GetChecked();
end;

-----------------------------------
-- Supporting functions for color swatch.
-----------------------------------
function VFL.UI.Swatch_Click()
	local sw = this;
	ColorPickerFrame.func = function()
		local r,g,b = ColorPickerFrame:GetColorRGB();
		sw:SetColor(r,g,b);
	end;
	ColorPickerFrame.hasOpacity = false;
--	ColorPickerFrame.hasOpacity = button.hasOpacity;
--	ColorPickerFrame.opacityFunc = button.opacityFunc;
--	ColorPickerFrame.opacity = button.opacity;
	ColorPickerFrame:SetColorRGB(this.r, this.g, this.b);
	ColorPickerFrame.previousValues = {r = this.r, g = this.g, b = this.b, opacity = this.a};
	ColorPickerFrame.cancelFunc = function()
		local r,g,b = ColorPickerFrame:GetColorRGB();
		VFL.debug("ColorPickerCancel r "..r.." g "..g.." b "..b);
		sw:SetColor(ColorPickerFrame.previousValues.r, ColorPickerFrame.previousValues.g, ColorPickerFrame.previousValues.b);
	end;
	ShowUIPanel(ColorPickerFrame);
end;

function VFL.UI.Swatch_SetColor(self, r, g, b)
	self.r = r; self.g = g; self.b = b;
	getglobal(self:GetName() .. "_SwatchTexture"):SetVertexColor(r,g,b);
	getglobal(self:GetName() .. "_BorderTexture"):SetVertexColor(r,g,b);
end;

function ColorToSwatch(ctbl, swatch)
	swatch:SetColor(ctbl.r, ctbl.g, ctbl.b);
end;

function ColorFromSwatch(ctbl, swatch)
	ctbl.r = swatch.r; ctbl.g = swatch.g; ctbl.b = swatch.b;
end;

-------
-- Supporting functions for message box.
-------
function VFL.UI.MessageBox(caption, showTextEntry, callback)
	VFLMsgBoxLblTxt:SetText(caption);
	VFLMsgBoxEdit:SetText("");
	if(showTextEntry) then
		VFLMsgBoxEdit:Show();
	else
		VFLMsgBoxEdit:Hide();
	end
	VFLMsgBox.callback = callback;
	VFLMsgBox:Show();
end;

----
-- Initialize VFL UI objects
----
function VFL.UI.init()
	-- Populate the popup menu pool.
	for i=1,3 do
		local f = getglobal("VP" .. i);
		if not f then
			VFL.debug("VFL.UI.init: invalid popmenu frame VP"..i);
		else
			local p = VFL.UI.PopMenu:new();
			p:init(f);
			VFL.UI.PopMenu.pool:Release(p);
		end
	end
end;


