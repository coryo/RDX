-- Frame_Scroll.lua
-- VFL
-- (C)2006 Bill Johnson
--
-- Generators for horizontal and vertical scrollbars, and other scrolling-
-- related frametypes.

-- Internal: Create a scroll button with the given textures.
local function CreateScrollButton(nrm, psh, dis, hlt)
	local self = VFLUI.AcquireFrame("Button");
	-- Size is 16x16
	self:SetWidth(16); self:SetHeight(16);

	-- Button textures
	self:SetNormalTexture(nrm);
	self:SetPushedTexture(psh);
	self:SetDisabledTexture(dis);
	
	-- Highlight texture requires special handling (for blend mode)
	local hltTex = VFLUI.CreateTexture(self);
	hltTex:SetAllPoints(self); hltTex:Show();
	hltTex:SetTexture(hlt);
	hltTex:SetBlendMode("ADD");
	self:SetHighlightTexture(hltTex);
	self.hltTex = hltTex;

	self.Destroy = VFL.hook(function(s) 
		VFLUI.ReleaseRegion(s.hltTex);
		s.hltTex = nil;
	end, self.Destroy);

	return self;
end

--- Check the value of a scroll bar, and grey out the scroll buttons
-- as appropriate.
function VFLUI.ScrollBarRangeCheck(sb)
	local min,max = sb:GetMinMaxValues();
	local val = sb:GetValue();
	if(VFL.close(val,min)) then
		sb.btnDecrease:Disable();
	else
		sb.btnDecrease:Enable();
	end
	if(VFL.close(val, max)) then
		sb.btnIncrease:Disable();
	else
		sb.btnIncrease:Enable();
	end
end

--- Create a button with the VFL "Scroll up" skin.
function VFLUI.CreateScrollUpButton()
	return CreateScrollButton("Interface\\Addons\\VFL\\Skin\\sb_up", 
		"Interface\\Addons\\VFL\\Skin\\sb_up_pressed", 
		"Interface\\Addons\\VFL\\Skin\\sb_up_disabled",
		"Interface\\Addons\\VFL\\Skin\\sb_up_hlt");
end

--- Create a button with the VFL "Scroll down" skin.
function VFLUI.CreateScrollDownButton()
	return CreateScrollButton("Interface\\Addons\\VFL\\Skin\\sb_down", 
		"Interface\\Addons\\VFL\\Skin\\sb_down_pressed", 
		"Interface\\Addons\\VFL\\Skin\\sb_down_disabled",
		"Interface\\Addons\\VFL\\Skin\\sb_down_hlt");
end

--- Create a button with the "Scroll right" skin
function VFLUI.CreateScrollRightButton()
	return CreateScrollButton("Interface\\Addons\\VFL\\Skin\\sb_right", 
		"Interface\\Addons\\VFL\\Skin\\sb_right_pressed", 
		"Interface\\Addons\\VFL\\Skin\\sb_right_disabled",
		"Interface\\Addons\\VFL\\Skin\\sb_right_hlt");
end

--- Create a button with the "Scroll left" skin
function VFLUI.CreateScrollLeftButton()
	return CreateScrollButton("Interface\\Addons\\VFL\\Skin\\sb_left", 
		"Interface\\Addons\\VFL\\Skin\\sb_left_pressed", 
		"Interface\\Addons\\VFL\\Skin\\sb_left_disabled",
		"Interface\\Addons\\VFL\\Skin\\sb_left_hlt");
end

local vsb_backdrop = {
	bgFile="Interface\\Addons\\VFL\\Skin\\sb_vgutter"; 
	insets = { left = 1; right = 0; top = 0; bottom = 0; }; 
	tile = true; tileSize = 16;
};

VFLUI.VScrollBar = {};
--- Create a new vertical scrollbar.
function VFLUI.VScrollBar:new(parent)
	local self = VFLUI.AcquireFrame("Slider");
	self:SetWidth(16); self:SetHeight(0);

	if parent then
		self:SetParent(parent);
		self:SetFrameStrata(parent:GetFrameStrata());
		self:SetFrameLevel(parent:GetFrameLevel());
	end

	-- Gutter texture
	self:SetBackdrop(vsb_backdrop);
	-- Thumb texture
	local sbThumb = self:CreateTexture();
	sbThumb:SetWidth(16); sbThumb:SetHeight(16); sbThumb:Show();
	sbThumb:SetTexture("Interface\\Addons\\VFL\\Skin\\sb_nub");
	self:SetThumbTexture(sbThumb);

	-- Create the up/down buttons
	local btn = VFLUI.CreateScrollUpButton();
	btn:SetParent(self); btn:Show();
	btn:SetPoint("BOTTOM", self, "TOP");
	btn:SetScript("OnClick", function()
		local sb = this:GetParent();
		local min,max = sb:GetMinMaxValues();
		sb:SetValue(sb:GetValue() - ((max-min) / 5));
		PlaySound("UChatScrollButton");
	end);
	self.btnDecrease = btn;

	btn = VFLUI.CreateScrollDownButton();
	btn:SetParent(self); btn:Show();
	btn:SetPoint("TOP", self, "BOTTOM");
	btn:SetScript("OnClick", function()
		local sb = this:GetParent();
		local min,max = sb:GetMinMaxValues();
		sb:SetValue(sb:GetValue() + ((max-min) / 5));
		PlaySound("UChatScrollButton");
	end);
	self.btnIncrease = btn;

	-- Create the onscroll script
	self:SetScript("OnValueChanged", function()
		VFLUI.ScrollBarRangeCheck(this);
		local p = this:GetParent();
		if p and p.SetVerticalScroll then
			p:SetVerticalScroll(arg1);
		end
	end);

	-- Hook the destroy handler
	self.Destroy = VFL.hook(function(self)
		self.btnDecrease:Destroy(); self.btnDecrease = nil;
		self.btnIncrease:Destroy(); self.btnIncrease = nil;
	end, self.Destroy);

	-- Done
	return self;
end

---------------------------------------
-- @class VFLUI.VScrollFrame
-- A class similar to a Blizzard ScrollFrame, preloaded with VFL-themed
-- scrollbars and appropriate scripts.
---------------------------------------
VFLUI.VScrollFrame = {};
function VFLUI.VScrollFrame:new(parent)
	local self = VFLUI.AcquireFrame("ScrollFrame");
	self.offset = 0; self.scrollBarHideable = nil;

	if parent then
		self:SetParent(parent);
		self:SetFrameStrata(parent:GetFrameStrata());
		self:SetFrameLevel(parent:GetFrameLevel() + 1);
	end

	local sb = VFLUI.VScrollBar:new(self);
	sb:SetPoint("TOPLEFT", self, "TOPRIGHT", 0, -16);
	sb:SetPoint("BOTTOMLEFT", self, "BOTTOMRIGHT", 0, 16);
	sb.btnIncrease:Disable(); sb.btnDecrease:Disable();
	sb:Show();

	local OnScrollRangeChanged = function()
		scrollrange = self:GetVerticalScrollRange();
		local value = sb:GetValue();
		if ( value > scrollrange ) then value = scrollrange; end
		sb:SetMinMaxValues(0, scrollrange);
		sb:SetValue(value);
		if ( math.floor(scrollrange) == 0 ) then
			if (this.scrollBarHideable ) then
				sb:Hide();
			else
				sb:Show();
				sb.btnIncrease:Disable(); sb.btnIncrease:Show();
				sb.btnDecrease:Disable(); sb.btnDecrease:Show();
			end
		else
			sb:Show();
			sb.btnDecrease:Show();
			sb.btnIncrease:Show(); sb.btnIncrease:Enable();
		end
	end

	self:SetScript("OnScrollRangeChanged", OnScrollRangeChanged);

	local BlizzSetScrollChild = getmetatable(self).__index(self, "SetScrollChild");
	self.SetScrollChild = function(s, sc)
		VFLUI:Debug(1, "VSFSetScrollChild " .. tostring(sc));
		BlizzSetScrollChild(s, sc);
		if sc then
			VFLUI.AddScript(sc, "OnSizeChanged", function() 
				VFLUI:Debug(5, "obj(" .. tostring(this) .. "):OnSizeChanged(): notifying scrollframe(" .. tostring(s) .. ") that our size is " .. this:GetWidth() .. "x" .. this:GetHeight());
				s:UpdateScrollChildRect(); 
				OnScrollRangeChanged();
			end);
		end
	end



	self:SetScript("OnVerticalScroll", function() sb:SetValue(arg1); VFLUI.ScrollBarRangeCheck(sb); end);

	self.Destroy = VFL.hook(function(s)
		self.offset = nil; self.scrollBarHideable = nil;
		self.SetScrollChild = nil;
		sb:Destroy();
	end, self.Destroy);
	return self;
end

---------------------------------------------------
-- @class VFLUI.HScrollBar
-- A horizontal slider.
---------------------------------------------------
local hsb_backdrop = {
	bgFile="Interface\\Addons\\VFL\\Skin\\sb_hgutter"; 
	insets = { left = 0; right = 0; top = 0; bottom = 0; }; 
	tile = true; tileSize = 16;
};
VFLUI.HScrollBar = {};
function VFLUI.HScrollBar:new(parent)
	local self = VFLUI.AcquireFrame("Slider");
	self:SetHeight(16); self:SetWidth(0);
	self:SetOrientation("HORIZONTAL");
	if parent then
		self:SetParent(parent);
		self:SetFrameStrata(parent:GetFrameStrata());
		self:SetFrameLevel(parent:GetFrameLevel());
	end

	-- Gutter texture
	self:SetBackdrop(hsb_backdrop);
	-- Thumb texture
	local sbThumb = self:CreateTexture();
	sbThumb:SetWidth(16); sbThumb:SetHeight(16); sbThumb:Show();
	sbThumb:SetTexture("Interface\\Addons\\VFL\\Skin\\sb_nub");
	self:SetThumbTexture(sbThumb);

	-- Create the up/down buttons
	local btn = VFLUI.CreateScrollLeftButton();
	btn:SetParent(self); btn:Show();
	btn:SetPoint("RIGHT", self, "LEFT");
	btn:SetScript("OnClick", function()
		local sb = this:GetParent();
		local min,max = sb:GetMinMaxValues();
		sb:SetValue(sb:GetValue() - ((max-min) / 5));
		PlaySound("UChatScrollButton");
	end);
	self.btnDecrease = btn;

	btn = VFLUI.CreateScrollRightButton();
	btn:SetParent(self); btn:Show();
	btn:SetPoint("LEFT", self, "RIGHT");
	btn:SetScript("OnClick", function()
		local sb = this:GetParent();
		local min,max = sb:GetMinMaxValues();
		sb:SetValue(sb:GetValue() + ((max-min) / 5));
		PlaySound("UChatScrollButton");
	end);
	self.btnIncrease = btn;

	-- Create the onscroll script
	self:SetScript("OnValueChanged", function()
		VFLUI.ScrollBarRangeCheck(this);
		local p = this:GetParent();
		if p and p.SetHorizontalScroll then
			p:SetHorizontalScroll(arg1);
		end
	end);

	-- Hook the destroy handler
	self.Destroy = VFL.hook(function(self)
		self.btnDecrease:Destroy(); self.btnDecrease = nil;
		self.btnIncrease:Destroy(); self.btnIncrease = nil;
	end, self.Destroy);

	-- Done
	return self;
end

--------------------------------------------------------------------
-- SLIDER VALUE TIP
-- This tooltip-like object is used by UI sliders to display their
-- current value.
--------------------------------------------------------------------
local svt = VFLUI.AcquireFrame("Frame");
svt:SetParent(UIParent); svt:SetFrameStrata("FULLSCREEN_DIALOG"); svt:SetFrameLevel(100);
svt:SetWidth(50); svt:SetHeight(24);
svt:SetBackdrop(VFLUI.DefaultDialogBackdrop); svt:Hide();
local txt = VFLUI.CreateFontString(svt);
txt:SetPoint("CENTER", svt, "CENTER"); txt:SetWidth(40); txt:SetHeight(16);
txt:SetFontObject(Fonts.Default); txt:Show();

--- Shows the slider value tip at the current mouse position using arg1 as the value.
function VFLUI.ShowSliderValueTip(value)
	if not svt:IsShown() then
		svt:Show();
		svt:SetScript("OnUpdate", function()
			if GetTime() > this.hideTime then
				this.hideTime = nil; 
				this:SetScript("OnUpdate", nil); 
				this:Hide();
			end
		end);
	end
	local x,y = GetRelativeLocalMousePosition(UIParent); y = y + 20; x = x - 10
	svt:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, y);
	txt:SetText(string.format("%0.2f", value));
	svt.hideTime = GetTime() + 3;
end

function VFLUI.Slider_OnValueChanged()
	VFLUI.ShowSliderValueTip(arg1);
	VFLUI.ScrollBarRangeCheck(this);
end

function VFLUI.Slider_OnEnter()
	VFLUI.ShowSliderValueTip(this:GetValue());
end
