-- Defaults.lua
-- RDX5 - Raid Data Exchange
-- (C)2005-06 Bill Johnson (Venificus of Eredar server)
--
-- Factory-default settings for preloading.
VFL.debug("[RDX5] Loading Defaults.lua", 2);

-----------------------------------
-- PREFERENCE MANAGEMENT
-----------------------------------
-- Load enc/module specific prefs
function RDX.MapUEMPrefs(en, mn, targ)
	if(not en) or (en == "") or (not mn) or (mn == "") then return false; end
	local p = RDXU["enc_" .. en];
	if not p then
		p = RDXU["enc_default"];
		if not p then
			p = {};
			RDXU["enc_default"] = p;
		end
	end
	local q = p["mod_"..mn];
	if not q then VFL.empty(targ); return false; end
	VFL.copyOver(targ, q);
	return true;
end

-- Save per-encounter-per-module prefs
function RDX.SaveUEMPrefs(en, mn, targ)
	if(not en) or (en == "") or (not mn) or (mn == "") then return false; end
	-- Determine if there are user prefs for this encounter
	local p = RDXU["enc_" .. en];
	-- If not, create them
	if not p then
		p = {};
		RDXU["enc_" .. en] = p;
	end
	-- Determine if the module has settings
	local q = p["mod_"..mn];
	if not q then
		q = {};
		p["mod_"..mn] = q;
	end
	-- Write the settings in from the target table
	VFL.copyOver(q, targ);
	return true;
end

-- Erase per-encounter-per-module prefs
function RDX.EraseUEMPrefs(en, mn)
	local p = RDXU["enc_" .. en];
	if not p then return; end
	p["mod_"..mn] = nil;
end

-- Overwrite the contents of the target table with the given module's
-- global preferences.
function RDX.MapUMPrefs(mn, targ)
	if(not mn) or (mn == "") then return false; end
	-- Determine if the pref exists
	local p = RDXU["mod_"..mn];
	-- If not, empty the table
	if not p then VFL.empty(targ); return false; end
	-- Otherwise, fill it with the pref data
	VFL.copyOver(targ, p);
	return true;
end

-- Save per-module prefs
function RDX.SaveUMPrefs(mn, targ)
	if(not mn) or (mn == "") then return false; end
	-- Determine if the pref exists
	local p = RDXU["mod_"..mn];
	-- If not, create
	if not p then 
		p = {};
		RDXU["mod_"..mn] = p;
	end
	-- Copy the data into the table
	VFL.copyOver(p, targ); return true;
end

-- Map global module prefs
function RDX.MapGMPrefs(mn, targ)
	if(not mn) or (mn == "") then return false; end
	-- Determine if the pref exists
	local p = RDXG["mod_"..mn];
	-- If not, empty the table
	if not p then VFL.empty(targ); return false; end
	-- Otherwise, fill it with the pref data
	VFL.copyOver(targ, p);
	return true;
end

-- Save global module prefs
function RDX.SaveGMPrefs(mn, targ)
	if(not mn) or (mn == "") then return false; end
	-- Determine if the pref exists
	local p = RDXG["mod_"..mn];
	-- If not, create
	if not p then 
		p = {};
		RDXG["mod_"..mn] = p;
	end
	-- Copy the data into the table
	VFL.copyOver(p, targ); return true;
end

-- Set a table key to a value if it doesn't already have one. Creates
-- all descending table keys if they don't exist
function RDX.Default(val, tbl, ...)
	local t,n = tbl,table.getn(arg);
	for i=1,(n-1) do
		if not t[arg[i]] then t[arg[i]] = {}; end
		t = t[arg[i]];
	end
	if t[arg[n]] == nil then t[arg[n]] = val; end
end

-- Apply all factory-default settings if necessary.
function RDX.SetDefaults()
	-------------------------
	-- PERFORMANCE DEFAULTS
	-------------------------
	----------
	-- Chat channel:
	-- Max msgq size
	RDX.Default(50, RDXG, "perf", "mqMaxSize"); 
	-- Delay between msgq procs
	RDX.Default(.75, RDXG, "perf", "mqDelay"); 
	----------
	-- Buff/debuff processing
	-- #units per aura update
	RDX.Default(5, RDXG, "perf", "bNumUnitsPerAuraUpdate"); 
	-- Min delay between aura updates
	RDX.Default(0.25, RDXG, "perf", "bAuraUpdateDelay"); 
	-- Min delay between death updates
	RDX.Default(0.25, RDXG, "perf", "bDeathUpdateDelay"); 
	-- Min delay between follow distance updates
	RDX.Default(0.25, RDXG, "perf", "bFollowDistanceUpdateDelay"); 
	-- Delay between buff timer updates
	RDX.Default(10, RDXG, "perf", "bAuraTimerSyncDelay"); 
	-- Delay between realtime aura timer updates
	RDX.Default(2, RDXG, "perf", "bAuraRealtimeSyncDelay"); 
	----------
	-- Windowing/GUI internals
	-- Min delay between individual window refreshes
	RDX.Default(0.25, RDXG, "perf", "uiWindowUpdateDelay");
	----------
	-- Heartbeats
	RDX.Default(0.20, RDXG, "perf", "hbFast");
	----------
	-- Higher-order targeting
	RDX.Default(true, RDXG, "perf", "enableHOT");

	------------------------
	-- EFFECTS METADATA
	------------------------
	RDX.Default({}, RDXG, "fxLow");

	------------------------
	-- APPEARANCE DEFAULTS
	-----------------------
	-- Debuff colors
	RDX.Default({r=0.50,g=0.50,b=0.50}, RDXG, "vis", "cDT", "other");
	RDX.Default({r=0.56,g=0.45,b=0.22}, RDXG, "vis", "cDT", "disease");
	RDX.Default({r=0.26,g=0.80,b=0.01}, RDXG, "vis", "cDT", "poison");
	RDX.Default({r=0.90,g=0.10,b=0.00}, RDXG, "vis", "cDT", "curse");
	RDX.Default({r=0.25,g=0.38,b=0.78}, RDXG, "vis", "cDT", "magic");
	RDX.Default({r=0,g=1,b=0}, RDXG, "vis", "cFriendHP");
	RDX.Default({r=1,g=0,b=0}, RDXG, "vis", "cFriendHPFade");
	RDX.Default({r=0,g=1,b=0}, RDXG, "vis", "cEnemyHP");
	RDX.Default({r=1,g=0,b=0}, RDXG, "vis", "cEnemyHPFade");
	RDX.Default({r=0,g=0,b=1}, RDXG, "vis", "cMana");
	RDX.Default({r=1,g=0,b=0}, RDXG, "vis", "cManaFade");
	RDX.Default({r=1,g=1,b=1}, RDXG, "vis", "cStatusText");
	RDX.Default({r=1,g=0,b=0}, RDXG, "vis", "cStatusTextFade");
	RDX.Default({r=.3,g=.7,b=.7}, RDXG, "vis", "cStaleData");
	RDX.Default({r=.5,g=.5,b=.5}, RDXG, "vis", "cLinkdead");
	RDX.Default({r=0.05,g=0.35,b=0.31}, RDXG, "vis", "cWindowTitle");
	RDX.Default({r=0.10,g=0.70,b=0.10}, RDXG, "vis", "cBuffWindowTitle");
end
