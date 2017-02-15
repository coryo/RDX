-- TabBox.lua
-- VFL
-- (C)2006 Bill Johnson and The VFL Project
--
-- A TabBox is a client area frame together with an attached TabBar. When a tab on the TabBar is clicked,
-- typically the client is populated with a different frame depend on which tab was clicked. Procedures
-- to easily enable this are provided.

local function NewTabBox(fp, parent, tabHeight, orientation)
	local self = VFLUI.AcquireFrame("Frame");
	if parent then
		self:SetParent(parent); self:SetFrameStrata(parent:GetFrameStrata());
		self:SetFrameLevel(parent:GetFrameLevel() + 1);
	end
	self:SetBackdrop(VFLUI.DefaultDialogBackdrop);

	local curClient = nil;

	--- Set the client frame for this window.
	function self:SetClient(cli)
		if curClient == cli then return; end
		if curClient then curClient:Hide(); end
		curClient = cli;
		if not cli then return; end
		cli:SetParent(self);	cli:ClearAllPoints();
		if orientation == "TOP" then
			cli:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -tabHeight);
		elseif orientation == "BOTTOM" then
			cli:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 5, tabHeight);
		end
		cli:SetWidth(self:GetWidth() - 10); cli:SetHeight(self:GetHeight() - tabHeight - 5);
		cli:Show();
	end

	--- Generate the AddTab() functions for the given client.
	function self:GenerateTabFuncs(cli)
		return function() self:SetClient(cli); end;
	end

	local tabBar = VFLUI.TabBar:new(self, tabHeight, orientation);
	if orientation == "TOP" then
		tabBar:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -2);
	elseif orientation == "BOTTOM" then
		tabBar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", 5, 2);
	end
	tabBar:Show();

	--- Get the TabBar for this TabBox.
	function self:GetTabBar() return tabBar; end

	-- Resize/show handling
	local function OnResize()
		tabBar:SetWidth(self:GetWidth() - 10);
		if curClient then 
			curClient:SetWidth(math.max(self:GetWidth() - 10, 0));
			curClient:SetHeight(math.max(0, self:GetHeight() - tabHeight - 5));
		end
	end 
	self:SetScript("OnSizeChanged", OnResize);
	self:SetScript("OnShow", OnResize);
	
	-- Destructor
	self.Destroy = VFL.hook(function(s)
		if curClient then curClient:Hide(); curClient = nil; end
		tabBar:Destroy(); tabBar = nil;
		self.SetClient = nil; self.GenerateTabFuncs = nil; self.GetTabBar = nil;
	end, self.Destroy);

	return self;
end

VFLUI.TabBox = {};
VFLUI.TabBox.new = NewTabBox;

function tabbox()
	theBox = VFLUI.TabBox:new(UIParent, 22, "BOTTOM");
	theBox:SetHeight(250); theBox:SetWidth(300);
	theBox:SetPoint("CENTER", UIParent, "CENTER");
	local cli = nil;
	for i=1,10 do
		cli = VFLUI.Button:new(); cli:SetText("cli " .. i); cli:Hide();
		theBox:GetTabBar():AddTab(50, theBox:GenerateTabFuncs(cli)):SetText(i);
	end
end
