-- Grid.lua
-- VFL
-- (C)2006 Bill Johnson

------------------------------------------------------------
------------------------------------------------------------
-- GRID
-- A grid is a rectangular array of frames which can itself
-- be manipulated like a frame.
-- 
-- A grid can be built using the Size() method, which will
-- allocate an array of frames using a user-provided allocator
-- function.
--
-- Every frame in a grid should be given an OnDeparent method, which
-- will be called when the frame is released from the grid.
------------------------------------------------------------
------------------------------------------------------------
VFLUI.Grid = {};
VFLUI.Grid.__index = VFLUI.Grid;

----------------------------------------------------------------------------------------------
-- INTERNAL IMPLEMENTATION
----------------------------------------------------------------------------------------------
-- Glue two frames together along a shared corner
local function glue(grid, lastx, lasty, lastframe, thisx, thisy, thisframe, padx, pady)
--	VFLUI:Debug(10, "gluing cell " .. thisx .. "," .. thisy);
	thisframe:ClearAllPoints();
	if(lasty == thisy) then
		if(lastx < thisx) then
			-- Last anchored frame was left of this one.
			-- Anchor the topleft of this one to the topright of the next
			thisframe:SetPoint("TOPLEFT", lastframe, "TOPRIGHT", padx, 0);
		else
			-- The last frame was to the right of this one.
			-- Anchor the topright of this to the topleft of last
			thisframe:SetPoint("TOPRIGHT", lastframe, "TOPLEFT", -padx, 0);
		end
	else
		-- Get the last frame from the previously laid-out row
		lastframe = grid.cells[thisx][lasty];
		if(lasty < thisy) then
			-- Last frame is above this one.
			-- Anchor topleft to bottomleft.
			thisframe:SetPoint("TOPLEFT", lastframe, "BOTTOMLEFT", 0, -pady);
		else
			-- Last frame is below this one.
			-- Anchor bottomleft to topleft
			thisframe:SetPoint("BOTTOMLEFT", lastframe, "TOPLEFT", 0, pady);
		end
	end
end

-- Update the interior cell layout for the grid
local function UpdateLayout(self)
	-- Get the first cell
	local it = self:Iterator(1);
	local c, x, y = it();
	-- If the grid is empty, terminate
	if not c then
		return; 
	end
	-- Anchor the first frame to the container
	c:ClearAllPoints();
	c:SetPoint("TOPLEFT", self, "TOPLEFT");
	-- Finish the layout operation
	local oldc, oldx, oldy = c, x, y;
	for c,x,y in it do
		glue(self, oldx, oldy, oldc, x, y, c, 0, 0);
		oldx = x; oldy = y; oldc = c;
	end
end

-- Remove/deparent a cell known to exist
local function RemoveCellAt(grid, x, y)
	local c = grid.cells[x][y];
	grid.cells[x][y] = nil;
	if (c and (c.OnDeparent)) then c:OnDeparent(); c.OnDeparent = nil; end
end

-- Apply all UI-specific primitives necessary to make the cell appear
-- correctly in the grid.
local function OrientCell(grid, cell)
	cell:SetParent(grid); cell:SetScale(1);
	cell:SetFrameStrata(grid:GetFrameStrata());
	cell:SetFrameLevel(grid:GetFrameLevel() + 1);
	-- Perform any additional orientation tasks.
	if grid.OnOrient then grid:OnOrient(cell); end
end

----------------------------------------------------------------------------------------
-- MUTATORS
----------------------------------------------------------------------------------------
-- Clear the grid, freeing all cells.
function VFLUI.Grid:Clear()
	for x=1,self.dx do
		for y=1,self.dy do
			RemoveCellAt(self, x, y);
		end
	end
	self.dx = 0; self.dy = 0; self.cells = {};
end

-- Size the grid to the given width and height.
-- 
-- OnAlloc(x,y) is called each time a newly allocated cell is touched. Its return
-- value is placed in the cell.
function VFLUI.Grid:Size(w, h, OnAlloc)
	-- Do-nothing check
	if(w == self.dx) and (h == self.dy) then return; end
	-- Destroy all out-of-bounds cells
	for x=1,self.dx do
		for y=1,self.dy do
			if(x>w) or (y>h) then
				RemoveCellAt(self, x, y);
			end
		end
		if(x>w) then self.cells[x] = nil; end
	end
	-- Allocate missing cells
	for x=1,w do
		if not self.cells[x] then self.cells[x] = {}; end
		for y=1,h do
			if not self.cells[x][y] then
				local c = nil;
				if OnAlloc then 
					c = OnAlloc(self, x, y); OrientCell(self, c);
				end
				self.cells[x][y] = c;
			end
		end
	end
	-- Update internal states
	self.dx = w; self.dy = h;
	-- Run layout engine
	UpdateLayout(self); self:ComputeFrameDimensions();
end

-- Insert a row of frames directly into the grid.
function VFLUI.Grid:InsertRow(pos, row)
	-- Make sure the target position is sane
	if(pos < 1) or (pos > self.dy) then return nil; end
	-- The row needs to have the right number of columns
	if(table.getn(row) ~= self.dx) then return nil; end
	for i=1,self.dx do
		OrientCell(self, row[i]);
		table.insert(self.cells[i], pos, row[i]);
	end
	-- Expand DY
	self.dy = self.dy + 1;
	return true;
end

-- Attach a frame to the END of a single-column grid.
function VFLUI.Grid:InsertFrame(f, pos)
	if (self.dx ~= 1) then return nil; end
	OrientCell(self, f);
	if pos then
		table.insert(self.cells[1], pos, f);
	else
		table.insert(self.cells[1], f);
	end
	self.dy = self.dy + 1;
	return true;
end

-- Remove a frame inserted by InsertFrame.
function VFLUI.Grid:RemoveFrame(f)
	if(self.dx ~= 1) or (self.dy < 1) then return nil; end
	local qq = self.cells[1];
	for i=1,self.dy do
		if (qq[i] == f) then 
			self.dy = self.dy - 1; table.remove(qq, i); return true; 
		end
	end
	return nil;
end

-- Delete a row of frames directly from the grid.
function VFLUI.Grid:DeleteRow(pos)
	-- Position sanity check
	if(pos < 1) or (pos > self.dy) or (self.dy == 0) then return false; end
	for i=1,self.dx do
		local c = table.remove(self.cells[i], pos);
		if(c.OnDeparent) then c:OnDeparent(); c.OnDeparent = nil; end
	end
	self.dy = self.dy - 1;
	return true;
end

-----------------------------------------------------------------------------
-- ITERATORS AND ACCESSORS
-----------------------------------------------------------------------------
-- Get the size of the grid
function VFLUI.Grid:GetSize()
	return self.dx, self.dy;
end
function VFLUI.Grid:GetNumRows() return self.dy; end
function VFLUI.Grid:GetNumColumns() return self.dx; end

-- Obtain an iterator over a region of the grid.
-- The iterator can move in various directions.
-- dir: 1=+x->+y 2=-x->+y 3=+x->-y 4=-x->-y 5 = +y->+x
function VFLUI.Grid:RegionIterator(x0, y0, x1, y1, dir)
	-- Bounds check for the iterator
	if(x0 < 1) or (y0 < 1) or (x1 < 1) or (y1 < 1) or (x0 > self.dx) or (y0 > self.dy) or (x1 > self.dx) or (y1 > self.dy) then
		return VFL.Nil;
	end	
	-- Switch based on the direction
	if(dir == 1) then
		local x,y = x0-1,y0;
		return function()
			x = x + 1;
			if(x > x1) then
				x = x0; y = y + 1;
				if(y > y1) then return nil; end
			end
			return self.cells[x][y], x, y;
		end;
	elseif(dir == 2) then
		local x,y = x1+1,y0;
		return function()
			x = x - 1;
			if(x < 1) then
				x = x1; y = y + 1;
				if(y > y1) then return nil; end
			end
			return self.cells[x][y], x, y;
		end;
	elseif(dir == 3) then
		local x,y = x0-1,y1;
		return function()
			x = x + 1;
			if(x > x1) then
				x = x0; y = y - 1;
				if(y < 1) then return nil; end
			end
			return self.cells[x][y], x, y;
		end;
	elseif(dir == 4) then
		local x,y = x1+1,y1;
		return function()
			x = x - 1;
			if(x < 1) then
				x = x1; y = y - 1;
				if(y < 1) then return nil; end
			end
			return self.cells[x][y], x, y;
		end
	elseif(dir == 5) then
		local x,y = x0, y0 - 1;
		return function()
			y = y + 1;
			if(y > y1) then
				y = y0; x = x + 1;
				if(x > x1) then return nil; end
			end
			return self.cells[x][y], x, y;
		end
	else
		error("VFLUI.Grid:RegionIterator() - invalid iterator direction");
	end
end

function VFLUI.Grid:Iterator(dir)
	if not dir then dir=1; end
	return self:RegionIterator(1,1,self.dx,self.dy,dir);
end

function VFLUI.Grid:RowIterator(row)
	return self:RegionIterator(1, row, self.dx, row, 1);
end

function VFLUI.Grid:ColumnIterator(col)
	return self:RegionIterator(col, 1, col, self.dy, 5);
end

------------------------------------------------------------------------------------
-- EXTENDED LAYOUT COMMANDS
------------------------------------------------------------------------------------
-- Sets the row heights and column widths.
-- The arguments can either be arrays (in which case each row height/column width is
-- set to the value of the corresponding array entry) or numbers (in which case each row height/
-- column width is set to the given value)
function VFLUI.Grid:SetCellDimensions(xdim, ydim)
	if type(xdim) == "table" then
		for c,x,y in self:Iterator() do
			if xdim[x] then c:SetWidth(xdim[x]); end
		end
	elseif type(xdim) == "number" then
		for c in self:Iterator() do
			c:SetWidth(xdim);
		end
	else
		error("xdim parameter to SetCellDimensions must be a table or number");
	end

	if type(ydim) == "table" then
		for c,x,y in self:Iterator() do
			if ydim[y] then c:SetHeight(ydim[y]); end
		end
	elseif type(ydim) == "number" then
		for c in self:Iterator() do
			c:SetHeight(ydim);
		end
	else
		error("ydim parameter to SetCellDimensions must be a table or number");
	end

	self:ComputeFrameDimensions();
end

-- Recompute all layout-related information (used when manipulating internal frames
-- directly)
function VFLUI.Grid:Relayout()
	UpdateLayout(self);	self:ComputeFrameDimensions();
end

------------------------------------------------------------------------------------
-- CONSTRUCTION
------------------------------------------------------------------------------------
--- Create a new Grid, optionally creating it as a child of the given parent.
-- @param parent (Optional) The frame to make this Grid a child of.
function VFLUI.Grid:new(parent)
	local self = VFLUI.AcquireFrame("Frame");

	if parent then
		self:SetParent(parent);
		self:SetFrameStrata(parent:GetFrameStrata());
		self:SetFrameLevel(parent:GetFrameLevel() + 1);
	end

	-- Get Blizz UI methods for overriding purposes
	local metaMethod = getmetatable(self).__index;
	local BlizzardSetHeight = metaMethod(self, "SetHeight");
	local BlizzardSetWidth = metaMethod(self, "SetWidth");

	-- Resize the container for this grid to appropriately accomodate the cells.
	self.ComputeFrameDimensions = function(s)
		if(s.dx == 0) or (s.dy == 0) then 
			BlizzardSetHeight(s, 0); BlizzardSetWidth(s, 0);
			return; 
		end
		local w, h = 0, 0;
		for c in s:RowIterator(1) do w = w + c:GetWidth(); end
		for c in s:ColumnIterator(1) do h = h + c:GetHeight(); end
		--VFLUI:Debug(7, "Grid(" .. tostring(s) .. "):ComputeFrameDimensions(): dx=" .. w .. " dy=" .. h);
		BlizzardSetHeight(s, h); BlizzardSetWidth(s, w);
	end

	-- Apply a downward layout constraint along the y-axis.
	self.SetHeight = function(s, height)
		VFLUI:Debug(7, "Grid(" .. tostring(s) .. "):SetHeight(" .. height .. ")");
		BlizzardSetHeight(s, height);
		if(s.dy == 0) then return; end
		height = height / s.dy;
		for c in s:Iterator() do c:SetHeight(height); end
	end

	-- Apply a downward layout constraint along the x-axis.
	self.SetWidth = function(s, width)
		VFLUI:Debug(7, "Grid(" .. tostring(s) .. "):SetWidth(" .. width .. ")");
		BlizzardSetWidth(s, width);
		if(s.dx == 0) then return; end
		width = width / s.dx;
		for c in s:Iterator() do c:SetWidth(width); end
	end

	-- Attach functions
	self.Size = VFLUI.Grid.Size;
	self.Clear = VFLUI.Grid.Clear;
	self.InsertRow = VFLUI.Grid.InsertRow;
	self.InsertFrame = VFLUI.Grid.InsertFrame;
	self.RemoveFrame = VFLUI.Grid.RemoveFrame;
	self.DeleteRow = VFLUI.Grid.DeleteRow;
	self.GetSize = VFLUI.Grid.GetSize;
	self.RegionIterator = VFLUI.Grid.RegionIterator;
	self.Iterator = VFLUI.Grid.Iterator;
	self.RowIterator = VFLUI.Grid.RowIterator;
	self.ColumnIterator = VFLUI.Grid.ColumnIterator;
	self.SetCellDimensions = VFLUI.Grid.SetCellDimensions;
	self.Relayout = VFLUI.Grid.Relayout;

	-- Setup destroy function
	self.Destroy = VFL.hook(function(self)
		self:Clear();

		self.ComputeFrameDimensions = nil; self.SetHeight = nil; self.SetWidth = nil;
		self.Size = nil;
		self.Clear = nil;
		self.InsertRow = nil;
		self.InsertFrame = nil;
		self.RemoveFrame = nil;
		self.DeleteRow = nil;
		self.GetSize = nil;
		self.RegionIterator = nil;
		self.Iterator = nil;
		self.RowIterator = nil;
		self.ColumnIterator = nil;
		self.SetCellDimensions = nil;
		self.Relayout = nil;

		self.OnOrient = nil;
	
		self.dx = nil; self.dy = nil; self.cells = nil;
	end, self.Destroy);
	
	-- Initialize
	self.dx = 0; self.dy = 0;
	self.cells = {};
	self:ClearAllPoints();

	return self;
end

--------------------------------
--------------------------------
-- VIRTUAL GRID
--
-- A VirtualGrid is a wrapper around a Grid that allows the grid to be
-- used as a view into an underlying data store.
--
-- The VirtualGrid contains the following member variables:
-- - vx - The virtual x-coordinate of the top-left square of the grid
-- - vy - The virtual y-coordinate of the top-left square of the grid
--
-- Closures must be provided by the user which do the following things:
-- - Render the cells of the grid from the underlying data source. (OnRenderCell)
-- - Determine the scroll boundaries of the virtual space. (GetVirtualSize)
--
-- self:OnRenderCell(cell, physicalX, physicalY, virtualX, virtualY) must update
-- the cell with its contents, extracted from the virtual space by whatever means
-- you choose.
--
-- self:GetVirtualSize() must return the maximum allowable values for vx and vy
-- acceptable to OnRenderCell.
---------------------------------
---------------------------------
VFLUI.VirtualGrid = {};
VFLUI.VirtualGrid.__index = VFLUI.VirtualGrid;

-- Create a virtual grid atop the given physical grid.
function VFLUI.VirtualGrid:new(phys)
	if not phys then return nil; end
	local self = {};
	self.vx = 1; self.vy = 1;
	setmetatable(self, VFLUI.VirtualGrid);
	self.physicalGrid = phys;
	return self;
end

-- Destroy a virtual grid and its underlying physical grid.
function VFLUI.VirtualGrid:Destroy()
	self.OnRenderCell = nil; self.GetVirtualSize = nil;
	self.physicalGrid:Destroy(); self.phys = nil;
end

-- Update the grid with the given virtual coordinates
function VFLUI.VirtualGrid:SetVirtualPosition(vx, vy)
	-- Sanify coordinates
	local vxMax, vyMax = self:GetVirtualSize();
	if(vx < 1) then vx = 1; elseif(vx > vxMax) then vx = vxMax; end
	if(vy < 1) then vy = 1; elseif(vy > vyMax) then vy = vyMax; end
	-- Update
	self.vx = vx; self.vy = vy;
	for c, x, y in self.physicalGrid:Iterator() do
		self:OnRenderCell(c, x, y, vx, vy);
	end
end

--------------------------------------------------------
--------------------------------------------------------
-- LIST
--
-- A list is a grid with one column and a fixed size. A list is
-- scrollable in the vertical direction; if more data is added to
-- the list than it has entries, a scrollbar is automatically allocated
-- and associated to the list.
--
-- The CreateList function returns an API object that allows access to
-- and manipulation of the underlying list.
--
-- API.SetData(data[], OnApplyData(cell, data)) - Sets the underlying
-- data array of the list, and the function to be used when rendering
-- the data. Also trips an update of the list.
--
-- API.Destroy() - Destroys the list and all underlying structures.
--
-- API.GetContainer() - Gets the containing grid object.
--------------------------------------------------------
--------------------------------------------------------
function VFLUI.CreateList(numCells, cellWidth, cellHeight, cellAlloc, parent)
	-- Create the grid
	local grid = VFLUI.Grid:new(parent);
	grid:Size(1, numCells, cellAlloc);
	grid:SetCellDimensions(cellWidth, cellHeight);
	-- Create the virtualizer
	local virt = VFLUI.VirtualGrid:new(grid);
	-- Create storage for the scrollbar
	local scrollbar = nil;
	-- Create storage for the data array
	local curData, dataSize, fnad = nil, 0, nil;

	-- Virtualizer supporting functions
	virt.GetVirtualSize = function()
		local q = dataSize - numCells + 1;
		if(q < 1) then q = 1; end
		return 1,q;
	end
	virt.OnRenderCell = function(v, c, x, y, vx, vy)
		local pos = y + vy - 1;
		if not curData[pos] then c:Hide(); else 
			c:Show(); fnad(c, curData[pos], pos); 
		end
	end

	local CreateScrollBar = function()
		-- Create the scrollbar object
		scrollbar = VFLUI.VScrollBar:new(grid);
		-- Resize the grid to accomodate the new scrollbar
		grid:SetCellDimensions(cellWidth - 16, cellHeight);
		-- Attach the scrollbar to the grid
		scrollbar:SetPoint("TOPLEFT", grid, "TOPRIGHT", 0, -16);
		scrollbar:SetWidth(16);
		scrollbar:SetHeight(grid:GetHeight() - 32);
		scrollbar:Show();
		grid.SetVerticalScroll = function(g, val) 
			local oldv, newv = virt.vy, math.floor(val);
			if(oldv ~= newv) then virt:SetVirtualPosition(1, newv); end
		end
	end

	local DestroyScrollBar = function()
		grid.SetVerticalScroll = nil;
		grid:SetCellDimensions(cellWidth, cellHeight);
		scrollbar:Destroy(); scrollbar = nil;
	end
	
	local SetData = function(nd, OnApplyData)
		curData = nd; fnad = OnApplyData;
		-- Update size
		dataSize = table.getn(curData);
		-- Determine if a scrollbar is needed
		local _,dy = virt:GetVirtualSize();
		if(dy > 1) then
			if (not scrollbar) then CreateScrollBar(); end
			scrollbar:SetMinMaxValues(1, dy);
		else
			if scrollbar then DestroyScrollBar(); end
		end
		-- Update
		virt:SetVirtualPosition(1, virt.vy);
		if scrollbar then 
			scrollbar:SetValue(virt.vy); 
			VFLUI.ScrollBarRangeCheck(scrollbar);
		end
	end;

	local SetEmpty = function()
		SetData(VFL.emptyTable, VFL.Noop);
	end

	local SetScroll = function(n, max)
		if not scrollbar then return; end
		if max then 
			virt:SetVirtualPosition(virt:GetVirtualSize()); 
		else
			virt:SetVirtualPosition(n - numCells);
		end
		scrollbar:SetValue(virt.vy);
		VFLUI.ScrollBarRangeCheck(scrollbar);
	end

	local Destroy = function()
		if scrollbar then DestroyScrollBar(); end
		virt:Destroy();
	end

	return {GetContainer = function() return grid; end, 
		SetData = SetData, 
		SetScroll = SetScroll, 
		Destroy = Destroy, 
		SetEmpty = SetEmpty}, grid;
end


----------------- testing
local function allocCell(x,y)
	local c = RDX.UnitFramePool:Acquire();
	c.OnDeparent = RDX.UnitFramePool.Releaser;
	c:SetWidth(25); c:SetHeight(12);
	c:SetPurpose(4);
	c.text1:SetText(x .. "," .. y); c:Show();
	return c;
end

function gtest()
	bigGrid = VFLUI.Grid:new();
	bigGrid:Size(1, 5, allocCell);
	bigGrid:SetPoint("TOPLEFT", "UIParent", "CENTER");
	bigGrid:Show();
	VFL:Debug(1, RDX.UnitFramePool:GetSize());
end

function gtest2()
	smallGrid = VFLUI.Grid:new();
	smallGrid.OnDeparent = VFLUI.Grid.Destroy;
	smallGrid:Size(3,3,allocCell); smallGrid:Show();
	bigGrid:SetCellDimensions(75, 12);
	bigGrid:InsertRow(2, {smallGrid});
	bigGrid:Relayout();
	VFL:Debug(1, RDX.UnitFramePool:GetSize());
end

function gtest3()
	bigGrid:DeleteRow(2);
	bigGrid:Relayout();
	VFL:Debug(1, RDX.UnitFramePool:GetSize());
end

function ltest1()
	theList = VFLUI.CreateList(10, 75, 12, allocCell);
	theFrame = theList.GetContainer();
	theFrame:SetPoint("TOPLEFT", UIParent, "CENTER");
	theFrame:Show();
	theList.SetData({"a", "b", "c"}, function(c,d) c.text1:SetText(d); end);
end

function ltest2()
	local dtbl = {};
	for i=1,20 do
		table.insert(dtbl, tostring(i));
	end
	theList.SetData(dtbl, function(c,d) c.text1:SetText(d); end);
end
