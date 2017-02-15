-- Shortcuts.lua
-- VFL
-- (C)2006 Bill Johnson and The VFL Project
--
-- Shortcuts to make common UI manipulations easier.

--- Makes a label on the given frame. A label is just a noninteractive
-- text string. All you need to do is anchor the label after you get it back
-- from this function; sizing is automatic.
--
-- Intended to be single-line.
function VFLUI.MakeLabel(src, parent, text)
	local fs = VFLUI.CreateFontString(parent);
	fs:SetFontObject(Fonts.Default10); fs:SetHeight(10);
	fs:SetJustifyH("LEFT"); fs:SetJustifyV("CENTER");
	fs:SetText(text); fs:SetWidth(fs:GetStringWidth() + 5);
	fs:Show();
	parent.Destroy = VFL.hook(function() VFLUI.ReleaseRegion(fs); fs = nil; end, parent.Destroy);
	return fs;
end

--- Makes a default-styled button on the given frame. You'll have to add the anchors 
-- and OnClick script yourself.
function VFLUI.MakeButton(src, parent, text, width)
	local btn = VFLUI.Button:new(parent);
	btn:SetHeight(25); btn:SetWidth(width); btn:SetText(text); btn:Show();
	parent.Destroy = VFL.hook(function() btn:Destroy(); btn = nil; end, parent.Destroy);
	return btn;
end
