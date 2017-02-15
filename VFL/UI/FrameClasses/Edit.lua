-- Edit.lua
-- VFL
-- (C)2006 Bill Johnson
--
-- VFLized implementations of the WoW EditBox frame.


VFLUI.Edit = {};
--- Create a new single-line edit control.
function VFLUI.Edit:new(parent)
	local self = VFLUI.AcquireFrame("EditBox");

	if parent then
		self:SetParent(parent);
		self:SetFrameStrata(parent:GetFrameStrata());
		self:SetFrameLevel(parent:GetFrameLevel() + 1);
	end

	-- Appearance
	self:SetBackdrop(VFLUI.BlackDialogBackdrop);
	self:SetFontObject(Fonts.Default);
	self:SetTextInsets(5,5,5,5);
	self:SetAutoFocus(nil); self:ClearFocus();

	-- Scripts
	self:SetScript("OnEscapePressed", function() this:ClearFocus(); end);
	
	return self;
end

--- This function resets the cursor position in an EditBox on the next frame.
-- From http://www.wowwiki.com/HOWTO:_Scroll_EditBoxes_to_the_left_programatically
function VFLUI.FixEditBoxCursor(eb)
	eb:SetScript("OnUpdate", function()
		this:HighlightText(0,1);
		this:Insert(" "..strsub(this:GetText(),1,1));
		this:HighlightText(0,1);
		this:Insert("");
		this:SetScript("OnUpdate", nil);
	end);
end
