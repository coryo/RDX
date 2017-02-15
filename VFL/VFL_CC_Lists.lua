-- VFL_CC_Lists.lua
-- VFL
-- Venificus' Function Library
--
-- Common controls representing list boxes of various kinds.

-----------------------------------
-- SELECTABLE
-- A basic list element.
-----------------------------------
if not VFL.Selectable then VFL.Selectable = {}; end
function VFL.Selectable.Imbue(x)
	local n = x:GetName();
	-- Internals
	x.selTexture = getglobal(n .. "Sel");
	x.text = getglobal(n .. "Txt");
	x.icon = getglobal(n.."Icon");
	x.purpose = 1;
	-- Functionality
	x.Select = VFL.Selectable.Select;
	x.Unselect = VFL.Selectable.Unselect;
	x.SetSize = VFL.Selectable.SetSize;
	x.SetPurpose = VFL.Selectable.SetPurpose;
end

function VFL.Selectable:Select()
	self.selTexture:SetVertexColor(0,0,1,0.3);
	self.selTexture:Show();
end

function VFL.Selectable:Unselect()
	self.selTexture:Hide();
end

function VFL.Selectable:SetSize(dx,dy)
	-- If no change, do nothing...
	if(self:GetWidth() == dx) and (self:GetHeight() == dy) then return; end
	self:SetWidth(dx); self:SetHeight(dy);
	-- Apply repurposing routine
	VFL.Selectable.Repurpose[self.purpose](self);
end

function VFL.Selectable.SetPurpose(self, n)
	if self.purpose ~= n then
		self.purpose = n;
		VFL.Selectable.Repurpose[n](self); 
	end
end

------- PURPOSES
VFL.Selectable.Repurpose = {};
-- Purpose 1: Left=aligned text, no icons
VFL.Selectable.Repurpose[1] = function(self, force)
	local dx,dy = self:GetWidth(), self:GetHeight();
	-- Resize textbox to the full size
	self.text:SetPoint("TOPLEFT", self, "TOPLEFT");
	self.text:SetWidth(dx-1); self.text:SetHeight(dy); self.text:SetJustifyH("LEFT");
	-- Hide icon
	self.icon:Hide();
end
-- Purpose 2: Left-aligned text, rightward-pointing arrow icon
VFL.Selectable.Repurpose[2] = function(self, force)
	local dx,dy = self:GetWidth(), self:GetHeight();
	-- Resize textbox to the full size
	self.text:SetPoint("TOPLEFT", self, "TOPLEFT");
	self.text:SetWidth(dx-1); self.text:SetHeight(dy); self.text:SetJustifyH("LEFT");
	-- Setup icon
	self.icon:ClearAllPoints(); self.icon:SetPoint("RIGHT", self, "RIGHT");
end
-- Purpose 3: Right-aligned text, left-pointing arrow icon
VFL.Selectable.Repurpose[3] = function(self, force)
	local dx,dy = self:GetWidth(), self:GetHeight();
	-- Resize textbox to the full size
	self.text:SetPoint("TOPLEFT", self, "TOPLEFT");
	self.text:SetWidth(dx-1); self.text:SetHeight(dy); self.text:SetJustifyH("RIGHT");
	-- Setup icon
	self.icon:ClearAllPoints(); self.icon:SetPoint("LEFT", self, "LEFT");
end
-- Purpose 4: Icon on the left with text anchored beside it
VFL.Selectable.Repurpose[4] = function(self, force)
	local dx,dy = self:GetWidth(), self:GetHeight();
	-- Setup icon
	self.icon:ClearAllPoints(); self.icon:SetPoint("LEFT", self, "LEFT"); self.icon:Show();
	-- Anchor textbox to icon
	self.text:ClearAllPoints();
	self.text:SetPoint("LEFT", self.icon, "RIGHT");
	self.text:SetWidth(dx-(self.icon:GetWidth())); self.text:SetHeight(dy); self.text:SetJustifyH("LEFT");
end


--Interface\InventoryItems\WoWUnknownItem01.blp


-----------------------------------
-- LIST CONTROL
-- A list control is an n-row, 1-column grid of interactive elements.
-- Elements must be of type FrameCell.
-----------------------------------
if not VFL.ListControl then VFL.ListControl = {}; end
VFL.ListControl.__index = VFL.ListControl;

function VFL.ListControl:new(container, cellPool, fnApplyData, scrollbar)
	local x = VFL.Grid:new();
	x.data = {};
	-- Pull an element from a control pool, with a twist.
	-- On allocate, bind the grid's OnClick handler after the button's
	-- original OnClick handler, whatever it may be. Store the original
	-- OnClick handler in c.plcOnClick for later repair.
	x.allocFunc = function(g)
		local c = cellPool:Acquire();
		c:SetParent(container);
		c.OnClick = function(frameClicked, arg)
			if(g.OnClick) then g:OnClick(frameClicked, arg); end
		end
		c.OnGridRelease = g.releaseFunc;
		return c;
	end
	-- Restore the OnClick functionality of the cell before returning it
	-- to the pool.
	x.releaseFunc = function(c,g)
		c.data = nil; -- BUGFIX: Ensure the release of allocated data memory.
		cellPool:Release(c);
	end
	-- Virtualize the grid, creating a scrolling view of data
	x:Virtualize(
	function(l) return 1,table.getn(l.data); end,
	function(l, x, y) return l.data[y]; end,
	fnApplyData
	);
	-- Bind main functionality
	x.Build = VFL.ListControl.Build;
	x.OnScroll = VFL.ListControl.OnScroll;
	x.UpdateContent = VFL.ListControl.UpdateContent;
	x.ChangeScrollFlag = VFL.ListControl.ChangeScrollFlag;
	-- Bind scrollbar
	if(scrollbar) then
		x.scrollbar = scrollbar;
		x.scrollflag = false;
		x.scrollbar.OnScroll = function(sv) x:OnScroll(sv); end
	end
	-- Done
	return x;
end

-- Construct a listcontrol in place
function VFL.ListControl:Build(cellHeight, cellWidth, nCells, data, ...)
	-- Store demographics
	self._ch = cellHeight; self._cw = cellWidth; self._nc = nCells; self._anc = arg;
	-- Now set up data.
	self.data = data;
	-- Now display the content
	self:UpdateContent(true);
end

-- Construct the scaffold for a list control.
function VFL.ListControl:ChangeScrollFlag(nsf, force)
	-- No change in scrollflag = abort.
	if (not force) and (nsf == self.scrollflag) then return; end
	self.scrollflag = nsf;
	-- Destroy preexisting list
	self:Destroy();
	if nsf and self.scrollbar then
		self:BuildList(self.allocFunc, self._ch, self._cw - 18, self._nc, unpack(self._anc));
		self.scrollbar:ClearAllPoints();
		self.scrollbar:SetPoint("TOPLEFT", self:GetCell(1,1):GetName(), "TOPRIGHT", 0, -16);
		self.scrollbar:SetWidth(16);
		self.scrollbar:SetHeight((self._ch*self._nc) - 32);
		self.scrollbar:SetFrameLevel(10);
		self.scrollbar:Show();
	else
		if self.scrollbar then 
			self.scrollbar:Hide();
			self.scrollbar:SetMinMaxValues(0, 0);
			self.scrollbar:SetValue(0);
		end
		self:SetScroll(0, 0);
		self:BuildList(self.allocFunc, self._ch, self._cw, self._nc, unpack(self._anc));
	end
end

function VFL.ListControl:OnScroll(value)
	local sx,sy = self:GetScroll();
	local sv = math.floor(value/10);
	if(sy ~= sv) then
		self:SetScroll(0, sv); 
	end
end

function VFL.ListControl:UpdateContent(force)
	local _,sr = self:GetScrollRanges();
	if(sr == 0) or (not self.scrollbar) then
		self:ChangeScrollFlag(false, force);
	else
		self:ChangeScrollFlag(true, force);
		_,sr = self:GetScrollRanges(); -- BUGFIX: Reacquire the scroll ranges after window build.
		self.scrollbar:Show();
		self.scrollbar:SetMinMaxValues(0, sr*10);
		local _,v=self:GetScroll();
		VFL.CC.Scroll_DisableBtns(self.scrollbar);
		self.scrollbar:SetValue(v*10);
	end
	self:VirtualUpdate();
end

---------------------------------------
-- STANDARD LIST
-- A standard list is a list in which one single element can be
-- selected, and each data element has a "text" field indicating
-- the text that should be rendered. The result of a click on a
-- standard list is to select the corresponding item.
---------------------------------------
if not VFL.StdList then VFL.StdList = {}; end

function VFL.StdList:ApplyData(cell, data, vx, vy, x, y)
	-- If no data, hide cell
	if not data then cell:Hide(); return; else cell:Show(); end
	if not data.icon then
		cell:SetPurpose(1);
	else
		cell:SetPurpose(4);
		cell.icon:SetTexture(data.icon);
	end
	-- Apply the data text.
	cell:SetText(data.text);
	-- If the cell is the selected cell, highlight it.
	if(vy == self.selected) then cell:Select(); else cell:Unselect(); end
end

function VFL.StdList:OnClick(cell, arg)
	local _,y = self:VirtualPos(cell);
	self.selected = y;
	self:VirtualUpdate();
end

function VFL.StdList:new(container, eltPool, scrollbar)
	local x = VFL.ListControl:new(container, eltPool, VFL.StdList.ApplyData, scrollbar);
	x.OnClick = VFL.StdList.OnClick;
	return x;
end

-------------------------------------
-- SCROLLLIST
-- Implementation for the VFLScrollListT class.
-- USAGE: OnShow call Setup(), OnHide call Destroy(), data resides at self.data
-------------------------------------
if not VFL.ScrollList then VFL.ScrollList = {}; end
function VFL.ScrollList.Imbue(f)
	-- Setup frame level
	f:SetFrameLevel(5);
	-- Create a framepool containing the ScrollList's frames
	f.framePool = VFL.Pool:new();
	f.framePool.OnRelease = function(pool, x) x:Hide(); end;
	f.framePool:Fill(f:GetName() .. "L");
	f.list = VFL.StdList:new(f, f.framePool, getglobal(f:GetName() .. "SB"));
	f.Setup = VFL.ScrollList.Setup;
end

function VFL.ScrollList:Setup()
	self.list:Build(16, self:GetWidth(), self.framePool:GetSize(), {}, self, "TOPLEFT");
end


