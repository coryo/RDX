-- Metadata_Warlock.lua
-- VFL
-- (C)2006 Bill Johnson and The VFL Project
--
-- CLASS METADATA FILE
--
-- The metadata format should be clear from examining the contents below. Note
-- that this file will only be loaded if the player is of the specified class.
-- 
-- Metadata for the Warlock class's spells.
local _,class = UnitClass("player");
if class == "WARLOCK" then
	VFLEvents:Bind("SPELLS_BUILD_CLASSES", nil, function()
		VFLS.ClassifySpell("Detect Lesser Invisibility()", "Detect Invisibility");
		VFLS.ClassifySpell("Detect Invisibility()", "Detect Invisibility");
		VFLS.ClassifySpell("Detect Greater Invisibility()", "Detect Invisibility");
	end);

	VFLEvents:Bind("SPELLS_BUILD_CATEGORIES", nil, function()
		VFLS.CategorizeClass("Shadow Bolt", "DIRECT");
		VFLS.CategorizeClass("Shadow Bolt", "DAMAGE");
	end);
end
