-- Metadata.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Metadata concerning various spells and abilities.
-- 
VFL.debug("[RDX5] Loading Metadata.lua", 2);
-----------------------------------
-- CLASS METATABLES
-----------------------------------
RDX.classes = {};
RDX.classesByName = {};

-- Class object
RDX.Class = {};
RDX.Class.__index = RDX.Class;

-- Check if a class can cure a given debuff type.
function RDX.Class:CanCure(dt)
	if (not dt) or (dt == "") then return false; end
	if self.cures[dt] then return true; else return false; end
end

function RDX.RegisterClass(tbl)
	if RDX.classes[tbl.id] then
		return
	end
	setmetatable(tbl, RDX.Class);
	RDX.classes[tbl.id] = tbl;
	RDX.classesByName[tbl.name] = tbl;
end

RDX.RegisterClass({
	id = 1; name = "warrior"; abbrev = "Wa";
	color = RAID_CLASS_COLORS["WARRIOR"];
	cures = {};
});
RDX.RegisterClass({
	id = 2; name = "priest"; abbrev = "Pr";
	color = RAID_CLASS_COLORS["PRIEST"];
	cures = {
		["magic"] = { "dispel magic" };
		["disease"] = { "cure disease", "abolish disease" };
	};
});
RDX.RegisterClass({
	id = 3; name = "mage"; abbrev = "Ma";
	color = RAID_CLASS_COLORS["MAGE"];
	cures = {
		["curse"] = {"remove lesser curse"};
	};
});
RDX.RegisterClass({
	id = 4; name = "rogue"; abbrev = "Rg";
	color = RAID_CLASS_COLORS["ROGUE"];
	cures = {};
});
RDX.RegisterClass({
	id = 5; name = "paladin"; abbrev = "Pa";
	color = RAID_CLASS_COLORS["PALADIN"];
	cures = {
		["disease"] = { "cleanse", "purify" };
		["poison"] = { "cleanse", "purify" };
		["magic"] = { "cleanse" };
	};
});
RDX.RegisterClass({
	id = 6; name = "warlock"; abbrev = "Wk";
	color = RAID_CLASS_COLORS["WARLOCK"];
	cures = {};
});
RDX.RegisterClass({
	id = 7; name = "hunter"; abbrev = "Hu";
	color = RAID_CLASS_COLORS["HUNTER"];
	cures = {};
});
RDX.RegisterClass({
	id = 8; name = "druid"; abbrev = "Dr";
	color = RAID_CLASS_COLORS["DRUID"];
	cures = {
		["poison"] = { "abolish poison" };
		["curse"] = { "remove curse" };
	};
});
RDX.RegisterClass({
	id = 9; name = "shaman"; abbrev = "Sh";
	color = RAID_CLASS_COLORS["SHAMAN"];
	cures = {
		["poison"] = { "cure poison "};
		["disease"] = { "cure disease" };
	};
});


-- Debuff type metatable
RDX.id2dt = {"curse", "magic", "poison", "disease"};
RDX.dt2id = {};
for i=1,table.getn(RDX.id2dt) do
	RDX.dt2id[RDX.id2dt[i]] = i;
end
function RDX.GetDebuffTypeID(dt)
	return RDX.dt2id[dt];
end
function RDX.GetDebuffTypeName(dtid)
	return RDX.id2dt[dtid];
end

---------------------------------------------------
-- BUFF/DEBUFF METADATA CACHE
-- Caches textures, tooltip-text, etc for buffs and debuffs
---------------------------------------------------
RDX.amd = {};
RDX.amd[1] = {}; RDX.amd[2] = {};
function RDX.SetAuraMetadata(type, name, texture, text1, text2, text3, dt)
	local mdt = RDX.amd[type];
	-- Don't overwrite if already exists
	if not mdt[name] then
		local md = {};
		-- Basic demographics
		md.texture = texture; md.name = name;
		md.text1 = text1; md.text2 = text2; md.text3 = text3;
		-- Curability
		if(dt) then
			md.dt = dt;
			if RDX.playerClass:CanCure(dt) then md.curable = true; else md.curable = false; end
		end
		mdt[name] = md;
	end
end

function RDX.GetAuraMetadata(type, name)
	return RDX.amd[type][name];
end
function RDX.GetBuffMetadata(name)
	return RDX.amd[1][name];
end
function RDX.GetDebuffMetadata(name)
	return RDX.amd[2][name];
end

function RDX.ShowAuraTooltip(meta, frame, anchor)
	GameTooltip:SetOwner(frame, "ANCHOR_NONE");
	GameTooltip:SetPoint("TOPLEFT", frame, anchor);
	GameTooltip:ClearLines();
	GameTooltip:AddDoubleLine(meta.text1, meta.text2);
	GameTooltip:AddLine(meta.text3, 1, 1, 1);
	GameTooltip:Show();
end

-------------------
-- SPELLS DB
-------------------
-- A spell corresponds to a single WoW spell.
if not RDX.Spell then RDX.Spell = {}; end
RDX.Spell.__index = RDX.Spell;

function RDX.Spell:new()
	local x = {};
	setmetatable(x, RDX.Spell);
	return x;
end

-- Load a spell from WoW
function RDX.Spell:load(id)
	self.id = id;
	local name,qual = GetSpellName(id, SpellBookFrame.bookType);
	if not name then return nil; end
	if(qual) and (qual ~= "") then
		self.title = name .. "(" .. qual .. ")";
		self.qual = string.lower(qual);
	else
		self.title = name;
	end
	self.ltitle = string.lower(self.title);
	self.name = string.lower(name); 
	self.rank = 1;
	local s,e,num = string.find(qual, "(%d+)");
	if s then self.rank = tonumber(num); end
	return true;
end

-- Get info about spells
function RDX.Spell:GetID() return self.id; end
function RDX.Spell:GetRank() return self.rank; end
function RDX.Spell:GetTitle() return self.title; end

-- Check a spell's cooldown
function RDX.Spell:GetCooldown()
	return GetSpellCooldown(self.id, SpellBookFrame.bookType);
end

-- Cast a spell
function RDX.Spell:Cast()
	CastSpell(self.id, SpellBookFrame.bookType);
	if SpellIsTargeting() then SpellStopTargeting(); end
end

-- Spell tables
RDX.sp = {}; -- Spells by ID
RDX.sp_maxid = 0;
RDX.spn = {}; -- Spells by name
RDX.spt = {}; -- Spells by full title

-- Get the best spell with the given name
function RDX.GetBestSpell(name)
	return RDX.spn[name];
end
-- Get a spell by ID
function RDX.GetSpellByID(id)
	return RDX.sp[id];
end
-- Get a spell by full title
function RDX.GetSpell(title)
	return RDX.spt[title];
end

-- Core spell enumerator
function RDX.EnumSpells()
	VFL.debug("RDX.EnumSpells()", 3);
	RDX.playerClass.cureSpells = {};
	RDX.playerClass.highestCure = {};
	local i = 1;
	while(true) do
		-- Create a spell for the slot, if it doesn't exist already
		if not RDX.sp[i] then RDX.sp[i] = RDX.Spell:new(); end
		local sp = RDX.sp[i];
		-- Acquire spell data
		if not sp:load(i) then
			-- We're out of spells, bail.
			RDX.sp_maxid = i - 1; break;
		end
		-- Populate title table
		RDX.spt[sp.ltitle] = sp;
		-- Populate name table
		if not RDX.spn[sp.name] then
			RDX.spn[sp.name] = sp;
		else
			-- Only replace if higher rank
			if RDX.spn[sp.name].rank < sp.rank then
				RDX.spn[sp.name] = sp;
			end
		end
		-- Determine if this spell can cure anything
		for k,v in RDX.playerClass.cures do
			for _,sn in v do
				if (sn == sp.name) then 
					VFL.debug("Spell " .. sp.name .. " is the cure for " .. k, 8);
					sp.cures = k;
					RDX.playerClass.highestCure[k] = sp.ltitle;
				end
			end
		end
		-- Determine if there's an effect called for by this spell
		local fx = RDX.GetEffectFromSpellName(sp.name);
		-- Update the effect's cached spell as appropriate
		if fx then
			VFL.debug("Spell " .. sp.name .. " matches effect " .. fx.name, 8);
			fx:SetPossible();
			fx:UpdateCachedSpell(sp);
		end
		-- Next iteration
		i = i + 1;
	end
end

-----------------------------
-- EFFECTS DB
-----------------------------
-- An effect is an integer-identified object associated with a buff or
-- debuff on a unit.
if not RDX.Effect then RDX.Effect = {}; end
RDX.Effect.__index = RDX.Effect;

-- Effect metatables
RDX.fx = {}; -- Effects
RDX.spn2fx = {}; -- Spell-name-to-effect map
RDX.buff2fx = {}; -- Buff-name-to-effect map
RDX.debuff2fx = {}; -- Debuff-name-to-effect map
RDX.possfx = {}; -- Possible effects map

function RDX.Effect:new(o)
	local x = o or {};
	x._csrank = 0;
	setmetatable(x, RDX.Effect);
	return x;
end

-- Mark this effect as possible for the current player
function RDX.Effect:SetPossible()
	self._possible = true;
end
-- Determine if this effect is possible for the current player
function RDX.Effect:IsPossible()
	return self._possible;
end

-- Update the cached spell associated with this effect, if necessary
function RDX.Effect:UpdateCachedSpell(sp)
	if (not sp) or (not self.spells) then return false; end
	-- Get the rating of the new spell. Ignore if lower rated than old spell
	local r = self.spells[sp.name];
	if (not r) or (r < self._csrank) then return false; end
	-- Enable us as a possible effect
	RDX.possfx[self.id] = true;
	-- Update the local rating
	self._csrank = r;
	-- If there is no spell, just add it
	if not self._cspell then self._cspell = sp; return true; end
	-- Otherwise, only update if the rank is better
	if sp.rank >= self._cspell.rank then self._cspell = sp; end
	return true;
end

-- Get the cached spell associated with this effect
function RDX.Effect:GetCachedSpell()
	return self._cspell;
end

-- Get the group version of the spell associated with this effect
function RDX.Effect:GetGroupVersionSpell()
	if not self.groupVersion then return nil; end
	return RDX.GetBestSpell(self.groupVersion);
end

-- Get the texture associated with this effect; return an unknown
-- texture if none.
function RDX.Effect:GetTexture()
	if self.texture then return self.texture; else return "Interface\\InventoryItems\\WoWUnknownItem01.blp"; end
end

-- Get the "low timer" for this effect.
function RDX.Effect:GetLowTimer()
	if(RDXG.fxLow[self.id]) then return RDXG.fxLow[self.id]; end
	if self.isLow then return self.isLow; else return 0; end
end

-- Get an effect by ID
function RDX.GetEffectByID(id)
	return RDX.fx[id];
end
-- Get an effect from a spell name
function RDX.GetEffectFromSpellName(spn)
	return RDX.spn2fx[spn];
end
-- Get an effect from a debuff name
function RDX.GetEffectFromDebuffName(dbn)
	return RDX.debuff2fx[dbn];
end
-- Get an effect from a buff name
function RDX.GetEffectFromBuffName(bn)
	return RDX.buff2fx[bn];
end

-- Register an effect. An effect is an integer-identified object associated
-- to a buff or debuff.
function RDX.RegisterEffect(etbl)
	-- Sanity check
	if (not etbl.id) or (not etbl.name) then
		VFL.debug("RDX.RegisterEffect: Recieved effect with no id, discarding.");
		return false;
	end
	-- See that it doesn't already exist
	if(RDX.fx[etbl.id]) then
		VFL.debug("RDX.RegisterEffect: An effect '" .. etbl.name .. "' tried to use id " .. etbl.id .. " that was already registered.");
		return false;
	end
	-- Create the effect
	local fx = RDX.Effect:new(etbl);
	RDX.fx[etbl.id] = fx;
	-- Create the spellname-to-effect mappings
	if fx.spells then
		for spn,_ in fx.spells do
			RDX.spn2fx[spn] = fx;
		end
	end
	-- Create the buffname-to-effect mappings
	if fx.equivBuffs then
		for _,spn in fx.equivBuffs do
			RDX.buff2fx[spn] = fx;
		end
	end
	-- Create debuff-to-effect mappings
	if fx.equivDebuffs then
		for _,spn in fx.equivDebuffs do
			RDX.debuff2fx[spn] = fx;
		end
	end
end

-------------------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------------------
--------------------------------------EFFECT DATABASE--------------------------------------------
------------ PRIEST
-- Example effect id = 1: Fortitude
RDX.RegisterEffect({
	-- CORE PARAMETERS
	id = 1;	-- The effect's numerical ID.
	name = "Fortitude"; -- The effect's mnemonic. Used by the RDX engine in menus/displays
	-- GAME ENGINE PARAMETERS
	spells = { -- Spell names capable of producing the effect. The numeric value is the rating, highest rated spell will be used
		["power word: fortitude"] = 2,
		["prayer of fortitude"] = 1
	}; 
	groupVersion = "prayer of fortitude"; -- The "group version" of the spell, used for group buffing.
	equivBuffs = {"power word: fortitude", "prayer of fortitude"}; -- Buff names equivalent to this effect.
	texture = "Interface\\Icons\\Spell_Holy_WordFortitude"; -- WoW internal texture, used for presentation quality
	-- RDX ENGINE PARAMETERS
	syncWoW = true; -- This buff should be synchronized via the WoW aura system
	syncTime = true; -- The amount of time remaining on this buff should be broadcast.
	realtime = false; -- This buff need not be updated in realtime.
	-- OTHER
	duration = 1800; -- The putative duration, in seconds, of this buff
	isLow = 120; -- This buff should be considered "low" if there are fewer than 120 sec remaining.
});

RDX.RegisterEffect({
	id = 4; name = "Divine Spirit"; texture="Interface\\Icons\\Spell_Holy_HolyProtection";
	spells = { ["divine spirit"] = 2, ["prayer of spirit"] = 1 };
	groupVersion = "prayer of spirit";
	equivBuffs = {"divine spirit", "prayer of spirit"};
	syncWoW = true; syncTime = true;
	isLow = 120; duration = 1800;
});
RDX.RegisterEffect({
	id = 5; name = "Fear Ward"; texture="Interface\\Icons\\Spell_Holy_Excorcism";
	spells = { ["fear ward"] =1 };
	equivBuffs = {"fear ward"};
	syncWoW = true; syncTime = true;
	isLow = 120; duration = 600;
});
RDX.RegisterEffect({
	id = 6; name = "Shadow Protection"; texture="Interface\\Icons\\Spell_Shadow_AntiShadow";
	spells = { ["shadow protection"] =1 };
	equivBuffs = {"shadow protection"};
	syncWoW = true; syncTime = true;
	isLow = 120; duration = 600;
});

---------------- DRUID [11-20]
RDX.RegisterEffect({
	id = 2; name = "Mark of the Wild"; texture = "Interface\\Icons\\Spell_Nature_Regeneration";
	spells = { ["mark of the wild"] = 2, ["gift of the wild"] =1 };
	groupVersion = "gift of the wild";
	equivBuffs = {"mark of the wild", "gift of the wild"};
	syncWoW = true; syncTime = true;
	isLow = 120; duration = 1800;
});
RDX.RegisterEffect({
	id = 11; name = "Thorns"; texture = "Interface\\Icons\\Spell_Nature_Thorns";
	spells = {["thorns"] = 1};
	equivBuffs = { "thorns" };
	syncWoW = true; syncTime = true; isLow = 60; duration = 600;
});
---------------- MAGE [21-30]
RDX.RegisterEffect({
	id = 3; name = "Arcane Intellect"; texture = "Interface\\Icons\\Spell_Holy_MagicalSentry";
	spells = { ["arcane intellect"] = 2, ["arcane brilliance"] =1 };
	groupVersion = "arcane brilliance";
	equivBuffs = {"arcane intellect", "arcane brilliance"};
	syncWoW = true; syncTime = true;
	isLow = 120; duration = 1800;
});
RDX.RegisterEffect({
	id = 21; name = "Amplify Magic";
	spells = {["amplify magic"] = 1};
	equivBuffs = { "amplify magic" };
	syncWoW = true; syncTime = true; isLow = 60; duration = 600;
});
RDX.RegisterEffect({
	id = 22; name = "Dampen Magic";
	spells = {["dampen magic"] = 1};
	equivBuffs = { "dampen magic" };
	syncWoW = true; syncTime = true; isLow = 60; duration = 600;
});
---------------- WARLOCK [31-40]
RDX.RegisterEffect({
	id = 7; name = "Water Breathing"; texture="Interface\\Icons\\Spell_Shadow_DemonBreath";
	spells = { ["unending breath"] =1 };
	equivBuffs = {"unending breath"};
	syncWoW = true; syncTime = true;
	isLow = 120; duration = 600;
});
RDX.RegisterEffect({
	id = 8; name = "Detect Invisibility"; texture="Interface\\Icons\\Spell_Shadow_DetectInvisibility";
	spells = { ["detect greater invisibility"] = 3, ["detect invisibility"] = 2, ["detect lesser invisibility"] = 1 };
	equivBuffs = {"detect greater invisibility", "detect invisibility", "detect lesser invisibility"};
	syncWoW = true; syncTime = true;
	isLow = 120; duration = 600;
});
RDX.RegisterEffect({
	id = 31; name = "Soulstone"; texture="Interface\\Icons\\Spell_Shadow_SoulGem";
	equivBuffs = {"soulstone resurrection"};
	syncWoW = true; syncTime = true; isLow = 120; duration = 1800;
});
------------------ PALADIN [41-50]
RDX.RegisterEffect({
	id = 41; name = "Blessing of Might"; texture="Interface\\Icons\\Spell_Holy_FistOfJustice";
	spells = { ["blessing of might"] = 1 };
	groupVersion = "greater blessing of might";
	equivBuffs = { "blessing of might", "greater blessing of might" };
	syncWoW = true; syncTime = true; isLow = 45; duration = 300;
});
RDX.RegisterEffect({
	id = 42; name = "Blessing of Wisdom"; texture="Interface\\Icons\\Spell_Holy_SealOfWisdom";
	spells = { ["blessing of wisdom"] = 1 };
	groupVersion = "greater blessing of wisdom";
	equivBuffs = { "blessing of wisdom", "greater blessing of wisdom" };
	syncWoW = true; syncTime = true; isLow = 45; duration = 300;
});
RDX.RegisterEffect({
	id = 43; name = "Blessing of Salvation"; texture="Interface\\Icons\\Spell_Holy_SealOfSalvation";
	spells = { ["blessing of salvation"] = 1 };
	groupVersion = "greater blessing of salvation";
	equivBuffs = { "blessing of salvation", "greater blessing of salvation" };
	syncWoW = true; syncTime = true; isLow = 45; duration = 300;
});
RDX.RegisterEffect({
	id = 44; name = "Blessing of Light"; texture="Interface\\Icons\\Spell_Holy_PrayerOfHealing02";
	spells = { ["blessing of light"] = 1 };
	groupVersion = "greater blessing of light";
	equivBuffs = { "blessing of light", "greater blessing of light" };
	syncWoW = true; syncTime = true; isLow = 45; duration = 300;
});
RDX.RegisterEffect({
	id = 45; name = "Blessing of Kings"; texture="Interface\\Icons\\Spell_Magic_MageArmor";
	spells = { ["blessing of kings"] = 1 };
	groupVersion = "greater blessing of kings";
	equivBuffs = { "blessing of kings", "greater blessing of kings" };
	syncWoW = true; syncTime = true; isLow = 45; duration = 300;
});
RDX.RegisterEffect({
	id = 46; name = "Blessing of Sanctuary";
	spells = { ["blessing of sanctuary"] = 1 };
	groupVersion = "greater blessing of sanctuary";
	equivBuffs = { "blessing of sanctuary", "greater blessing of sanctuary" };
	syncWoW = true; syncTime = true; isLow = 45; duration = 300;
});
