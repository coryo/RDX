-- VFL_CC_Grid.lua
-- 
-- VFL (Venificus' Function Library)
--
-- Manages the positions of frames, arranging them in a rectangular grid.

-------------------------------------------
-- CELL
-- A cell is a single entry of a grid.
-------------------------------------------
-- Cell type: Empty
if not VFL.Cell then VFL.Cell = {}; end
VFL.Cell.__index = VFL.Cell;

-- Construct a new empty cell
function VFL.Cell:new(o)
	local x = o or {};
	if not x.dx then x.dx=0; x.dy=0; end
	setmetatable(x, self);
	x:init();
	return x;
end
function VFL.Cell:init()
	self.lf = false;
	if not self.x then self.x = 0; self.y = 0; end
end

-- Set a cell's position in the grid
function VFL.Cell:SetGridPos(x, y)
	self.x = x; self.y = y;
end

-- Resize a cell
function VFL.Cell:SetSize(dx, dy)
	self.dx = dx; self.dy = dy;
end

-- Return the (dx,dy) size of a cell
function VFL.Cell:GetSize()
	return self.dx,self.dy;
end

-- Return the (x,y) position of a cell within the grid
function VFL.Cell:GetGridPos()
	return self.x, self.y;
end

-- Layout flag functions
function VFL.Cell:SetLayoutDirty()
	self.lf = false;
end

-- Determine if a cell is an empty cell
function VFL.Cell:IsEmpty() return true; end
-- Determine if a cell can serve as an anchor for another
-- at point x.
function VFL.Cell:CanHold(x) return false; end
-- Determine if a cell can be anchored
function VFL.Cell:CanGrab() return false; end

-----
-- Cell type: Frame (wraps an actual UI frame as a cell)
if not VFL.FrameCell then VFL.FrameCell = {}; end

-- Imbue a WOW UI frame with the functionality of a FrameCell.
function VFL.FrameCell.Imbue(f)
	VFL.Cell.init(f);
	f.SetGridPos = VFL.Cell.SetGridPos;
	f.GetGridPos = VFL.Cell.GetGridPos;
	f.SetSize = VFL.FrameCell.SetSize;
	f.GetSize = VFL.FrameCell.GetSize;
	f.IsEmpty = VFL.FrameCell.IsEmpty;
	f.SetLayoutDirty = VFL.Cell.SetLayoutDirty;
	f.CanHold = VFL.FrameCell.CanHold;
	f.CanGrab = VFL.FrameCell.CanGrab;
	f.GetHoldInfo = VFL.FrameCell.GetHoldInfo;
	f.GetGrabInfo = VFL.FrameCell.GetGrabInfo;
	return f;
end

function VFL.FrameCell:SetSize(dx, dy)
	self:SetHeight(dy); self:SetWidth(dx);
end

function VFL.FrameCell:GetSize()
	return self:GetWidth(), self:GetHeight();
end

function VFL.FrameCell:IsEmpty() return false; end
function VFL.FrameCell:CanHold(x) return true; end
function VFL.FrameCell:CanGrab() return true; end

function VFL.FrameCell:GetHoldInfo(x)
	return self:GetName(), x;
end

function VFL.FrameCell:GetGrabInfo()
	return self, "TOPLEFT";
end

----------------------------------------
-- A grid is a two-dimensional array of cells, some possibly empty.
-- No nonempty cell may be surrounded by empty cells.
----------------------------------------
if not VFL.Grid then VFL.Grid = {}; end
VFL.Grid.__index = VFL.Grid;

function VFL.Grid:new()
	x = {};
	setmetatable(x, VFL.Grid);
	x:InitGrid();
	return x;
end

-- Initialize a grid
function VFL.Grid:InitGrid()
	self.dx = 0; self.dy = 0;
	self.cells = {};
	self.cw = {}; self.rh = {};
	self.defCW = 30; self.defRH = 15;
	self.rpad = 0; self.cpad = 0;
end

-- Set the dimension of the grid. New cells are allocated by the given 
-- allocator function.
function VFL.Grid:Size(w, h, fnAcq)
	-- Don't resize if not needed
	if (w == self.dx) and (h == self.dy) then return; end
	-- Create acquisition function for empty cells if not provided
	if not fnAcq then fnAcq = function(g) return VFL.Cell:new(); end end
	-- Destroy all cells in the current grid that are out of bounds
	for x=1,self.dx do
		for y=1,self.dy do
			if (x > w) or (y > h) then self:ReleaseCell(x, y); end
		end
		if(x > w) then self.cells[x] = nil; end
	end
	-- Now allocate missing cells
	for x=1,w do
		if not self.cells[x] then self.cells[x] = {}; end
		for y=1,h do
			if not self.cells[x][y] then 
				local c = fnAcq(self);
				c:SetLayoutDirty();
				c:SetGridPos(x,y);
				self.cells[x][y] = c;
			end
		end
	end
	-- Update row and column width tables
	VFL.asizeup(self.cw, w, self.defCW);
	VFL.asizeup(self.rh, h, self.defRH);
	-- Update internal dimensions
	self.dx = w; self.dy = h;
end

-- Destroy all contents of the grid
function VFL.Grid:Destroy()
	if not self.dx then self:InitGrid(); return; end
	self:Size(0,0);
	self.cw = {}; self.rh = {};
end

-- Get the current contents of a cell.
function VFL.Grid:GetCell(x, y)
	if not self.cells[x] then return nil; end
	return self.cells[x][y];
end

-- Release the current contents of a cell
function VFL.Grid:ReleaseCell(x,y)
	if not self.cells[x] then return; end
	local c = self.cells[x][y];
	if c then 
		if(c.OnGridRelease) then 
			c:OnGridRelease(self); 
			c.OnGridRelease = nil;
		end
		if(self.OnRelease) then
			self:OnRelease(c);
		end
		self.cells[x][y] = nil; 
	end
end

-----------------------------------
-- ITERATION
-----------------------------------
-- Cell iterators
function VFL.Grid:Region(x0, y0, x1, y1)
	return function(s,x) -- iterator
		s.x = s.x + 1;
		if(s.x > s.x1) then
			s.x = s.x0; s.y = s.y + 1;
			if(s.y > s.y1) then
				return nil;
			end
		end
		return self:GetCell(s.x, s.y);
	end, 
	{ x0 = x0; x1 = x1; y0 = y0; y1 = y1; x = x0-1; y = y0; }, -- iterator state
	nil; -- iterator IV
end
function VFL.Grid:Column(c)
	return function(s,x)
		s.y = s.y + 1;
		if(s.y > self.dy) then return nil; end
		return self:GetCell(s.c, s.y);
	end,
	{ y = 0; c = c; },
	nil;
end
function VFL.Grid:Row(r)
	return function(s,x)
		s.x = s.x + 1;
		if(s.x > self.dx) then return nil; end
		return self:GetCell(s.x, s.r);
	end,
	{ x = 0; r = r; },
	nil;
end
function VFL.Grid:All()
	return self:Region(1,1,self.dx,self.dy);
end

-- External full iterator
-- Direction: 0 = horizontal (dx before dy), 1 = vertical (dy before dx)
function VFL.Grid:ExternalIterator(dir)
	if dir == 0 then
		-- Construct a closure that iterates the grid in the x direction
		local x,y = 0,1;
		return function()
			x=x+1;
			if(x > self.dx) then x = 1; y = y + 1; end
			if(y > self.dy) then return nil; end
			return self:GetCell(x,y);
		end;
	else
		-- Construct a closure that iterates in the y direction
		local x,y = 1,0;
		return function()
			y=y+1;
			if(y > self.dy) then y = 1; x = x + 1; end
			if(x > self.dx) then return nil; end
			return self:GetCell(x,y);
		end;
	end
end

----------------------------------
-- LAYOUT ARGUMENTS
----------------------------------
-- Set the width of a grid column.
function VFL.Grid:GetColumnWidth(c) return self.cw[c]; end
function VFL.Grid:SetColumnWidth(c, w)
	if(c < 1) or (c > self.dx) then return; end
	if(c > self.dx) then
		VFL.asizeup(self.cw, w, self.defCW);
		self.cw[c] = w;
		return;
	end
	if(self.cw[c] ~= w) then
		self.cw[c] = w;
		for x in self:Column(c) do x:SetLayoutDirty(); end
	end
end
function VFL.Grid:SetDefaultColumnWidth(w) self.defCW = w; end
function VFL.Grid:SetColumnPadding(w) 
	if(self.cpad ~= w) then
		self.cpad = w;
		for x in self:All() do x:SetLayoutDirty(); end
	end
end

-- Set the height of a grid row.
function VFL.Grid:GetRowHeight(r) return self.rh[r]; end
function VFL.Grid:SetRowHeight(r, h)
	if(r < 1) then return; end
	if(r > self.dy) then
		VFL.asizeup(self.rh, r, self.defRH);
		self.rh[r] = h;
		return;
	end
	if(self.rh[r] ~= h) then
		self.rh[r] = h;
		for x in self:Row(r) do x:SetLayoutDirty(); end
	end
end
function VFL.Grid:SetDefaultRowHeight(h) self.defRH = h; end
function VFL.Grid:SetRowPadding(h)
	if(self.rpad ~= h) then
		self.rpad = h; 
		for x in self:All() do x:SetLayoutDirty(); end
	end
end

-- Get the extents of the grid
function VFL.Grid:GetExtents()
	if(self.dx == 0) or (self.dy == 0) then return 0,0; end
	local xex,yex = 0,0;
	-- Xextent = sum(cwidth) + sum(cpads)
	for i=1,self.dx do
		xex = xex + self.cw[i];
	end
	xex = xex + ((self.dx-1)*self.cpad);
	-- Yextent = sum(rheight) + sum(rpads)
	for i=1,self.dy do
		yex = yex + self.rh[i];
	end
	xex = xex + ((self.dy-1)*self.rpad);
	return xex, yex;
end

-- Set the top left anchor for the grid
function VFL.Grid:SetGridAnchor(...)
	self._anchor = arg;
end

-- Layout all cells in the current grid
function VFL.Grid:Layout()
	-- Don't layout empty grids
	if(self.dx == 0) or (self.dy == 0) then return true; end
	-- Return the result of a tail-recursive _Layout call
	return self:LayoutRecursive(0);
end

-- Layout engine: mainloop
function VFL.Grid:LayoutRecursive(lastn)
	-- GENERAL IDEA: Iterate over entire grid, laying out cells until 
	-- all layout flags are TRUE.
	local c,n,k = nil,0,0;
	for c in self:All() do
		if not c.lf then
			n=n+1;
			if(self:LayoutCell(c)) then
				c.lf = true;
				k=k+1;
			end
		end
	end
	-- If all cells have been laid out, exit with success
	if(n == k) or (n == 0) then return true; end
	-- If we've made no progress, exit with failure
	if(n == lastn) then return false; end
	-- Otherwise, go again.
	return self:LayoutRecursive(n);
end

-- Attempt to layout a single cell
function VFL.Grid:LayoutCell(c)
	if not c then return false; end
	local x,y = c:GetGridPos();
	--VFL.debug("VFL.Grid:LayoutCell(" .. x .. "," .. y .. ")", 10);
	-- If the cell can't be anchored, there's no need to worry about laying it out
	if not c:CanGrab() then return true; end
	-- Resize the frame to the cell size
	c:SetSize(self:GetColumnWidth(x), self:GetRowHeight(y));
	-- Special case for 1,1 - grab onto the root grid anchor
	if(x == 1) and (y == 1) then
		local f,tp = c:GetGrabInfo();
--		local tf,ttp,dx,dy = unpack(self._anchor);
		f:SetPoint(tp, unpack(self._anchor));
		return true;
	end
	-- Otherwise try grabbing cells in various directions
	if self:LayoutTryCellGrab(c, "TOPRIGHT", x-1, y)  then
	elseif self:LayoutTryCellGrab(c, "BOTTOMLEFT", x, y-1) then
	elseif self:LayoutTryCellGrab(c, "BOTTOMRIGHT", x-1, y-1) then
	else return false; end
	-- Success
	return true;
end

function VFL.Grid:LayoutTryCellGrab(c,hpt,x,y)
	local d = self:GetCell(x,y);
	if not d then return false; end
	if not d:CanHold(hpt) then return false; end
	local f,tp = c:GetGrabInfo();
	local tf,ttp = d:GetHoldInfo(hpt);
--	VFL.debug("ANCHORING: "..f:GetName().." to "..tf, 10);
	if(hpt == "BOTTOMLEFT") then
		f:SetPoint(tp, tf, ttp, 0, -self.rpad); -- Offset down by row padding
	elseif(hpt == "BOTTOMRIGHT") then
		f:SetPoint(tp, tf, ttp, self.cpad, -self.rpad); -- Offset right by cpad, down by rpad
	else
		f:SetPoint(tp, tf, ttp, self.cpad, 0); -- Offset right by cpad
	end
	return true;
end

-- Shortcut: instruct all elements of the grid to show.
function VFL.Grid:Show()
	for c in self:All() do
		if(c.Show) then c:Show(); end
	end
end

-- Virtualize a grid, binding it to an underlying store of data and allowing
-- it to function as a scrolling view of that data.
-- ARGS: fnGetDataSize - function: x,y=fnGetDataSize(grid); should return the total size of available data
-- fnGetData(grid, x,y) should return the data at absolute position x,y or nil if there is no such data.
-- fnApplyData(grid, cell, data, vx, vy, x, y) should apply the return value of fnGetData to the given cell. If data is nil its effect should be to clear the cell.
function VFL.Grid:Virtualize(fnGetDataSize, fnGetData, fnApplyData)
	self.vfnGetDataSize = fnGetDataSize;
	self.vfnGetData = fnGetData;
	self.vfnApplyData = fnApplyData;
	self.vx = 0; self.vy = 0;
end

-- Change the data application function
function VFL.Grid:SetFnApplyData(f)
	self.vfnApplyData = f;
end

-- The virtual map - map the given coordinates of grid space into the
-- correct coordinates of data space.
function VFL.Grid:VirtualMap(gx, gy)
	return gx+self.vx, gy+self.vy;
end
function VFL.Grid:VirtualPos(c)
	local x,y = c:GetGridPos();
	return x+self.vx,y+self.vy;
end

-- ApplyData to all grid cells.
function VFL.Grid:VirtualUpdate()
	for c in self:All() do
		local x,y = c:GetGridPos();
		local vx,vy = self:VirtualMap(x,y);
		local d = self:vfnGetData(vx,vy);
		self:vfnApplyData(c, d, vx, vy, x, y);
	end
end

-- Get the horizontal and vertical scroll ranges of the virtual grid.
-- The scroll range is the total data size minus the number of displayed
-- elements.
function VFL.Grid:GetScrollRanges()
	local dsx,dsy = self:vfnGetDataSize();
	dsx = dsx - self.dx; dsy = dsy - self.dy;
	if(dsx < 0) then dsx = 0; end
	if(dsy < 0) then dsy = 0; end
	return dsx, dsy;
end

-- Scroll the grid to a given point between 0 and the results of GetScrollRanges.
function VFL.Grid:GetScroll()
	return self.vx,self.vy;
end
function VFL.Grid:SetScroll(x,y)
	self.vx = x; self.vy = y; self:VirtualUpdate();
end

---------------------------------------
-- GRID BUILDING
---------------------------------------
-- Construct a single-column grid using UI elements.
function VFL.Grid:BuildList(fnCellSource, cellHeight, cellWidth, nCells, container, ...)
	self:Destroy();
	self:SetDefaultRowHeight(cellHeight);
	self:SetDefaultColumnWidth(cellWidth);
	self:Size(1, nCells, fnCellSource);
	self:SetGridAnchor(container:GetName(), unpack(arg));
	for c in self:All() do c:SetFrameLevel(container:GetFrameLevel() + 1); end
	self:Layout();
end

