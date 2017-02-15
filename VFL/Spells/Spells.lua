-- Spells.lua
-- VFL
-- (C)2006 Bill Johnson
--
-- Code relating to the manipulation of in-game spells and abilities.
--
-- Each spell is represented by its WoW numerical spell ID. Spells are grouped into SpellClasses;
-- all spells in a SpellClass have the same effect, but to different magnitudes.
--
-- Examples of SpellClasses: Shadow Bolt(Rank 1), Shadow Bolt(Rank 2), ...
--                           Detect Lesser Invisibility, Detect Invisibility, Detect Greater Invisibility
-- Subtleties: Power Word: Fortitude and Prayer of Fortitude are DIFFERENT spell classes because
--   they don't have the exact same effect (one buffs a single person, one buffs a group.)
--
-- Spells are also grouped into SpellCategories. A SpellCategory can be something like "DAMAGE", 
-- "HEALING", "PERIODIC", "INSTANT", etc. A spell can be in multiple SpellCategories.
--
-- Spells are also grouped into RangeClasses. Spells in the same RangeClass have the same range.
--
-- Spells can be manually grouped into generic SpellGroups which can have any content or meaning 
-- that the programmer desires.
-- 
-- Interesting spell events
-- LEARNED_SPELL_IN_TAB(tabnum)
-- SPELL_UPDATE_USABLE
--

VFLS = RegisterVFLModule({
	name = "VFLS";
	title = "VFL Spell System";
	description = "VFL Spell System";
	version = {0,1,0};
	parent = VFL;
});

-----------------------------------
-- Metadata about WoW classes.
-----------------------------------

local idToClass = { "PRIEST", "DRUID", "PALADIN", "SHAMAN", "WARRIOR", "WARLOCK", "MAGE", "ROGUE", "HUNTER" };

local classToID = VFL.invert(idToClass);

local idToLocalName = { "Priest", "Druid", "Paladin", "Shaman", "Warrior", "Warlock", "Mage", "Rogue", "Hunter" };

local idToClassColor = {};
for i=1,9 do
	idToClassColor[i] = RAID_CLASS_COLORS[idToClass[i]];
end
local _grey = { r=.8, g=.8, b=.8};

--- Retrieve the class ID for the class with the given proper name.
-- The proper name is the SECOND parameter returned from UnitClass(), and is
-- the fully capitalized English name of the class (e.g. "WARRIOR", "PALADIN")
function VFLGetClassID(cn) return classToID[cn] or 0; end

--- Given the class ID, retrieve the localized name for the class.
function VFLGetClassName(cid) return idToLocalName[cid] or "Unknown"; end

--- Given the class ID, retrieve the class color as an RGB table.
function VFLGetClassColor(cid) return idToClassColor[cid] or _grey; end

------------------------------------------------
-- Basic spell API
------------------------------------------------

--- Given a spell's numerical ID, return its full name.
function VFLS.GetSpellFullName(id)
	if not id then return nil; end
	local name,q = GetSpellName(id, BOOKTYPE_SPELL);
	if not name then return nil; end
	return name .. '(' .. q .. ')', name, q;
end

--- Given a spell's numerical ID, attempt to figure out its numerical rank,
-- if any.
function VFLS.GetSpellRank(id)
	local name,q = GetSpellName(id, BOOKTYPE_SPELL);
	if not name then return nil; end
	if q then
		local _,_,num = string.find(q, "(%d+)");
		if num then return tonumber(num), name, q; end
	end
	return 0, name, q;
end

------------------------------------------------
-- Core spell databases
------------------------------------------------
-- Spells by full name
local spFN = {};

--- Get a spell by FULL NAME: Spell Name(Rank X)
-- Partial names will not work.
function VFLS.GetSpellByFullName(n)
	if not n then return nil; end
	return spFN[n];
end

--- Get a table (name->id) of all spells recognized by VFL.
function VFLS.GetAllSpells() return spFN; end

--- Exclusion tables. Spells excluded by this table will not
-- appear in the VFL spell system.
local excludeNames = {
	["Attack"] = true,
	["Disenchant"] = true,
	["Gnomish Engineer"] = true,
	["Goblin Engineer"] = true,
};
local excludeQualifiers = {
	["Passive"] = true,
	["Racial Passive"] = true,
	["Apprentice"] = true,
	["Apprentice "] = true,
	["Journeyman"] = true,
	["Master"] = true,
	["Expert"] = true,
	["Artisan"] = true,
};

-- Filter this spell for "worthwhile-ness"
local function SpellFilter(id,name,q)
	if IsSpellPassive(id, BOOKTYPE_SPELL) then return nil; end
	if excludeNames[name] then return nil; end
	if excludeQualifiers[q] then return nil; end
	return true;
end

-- Empty the core spell database
local function ResetCoreSpellDB()
	VFL.empty(spFN);
end

-- Rebuild the core spell database
local function BuildCoreSpellDB()
	local i=1;
	while true do
		local name,q = GetSpellName(i, BOOKTYPE_SPELL);
		if not name then break; end
		if SpellFilter(i,name,q) then
			spFN[name.."("..q..")"] = i;
		end
		i=i+1;
	end
end

------------------------------------------------
-- SpellGroup
-- A SpellGroup is a group of spells. Big shocker there. The spells in the
-- group can be queried by ID or name.
------------------------------------------------
VFLS.SpellGroup = {};
function VFLS.SpellGroup:new()
	local s = {};
	
	local spells = {};
	local spellsByID = {};
	local spellsByName = {};
	
	--- Get all spells in this group, as a sorted array.
	function s:Spells() return spells; end

	--- Empty this spell group
	function s:Empty()
		VFL.empty(spells); VFL.empty(spellsByID); VFL.empty(spellsByName);
	end

	--- Add a spell to this group.
	function s:AddSpell(id)
		if not id then error("expected id, got nil"); end
		if spellsByID[id] then return nil; end
		local sn = VFLS.GetSpellFullName(id); if not sn then return nil; end
		table.insert(spells, id);
		spellsByID[id] = true;
		spellsByName[sn] = id;
		return true;
	end

	--- Add a spell to this group by full name.
	function s:AddSpellByFullName(fn)
		self:AddSpell(VFLS.GetSpellByFullName(fn));
	end

	--- Determine if the spell with the given ID is in this group
	function s:HasSpellByID(id)
		if not id then return nil; end
		return spellsByID[id];
	end

	--- Determine if the spell with the given full name is in this group.
	function s:HasSpellByFullName(fn)
		if not fn then return nil; end
		return spellsByName[fn];
	end

	--- Get the highest-sorted spell in this group.
	function s:GetBestSpell()
		local n = table.getn(spells);
		if(n == 0) then return nil; end
		return spells[n];
	end

	-- Debug string dump
	function s:_DebugDump()
		local str = "";
		for _,sp in ipairs(spells) do
			str = str .. VFLS.GetSpellFullName(sp) .. ",";
		end
		return str;
	end

	return s;
end

----------------------------------------------------------------
-- SpellClass
-- A SpellClass is a spell group containing spells that have identical
-- effects, but different magnitudes.
----------------------------------------------------------------

-- The class databases
local id2class = {};
local cn2class = {};

--- Get all spell classes
function VFLS.GetSpellClasses() return cn2class; end

--- Get the class of the spell with the given id, if any.
function VFLS.GetClassOfSpell(id)
	if not id then return nil; end
	return id2class[id];
end

--- Get the class of the given name.
function VFLS.GetClassByName(cn)
	if not cn then return nil; end
	return cn2class[cn];
end

--- Get a class with a given name, creating it if it does not exist.
function VFLS.GetOrCreateClassByName(cn)
	if not cn then return nil; end
	local cc = cn2class[cn];
	if not cc then
		cc = VFLS.SpellGroup:new();
		cn2class[cn] = cc;
	end
	return cc;
end

--- Get the "best" spell of a given class.
function VFLS.GetBestSpell(name)
	if not name then return nil; end
	local c = VFLS.GetClassByName(name); if not c then return nil; end
	return c:GetBestSpell();
end

--- Manually classify a spell.
function VFLS.ClassifySpell(spellFullName, className)
	if (not spellFullName) or (not className) then error("usage: VFLS.ClassifySpell(spellFullName, className)"); end
	local cls = VFLS.GetOrCreateClassByName(className);
	local id = VFLS.GetSpellByFullName(spellFullName); if not id then return; end
	if id2class[id] then return; end
	id2class[id] = cls; cls:AddSpell(id);
end

-- Empty the spell-class database
local function ResetSpellClassDatabase()
	VFL.empty(id2class);
	VFL.empty(cn2class);
end

-- Sort an implicit rank-defined class by spell rank
local function SortImplicitClass(class)
	if not class then return; end
	local sp = class:GetSpells();
	table.sort(sp, function(s1, s2) return VFLS.GetSpellRank(s1) < VFLS.GetSpellRank(s2); end);
end

-- Implicitly classify all spells not already explicitly classified.
local function BuildImplicitSpellClasses()
	local i=1;
	while true do
		local name,q = GetSpellName(i, BOOKTYPE_SPELL);
		if not name then break; end
		if SpellFilter(i,name,q) then
			if not VFLS.GetClassOfSpell(i) then
				local cls = VFLS.GetOrCreateClassByName(name);
				id2class[i] = cls; cls:AddSpell(i);
			end
		end
		i=i+1;
	end
end

--------------------------------------------------------------------
-- SpellCategory
--
-- A SpellCategory is a loose string-identified grouping of spells.
-- A spell can belong to multiple categories, and there are API
-- calls to identify which categories a spell belongs to.
--------------------------------------------------------------------

local catname2category = {};
local spell2cats = {};

local function ResetSpellCategoryDatabase()
	VFL:Debug(1, "ResetSpellCategoryDatabase()");
	VFL.empty(catname2category);
	VFL.empty(spell2cats);
end

--- Get the category database
function VFLS.GetAllCategories()
	return catname2category;
end

--- Get a category by name.
function VFLS.GetCategoryByName(cn)
	if not cn then return nil; end
	return catname2category[cn];
end

--- Get a category by name, creating it if it does not exist.
function VFLS.GetOrCreateCategoryByName(cn)
	if not cn then return nil; end
	local cat = catname2category[cn];
	if not cat then
		cat = VFLS.SpellGroup:new();
		VFL:Debug(3,"Creating SpellCategory<"..cn.."> as " .. tostring(cat));
		catname2category[cn] = cat;
	end
	return cat;
end

--- Categorize a spell, assuming both the category and SID are valid.
local function CategorizeSpell(cat, cn, id)
	if cat:HasSpellByID(id) then return; end
	cat:AddSpell(id);
	local s = spell2cats[id];
	if not s then s = {}; spell2cats[id] = s; end
	s[cn] = true;
end

--- Categorize a single spell.
function VFLS.CategorizeSpell(spellfn, cn)
	if (not spellfn) or (not cn) then return; end
	local id = VFLS.GetSpellByFullName(spellfn); if not id then return; end
	local cat = VFLS.GetOrCreateCategoryByName(cn);
	CategorizeSpell(cat, cn, id);
end

--- Categorize all spells in a SpellClass.
function VFLS.CategorizeClass(class, cn)
	if(not class) or (not cn) then error("usage: VFLS.CategorizeClass(className, categoryName)"); end
	local cls = VFLS.GetClassByName(class); if not cls then error("no class"); return; end
	local cat = VFLS.GetOrCreateCategoryByName(cn);
	for _,id in cls:Spells() do CategorizeSpell(cat, cn, id); end
end

--- Get a table (cat->true) mapping of all categories to which the given spell belongs.
function VFLS.GetSpellCategories(id)
	if not id then return VFL.emptyTable; end
	return spell2cats[id] or VFL.emptyTable;
end

------------------------------------------------
-- UPDATERS/EVENTS
------------------------------------------------

-- Master updater for the spell engine.
local function UpdateSpells()
	ResetCoreSpellDB();
	ResetSpellClassDatabase();
	ResetSpellCategoryDatabase();
	VFLEvents:Dispatch("SPELLS_RESET");
	BuildCoreSpellDB()
	VFLEvents:Dispatch("SPELLS_BUILD_CLASSES");
	BuildImplicitSpellClasses();
	VFLEvents:Dispatch("SPELLS_BUILD_CATEGORIES");
	VFLEvents:Dispatch("SPELLS_UPDATED");
	VFLS.UpdateActionMap();
end

VFLS.UpdateSpells = VFL.CreatePeriodicLatch(1, UpdateSpells);

WoWEvents:Bind("LEARNED_SPELL_IN_TAB", nil, VFLS.UpdateSpells);
WoWEvents:Bind("PLAYER_ENTERING_WORLD", nil, VFLS.UpdateSpells);

-----------------------------------------------
-- ACTION MAP
-----------------------------------------------
local action2spell = {};
local spell2action = {};

local function UpdateActionMap()
	-- Empty preexisting ActionMap
	VFL.empty(action2spell); VFL.empty(spell2action);
	for i=1,120 do
		if HasAction(i) then
			if GetActionText(i) == nil then
				VFLTip:ClearLines();
				VFLTip:SetAction(i);
				local t1,t2 = VFLTipTextLeft1:GetText(), VFLTipTextRight1:GetText();
				if not t1 then t1 = ""; end if not t2 then t2 = ""; end
				local spid = VFLS.GetSpellByFullName(t1 .. "(" .. t2 .. ")");
				if spid then
					spell2action[spid] = i;
					action2spell[i] = spid;
				end
			end
		end
	end
	VFLEvents:Dispatch("SPELLS_ACTIONMAP_UPDATED");
end

VFLS.UpdateActionMap = VFL.CreatePeriodicLatch(1, UpdateActionMap);

function VFLS.GetSpellAction(sid)
	if not sid then return nil; end
	return spell2action[sid];
end

function VFLS.GetActionSpell(aid)
	if not aid then return nil; end
	return action2spell[aid];
end

-----------------------------------------------
-- DEBUGGERY
-----------------------------------------------
function DebugSpells()
	for k,v in VFLS.GetAllSpells() do
		VFL.print(v .. ": " .. k);
	end
end

function DebugSpellClasses()
	for k,v in VFLS.GetSpellClasses() do
		VFL.print(k .. ": " .. v:_DebugDump());
	end
end

function DebugSpellCategories()
	for k,v in VFLS.GetAllCategories() do
		VFL.print(k .. ": " .. v:_DebugDump());
	end
end
