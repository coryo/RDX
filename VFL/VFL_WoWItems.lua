-- VFL_WoWItems.lua
-- VFL - Venificus' Function Library
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Functions for manipulating World of Warcraft items and item links.

-----------------------------
-- GameItem object
-- Represents a transportable WoW item.
-----------------------------
if not VFL.GameItem then VFL.GameItem = {}; end
VFL.GameItem.__index = VFL.GameItem

function VFL.GameItem:new()
	local x = {};
	setmetatable(x, VFL.GameItem);
	return x;
end

-- Get a hyperlink for this item.
function VFL.GameItem:GetHyperlink()
	return "|c" .. self.color .. "|Hitem:" .. self.code .. "|h[" .. self.name .. "]|h|r";
end

-- Generate item data from an item hyperlink.
function VFL.GetItemFromHyperlink(hy)
	-- Try to parse a hyperlink.
	local valid, _, color, code, name = string.find(hy, "|c(%x+)|Hitem:(%d+:%d+:%d+:%d+)|h%[(.-)%]|h|r");
	-- If not, bail
	if not valid then return nil; end
	-- Cleanse the link code
	code = string.gsub(code, "(%d+):(%d+):(%d+):(%d+)", "%1:0:%3:%4");
	-- Create the object
	local ret = VFL.GameItem:new();
	ret.color = color; ret.code = code; ret.name = name;
	return ret;
end

-- Generate item data from a transported item code
local rarityColors = { "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000" };
function VFL.GetItemFromCode(code)
	-- Check validity of item
	local name,link,rarity = GetItemInfo("item:"..code);
	if not name then return nil; end
	-- Get color of item
	local color = "ffffffff";
	if rarityColors[rarity+1] then color = rarityColors[rarity+1]; end
	-- Construct item
	local ret = VFL.GameItem:new();
	ret.color = color; ret.code = code; ret.name = name;
	return ret;
end

---------------------------
-- ItemLink control
---------------------------
if not VFL.ItemLink then VFL.ItemLink = {}; end

-- Imbue an item link button
function VFL.ItemLink.Imbue(self)
	self:SetText(""); self.code = nil;
	self.SetItem = VFL.ItemLink.SetItem;
end

function VFL.ItemLink:SetItem(itm)
	self.code = nil;
	if (not itm) or (not itm.code) then return; end
	self:SetText(itm:GetHyperlink());
	self.code = itm.code;
end
