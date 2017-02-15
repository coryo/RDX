-- Dropdown.lua
-- VFL
-- (C)2006 Bill Johnson and The VFL Project
--
-- A dropdown box allows the selection of something from a predefined list.
-- Closely related, the combo box is an edit control with an attached dropdown
-- list that also allows the entry of custom data.
VFLUI.Dropdown = {};
function VFLUI.Dropdown:new(parent, onBuild, onSelChanged, initText, initValue)
	if not onBuild then error("expected onBuild function, got nil"); end
	if not onSelChanged then onSelChanged = VFL.Noop; end
	if initText then
		if not initValue then initValue = initText; end
	end

	local self = VFLUI.AcquireFrame("Frame");
	if parent then
		self:SetParent(parent);
		self:SetFrameStrata(parent:GetFrameStrata());
		self:SetFrameLevel(parent:GetFrameLevel() + 1);
	end
	self:SetBackdrop(VFLUI.BlackDialogBackdrop); self:SetHeight(25);

	local selTxt, selValue = initText, initValue;
	
	local txt = VFLUI.CreateFontString(self);
	txt:SetPoint("LEFT", self, "LEFT", 5, 0); txt:SetHeight(12);
	txt:SetFontObject(Fonts.Default);
	txt:SetJustifyH("LEFT");
	if initText then txt:SetText(initText); end
	txt:Show();

	local function Layout()
		txt:SetWidth(math.max(self:GetWidth() - 22, 0));
	end
	self:SetScript("OnShow", Layout);
	self:SetScript("OnSizeChanged", Layout);

	function self:RawSetSelection(text, value)
		if not value then value = text; end
		selTxt = text; selValue = value;
		txt:SetText(selTxt or "");
	end

	function self:SetSelection(text, value)
		if not value then value = text; end
		selTxt = text; txt:SetText(selTxt or "");
		if(selValue ~= value) then
			selValue = value;
			onSelChanged(value);
		end
	end

	function self:GetSelection() return selTxt, selValue; end

	local function Popup()
		if VFL.poptree:IsInUse() then VFL.Escape(); return; end
		VFL.poptree:Begin(math.max(self:GetWidth() - 10, 24), 12, self);
		local mnu = onBuild();
		for _,mentry in mnu do
			local x,y = mentry.text, mentry.value;
			mentry.OnClick = function() self:SetSelection(x,y); VFL.poptree:Release(); end
		end
		VFL.poptree:Expand(nil, mnu);
	end
	
	local btn = VFLUI.AcquireFrame("Button");
	btn:SetParent(self);
	btn:SetHeight(12); btn:SetWidth(12);
	btn:SetNormalTexture("Interface\\Addons\\VFL\\Skin\\sb_down");
	btn:SetPoint("RIGHT", self, "RIGHT", -5, 0); btn:Show();
	btn:SetScript("OnClick", Popup);

	self.Destroy = VFL.hook(function(s)
		VFLUI.ReleaseRegion(txt); txt = nil;
		btn:Destroy(); btn = nil;
		s.SetSelection = nil; s.GetSelection = nil; s.RawSetSelection = nil;
	end, self.Destroy);

	return self;
end

