-- VFL
-- WoW Gameplay-manipulating components
--
VFL.Game = {
	-- Number of people in group
	groupSize = 5;
	-- Number of groups in a raid
	numRaidGroups = 8;
	-- Class lookup tables
	classID = {"priest", "druid", "rogue", "hunter", "mage", "warlock", "warrior", "paladin", "shaman"};
	classIDByName = {};
	-- Debuff type table
	debuffTypes = { "magic", "curse", "disease", "poison" };
};

VFL.Game.classIDByName = VFL.table.transform(VFL.Game.classID, function(k,v) return v,k; end);


-----------------------
-- SUPPORTING FUNCTIONS
------------------------
-- Tries to target the given player. If it fails, attempts to revert to previous target.
function TryToTarget(name)
	if not name then ClearTarget(); return; end
	name = string.lower(name);
	local prevt = UnitName("target");
	-- Try to retarget
	TargetByName(name);
	-- If targeting failed
	if (not UnitName("target")) or not (string.lower(UnitName("target")) == name) then
		-- Retarget to previous
		if(prevt) then TargetByName(prevt); end
		-- If that failed
		if not (UnitName("target") == prevt) then
			ClearTarget();
		end
		return false;
	else
		return true;
	end
end;

-------------------------
-- SPELL DATABASING
-------------------------

-- For each spell I have, I want to know:
--	Buff ID
-- 	GetGroupVersion
--	Full/partial name
--	Debuff types cured
-- 	Rank
-- Also need:
-- 	Ability to list buffs I have, by buff ID.
-- 	Ability to index cures I have, by debuff type.
VFL.Game.Spell = {};

-- Construct a new spell
function VFL.Game.Spell:new(o)
	local x = o or {};
	setmetatable(x, self);
	self.__index = self;
	return x;
end;

-- Populate a spell from a spell ID.
function VFL.Game.Spell:load(id)
	self.id = id;
	self.meta = nil;
	-- Obtain data from WOW
	local name,qual = GetSpellName(id, SpellBookFrame.bookType);
	if not name then return nil; end
	self.officialTitle = name .. "(" .. qual .. ")"; -- Official Blizzard spell title.
	name = string.lower(name);
	qual = string.lower(qual);
	-- Pop variables
	self.name = name; self.qualifier = qual;
	self.rank = 0;
	local s,e,num = string.find(qual, "(%d+)");
	if(s) then
		self.rank = tonumber(num);
	end
	-- Check for metadata
	self.meta = VFL.Game.Spell._metaByName[name];
	return true;
end;

-- Get the ID of a spell.
function VFL.Game.Spell:GetID()
	return self.id;
end;

-- Get the spell name of a spell.
function VFL.Game.Spell:GetSpellName()
	return self.name;
end;

-- Get the fully qualified name of a spell
function VFL.Game.Spell:GetFullName()
	return self.name .. "(" .. self.qualifier .. ")";
end;

-- Get the rank of a spell
function VFL.Game.Spell:GetRank()
	return self.rank;
end;

-- Get the metadata for a spell
function VFL.Game.Spell:GetMeta()
	return self.meta;
end;

-- Is spell a buff?
function VFL.Game.Spell:IsBuff()
	if not self.meta then return false; end
	if self.meta.use ~= "buff" then return false; end
	return true;
end;

-- Get BuffID
function VFL.Game.Spell:GetMetaID()
	return self.meta.id;
end;

-- Is spell a cure?
function VFL.Game.Spell:IsCure()
	if not self.meta then return false; end
	if self.meta.use ~= "cure" then return false; end
	return true;
end;

-- Get list of curable types
function VFL.Game.Spell:CureTypes()
	return self.meta.cures;
end;

-- Cast the spell on the current target.
function VFL.Game.Spell:Cast()
	-- Cast it
	CastSpell(self.id, SpellBookFrame.bookType);
	-- Remove targeting cursor if it failed
	if SpellIsTargeting() then SpellStopTargeting(); end
end;

-- Try to cast the spell on the given target
function VFL.Game.Spell:CastOn(t)
	-- Try to target the intended spell target, abort on failure
	if not TryToTarget(t) then return; end 
	-- Cast the spell
	self:Cast();
end;

-- Find the group version of a spell, if applicable.
function VFL.Game.Spell:GetGroupVersion()
	if not self.meta then return nil; end
	if not self.meta.group then return nil; end
	return VFL.Game.Spell.lookup(self.meta.group);
end;

-- SPELL LOOKUP API
VFL.Game.Spell._stbl = {}; -- Spells by ID
VFL.Game.Spell._ntbl = {}; -- Spells by fullname
VFL.Game.Spell._btbl = {}; -- Highest ranking spells by spellname
VFL.Game.Spell._buffs = {}; -- Buffs by buff ID
VFL.Game.Spell._cures = {}; -- Cures by debuff type
VFL.Game.Spell._byMeta = {}; -- Spells by meta ID

---------------------------
-- SPELL ENUMERATION
----------------------------
-- Virtual event to notify those who wish to know about spell enum.
-- updates.
VFL.Event.RegisterNamed("SPELL_DATA_UPDATED", {});

-- Core spell enumerator.
function VFL.Game.Spell._enumSpells()
	VFL.Game.Spell._stbl = {};
	VFL.Game.Spell._ntbl = {};
	VFL.Game.Spell._btbl = {};
	VFL.Game.Spell._buffs = {};
	VFL.Game.Spell._cures = {};
	VFL.Game.Spell._byMeta = {};
	local i=1;
	while(true) do
		local sp = VFL.Game.Spell:new();
		if not sp:load(i) then do break end end
--		VFL.debug("Enumerating " .. sp.officialTitle);
		-- Populate idtable
		VFL.Game.Spell._stbl[i] = sp;
		-- Populate fullname table
		VFL.Game.Spell._ntbl[sp:GetFullName()] = sp;
		-- Populate highrank table
		VFL.Game.Spell._btbl[sp:GetSpellName()] = sp;
		-- Populate byMeta table
		if sp:GetMeta() then
			if not VFL.Game.Spell._byMeta[sp:GetMeta().id] then VFL.Game.Spell._byMeta[sp:GetMeta().id] = {}; end
			table.insert(VFL.Game.Spell._byMeta[sp:GetMeta().id], sp);
		end
		-- Populate buff table
		if sp:IsBuff() then
			if not VFL.Game.Spell._buffs[sp:GetMetaID()] then VFL.Game.Spell._buffs[sp:GetMetaID()] = {}; end
			table.insert(VFL.Game.Spell._buffs[sp:GetMetaID()], sp);
		end
		-- Populate cures table
		if sp:IsCure() then
			for _,ct in sp:CureTypes() do
				if not VFL.Game.Spell._cures[ct] then VFL.Game.Spell._cures[ct] = {}; end
				table.insert(VFL.Game.Spell._cures[ct], sp);
			end
		end
		-- Next spell.
		i = i + 1;
	end -- while(true)

	-- Notify interested parties that spells were updated.
	VFLEvent:RaiseByName("SPELL_DATA_UPDATED");
end;

------------------------------------
-- SPELL LOOKUP
------------------------------------
-- Root spell lookup.
-- If no rank is provided, returns the best rank.
function VFL.Game.Spell.lookup(n)
	local ln = string.lower(n);
	local p = VFL.Game.Spell._ntbl[ln];
	if not p then
		return VFL.Game.Spell._btbl[ln];
	else
		return p;
	end
end;

-- Gets the entire spell table, by id
function VFL.Game.Spell.GetSpellTable()
	return VFL.Game.Spell._stbl;
end;

function VFL.Game.Spell.ByID(id)
	return VFL.Game.Spell._stbl[id];
end;

-- Cast a spell by name
function VFL.Game.Spell.CastByName(n)
	local sp = VFL.Game.Spell.lookup(n);
	if not sp then return nil; end
	sp:Cast();
end;

-- Return a list of all buff names
function VFL.Game.Spell.GetMyBuffs()
	local x = {};
	for mid,_ in VFL.Game.Spell._buffs do
		table.insert(x, VFL.Game.Spell._meta[mid].name);
	end
	return x;
end;

-- Return a list of metadata for all possible buffs.
function VFL.Game.Spell.GetAllBuffs()
	return VFL.Game.Spell._allBuffs;
end;

-- From a true/false table of debuffs, return the first true type.
function VFL.Game.Spell.GetFirstDebuff(debuffs)
	if(debuffs.curse) then return "curse"
	elseif(debuffs.magic) then return "magic"
	elseif(debuffs.disease) then return "disease"
	elseif(debuffs.poison) then return "poison"
	else return nil;
	end
end;

-- Return true iff I can cure the debuff type.
function VFL.Game.Spell.CanICure(ty)
	if VFL.Game.Spell._cures[ty] then return true; else return false; end
end;

-- Get the best spell I can cast of the given meta ID
function VFL.Game.Spell.GetBestMeta(mid)
	if not VFL.Game.Spell._byMeta[mid] then return nil; end
	-- Go in order of the spell metalist if it's there
	local sml = VFL.Game.Spell._meta[mid].spells
	if(sml) then
		for _,x in sml do
			local sp = VFL.Game.Spell.lookup(x);
			if(sp) then return sp; end
		end
	end
	-- Otherwise, _byMeta list.
	local n = table.getn(VFL.Game.Spell._byMeta[mid]);
	return VFL.Game.Spell._byMeta[mid][n];
end;

-- Get the best cure for the given debuff type.
function VFL.Game.Spell.GetBestCure(ty)
	if not VFL.Game.Spell._cures[ty] then return nil; end
	local n = table.getn(VFL.Game.Spell._cures[ty]);
	return VFL.Game.Spell._cures[ty][n];
end;

-- Get all cures for the given debuff type.
function VFL.Game.Spell.GetAllCures(ty)
	if not VFL.Game.Spell._cures[ty] then return {}; end
	return VFL.Game.Spell._cures[ty];
end;

-- From a true/false table of debuffs, return the first curable type.
function VFL.Game.Spell.GetFirstCurableType(debuffs)
	for k,v in debuffs do
		if v then
			if VFL.Game.Spell._cures[k] then
				return k;
			end
		end
	end
	return nil;
end;

--
-- SPELL METATABLE
-- WARNING: NEW SPELLS MUST BE ADDED TO THE *END* OF THIS TABLE
-- OR COMPATIBILITY WILL BE BROKEN. YOU HAVE BEEN WARNED.
-- 
VFL.Game.Spell._meta = {
	-- PALADIN 1.3.0
	{ name = "Blessing of Might", use="buff", low = 20 };
	{ name = "Blessing of Wisdom", use="buff", low = 20 };
	{ name = "Blessing of Salvation", use="buff", low = 20 };
	{ name = "Blessing of Light", use = "buff", low = 30 };
	{ name = "Blessing of Sanctuary", use = "buff" };
	{ name = "Blessing of Kings", use = "buff", low = 20 };
	{ name = "Cleanse", use = "cure", cures = {"disease","poison","magic"} };
	{ name = "Purify", use = "cure", cures = {"disease","poison"} };
	-- DRUID 1.3.0
	{ name = "Mark of the Wild", use = "buff", spells = {"Mark of the Wild", "Gift of the Wild"}, group = "Gift of the Wild", low = 120 };
	{ name = "Thorns", use = "buff", low = 30 };
	{ name = "Abolish Poison", use = "cure", cures = {"poison"} };
	{ name = "Remove Curse", use = "cure", cures = {"curse"} };
	-- PRIEST 1.3.0
	{ name = "Power Word: Fortitude", spells = {"Power Word: Fortitude", "Prayer of Fortitude"}, use = "buff", group = "Prayer of Fortitude", low = 120, castDelay = 2, groupDelay = 6 };
	{ name = "Power Word: Shield", use = "buff" };
	{ name = "Shadow Protection", use = "buff", low = 30 };
	{ name = "Fear Ward", use = "buff", low = 30 };
	{ name = "Cure Disease", use = "cure", cures = {"disease"} };
	{ name = "Dispel Magic", use = "cure", cures = {"magic"} };
	{ name = "Abolish Disease", use = "cure", cures = {"disease"} };
	-- MAGE 1.3.0
	{ name = "Arcane Intellect", spells = {"Arcane Intellect", "Arcane Brilliance"}, group = "Arcane Brilliance", use = "buff", low = 120 };
	{ name = "Amplify Magic", use = "buff" };
	{ name = "Dampen Magic", use = "buff" };
	{ name = "Remove Lesser Curse", use = "cure", cures = {"curse"} };
	-- WARLOCK 1.3.0
	{ name = "Unending Breath", use = "buff", low = 60 };
	{ name = "Detect Invisibility", spells = { "Detect Greater Invisibility", "Detect Invisibility", "Detect Lesser Invisibility", }, use = "buff", low = 60 };
	-- SHAMAN 1.3.0
	{ name = "Cure Poison", use = "cure", cures = {"poison"} };
	{ name = "Cure Disease", use = "cure", cures = {"disease"} };
	-- PRIEST - DIVINE SPIRIT, added in R3
	{ name = "Divine Spirit", use = "buff", castDelay = 2, low = 30 };
	-- Soulstone buff, added in R5
	{ name = "Soulstone Resurrection", use = "buff", low = 120 };
};
-- Assign meta IDs
for id,m in VFL.Game.Spell._meta do
	m.id = id;
end
-- Generate named metatable from the above
VFL.Game.Spell._metaByName = {};
for id,m in VFL.Game.Spell._meta do
	local q = nil;
	if(m.spells) then q=m.spells; else q={m.name}; end
	for _,spn in q do
		VFL.Game.Spell._metaByName[string.lower(spn)] = m;
	end
end
-- Generate list of buffs by name from the above.
VFL.Game.Spell._allBuffs = {};
for id,m in VFL.Game.Spell._meta do
	if(m.use == "buff") then
		table.insert(VFL.Game.Spell._allBuffs, m);
	end
end;

-- Look up metadata by buff name
function VFL.Game.Spell.MetadataByBuffName(name)
	return VFL.Game.Spell._metaByName[name];
end;
