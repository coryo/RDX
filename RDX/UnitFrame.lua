-- UnitFrame.lua
-- RDX 5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Standard data frame for units.
if not RDX.UnitFrame then RDX.UnitFrame = {}; end

----------------------------------------
-- UNITFRAME BASIC FUNCTIONALITY
----------------------------------------
-- Imbue a frame with the functionality of a UnitFrame.
function RDX.UnitFrame.Imbue(f)
	-- A unitframe is also a framecell for grid inclusion
	VFL.FrameCell.Imbue(f);
	-- Acquire subcontrols
	local n = f:GetName();
	f.text1 = getglobal(n.."Txt1");
	f.text2 = getglobal(n.."Txt2");
	f.text3 = getglobal(n.."Txt3");
	f.bar1 = getglobal(n.."B1");
	f.bar2 = getglobal(n.."B2");
	f.bar1:SetMinMaxValues(0,1); f.bar2:SetMinMaxValues(0,1);
	f.icon = {};
	for i=1,4 do
		f.icon[i] = getglobal(n.."I"..i);
	end
	f.hlt = getglobal(n.."Hlt");
	-- Internal variables
	f.purpose = 1;
	-- Functionality
	f.SetSize = RDX.UnitFrame.SetSize;
	f.SetPurpose = RDX.UnitFrame.SetPurpose;
	f.SetFontSize = RDX.UnitFrame.SetFontSize;
end

-- Called to resize
function RDX.UnitFrame:SetSize(dx, dy)
	-- If we're not actually doing anything, ignore
	if (dy == self:GetHeight()) and (dx == self:GetWidth()) then return; end
	-- Update values
	self:SetHeight(dy); self:SetWidth(dx);
	-- Force repurpose
	RDX.UnitFrame.Repurpose[self.purpose](self);
end

-- Change the purpose (layout/style/etc) of this unit frame
function RDX.UnitFrame:SetPurpose(p)
	if p ~= self.purpose then
		self.purpose = p;
		RDX.UnitFrame.Repurpose[p](self);
	end
end

-- Change the font size of this frame
function RDX.UnitFrame:SetFontSize(sz)
 self.text1:SetFont(VFL.GetFontFile(), sz);
 self.text2:SetFont(VFL.GetFontFile(), sz);
 self.text3:SetFont(VFL.GetFontFile(), sz);
end

-- Repurposing functions
RDX.UnitFrame.Repurpose = {};

-- Purpose 1: Single percentage bar only
RDX.UnitFrame.Repurpose[1] = function(self)
	local w,h = self:GetWidth(), self:GetHeight();
	-- Align first text box
	self.text1:SetHeight(h);  self.text1:SetWidth(w / 2);
	self.text1:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 1);
	self.text1:Show();
	-- Align second text box
	self.text2:SetHeight(h); self.text2:SetWidth(w / 2);
	self.text2:SetPoint("TOPLEFT", self.text1, "TOPRIGHT");
	self.text2:Show();
	self.text3:Hide();
	-- Align percentage bar
	self.bar1:SetPoint("TOPLEFT", self);
	self.bar1:SetPoint("BOTTOMRIGHT", self);
	self.bar1:Show();
	-- Hide second percentage bar
	self.bar2:Hide();
	-- Hide all icons
	for i=1,4 do self.icon[i]:Hide(); end
end
-- Purpose 2: Two percentage bars
RDX.UnitFrame.Repurpose[2] = function(self)
	local w,h=self:GetWidth(),self:GetHeight();
	-- Align first text box
	self.text1:SetHeight(h);  self.text1:SetWidth(w / 2);
	self.text1:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 1);
	self.text1:Show();
	-- Align second text box
	self.text2:SetHeight(h); self.text2:SetWidth(w / 2);
	self.text2:SetPoint("TOPLEFT", self.text1, "TOPRIGHT");
	self.text2:Show();
	self.text3:Hide();
	-- Align bars
	self.bar1:ClearAllPoints();
	self.bar1:SetPoint("TOPLEFT", self); self.bar1:SetHeight(h/2); self.bar1:SetWidth(w); self.bar1:Show();
	self.bar2:ClearAllPoints();
	self.bar2:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -h/2); self.bar2:SetHeight(h/2); self.bar2:SetWidth(w); self.bar2:Show();
	-- Hide all icons
	for i=1,4 do self.icon[i]:Hide(); end
end
-- Purpose 3: No percentage bars. One left-aligned textbox.
-- Four icons anchored on the right.
RDX.UnitFrame.Repurpose[3] = function(self)
	local w,h=self:GetWidth(),self:GetHeight();
	-- Align first text box
	self.text1:SetHeight(h);  self.text1:SetWidth(w / 2);
	self.text1:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 1);
	self.text1:Show();
	-- Hide second text and bars
	self.text2:Hide(); 	self.text3:Hide(); self.bar1:Hide(); self.bar2:Hide();
	-- Align icons
	local af = self.text1;
	for i=1,4 do
		self.icon[i]:ClearAllPoints();
		self.icon[i]:SetPoint("LEFT", af, "RIGHT");
		self.icon[i]:SetFrameLevel(10);
		self.icon[i]:Hide();
		af = self.icon[i];
	end
end
-- Purpose 4: Text1 only
RDX.UnitFrame.Repurpose[4] = function(self)
	local w,h = self:GetWidth(),self:GetHeight();
	-- Align first text box
	self.text1:SetHeight(h);  self.text1:SetWidth(w);
	self.text1:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 1);
	self.text1:Show();
	-- Hide second text and bars
	self.text2:Hide();	self.text3:Hide(); self.bar1:Hide(); self.bar2:Hide();
	-- Hide icons
	for i=1,4 do self.icon[i]:Hide(); end
end
-- Purpose 5: Two textboxes, no percent bars
RDX.UnitFrame.Repurpose[5] = function(self)
	local w,h = self:GetWidth(),self:GetHeight();
	-- Align first text box
	self.text1:SetHeight(h);  self.text1:SetWidth(50);
	self.text1:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 1);
	self.text1:Show();
	-- Align second text box
	self.text2:SetHeight(h); self.text2:SetWidth(w-50);
	self.text2:SetPoint("TOPLEFT", self.text1, "TOPRIGHT");
	self.text2:Show();
	self.text3:Hide();
	-- Hide other ui elements
	self.bar1:Hide(); self.bar2:Hide();
	for i=1,4 do self.icon[i]:Hide(); end
end
-- Purpose 6: Single percentage bar only, small percent text, big other text
RDX.UnitFrame.Repurpose[6] = function(self)
	local w,h = self:GetWidth(), self:GetHeight();
	-- Align first text box
	self.text1:SetHeight(h);  self.text1:SetWidth(w-40);
	self.text1:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 1);
	self.text1:Show();
	-- Align second text box
	self.text2:SetHeight(h); self.text2:SetWidth(40);
	self.text2:SetPoint("TOPLEFT", self.text1, "TOPRIGHT");
	self.text2:Show();
	self.text3:Hide();
	-- Align percentage bar
	self.bar1:SetPoint("TOPLEFT", self);
	self.bar1:SetPoint("BOTTOMRIGHT", self);
	self.bar1:Show();
	-- Hide second percentage bar
	self.bar2:Hide();
	-- Hide all icons
	for i=1,4 do self.icon[i]:Hide(); end
end
-- Purpose 7: 3 text boxes, large center box
RDX.UnitFrame.Repurpose[7] = function(self)
	local w,h = self:GetWidth(), self:GetHeight();
	self.text1:SetHeight(h); self.text1:SetWidth(45);
	self.text1:SetPoint("TOPLEFT", self, "TOPLEFT");
	self.text1:Show();
	self.text3:SetHeight(h); self.text3:SetWidth(w-85);
	self.text3:SetPoint("TOPLEFT", self.text1, "TOPRIGHT");
	self.text3:Show();
	self.text2:SetHeight(h); self.text2:SetWidth(40);
	self.text2:SetPoint("TOPLEFT", self.text3, "TOPRIGHT");
	self.text2:Show();
	self.bar1:Hide(); self.bar2:Hide();
	for i=1,4 do self.icon[i]:Hide(); end
end

-------------------------------------------------
-- UNITFRAME API
-------------------------------------------------
function RDX.SetStatusBar(bar, val, color, fadeColor)
	if fadeColor then
		tempcolor:blend(fadeColor, color, val);
		bar:SetStatusBarColor(tempcolor.r, tempcolor.g, tempcolor.b);
	else
		bar:SetStatusBarColor(color.r, color.g, color.b);
	end
	bar:SetValue(val);
end

function RDX.SetStatusText(txt, val, color, fadeColor)
	if fadeColor then
		tempcolor:blend(fadeColor, color, val);
		txt:SetTextColor(tempcolor.r, tempcolor.g, tempcolor.b);
	else
		txt:SetTextColor(color.r, color.g, color.b);
	end
end

function RDX.GenStatusColor(val, color, fadeColor)
	if fadeColor then
		tempcolor:blend(fadeColor, color, val);
	else
		tempcolor.r = color.r; tempcolor.g = color.g; tempcolor.b = color.b
	end
end


--------------------------------------------------
-- GLOBAL UNITFRAME POOL
--------------------------------------------------
RDX.UnitFramePool = VFL.Pool:new();
-- Handler for when frames are released into the framepool
RDX.UnitFramePool.OnRelease = function(pool, x)
	-- Reset appearance parameters
	x:SetParent(nil); x:SetFontSize(10);
	x:Hide();
	-- Clear straggling handlers and userdata
	x.OnClick = nil;
	x._tmp = nil;
	x:SetScript("OnUpdate", nil); x:SetScript("OnEnter", nil); x:SetScript("OnLeave", nil);
end

-- Initialize the RDX unitframe pool.
function RDX.UnitFrame.Init()
	VFL.debug("RDX.UnitFrame.Init()", 5);
	RDX.UnitFramePool:Fill("RDXUF");
end
