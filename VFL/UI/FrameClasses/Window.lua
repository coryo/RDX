-- Window.lua
-- VFL
-- (C)2006 Bill Johnson and The VFL Project
--
-- A Window is a frame with a title bar and various other decorations.
VFLUI.Window = {};

-----------------------------------------------------
-- Apply the "Default" framing to a Window object.
-----------------------------------------------------
function VFLUI.Window.SetDefaultFraming(self, titleHeight)
	self:SetBackdrop(VFLUI.DefaultDialogBackdrop);
	function self:GetTitleHeight() return titleHeight; end
	local titleBar = self:GetTitleBar();
	titleBar:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -5);
	titleBar:SetHeight(titleHeight - 5); titleBar:Show();

	local titleText = VFLUI.CreateFontString(titleBar);
	titleText:SetPoint("TOPLEFT", titleBar, "TOPLEFT");
	titleText:SetHeight(titleHeight - 5);
	titleText:SetFontObject(VFLUI.GetFont(Fonts.Default, titleHeight*.5));
	titleText:SetJustifyH("LEFT"); titleText:Show();
	
	local tx1 = VFLUI.CreateTexture(titleBar);
	tx1:SetDrawLayer("ARTWORK");
	tx1:SetTexture("Interface\\TradeSkillFrame\\UI-TradeSkill-SkillBorder");
	tx1:SetTexCoord(0.1, 1.0, 0, 0.25);
	tx1:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -(titleHeight-4));
	tx1:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -5, -(titleHeight+4));
	tx1:Show();

	local tx2 = VFLUI.CreateTexture(titleBar);
	tx2:SetDrawLayer("ARTWORK");
	tx2:SetTexture(1,1,1); tx2:SetGradient("HORIZONTAL",1,1,1,0.1,0.1,0.1);
	tx2:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -5);
	tx2:SetPoint("BOTTOMRIGHT", self, "TOPRIGHT", -5, -titleHeight);
	tx2:Show();

	function self:SetText(txt) titleText:SetText(txt); end
	function self:SetTitleColor(r,g,b) tx2:SetTexture(r,g,b); end

	local clientArea = self:GetClientArea();
	clientArea:ClearAllPoints();
	clientArea:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -titleHeight-2);

	local buttonArea = self:GetButtonArea();
	buttonArea:SetHeight(titleHeight * .70);
	buttonArea:SetPoint("RIGHT", self, "TOPRIGHT", -5, -(titleHeight/2)-2);
	buttonArea:Show();

	function self:Accomodate(dx, dy)
		self:SetWidth(dx + 10); self:SetHeight(dy + titleHeight + 7);
	end

	function self:_Destroy()
		VFLUI.ReleaseRegion(titleText); titleText = nil;
		VFLUI.ReleaseRegion(tx1); tx1 = nil;
		VFLUI.ReleaseRegion(tx2); tx2 = nil;
	end

	function self:_Layout()
		local tw = self:GetWidth() - 10;
		titleBar:SetWidth(tw - buttonArea:GetWidth());
		clientArea:SetWidth(tw);
		clientArea:SetHeight(self:GetHeight() - (titleHeight + 7));
	end

	self:_Layout();
end

--- Create a new Window
function VFLUI.Window:new(parent)
	local self = VFLUI.AcquireFrame("Frame");
	if parent then
		self:SetParent(parent); self:SetFrameStrata(parent:GetFrameStrata());
		self:SetFrameLevel(parent:GetFrameLevel() + 1000);
	end
	
	-------------------------------- PREDECL
	self._Destroy = VFL.Noop; self._Layout = VFL.Noop;

	-------------------------------- TITLE REGION
	local titleBar = VFLUI.AcquireFrame("Button");
	titleBar:SetParent(self); titleBar:SetFrameLevel(self:GetFrameLevel() + 1);

	--------------------------------- CLIENT AREA
	local clientArea = VFLUI.AcquireFrame("Frame");
	clientArea:SetParent(self); clientArea:SetFrameLevel(self:GetFrameLevel());
	clientArea:Show();

	--- Get the client area frame of this window.
	function self:GetClientArea() return clientArea; end

	--------------------------------- BUTTON AREA
	local FnDestroyButtons, lastBtn = VFL.Noop, nil;
	local buttonArea = VFLUI.AcquireFrame("Frame");
	buttonArea:SetParent(self); buttonArea:SetFrameLevel(self:GetFrameLevel());
	buttonArea:SetWidth(0); buttonArea:SetHeight(0); buttonArea:Hide();

	--- Get the button area frame of this window
	function self:GetButtonArea() return buttonArea; end

	function self:AddButton(btn)
		btn:SetParent(buttonArea); btn:SetFrameLevel(self:GetFrameLevel() + 10);
		btn:SetWidth(buttonArea:GetHeight()); btn:SetHeight(buttonArea:GetHeight());
		buttonArea:SetWidth(buttonArea:GetWidth() + buttonArea:GetHeight());
		if lastBtn then
			btn:SetPoint("RIGHT", lastBtn, "LEFT");
		else
			btn:SetPoint("TOPRIGHT", buttonArea, "TOPRIGHT");
		end
		btn:Show();
		FnDestroyButtons = VFL.hook(function() btn:Destroy(); end, FnDestroyButtons);
		lastBtn = btn;
		self:_Layout();
	end
	
	-------------------------------- INITIALIZATION
	function self:Reset()
		FnDestroyButtons(); FnDestroyButtons = VFL.Noop; lastBtn = nil;
		self:_Destroy(); self._Destroy = VFL.Noop; self._Layout = VFL.Noop;
		titleBar:ClearAllPoints(); titleBar:SetWidth(0); titleBar:SetHeight(0); titleBar:Show();
		buttonArea:ClearAllPoints(); buttonArea:SetWidth(0); buttonArea:SetHeight(0); buttonArea:Hide();
		clientArea:ClearAllPoints(); clientArea:SetAllPoints(self); clientArea:Show();
		self:SetBackdrop(nil); -- BUGFIX: clear any backdrop on self that may have been set by the framing.
		function self:GetTitleBar() return titleBar; end
		function self:GetTitleHeight() return 0; end
		function self:SetText(txt) end
		function self:SetTitleColor(r,g,b) end
		function self:Accomodate(dx, dy) self:SetWidth(dx); self:SetHeight(dy); end
	end
	self:SetScript("OnShow", function() self:_Layout(); end);
	self:SetScript("OnSizeChanged", function() self:_Layout(); end);

	----------- DESTRUCTOR
	self.Destroy = VFL.hook(function(s)
		-- Destroy framing
		if self._Destroy then 
			self:_Destroy(); self._Destroy = nil; 
		end
		self._Layout = nil;
		FnDestroyButtons(); FnDestroyButtons = nil; lastBtn = nil;
		titleBar:Destroy(); titleBar = nil;
		clientArea:Destroy(); clientArea = nil;
		buttonArea:Destroy(); buttonArea = nil;
		-- Destroy functionals
		self.AddButton = nil; self.Accomodate = nil; self.GetClientArea = nil;
		self.GetTitleHeight = nil; self.GetTitleBar = nil; self.SetText = nil;
		self.SetTitleColor = nil; self.GetButtonArea = nil; self.Reset = nil;
	end, self.Destroy);
	
	self:Reset();
	return self;
end

function wtest(n)
	if not n then n=24; end
	theWindow = VFLUI.Window:new(nil);
	VFLUI.Window.SetDefaultFraming(theWindow, n);
	theWindow:SetWidth(200); theWindow:SetHeight(100);
	theWindow:SetPoint("CENTER", UIParent, "CENTER");
	theWindow:SetTitleColor(0,.8,0);
	theWindow:SetText("Scourgify");
	local btn1 = VFLUI.CloseButton:new();
	theWindow:AddButton(btn1);
	theWindow:Show();
end
