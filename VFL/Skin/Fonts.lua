-- Fonts.lua
-- VFL - Venificus' Function Library
-- (C)2006 Bill Johnson (Venificus of Eredar server)
--
-- Registration for basic VFL fonts.

Fonts = RegisterVFLModule({
	name = "Fonts";
	description = "Replaceable fonts for VFL applications.";
	version = {6,0,1}; devel = true;
	parent = VFL;
});

-- Font 1: VFL default
Fonts.Default = CreateFont("Font_Default");
Fonts.Default:SetFont("Interface\\Addons\\VFL\\Fonts\\framd.ttf", 12);

Fonts.DefaultItalic = CreateFont("Font_DefaultItalic");
Fonts.DefaultItalic:SetFont("Interface\\Addons\\VFL\\Fonts\\framdit.ttf", 12);

Fonts.Default10 = CreateFont("Font_Default10");
Fonts.Default10:SetFont("Interface\\Addons\\VFL\\Fonts\\framd.ttf", 10);
