-- List.lua
-- VFL
-- (C)2006 Bill Johnson
-- 
-- A List is a frame that contains a number of subframes and (possibly) a scrollbar.
VFLUI.List = {};

--- Create a new List.
-- @param cellHeight The height of each cell in the list.
-- @param fnAlloc The function called to allocate a new frame in the list.
function VFLUI.List:new(parent, cellHeight, fnAlloc)
	local self = VFLUI.AcquireFrame("Frame");
	if parent then
		self:SetParent(parent); self:SetFrameStrata(parent:GetFrameStrata()); self:SetFrameLevel(parent:GetFrameLevel());
	end

	------- INTERNAL PARAMETERS
	-- Dimensions
	local nCells, dy = 0, 0;
	-- Scrollbar
	local scrollbar = nil;
	-- Apply data function
	local fnSize, fnData = VFL.EmptyLiterator();
	local fnApplyData = VFL.Noop;

	------- GRID CORE
	local grid = VFLUI.Grid:new(self);
	grid:SetPoint("TOPLEFT", self, "TOPLEFT"); grid:Show();
	
	------- SCROLLING VIRTUALIZER
	local virt = VFLUI.VirtualGrid:new(grid);
	virt.GetVirtualSize = function()
		local q = fnSize() - nCells + 1;
		if(q < 1) then q = 1; end
		return 1,q;
	end
	virt.OnRenderCell = function(v, c, x, y, vx, vy)
		local pos = y + vy - 1;
		local qq = fnData(pos);
		if not qq then 
			c:Hide() 
		else
			c:Show(); fnApplyData(c, qq, pos);
		end
	end

	------- SCROLLBAR HANDLER
	local CreateScrollBar = function()
		-- Don't create if we already have one
		if scrollbar then return; end
		-- Create the scrollbar object
		scrollbar = VFLUI.VScrollBar:new(self);
		-- Resize the grid to accomodate the new scrollbar
		grid:SetCellDimensions(self:GetWidth() - 16, cellHeight);
		-- Attach the scrollbar to the grid
		scrollbar:SetPoint("TOPLEFT", grid, "TOPRIGHT", 0, -16);
		scrollbar:SetWidth(16);
		scrollbar:SetHeight(grid:GetHeight() - 32);
		scrollbar:Show();
		self.SetVerticalScroll = function(g, val) 
			local oldv, newv = virt.vy, math.floor(val);
			if(oldv ~= newv) then virt:SetVirtualPosition(1, newv); end
		end	
	end
	local DestroyScrollBar = function()
		if scrollbar then
			self.SetVerticalScroll = nil;
			grid:SetCellDimensions(self:GetWidth(), cellHeight);
			scrollbar:Destroy(); scrollbar = nil;
		end
	end

	--- Rebuild the list control. This should be used when the size of the container frame changes.
	function self:Rebuild()
		DestroyScrollBar(); grid:Clear();
		nCells = math.floor(self:GetHeight() / cellHeight);
		if(nCells < 0) then nCells = 0; end
		VFLUI:Debug(2, "List:Rebuild() to size " .. nCells);
		grid:Size(1, nCells, fnAlloc);
		grid:SetCellDimensions(self:GetWidth(), cellHeight);
		self:Update();
	end

	--- Get the cell height provided at list creation.
	function self:GetCellHeight() return cellHeight; end
	
	--- Set the underlying data source for this list. The data source must be a _linear iterator_
	-- which consists of a pair of functions; one to retrieve the size of the underlying list and
	-- one which takes a numerical parameter and returns the data at that index, or NIL for none.
	function self:SetDataSource(fnad, liSz, liData)
		fnSize = liSz; fnData = liData; fnApplyData = fnad;
		self:Update();
	end

	--- Set this list to empty.
	function self:SetEmpty() self:SetDataSource(VFL.EmptyLiterator(), VFL.Noop); end

	--- Update the list in response to an update of the data table.
	function self:Update()
		local _,dy = virt:GetVirtualSize();
		if(dy > 1) then
			if(not scrollbar) then CreateScrollBar(); end
			scrollbar:SetMinMaxValues(1, dy);
		else
			if scrollbar then DestroyScrollBar(); end
		end
		virt:SetVirtualPosition(1, virt.vy);
		if scrollbar then
			scrollbar:SetValue(virt.vy); VFLUI.ScrollBarRangeCheck(scrollbar);
		end
	end

	--- Change the scroll value of the list. If the second parameter is given, the scrollbar
	-- will be pinned to the maximum value.
	function self:SetScroll(n, max)
		if not scrollbar then return; end
		if max then
			virt:SetVirtualPosition(virt:GetVirtualSize());
		else
			virt:SetVirtualPosition(n - nCells);
		end
		scrollbar:SetValue(virt.vy);
		VFLUI.ScrollBarRangeCheck(scrollbar);
	end

	-- Destroy handler.
	self.Destroy = VFL.hook(function(s)
		DestroyScrollBar(); virt:Destroy();
		self.Rebuild = nil;
		self.GetCellHeight = nil;
		self.SetDataSource = nil;
		self.SetEmpty = nil;
		self.Update = nil;
		self.SetScroll = nil;
	end, self.Destroy);

	return self;
end

