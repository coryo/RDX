-- PopupMenu.lua
-- VFL - Venificus' Function Library
-- (C)2005-2006 Bill Johnson (Venificus of Eredar server)
--
-- Implementation of a generalized popup menu object.

-- An empty popup menu
local emptyMenu = {
	{ text = "|c00888888(Empty menu)|r" }
};

-----------------------------------------------------------------------------
-- @class VFLUI.PopMenu
--
-- An entity for displaying a hierarchical menu whose display entities are 
-- VFL Selectables.
-- 
-- PopupMenu:Begin(targetFrame, targetPoint, offx, offy) functions like SetPoint
-- and sets where the popup menu will originate from.
--
-- PopupMenu:Expand(anchorFrame, data) expands the tree, hanging it off the given
-- frame.
-----------------------------------------------------------------------------
-- Rendering functions
local function UnivMenuApplyData(cell, data)
	-- Set pictorials
	if(data.isSubmenu) then 
		cell.icon:Show();
	elseif(data.texture) then
		cell.icon:SetTexture(data.texture);
		cell.icon:Show();
	else
		cell.icon:Hide();
	end
	-- Set text color
	if(data.color) then
		cell.text:SetTextColor(data.color.r, data.color.g, data.color.b);
	else
		cell.text:SetTextColor(1,1,1);
	end
	-- Set text
  cell:Enable();
	cell.text:SetText(data.text);
	cell:SetScript("OnClick", data.OnClick);
	-- Show highlight
	if(data.hlt) then cell:Select(); else cell:Unselect(); end
end

local function LeftMenuApplyData(cell, data)
	cell:SetPurpose(3);
	cell.icon:SetTexture("Interface\\Addons\\VFL\\Skin\\sb_left");
	UnivMenuApplyData(cell, data);
end

local function RightMenuApplyData(cell, data)
	cell:SetPurpose(2);
	cell.icon:SetTexture("Interface\\Addons\\VFL\\Skin\\sb_right");
	UnivMenuApplyData(cell, data);
end

local function DisableListContents(list)
	local ctr = list.GetContainer();
	ctr:SetAlpha(0.45);
	for x in ctr:Iterator() do
		x:Disable();
	end
end

-- Popmenu object
VFLUI.PopMenu = {};
VFLUI.PopMenu.__index = VFLUI.PopMenu;

function VFLUI.PopMenu:new()
	local self = {};
	setmetatable(self, VFLUI.PopMenu);
	-- Create unique escape handler
	self.esch = function() self:Release(); end
	return self;
end

-- Determine if the popup tree is currently in use.
function VFLUI.PopMenu:IsInUse()
	if self.menus then return true; else return nil; end
end

-- Start a new popup tree. Destroys any old popup tree and sets the anchor point for the
-- newly created tree
function VFLUI.PopMenu:Begin(cellWidth, cellHeight, frame, point, dx, dy)
	VFLUI:Debug(10, "VFLUI.PopMenu:Begin(" .. cellWidth .. "," .. cellHeight .. "," .. tostring(frame) .. "," .. tostring(point) .. "," .. tostring(dx) .. "," .. tostring(dy) .. ")");
	-- Sanify parameters
	if (not frame) then return false; end
	if (not dx) then dx = 0; dy = 0; end
	-- Destroy preexisting menus
	if(self.menus) then self:Release(); end
	-- Compute orientation
	-- Get center
	local UICx, UICy = UIParent:GetCenter();
	-- Translate 1/4 screenwidth rightward
	UICx = UICx + ((UIParent:GetRight() - UICx)/2);
	-- Go universal
	UICx, UICy = GetUniversalCoords(UIParent, UICx, UICy);
	-- Get universal coords of new frame center
	local MCx, MCy = GetUniversalCoords(frame, frame:GetCenter());
	if(MCx > UICx) then self.orientation = 1; else self.orientation = 2; end
	
	-- Initialize state
	self.af = frame; self.ap = point; self.adx = dx; self.ady = dy; self.cdx = cellWidth; self.cdy = cellHeight;
	self.menus = {};

	-- If no point was provided, treat as a dropdown
	if not point then
		if self.orientation == 1 then
			self.ap = "BOTTOMRIGHT";
		else
			self.ap = "BOTTOMLEFT";
		end
	end
end

-- Expand the popup tree by attaching a menu with the given data, anchored to
-- the given frame.
function VFLUI.PopMenu:Expand(aFrame, data, limit)
	-- Sanity check on data
	if (not data) or (table.getn(data) == 0) then data = emptyMenu; end
	-- Determine layout parameters
	local aHoldPoint, aGrabPoint, fnad, dy, dx = nil, nil, nil, 0, 5;
	if(self.orientation == 1) then -- left-oriented
		aHoldPoint = "TOPLEFT"; aGrabPoint = "TOPRIGHT"; fnad = LeftMenuApplyData;
		dx = -dx;
	else -- right oriented
		aHoldPoint = "TOPRIGHT"; aGrabPoint = "TOPLEFT"; fnad = RightMenuApplyData;
	end
	
	-- If we've not yet created a menu...
	if(table.getn(self.menus) == 0) then
		VFL.AddEscapeHandler(self.esch);
		aFrame = self.af; aHoldPoint = self.ap; dx = dx + self.adx; dy = self.ady;
	else
		dy = 0; -- Shift things upward by units of one cell (?)
	end

	-- Create the decor frame to "look pretty"
	local decor = VFLUI.AcquireFrame("Frame");
	decor:SetParent("UIParent");
	decor:SetFrameStrata("FULLSCREEN_DIALOG");
	decor:SetFrameLevel(100);
	decor:SetScale(self.af:GetEffectiveScale() / UIParent:GetEffectiveScale());
	decor:SetBackdrop(VFLUI.BlackDialogBackdrop);
	
	-- Create the menu
	local menuSz = table.getn(data);
	if limit then menuSz = math.min(limit, menuSz); end
	VFLUI:Debug(10, "Expanding menu of size " .. table.getn(data) .. " limited to " .. tostring(limit));
	local menu = VFLUI.CreateList(menuSz, self.cdx, self.cdy, function() 
		local c = VFLUI.Selectable:new();
		c.OnDeparent = c.Destroy;
		return c;
	end, decor);

	-- Assign and anchor the decor to the menu
	menu.decor = decor;
	local ctr = menu.GetContainer();
	decor:SetPoint("TOPLEFT", ctr, "TOPLEFT", -5, 4);
	decor:SetPoint("BOTTOMRIGHT", ctr, "BOTTOMRIGHT", 5, -5);

	-- Anchor the menu to the appropriate point
	ctr:SetPoint(aGrabPoint, aFrame, aHoldPoint, dx, dy);

	-- Show the new menu
	ctr:Show(); decor:Show();
	menu.SetData(data, fnad);
	-- Disable the previous menu in the hierarchy
	if self.menus[1] then
		DisableListContents(self.menus[1]);
	end
	-- Insert our new menu into the hierarchy
	table.insert(self.menus, 1, menu);

	-- Check for off-screenage
	local bx, by = 0, 0;
	if(ctr:GetLeft() < 0) then
		bx = -ctr:GetLeft();
	else
		local univMenuRight, univScreenRight = ToUniversalAxis(ctr, ctr:GetRight()), ToUniversalAxis(UIParent, UIParent:GetRight());
		if( univMenuRight > univScreenRight ) then
			bx = -ToLocalAxis(ctr, univMenuRight - univScreenRight);
		end
	end
	if(ctr:GetBottom() < 0) then by = -ctr:GetBottom(); end
	self:Bump(bx, by);
end

-- Bump the popup tree by moving the first anchor by the given distance.
function VFLUI.PopMenu:Bump(dx, dy)
	if(dx == 0) and (dy == 0) then return; end
	self.adx = self.adx + dx; self.ady = self.ady + dy;
	local firstm = self.menus[table.getn(self.menus)];
	if not firstm then return; end
	local aGrabPoint = "TOPLEFT";
	if(self.orientation == 1) then aGrabPoint = "TOPRIGHT"; end
	firstm.GetContainer():SetPoint(aGrabPoint, self.af, self.ap, self.adx, self.ady);
end

-- Release and destroy the entire popup tree.
function VFLUI.PopMenu:Release()
	if not self.menus then return; end
	local m = table.remove(self.menus);
	while m do
		m.Destroy();
		m.decor:Destroy(); m.decor = nil;
		m = table.remove(self.menus);
	end
	self.menus = nil;
	VFL.RemoveEscapeHandler(self.esch);
end

--- Global popup menu object.
VFL.poptree = VFLUI.PopMenu:new();

