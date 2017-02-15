-- VFL_Abilities.lua
-- VFL (Venificus's function library)
--
-- Objects and functions for managing player abilities.

--------------------------------------------------------
-- EFFECT OBJECT
-- An Effect is a named construct with an associated set of metadata.
-- Usually an effect represents a buff or debuff. Can have an associated
-- spell.
--------------------------------------------------------
if not VFL.Effect then VFL.Effect = {}; end

-- Create a new effect object
function VFL.Effect:new(o)
	local x = o or {};
	setmetatable(x, self);
	self.__index = self;
	return x;
end

-- Initialize an effect to an empty state.
function VFL.Effect:init()
	self.buff = nil; 
	self.debuff = nil; 
	self.text = nil; 
	self.duration = nil;
end
 
-- Get the name of the effect.
function VFL.Effect:GetName()
	return self.name;
end

-- Return true iff the effect is a buff.
function VFL.Effect:IsBuff()
	return self.buff;
end

-- Return the debuff type of the effect, or nil if it is not a debuff.
function VFL.Effect:GetDebuffType()
	return self.debuff;
end

-- Return the numeric ID of the effect, if set.
function VFL.Effect:GetID()
	return self.id;
end

-- Return the duration of the effect; nil indicates infinite duration
function VFL.Effect:GetDuration()
	return self.duration;
end

-- Load an effect from a unit buff index
function VFL.Effect:LoadPlayerBuff(unit, idx)
	-- Stuff tooltip
	VFLTipTextLeft1:SetText(nil);
	VFLTip:SetPlayerBuff(idx);
	if(VFLTipTextLeft1:GetText()) then 
		self.text = string.lower(VFLTipTextLeft1:GetText());
	else
		-- self:init();
		return false;
	end
end




------------------------------------------
-- SPELL OBJECT
-- A Spell represents an ability possessed by the player that can be cast.
------------------------------------------
if not VFL.Spell then VFL.Spell = {}; end

-- Construct a new empty spell
function VFL.Spell:new(o)
	local x = o or {};
	setmetatable(x, self);
	self.__index = self;
	return x;
end;

-- Populate a spell from spell ID
function VFL.Spell:load(id)
	self.id = nil;
	-- Verify spell existence
	local name,qual = GetSpellName(id, SpellBookFrame.bookType);
	if not name then return nil; end
	-- Populate id and title
	self.id = id;
	self.title = name .. "(" .. qual .. ")";
	-- Populate name/qualifiers
	name = string.lower(name);
	qual = string.lower(qual);
	self.name = name; self.qualifier = qual;
	-- Populate rank
	local s,e,num = string.find(qual, "(%d+)");
	if(s) then self.rank = tonumber(s); end
	return true;
end;

-- Is the wrapped spell valid?
function VFL.Spell:IsValid()
	if(self.id == nil) then return false; else return true; end
end;

-- Get the ID of the wrapped spell
function VFL.Spell:GetID()
	return self.id;
end

-- Get the root spell name
function VFL.Spell:GetName()
	return self.name;
end

-- Pure cast
function VFL.Spell:ForceCast()
	CastSpell(self.id, SpellBookFrame.bookType);
end

-- Cast the spell on the current target, aborting target if failure
function VFL.Spell:Cast()
	-- Cast it
	CastSpell(self.id, SpellBookFrame.bookType);
	-- Remove targeting cursor
	if SpellIsTargeting() then SpellStopTargeting(); end
end
