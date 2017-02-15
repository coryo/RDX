-- Tracking.lua
-- RDX5 - Raid Data Exchange
-- (C)2005-2006 Bill Johnson (Venificus of Eredar server)
--
-- Implementation of the "tracking list." The tracking list is a data structure
-- that watches units in the raid, their targets, and their second-order
-- targets.
--
-- In its most simple usage, the tracking list can be used to map a player
-- name to a raid unit ID, or nil if none exists. More complex scenarios
-- include tracking a particular mob (provided it is being targeted by someone)
-- , tracking all people being attacked by hostile mobs, and so forth.
--
--
-- EVENT RESPONSE
-- 
-- Tracking Pulse:
-- There are several events that tracking entries can respond to. The most
-- primitive of these is the "tracking pulse." A tracking pulse is tripped 
-- under several circumstances:
--
-- * RAID_ROSTER_UPDATE
-- * Execution of RDX.Track()
-- * On any pulse of a .25 second heartbeat
--
-- When a tracking pulse executes, the raid roster is iterated, and for each
-- such valid unit, signals are raised corresponding to the "level" of the event that
-- tripped.

TRACK_PVP_PLAYERS = false; --this constant will be turned true to force the tracking module to track players



RDX.Tracking = {};

------------------------------------
-- TRACKING PULSE DISPATCH TABLES
------------------------------------
RDX_te = {};
function RDX.RegisterTrackingEntry(tbl)
	if (not tbl) or (not tbl.level) then return; end
	table.insert(RDX_te, tbl);
	return tbl;
end

function RDX.UnregisterTrackingEntry(tbl)
	if(not tbl) then return; end
	local idx = VFL.vfind(RDX_te, tbl);
	if idx then table.remove(RDX_te, idx); end
end

----------------------------
-- RAIDER TRACKING ENTRY
-- A raider tracking entry maps a unit name to its unit object, provided
-- a unit with that name is in the raid.
----------------------------
RDX.RaiderTrackingEntry = {};
RDX.RaiderTrackingEntry.__index = RDX.RaiderTrackingEntry;

function RDX.RaiderTrackingEntry:new(name)
	local x = {};
	setmetatable(x, RDX.RaiderTrackingEntry);
	x.name = name; x.unit = nil;
	return x;
end

-- Get the name of the target unit for this entry
function RDX.RaiderTrackingEntry:GetUnitName()
	return self.name;
end

-- Get the unit currently tracked by this entry
function RDX.RaiderTrackingEntry:GetUnit()
	return self.unit;
end

-----------------------------
-- RAIDER TRACKING TABLE
-- The raider tracking table is a weak table mapping raider names to raider
-- tracking entries. The tracking entries are updated on the tracking pulse
-- to contain the proper units.
-----------------------------
local tt_raiders = {};
setmetatable(tt_raiders, { __mode = 'v' }); -- Make this a weak table.

-- Create a tracker for a raider with the given name.
function RDX.TrackRaider(name)
	if (not name) or (not type(name) == "string") or (name == "") then return nil; end
	-- If it already exists, return it...
	local u = tt_raiders[name];
	if u then return u; end
	-- Otherwise, create a new one
	u = RDX.RaiderTrackingEntry:new(name);
	tt_raiders[name] = u;
	-- Trip a tracking pulse to possibly pickup our new entry...
	RDX.Track(3);
	return u;
end

-- Debug dump the tracking table
function RDX.DebugDumpRaiderTracking()
	VFL.debug("Tracking raiders:");
	for k,v in tt_raiders do
		VFL.debug("Name ["..k.."] Valid ["..tostring(v.unit).."]");
	end
end

-- The tracking pulse handler.
function RDX.RaiderTrackingPulseHandler(u)
	if tt_raiders[u.name] then tt_raiders[u.name].unit = u; end
end

-- Bind to a level 3 tracking pulse
RDX.RegisterTrackingEntry({
	level = 3;
	onBegin = function() for _,te in tt_raiders do te.unit = nil; end end;
	onUnit = function(u) if tt_raiders[u.name] then tt_raiders[u.name].unit = u; end end
});

----------------------------
-- TRACKING PULSE MANAGER
----------------------------
local RDX_tp_level = 1;

RDX.SigTrackingPulse = Signal:new();

-- Trip a midlevel tracking pulse
function RDX.Track(n)
	if not n then n = 2; end
	RDX_tp_level = n;
end

-- Main tracking pulse
function RDX.TrackingPulse()

	local i,j;
	-- Call the begin-sweep handler for all applicable tracking apps
	for _,i in RDX_te do
		if (RDX_tp_level >= i.level) then 
			if i.onBegin then i.onBegin(); end
		end
	end
	-- Foreach valid unit...
	for i=1,40 do
		local u = RDX.GetUnitByNumber(i);
		if (u:IsValid()) then
			-- Execute all tracking pulses of the given level and lower...
			for _,j in RDX_te do
				if (RDX_tp_level >= j.level) then 
					if j.onUnit then j.onUnit(u); end 
				end
			end -- for j
		end -- if u:IsValid()
	end -- for i
	-- Call the end-sweep handler for all applicable tracking apps
	for _,i in RDX_te do
		if (RDX_tp_level >= i.level) then 
			if i.onEnd then i.onEnd(); end
		end
	end
	-- Raise the appropriate signal
	RDX.SigTrackingPulse:Raise(RDX_tp_level);
	-- Reset the pulse level
	RDX_tp_level = 1;
	-- Schedule the next pulse.
	VFL.schedule(RDXG.perf.hbFast, RDX.TrackingPulse);
end

-- Initialize the tracking pulse manager.
function RDX.Tracking.Init()
	VFL.debug("RDX.Tracking.Init()", 2);
	-- A raid roster update trips a level 3 event.
	RDX.SigRaidRosterUpdate:Connect(nil, function() RDX_tp_level = 3; end);
	-- Start off our first pulse
	RDX.TrackingPulse();
end

--------------------------------------------------
-- HOT - Higher Order Targeting
--------------------------------------------------
HOT = RegisterVFLModule({
	name = "HOT";
	description = "Higher Order Targeting module for RDX";
	parent = RDX;
});

-- Tracking database
tt_targets = {};
setmetatable(tt_targets, { __mode = 'v' }); -- Make this a weak table.

------------------------
-- Target Tracking entry
-- Track an individual target by name.
------------------------
HOT.TargetTrackingEntry = {};
HOT.TargetTrackingEntry.__index = HOT.TargetTrackingEntry;

function HOT.TargetTrackingEntry:new(name)
	local self = {};
	setmetatable(self, HOT.TargetTrackingEntry);
	self.name = name;
	self.unit = nil; self.target = nil; self.lastUpdate = 0;
	self.health = 1; self.healthMax = 1; self.mana = 1; self.manaMax = 1;
	self.targetName = nil;
	self.class = nil;
	self.SigUpdate = Signal:new();
	self.SigLost = Signal:new();
	return self;
end

-- Determine if we are currently tracking the target
function HOT.TargetTrackingEntry:IsTracking()
	if(self.unit) then return true; else return false; end
end

-- Update local data from target info
function HOT.TargetTrackingEntry:Update(unit)
	-- If no unit provided, nil out all data

	if (unit == nil) then 
		self.unit = nil;
		return; 
	end
	-- Acquire data
	self.unit = unit; self.unitName = UnitName(unit);
	self.lastUpdate = GetTime();
	self.health = UnitHealth(unit); self.healthMax = UnitHealthMax(unit);
	self.class = UnitClass(unit);
	self.mana = UnitMana(unit); self.manaMax = UnitManaMax(unit);
	if UnitExists(unit .. "target") then
		self.target = unit .. "target";
		self.targetName = UnitName(self.target); self.targetIsRaider = UnitInRaid(self.target);
	else
		self.target = nil;
		self.targetName = nil; self.targetIsRaider = nil;
	end
	-- Notify that we have new data
	self.SigUpdate:Raise(self);
end

-- Forcibly release a target tracking entry
function HOT.TargetTrackingEntry:Release()
	self.SigUpdate = nil; self.SigLost = nil;
	tt_targets[string.lower(self.name)] = nil;
end

-- Debug dump the tracking table
function RDX.DebugDumpTargetTracking()
	VFL.debug("Tracking targets:");
	for k,v in tt_targets do
		VFL.debug("Name ["..k.."]");
	end
end

-- Main API hook into target tracking.
-- Tracks the target with the given name.
function HOT.TrackTarget(name)
	if (not name) or (not type(name) == "string") or (name == "") then return nil; end
	local lname = string.lower(name);
	-- If it already exists, return it...
	local u = tt_targets[lname];
	if u then return u; end
	-- Otherwise, create a new one
	u = HOT.TargetTrackingEntry:new(name);
	tt_targets[lname] = u;
	-- Trip a tracking pulse to possibly pickup our new entry...
	RDX.Track(1);
	return u;
end

function HOT.DeferredInit()
	HOT:Debug(1, "HOT.DeferredInit()");
	if RDXG.perf.enableHOT then
		HOT:Debug(1, "HOT.DeferredInit(): enabled, processing");
		RDX.RegisterTrackingEntry({
			level = 1;
			-- At the beginning of a cycle, remove all units
			onBegin = function() 
				for _,te in tt_targets do
					if te.unit then te.had = true; else te.had = nil; end
					te.unit = nil; te.found = nil; 
				end 
			end;
			-- For each unit, check his target and match it to tracking entries
			onUnit = function(u)
				local tgt = u.uid .. "target";
				if UnitExists(tgt) and (not UnitIsPlayer(tgt) or TRACK_PVP_PLAYERS) then
					local te = tt_targets[string.lower(UnitName(tgt))];
					if te and (not te.found) then
						te.found = true;
						te:Update(tgt);
					end
				end
			end;
			-- At the end of a cycle, if we lost our lock, raise all notifiers.
			onEnd = function()
				for _,te in tt_targets do
					if te.had and (not te.found) then
						te.SigLost:Raise(te); te.SigUpdate:Raise(te);
					end
				end
			end;
		});
	end
end
