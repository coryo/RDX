-- DB.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Data structures and data management for raid units.
--
VFL.debug("[RDX5] Loading DB.lua", 2);
if not RDX.DB then RDX.DB = {}; end

---------------------------------------------------
-- SET
-- A mapping from unit numbers to {true, false}
---------------------------------------------------
if not RDX.Set then RDX.Set = {}; end
RDX.Set.__index = RDX.Set;

-- Generate a new empty set
function RDX.Set:new()
	local x = {};
	x.nm = 0; -- num. of members
	x.members = {}; x.dirty = false; x.emptinessDirty = false;
	setmetatable(x, RDX.Set);
	return x;
end

-- Initialize a set
function RDX.Set:init()
	for i=1,40 do self.members[i] = false; end
	if(self.nm > 0) then self.emptinessDirty = true; end
	self.nm = 0;
	self.dirty = false;
end

-- Determine whether a given unit ID number is a member of the set.
function RDX.Set:IsMember(un)
	if self.members[un] then return true; else return false; end
end

-- Get the exact membership value of a given unit.
function RDX.Set:GetMember(un)
	return self.members[un];
end

-- Get the number of members in a set
function RDX.Set:GetSize()
	return self.nm;
end

-- Is the set empty?
function RDX.Set:IsEmpty()
	return (self.nm == 0);
end

-- Dirtiness
-- Has the membership of the set changed since last Clean()?
function RDX.Set:IsDirty() return self.dirty; end
-- Has the set gone from empty to nonempty or vice versa since the last Clean()?
function RDX.Set:IsEmptinessDirty() return self.emptinessDirty; end
-- Clean all dirty flags.
function RDX.Set:Clean() 
	self.dirty = false;
	self.emptinessDirty = false;
end

-- Update a member relation, preserving dirtiness.
function RDX.Set:SetMember(un, val)
	local prev = self.members[un];
	if val ~= prev then 
		self.dirty = true; 
		self.members[un] = val;
		-- Update member count as necessary
		if prev and (not val) then 
			self.nm = self.nm - 1;
			if(self.nm == 0) then self.emptinessDirty = true; end
		elseif val and (not prev) then 
			self.nm = self.nm + 1; 
			if(self.nm ~= 0) then self.emptinessDirty = true; end
		end
	end
end

-- Remove all members, preserving dirtiness
function RDX.Set:RemoveAllMembers()
	-- If already empty, do nothing
	if self:IsEmpty() then return; end
	-- Remove all members
	for k,v in self.members do
		self.members[k] = nil;
	end
	-- Update emptiness/dirtiness
	self.nm = 0; self.emptinessDirty = true; self.dirty = true;
end

-- Get the members relation of a set
function RDX.Set:GetMembers()
	return self.members;
end

-- Recount the members of a set
function RDX.Set:Recount()
	local n = 0;
	for k,v in self.members do if v then n=n+1; end end
	self.nm = n;
end

-- this = s1 intersect s2 intersect ... intersect sn
function RDX.Set:SetIntersection(...)
	local narg = table.getn(arg);
	for i=1,40 do
		self.members[i] = true;
		for j=1,narg do
			if not arg[j].members[i] then self.members[i] = false; break; end
		end
	end
end
function RDX.Set:SetUnion(...)
	local narg = table.getn(arg);
	for i=1,40 do
		self.members[i] = false;
		for j=1,narg do
			if arg[j].members[i] then self.members[i] = true; break; end
		end
	end
end
function RDX.Set:SetCoUnion(...)
	local narg = table.getn(arg);
	for i=1,40 do
		self.members[i] = true;
		for j=1,narg do
			if arg[j].members[i] then self.members[i] = false; break; end
		end
	end
end
function RDX.Set:SetCoIntersection(...)
	local narg = table.getn(arg);
	for i=1,40 do
		self.members[i] = false;
		for j=1,narg do
			if not arg[j].members[i] then self.members[i] = true; break; end
		end
	end
end

-- Filter a set
function RDX.Set:FilterBy(f)
	for k,v in self.members do if v then
		if not f(RDX.GetUnitByNumber(k)) then
			self.members[k] = nil;
		end
	end end
end

-- The empty set.
RDX.emptyset = RDX.Set:new();

---------------------------------------------------
-- FLAG SET
-- An individual unit holds several flag bundles representing
-- different possible states.
---------------------------------------------------
if not RDX.FlagSet then RDX.FlagSet = {}; end
RDX.FlagSet.__index = RDX.FlagSet;

-- Generate a new flag data structre
function RDX.FlagSet:new(mux, unit)
	local x = {};
	x.dirty = false; x.flags = {}; x.mux = mux; x.unit = unit;
	setmetatable(x, RDX.FlagSet);
	return x;
end

-- Set the value of a flag
function RDX.FlagSet:Set(f, v, touch)
	local fd = self.flags[f];
	if not fd then
		fd = { touched = false, dirty = false };
		self.flags[f] = fd;
	end
	self:DirectSet(f, fd, v);
	if touch then fd.touched = true; end
end

-- Directly set flag value
function RDX.FlagSet:DirectSet(fn, fd, v)
	if(v ~= fd.value) then
		-- Update flag descriptor
		self.dirty = true; fd.dirty = true; fd.value = v;
		-- Update flag multiplexer
		if self.mux then self.mux:ChangeFlagValue(fn, self.unit:GetNumber(), v); end
	end
end

-- Get a flag's value
function RDX.FlagSet:Get(f)
	local fd = self.flags[f];
	if not fd then return nil; else return fd.value; end
end

-- Determine if a flagset is dirty
function RDX.FlagSet:IsDirty() return self.dirty; end

-- "Clean" a flagset and all flags in it
function RDX.FlagSet:Clean()
	self.dirty = false;
	for k,v in self.flags do v.dirty = false; end
end

-- "Untouch" all flags in the flagset
function RDX.FlagSet:Untouch()
	for k,v in self.flags do v.touched = false; end
end

-- Clear all untouched flags
function RDX.FlagSet:ClearUntouched()
	for k,v in self.flags do
		if not v.touched then
			self:DirectSet(k, v, nil);
		end
	end
end

-- Clear all flags
function RDX.FlagSet:Clear()
	for k,v in self.flags do self:DirectSet(k, v, nil); end
end

-- Debug dump all flags with their statuses
function RDX.FlagSet:DebugDump()
	local x, out = "", "";
	if self.dirty then x = "dirty"; else x = "clean"; end
	out = out .. x .. ": ";
	for k,v in self.flags do
		if v.dirty then x="*"; else x=""; end
		out = out .. "[" .. k .. "=" .. tostring(v.value) .. x .. "] ";
	end
	VFL.debug(out);
end

---------------------------------------------------
-- FLAG MULTIPLEXER
-- Maintains a list of what units have what flags.
---------------------------------------------------
if not RDX.FlagMux then RDX.FlagMux = {}; end
RDX.FlagMux.__index = RDX.FlagMux;

function RDX.FlagMux:new()
	local x = {};
	setmetatable(x, RDX.FlagMux);
	return x;
end

-- Get the flag container for a given flag, creating if nonexistent
function RDX.FlagMux:Get(f)
	local fd = self[f];
	if not fd then 
		fd = RDX.Set:new();
		self[f] = fd;
	end
	return fd;
end

-- Clears all flags in this mux for unit n
function RDX.FlagMux:ClearUnitFlags(n)
	for _,fd in self do
		fd:SetMember(n, nil);
	end
end

-- Respond to a change in flag value
function RDX.FlagMux:ChangeFlagValue(f, un, val)
	local fd = self:Get(f);
	if val then fd:SetMember(un, true); else fd:SetMember(un, nil); end
end

-- Clean all dirty mux flags
function RDX.FlagMux:Clean()
	for _,fd in self do fd:Clean(); end
end

-- Call the given signal for every dirty flag, passing the appropriate set.
function RDX.FlagMux:Signal(s)
	if s:IsEmpty() then return; end
	for k,fd in self do
		if fd:IsDirty() then
			s:Raise(k, fd);
		end
	end
end

-- Debug dump the content of a mux
function RDX.FlagMux:DebugDump()
	local out;
	for k,fd in self do
		out = k .. ": ";
		for h,v in fd.members do
			if v then out = out .. h .. " "; end
		end
		VFL.debug(out, 1);
	end
end

------------------ GLOBAL FLAG MULTIPLEXERS
RDX.fm = {};
for i=1,4 do RDX.fm[i] = RDX.FlagMux:new(); end

-- Simplified retrieval functions
function RDX.AllDebuffs() return RDX.fm[1]; end
function RDX.AllEffects() return RDX.fm[4]; end

---------------------------------------------------
-- UNIT DATA CLASS
-- Information about an individual unit.
---------------------------------------------------
if not RDX.Unit then RDX.Unit = {}; end
RDX.Unit.__index = RDX.Unit;

-- Generate a new unit
function RDX.Unit:new(n)
	local x = {};
	setmetatable(x, RDX.Unit);
	-- Populate basic fields
	x.nid = n; x.uid = "raid"..n; 
	x.group = 0; x.name = "";
	x.valid = false;
	x.lastContact = 0;
	-- Generate flagsets; link them with the flag multiplexers.
	x.flagsets = {};
	for i=1,4 do x.flagsets[i] = RDX.FlagSet:new(RDX.fm[i], x); end
	-- We're done
	return x;
end

-- Clear all internal unit data
function RDX.Unit:Invalidate()
	if self.valid then
		-- Reset flags
		for i=1,4 do self.flagsets[i]:Clear(); end
		-- Reset fx timers
		self.fxTimers = {}; self.fxTimersDirty = false; self.fxTimersTime = 0;
		-- Reset last contact
		self.lastContact = 0;
		-- Reset validity
		self.valid = false;
	end
end

-------------- SIMPLE ACCESSORS
function RDX.Unit:GetProperName()
	return VFL.capitalize(self.name);
end

function RDX.Unit:IsValid()
	return self.valid;
end

function RDX.Unit:IsNear()
	return UnitIsVisible(self.uid);
end

function RDX.Unit:IsLeader()
	return (self.ldr > 0);
end

---- HP data
function RDX.Unit:Health()
	return UnitHealth(self.uid);
end
function RDX.Unit:MaxHealth()
	return UnitHealthMax(self.uid);
end
function RDX.Unit:FracHealth()
	local a,b = UnitHealth(self.uid),UnitHealthMax(self.uid);
	if(b<1) or (a<0) then return 0; end
	return a/b;
end
function RDX.Unit:MissingHealth()
	return UnitHealthMax(self.uid) - UnitHealth(self.uid);
end
function RDX.Unit:FracMissingHealth()
	local a,b = UnitHealth(self.uid),UnitHealthMax(self.uid);
	if(b<1) or (a<0) then return 0; end
	return (b-a)/b;
end
function RDX.Unit:IsDead()
	return UnitIsDeadOrGhost(self.uid);
end
function RDX.Unit:IsFollowDistance()
	return CheckInteractDistance(self.uid, 4);
end
---- MP data
function RDX.Unit:Mana()
	return UnitMana(self.uid);
end
function RDX.Unit:MaxMana()
	return UnitManaMax(self.uid);
end
function RDX.Unit:FracMana()
	local a,b = UnitMana(self.uid),UnitManaMax(self.uid);
	if(b<1) or (a<0) then return 0; end
	return a/b;
end
function RDX.Unit:MissingMana()
	return UnitManaMax(self.uid) - UnitMana(self.uid);
end
function RDX.Unit:FracMissingMana()
	local a,b = UnitMana(self.uid),UnitManaMax(self.uid);
	if(b<1) or (a<0) then return 0; end
	return (b-a)/b;
end

function RDX.Unit:IsHealer()
	if self.class == 2 or self.class == 5 or self.class == 8 or self.class == 9 then
		--paladin, shaman, priest, or druid
		return true;
	else
		return false;
	end
end

-- Returns the WoW Powertype of the unit
function RDX.Unit:PowerType()
	return UnitPowerType(self.uid);
end

-- Return the fundamental numeric ID of the unit.
function RDX.Unit:GetNumber()
	return self.nid;
end

-- Update last chat contact time
function RDX.Unit:UpdateContactTime()
	self.lastContact = GetTime();
end

-- Determine if this unit is properly connected to the game/RDX
function RDX.Unit:IsSynced()
	if not self.online then return false; end
	return true;
end
function RDX.Unit:IsOnline()
	return self.online;
end
function RDX.Unit:IsInDataRange()
	return UnitIsVisible(self.uid);
end


-- Determine if this unit is curable
function RDX.Unit:IsCurable()
	for k,v in self.flagsets[2].flags do if v then
		if RDX.playerClass:CanCure(k) then return true; end
	end end
	return false;
end

-- Determine if this unit has a named debuff
function RDX.Unit:HasDebuff(d)
	return self.flagsets[1]:Get(d);
end

function RDX.Unit:Debuffs()
	return self.flagsets[1].flags;
end

-- Determine if this unit has a given effect
function RDX.Unit:HasEffect(e)
	return self.flagsets[4]:Get(e);
end

------------------------ FLAG DATA ACQUISITION
-- Debuff enumeration subroutine
function RDX.Unit:EnumDebuffs()
	-- untouch debuff and debuff-type flags
	self.flagsets[1]:Untouch();
	self.flagsets[2]:Untouch();
	-- Enumerate all unit debuffs
	local i = 1;
	while true do
		-- Acquire debuff texture
		local dtex = UnitDebuff(self.uid, i);
		if not dtex then break; end
		-- Stuff tooltip
		VFLTipTextLeft1:SetText(nil);
		VFLTipTextRight1:SetText(nil);
		VFLTip:SetUnitDebuff(self.uid, i);
		-- Extract tooltip info
		local dn, dt, fd = VFLTipTextLeft1:GetText(), VFLTipTextRight1:GetText(), nil;
		-- Apply debuff-type flag
		if(dt) and (dt ~= "") then
			dt = string.lower(dt);
			self.flagsets[2]:Set(dt, true, true);
		end
		-- Touch debuff flag
		if(dn) and (dn ~= "") then
			dn = string.lower(dn);
			RDX.SetAuraMetadata(2, dn, dtex, VFLTipTextLeft1:GetText(), VFLTipTextRight1:GetText(), VFLTipTextLeft2:GetText(), dt)
			self.flagsets[1]:Set(dn, true, true);
			-- Determine if there's an effect associated with this debuff
			local fx = RDX.GetEffectFromDebuffName(dn);
			-- If it's a WoW-synced effect...
			if fx and fx.syncWoW then
				self.flagsets[4]:Set(fx.id, true, true);
			end
		end
		-- Increment debuff index
		i = i + 1;
	end
	-- Zero out all untouched flags of both kinds
	self.flagsets[1]:ClearUntouched();
	self.flagsets[2]:ClearUntouched();
end

-- Buff update subroutine
function RDX.Unit:EnumBuffs()
	local flagset = self.flagsets[3];
	-- Untouch buff flags
	flagset:Untouch();
	-- Enumerate all buffs
	local i = 1;
	while true do
		-- Acquire buff texture
		local btex = UnitBuff(self.uid, i);
		if not btex then break; end
		-- Stuff tooltip
		VFLTipTextLeft1:SetText(nil);
		VFLTipTextRight1:SetText(nil);
		VFLTip:SetUnitBuff(self.uid, i);
		-- Get buff name
		local bn = VFLTipTextLeft1:GetText();
		if(bn) and (bn ~= "") then
			bn = string.lower(bn);
			RDX.SetAuraMetadata(1, bn, btex, VFLTipTextLeft1:GetText(), VFLTipTextRight1:GetText(), VFLTipTextLeft2:GetText())
			flagset:Set(bn, true, true);
			local fx = RDX.GetEffectFromBuffName(bn);
			if fx and fx.syncWoW then
				self.flagsets[4]:Set(fx.id, true, true);
			end
		end
		-- Incr index
		i = i + 1;
	end
	flagset:ClearUntouched();
end

-- Derive aura changes from the WOW Aura impulse
function RDX.Unit:EnumAuras()
	-- Untouch effect flags
	self.flagsets[4]:Untouch();
	-- Process auras
	self:EnumDebuffs();
	self:EnumBuffs();
	-- Clear untouched effects that are WoW-synced
	for k,v in self.flagsets[4].flags do
		if RDX.fx[k].syncWoW then
			if not v.touched then
				self.flagsets[4]:DirectSet(k, v, nil);
			end
		end
	end
end

-- Clean all flags after processing
function RDX.Unit:Clean()
	for i=1,4 do self.flagsets[i]:Clean(); end
end

-- Debug dump flag info
function RDX.Unit:DebugDumpFlags(n)
	local fns = { "debuff", "debuff-type", "buff", "effect" };
	VFL.debug("FLAGDUMP <" .. self.name .. "> type: " .. fns[n]);
	self.flagsets[n]:DebugDump();
end

-- Get class color
function RDX.Unit:GetClassColor()
	return self.classObject.color;
end

------------------------------------------------
-- GLOBAL UNIT DATABASE
------------------------------------------------
-- Initially, pop the database with 40 empty units
RDX.unit = {};
RDX.uname = {};
for i=1,40 do
	RDX.unit[i] = RDX.Unit:new(i);
end

-- Get a unit by unit number
function RDX.GetUnitByNumber(i)
	return RDX.unit[i];
end

-- Get a unit by unit name
function RDX.GetUnitByName(n)
	return RDX.uname[n];
end

-- Signal that's tripped whenever unit identities change
RDX.SigUnitIdentitiesChanged = VFL.Signal:new();
-- Signal that's tripped whenever raid roster is shifted around without ID change
RDX.SigRaidRosterMoved = VFL.Signal:new();
-- Signal that's tripped on any change of raid roster
RDX.SigRaidRosterUpdate = VFL.Signal:new();

-- Called on a raid roster update
function RDX.RaidRosterUpdate()
	VFL.debug("RDX.RaidRosterUpdate()", 5);
	-- Determine if the player is even in a raid
	local n = GetNumRaidMembers();
	if(n == 0) then
		-- not in raid
	else
		-- in raid
	end

	-- Now rebuild the database
	local anyidchange = false;
	-- Quash old name hash
	RDX.uname = {};
	-- Iterate over all raid units
	for i=1,40 do
		local u = RDX.GetUnitByNumber(i);
		local idchange = false;
		local name, ldr, grp, lvl, class, _, zone, online = GetRaidRosterInfo(i);
		-- If the unit doesn't exist, invalidate
		if not name then
			if u:IsValid() then
				-- The unit was valid, trip identity change
				anyidchange = true;
			end
			u:Invalidate();
		else
			name = string.lower(name);
			-- Remap this unit's identity in the name table
			RDX.uname[name] = u;
			-- Check if this unit has changed identities
			if(u.name ~= name) then
				idchange = true; anyidchange = true;
				VFL.debug("Unit identity change: unit raid"..i.." changed from " .. u.name .. " to " .. name, 2);
				-- It has, invalidate old data
				u:Invalidate();
			end
			-- Repopulate unit data fields
			u.valid = true; u.name = name;
			u.ldr = ldr; u.group = grp; u.level = lvl; u.className = string.lower(class); u.online = online;
			u.classObject = RDX.classesByName[u.className];
			u.class = u.classObject.id;
			-- If identity changed, mark everything dirty
			if(idchange) then
				RDX.DB.ForceAurasDirty(u:GetNumber());
			end
		end
	end
	-- Trip appropriate signals
	if(anyidchange) then 
		VFL.debug("RDX.SigUnitIdentitiesChanged:Raise()", 5);
		RDX.SigUnitIdentitiesChanged:Raise();
	else
		VFL.debug("RDX.SigRaidRosterMoved:Raise()", 5);
		RDX.SigRaidRosterMoved:Raise();
	end
	VFL.debug("RDX.SigRaidRosterUpdate:Raise()", 5);
	RDX.SigRaidRosterUpdate:Raise();
end

-- Get the player's unit
function RDX.GetPlayerUnit()
	return RDX.uname[string.lower(UnitName("player"))];
end

-- Copy all valid raid group units into the given set
function RDX.MakeRaidGroupSet(set)
	for i=1,40 do
		if RDX.unit[i].valid then
			set.members[i] = true;
		else
			set.members[i] = nil;
		end
	end
end

function RDX.MakeFilteredRaidGroupSet(set, filter)
	for i=1,40 do
		set.members[i] = nil;
		if RDX.unit[i].valid and filter(RDX.unit[i]) then set.members[i] = true; end
	end
end

--------------------------------------------------
-- FLAG EVENT PROCESSING
--------------------------------------------------
-- Create the "unit's flags are dirty" signals
RDX.SigUnitFlagsDirty = {};
for i=1,4 do RDX.SigUnitFlagsDirty[i] = VFL.Signal:new(); end
-- Create the "multiplexer content is dirty" signals
RDX.SigMuxFlagsDirty = {};
for i=1,4 do RDX.SigMuxFlagsDirty[i] = VFL.Signal:new(); end

-- Create the dirty unit aura queue
RDX.auraq = {};

-- Process the aura queue
function RDX.DB.DoProcessAuras()
	local i = 1;
	-- For all units with dirty auras...
	for u,v in RDX.auraq do if v then
		-- Cap number of auras per processing cycle
		if i > RDXG.perf.bNumUnitsPerAuraUpdate then 
			VFL.debug("RDX.DB.DoProcessAuras(): exceeded max " .. i .. " aura updates in a single cycle.", 8);
			break; 
		end
		-- Now reenumerate the unit auras
		local unit = RDX.GetUnitByNumber(u);
		if unit:IsValid() then
			-- Re-enumerate the unit's buffs and debuffs
			unit:EnumAuras();
			-- Raise signals for any auras that might be dirty
			for i=1,4 do
				if unit.flagsets[i].dirty then RDX.SigUnitFlagsDirty[i]:Raise(unit); end
			end
			-- Clean all dirty flags
			unit:Clean();
			-- Nil out the appropriate entry of the auraq
			RDX.auraq[u] = nil;
		end
		-- Increment and move on
		i = i + 1;
	end end
	-- Now process any multiplexer events
	for i=1,4 do
		RDX.fm[i]:Signal(RDX.SigMuxFlagsDirty[i]);
		RDX.fm[i]:Clean();
	end
	VFL.schedule(RDXG.perf.bAuraUpdateDelay, RDX.DB.DoProcessAuras);
end

-- Signals
RDX.SigUnitDeath = VFL.Signal:new();
-- Create the dirty death list
RDX.deathlist = {};
function RDX.DB.DoProcessDeath()
	for i=1, 40 do
		local dead = RDX.unit[i]:IsDead();
		if dead ~= RDX.deathlist[i] then
			RDX.SigUnitDeath:Raise(i, RDX.GetUnitByNumber(i));
		end
		RDX.deathlist[i] = dead;
	end
	VFL.schedule(RDXG.perf.bDeathUpdateDelay, RDX.DB.DoProcessDeath);
end

-- Signals
RDX.SigUnitFollowDistance = VFL.Signal:new();
-- Create the dirty follow distance list
RDX.followdistancelist = {};
function RDX.DB.DoProcessFollowDistance()
	for i=1, 40 do
		local followdistance = RDX.unit[i]:IsFollowDistance();
		if followdistance ~= RDX.followdistancelist[i] then
			RDX.SigUnitFollowDistance:Raise(i, RDX.GetUnitByNumber(i));
		end
		RDX.followdistancelist[i] = followdistance;
	end
	VFL.schedule(RDXG.perf.bFollowDistanceUpdateDelay, RDX.DB.DoProcessFollowDistance);
end

-- Called on UNIT_AURA
function RDX.DB.OnUnitAura(uid)
	if not IsRaidUnit(uid) then return; end
	local n = UIDtoN(uid);
	RDX.auraq[n] = true;
end

-- Force-set auras dirty for a given unit number
function RDX.DB.ForceAurasDirty(n)
	RDX.auraq[n] = true;
end

-- Called when an outside source might have disturbed the effects (flagtype 4)
-- through an impulse like a chat channel
function RDX.DB.HandleUnitDirtyEffects(u)
	if u.flagsets[4].dirty then
		RDX.SigUnitFlagsDirty[4]:Raise(u);
		u.flagsets[4]:Clean();
	end
end

-----------------------------------------------------------
-- UNIT_HEALTH/UNIT_MANA
-----------------------------------------------------------
-- Signals
RDX.SigUnitHealth = VFL.Signal:new();
RDX.SigUnitMana = VFL.Signal:new();

function RDX.DB.OnUnitHealth(uid)
	if not IsRaidUnit(uid) then return; end
	local n = UIDtoN(uid);
	RDX.SigUnitHealth:Raise(n, RDX.GetUnitByNumber(n));
end
function RDX.DB.OnUnitMana(uid)
	if not IsRaidUnit(uid) then return; end
	local n = UIDtoN(uid);
	RDX.SigUnitMana:Raise(n, RDX.GetUnitByNumber(n));
end

------------------------------------------------------------
-- INIT
------------------------------------------------------------
-- Core database initialization
function RDX.DB.Init()
	VFL.debug("RDX.DB.Init()", 5);
	
	-- Raid roster events
	RDXEvent:Bind("RAID_ROSTER_UPDATE", nil, RDX.RaidRosterUpdate);
	RDX.RaidRosterUpdate();

	-- UNIT_AURA events
	RDXEvent:Bind("UNIT_AURA", nil, function() RDX.DB.OnUnitAura(arg1); end);
	VFL.schedule(RDXG.perf.bAuraUpdateDelay, RDX.DB.DoProcessAuras);
	
	-- Death Updates
	VFL.schedule(RDXG.perf.bDeathUpdateDelay, RDX.DB.DoProcessDeath);
	
	-- Distance Updates
	VFL.schedule(RDXG.perf.bFollowDistanceUpdateDelay, RDX.DB.DoProcessFollowDistance);

	-- UNIT_HEALTH/UNIT_MANA events
	RDXEvent:Bind("UNIT_HEALTH", nil, function() RDX.DB.OnUnitHealth(arg1); end);
	RDXEvent:Bind("UNIT_HEALTH_MAX", nil, function() RDX.DB.OnUnitHealth(arg1); end);
	RDXEvent:Bind("UNIT_MANA", nil, function() RDX.DB.OnUnitMana(arg1); end);
	RDXEvent:Bind("UNIT_MANA_MAX", nil, function() RDX.DB.OnUnitMana(arg1); end);
end
