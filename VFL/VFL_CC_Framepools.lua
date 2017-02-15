-- VFL_CC_Framepools.lua
-- VFL - Venificus' Function Library
--  
-- Basic code to create and populate framepools.
-- 
--
-- Selectables
--VFL.selectablePool = VFL.Pool:new();
--VFL.selectablePool.OnRelease = function(pool, f)
--	f:ClearAllPoints();
--	f:SetScript("OnMouseUp", nil);
--	f:SetScript("OnMouseDown", nil);
--	f:Hide(); f:SetAlpha(1); f:SetParent(nil);
--end
--VFL.selectablePool:Fill("VFLSelF");
-- Containers
VFL.containerPool = VFL.Pool:new();
VFL.containerPool.OnRelease = function(pool, f)
	f:SetParent("UIParent");
	f:ClearAllPoints(); f:SetWidth(20); f:SetHeight(20);
	f:Hide(); f:SetAlpha(1);
end
VFL.containerPool:Fill("VFLContF");
-- Scrollbars
VFL.vscrollPool = VFL.Pool:new();
VFL.vscrollPool.OnRelease = function(pool, f)
	f:SetParent("UIParent"); f:ClearAllPoints(); f:Hide(); f:SetAlpha(1);
end
VFL.vscrollPool:Fill("VFLVSB");

-- Editboxes
VFL.editPool = VFL.Pool:new();
VFL.editPool.OnRelease = function(pool, f)
	f:SetParent(nil);
	f:ClearAllPoints(); f:SetText(""); f:SetAlpha(1);
	f:Hide();
end
VFL.editPool:Fill("VFLEd");
