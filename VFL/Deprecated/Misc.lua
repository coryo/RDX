---------------------------------------------
-- POPUP
-- A scrollable list of Selectables inset in a container
---------------------------------------------
if not VFL.PopupMenu then VFL.PopupMenu = {}; end
VFL.PopupMenu.__index = VFL.PopupMenu;

-- Generate a popup menu
function VFL.PopupMenu:new(container, sb, cellPool, maxcells, cdx, cdy, fnApplyData)
	local self = {};
	setmetatable(self, VFL.PopupMenu);
	-- Arrange frames
	self.container = container; 
	if(sb) then
		self.sb = sb;
		sb:SetParent(container);
	end
	self.cdx = cdx; self.cdy = cdy;
	-- Set data
	self.maxcells = maxcells;
	-- Create list control
	self.list = VFL.ListControl:new(container, cellPool, fnApplyData, sb);
	return self;
end

-- Show the PopupMenu with the given data
function VFL.PopupMenu:Show(data)
	-- If no data given, use current data
	if not data then data = self.list.data; end
	-- Determine the dimensions of the list
	local n,dx,dy = math.min(table.getn(data), self.maxcells),0,0;
	-- Show the container
	self.container:Show();
	-- Rebuild list
	self.list:Destroy();
	self.list:Build(self.cdy, self.cdx, n, data, self.container, "TOPLEFT", 5, -5);
	-- Resize the container
	self.container:SetHeight((n*self.cdy) + 10); self.container:SetWidth(self.cdx + 10);
	self.container:SetFrameLevel(1); self.container:SetFrameStrata("DIALOG");
	-- Update the content
	self.list:UpdateContent();
end

-- Disable the contents of the popmenu, giving it a "Greyed out" look
function VFL.PopupMenu:Disable()
	self.container:SetAlpha(0.45);
	for b in self.list:All() do
		b:Disable();
	end
end

-- Destroy the popupmenu
function VFL.PopupMenu:Destroy()
	self.list:Destroy();
	self.container:SetAlpha(1);
	self.container:Hide();
end

-- Destroy the popup menu and all internal contents
function VFL.PopupMenu:DestroyAndFree()
	self:Destroy();
	self.list.data = nil; self.list = nil;
end

------------------------------------------------------------
-- BASIC POPUP WINDOW
-- A popup list of Selectables, with a scrollbar
------------------------------------------------------------
if not VFL.PopupWindow then VFL.PopupWindow = {}; end
VFL.PopupWindow.__index = VFL.PopupWindow;

function VFL.PopupWindow:new()
	local self = {};
	setmetatable(self, VFL.PopupWindow);
	-- Escape handler
	self.esch = function() self:Release(); end
	return self;
end

-- Generate a popup window, beginning from the given anchor point and with the
-- given-size cells.
function VFL.PopupWindow:Show(data, maxFrames, af, ap, cdx, cdy)
	-- Release any preexisting menu
	if(self.win) then self:Release(); return; end
	-- Add the escape handler
	VFL.AddEscapeHandler(self.esch);
	-- Create the window
	local ctr = VFL.containerPool:Acquire();
	local sb = VFL.vscrollPool:Acquire();
	self.win = VFL.PopupMenu:new(ctr, sb, VFL.selectablePool, maxFrames, cdx, cdy, VFL.PopupWindow.ApplyData);
	-- Anchor the container frame
	ctr:SetPoint("TOPLEFT", af, ap, 0, 0);
	-- Show the menu
	self.win:Show(data);
end

-- Release a popup window
-- Release all popups in the tree.
function VFL.PopupWindow:Release()
	VFL.RemoveEscapeHandler(self.esch);
	if not self.win then return; end
	self.win:DestroyAndFree();
	VFL.containerPool:Release(self.win.container); self.win.container = nil;
	VFL.vscrollPool:Release(self.win.sb); self.win.sb = nil;
	self.win = nil;
end

-- Apply data to a popup cell
function VFL.PopupWindow.ApplyData(grid, cell, data, vx, vy, x, y)
	if not data then cell:Hide(); return; else cell:Show(); end
  if(data.texture) then
		cell:SetPurpose(4);
		cell.icon:SetTexture(data.texture);
	else
		cell:SetPurpose(1);
	end
	if(data.color) then
		cell.text:SetTextColor(data.color.r, data.color.g, data.color.b);
	else
		cell.text:SetTextColor(1,1,1);
	end
	-- Show highlight
	if(data.hlt) then cell:Select(); else cell:Unselect(); end
	if(not data.hlt) and (data.selColor) then
		cell.selTexture:Show();
		cell.selTexture:SetVertexColor(data.selColor.r, data.selColor.g, data.selColor.b, data.selColor.a);
	else
		cell.selTexture:Hide();
	end
	-- Set text
  cell:Enable();
	cell:SetText(data.text);
	cell.OnClick = data.OnClick;

end

-- Global structures
VFL.popwin = VFL.PopupWindow:new();



-- Functions for time manipulation
VFL.time = {
	-- Converts seconds to an (hour,min,sec) datastructure
	secToHMS = function(sec)
		local min = math.floor(sec/60); sec = math.mod(sec, 60);
		local hr = math.floor(min/60); min = math.mod(min, 60);
		return { h = hr; m = min; s = sec; };
	end;

	-- Converts (hour, min, sec) to seconds
	HMSToSec = function(hms)
		return (hms.h * 3600) + (hms.m * 60) + hms.s;
	end;

	-- Format an HMS data structure with colon separators
	format = function(hms)
		return format("%d:%02d:%02d", hms.h, hms.m, hms.s);
	end;
	
	-- Parse a time. Return nil if no time found, otherwise an
	-- hms representation.
	parseHMS = function(str)
		local d = {};
		for w in string.gfind(str .. ":", "%d+:") do
			table.insert(d, tonumber(string.sub(w,1,-2)));
		end
		if(d[3]) then return { h=d[1]; m=d[2]; s=d[3]; };
		elseif(d[2]) then return { h=0; m=d[1]; s=d[2]; };
		elseif(d[1]) then return { h=0; m=0; s=d[1]; };
		else return nil;
		end
	end;
};


-- Functions for text/string manipulation.
str = {
	-- "Flag string" mainipulation
	checkFlag = function(str, flag)
		if(str == nil) then return false; end
		return string.find(str, flag, 1, true);
	end;
	setFlag = function(str, flag)
		if(str == nil) then return flag; end
		if not VFL.str.checkFlag(str, flag) then
			return str .. flag;
		else
			return str;
		end
	end;
	
	-- Capitalize first letter of a string
	capsFirst = function(str)
		return string.gsub(str, "^%l", string.upper);
	end;

	-- Return a colorized version of the given string
	colorize = function(color, str)
		return VFL.str.getColorTag(color) .. str .. VFL.str.getColorCloseTag();
	end;

	-- Get the WoW color tag for a given color
	getColorTag = function(color)
		return format("|cFF%02X%02X%02X", math.floor(color.r*255), math.floor(color.g*255), math.floor(color.b*255));
	end;

	-- Get the WoW color closing tag
	getColorCloseTag = function()
		return "|r";
	end;
	
	-- Get a word from the front of a string
	getWord = function(str)
		if(str == nil) or (str == "") then return nil; end;
		local i = string.find(str, " ");
		if(i == nil) then return str, ""; end;
		return string.sub(str, 1, i-1), string.sub(str, i+1, -1);
	end;
		
	-- Print a string to the default frame.
	print = function(str)
		if(str == nil) then return; end
		local c = NORMAL_FONT_COLOR;
		ChatFrame1:AddMessage(str, c.r, c.g, c.b);
	end;

	-- Print a string to the error frame.
	errorPrint = function(str)
		if(str == nil) then return; end
		local c = RED_FONT_COLOR;
		UIErrorsFrame:AddMessage(str, c.r, c.g, c.b, 1.0, UIERRORS_HOLD_TIME);
	end;
};

-- Functions for color manipulation
color = {
	blend = function(c1, c2, factor)
		return {
			r = (1-factor) * c1.r + factor * c2.r;
			g = (1-factor) * c1.g + factor * c2.g;
			b = (1-factor) * c1.b + factor * c2.b;
		};
	end;

	clone = function(src)
		return { r=src.r, g=src.g, b=src.b, a=src.a };
	end;

	copyTo = function(cDest, cSrc)
		cDest.r = cSrc.r;
		cDest.g = cSrc.g;
		cDest.b = cSrc.b;
	end;
};
