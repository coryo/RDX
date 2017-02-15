-- VFL_CommonControls.lua
-- VFL
-- Venificus' Function Library
--
-- Implementation of a set of controls with common appearance
-- and functionality to ease UI design.
if not VFL.CC then VFL.CC = {}; end
-------------------------------------
-- Font supporting functions
-------------------------------------
-- Get the path to VFL
function VFL.GetPath()
	return "Interface\\Addons\\VFL";
end
-- Get the path to the VFL font file.
function VFL.GetFontFile()
	return "Interface\\Addons\\VFL\\Fonts\\framd.ttf";
end
function VFL.GetThinFontFile()
	return "Interface\\Addons\\VFL\\Fonts\\bs.ttf";
end

-----------------------
-- Supporting functions for VFLStaticT
-----------------------
function VFL.CC.Static_Setup(self, x)
	self.txt:SetText(x);
end
function VFL.CC.Static_Align(self,h,v)
	self.txt:SetJustifyH(h); self.txt:SetJustifyV(v); 
end
function VFL.CC.Static_Color(self,r,g,b)
	self.txt:SetTextColor(r,g,b);
end
function VFL.CC.Static_SetFontSize(self, sz)
	self.txt:SetFont(VFL.GetFontFile(), sz);
end

function Label_Gold(x)
	x:Color(0.85, 0.8, 0);
end

function CC_ColorFromTbl(x, tbl)
	x.txt:SetTextColor(tbl.r, tbl.g, tbl.b);
end

function CC_ColorFromRGB(x,r,g,b)
	x.txt:SetTextColor(r,g,b);
end

function CC_ColorGold(x)
	CC_ColorFromRGB(x,0.85,0.8,0);
end

-----------------------
-- Supporting functions for VFLChkT
-----------------------
function VFL.CC.Chk_OnLoad(f)
	f.chk = getglobal(f:GetName() .. "Chk");
	f.txt = getglobal(f:GetName() .. "Txt");
	f.Set = VFL.CC.Chk_Set;
	f.Get = VFL.CC.Chk_Get;
	f.Setup = VFL.CC.Chk_Setup;
end
function VFL.CC.Chk_Set(self, x)
	self.chk:SetChecked(x);
end
function VFL.CC.Chk_Get(self)
	return self.chk:GetChecked();
end
function VFL.CC.Chk_Setup(self, txt)
	self.txt:SetText(txt);
end

---------------------------
-- Supporting functions for scrollbars
--------------------------
function VFL.CC.Scroll_DisableBtns(sb)
	local min,max = sb:GetMinMaxValues();
	local val = sb:GetValue();
	if(val == min) then
		sb.btnReduce:Disable();
	else
		sb.btnReduce:Enable();
	end
	if(val == max) then
		sb.btnIncrease:Disable();
	else
		sb.btnIncrease:Enable();
	end
end

function VFL.CC.Scroll_RangeChanged(scrollbar, scrollrange)
	Root:Debug(5, "VFL.CC.Scroll_RangeChanged(" .. scrollbar:GetName() .. "," .. tostring(scrollrange) ..")");
	if ( not scrollrange ) then
		scrollrange = this:GetVerticalScrollRange();
	end
	local value = scrollbar:GetValue();
	if ( value > scrollrange ) then
		value = scrollrange;
	end
	scrollbar:SetMinMaxValues(0, scrollrange);
	scrollbar:SetValue(value);
	if ( floor(scrollrange) == 0 ) then
		if (this.scrollBarHideable ) then
			Root:Debug(5, "VFL.CC.Scroll_RangeChanged: Hiding scrollbar " .. scrollbar:GetName());
			scrollbar:Hide();
		else
			scrollbar:Show();
			getglobal(scrollbar:GetName().."ScrollDownButton"):Disable();
			getglobal(scrollbar:GetName().."ScrollUpButton"):Disable();
			getglobal(scrollbar:GetName().."ScrollDownButton"):Show();
			getglobal(scrollbar:GetName().."ScrollUpButton"):Show();
		end
		
	else
		scrollbar:Show();
		getglobal(scrollbar:GetName().."ScrollDownButton"):Show();
		getglobal(scrollbar:GetName().."ScrollUpButton"):Show();
		getglobal(scrollbar:GetName().."ScrollDownButton"):Enable();
	end
end

----------------------------------
-- Common popup box
----------------------------------
function VFL.CC.Popup(callback, title, text, editVal)
	local dlg,dn = VFLPopBox,"VFLPopBox";
	local edit,txt = getglobal(dn.."Edit"),getglobal(dn.."Text");
	local cancel = function()
		dlg:Hide();
		if callback then callback(false, edit:GetText()); end
	end
	local ok = function()
		dlg:Hide();
		if callback then callback(true, edit:GetText()); end
	end
	-- Setup title
	getglobal(dn.."TitleBkg"):SetGradient("HORIZONTAL",0,0,0.9,0,0,0.1);
	getglobal(dn.."Title"):Setup(title);
	getglobal(dn.."Title"):SetFontSize(12);
	dlg:Show();
	-- Setup editor
	if(editVal) then
		txt:SetHeight(16);
		edit:Show(); edit:SetText(editVal); edit:SetFocus();
		edit:HighlightText(0)
		edit.OnEnterPressed = ok;
	else
		txt:SetHeight(41);
		edit:Hide();
		edit.OnEnterPressed = nil;
	end
	-- Setup primary text
	getglobal(dn.."Text"):Setup(text);
	-- Setup buttons
	getglobal(dn.."OK").OnClick = ok;
	getglobal(dn.."Cancel").OnClick = cancel;
	VFL.AddEscapeHandler(cancel);
end


