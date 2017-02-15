-- Location.lua
-- RDX5 - Raid Data Exchange by Bill Johnson (Venificus of Eredar Server)
--
-- Creates and maintains a three-dimensional
-- relative coordinate system for raid members
-- and targets derived from communicated 
-- distance ranges.
-- 

VFL.debug("[RDX5] Loading Location.lua", 2);

if not RDX.Location then RDX.Location = {}; end

-- Do stuff after variables have loaded
function RDX.Location.Init()
	VFL.debug("RDX.Location.Init()", 2);
	-- Bind start/stop message for testing
	RPC.Bind("loc_start", RDX.Location.StartHeartbeat);
	RPC.Bind("loc_stop", RDX.Location.StopHeartbeat);
	-- Bind channel messages to calculation functions
	VFLEvent:NamedBind("loc_calc", BlizzEvent("CHAT_MSG_ADDON"), function() if arg1=="RDX" and strsub(arg2, 1, 2) == "D:" then RDX.Location.DB:Update(arg2, arg1); end end);
end

local laststr = nil;

function RDX.Location.StartHeartbeat()
	-- 1 Second Heartbeat
	local str = "D:";
	for i=1,GetNumRaidMembers() do
		local uid = "raid"..i
		str = str .. tostring(RDX.Location.GetDistanceRange(uid));
	end
	VFL.scheduleExclusive("loc_heartbeat", 1, function() RDX.Location.StartHeartbeat(); end)
	if laststr == str then return; end -- Only send new data
	laststr = str
	SendAddonMessage("RDX", str, "RAID")
end

function RDX.Location.StopHeartbeat()
	VFL.removeScheduledEventByName("loc_heartbeat");
end

function RDX.Location.GetDistanceRange(uid)
	local dist = nil;
	if CheckInteractDistance(uid, 4) then
		-- <30 yards
		if CheckInteractDistance(uid, 3) then
			-- <10 yards
			if CheckInteractDistance(uid, 1) then
				-- 0-5.55 yards
				return 0
			else
				-- 5.55-10 yards
				return 1
			end
		else
			-- 10-30 yards
			if CheckInteractDistance(uid, 2) then
				-- 10-11.11 yards
				return 2
			else
				-- 11.11 - 30 yards
				return 3
			end
		end
	else
		return 4 -- 30+ yards
	end
end

if not RDX.Location.DB then RDX.Location.DB = {}; end

function RDX.Location.DB:Update(author, str, avg)
	if not str then return; end
	if not avg then
		avg = RDX.Location.GetAvgDistanceFromString(str)
	end
	local complete = nil;
	for i=1,table.getn(self) do
		if not complete then
			if self[i].name == author then
				self[i].str = str;
				self[i].time = GetTime();
				self[i].avg = avg;
				complete = 1
			end
		end
	end
	if complete then
		return;
	else
		table.insert(self, { 
				name = author;
				str = str;
				time = GetTime();
				avg = avg;
				});
	end				
end

function RDX.Location.DB:GetSpreadOutFactor()
	local rt = 0;
	local n = table.getn(self);
	for i=1,n do
		rt = rt+self[i].avg;
	end
	local avg = rt/n;
	return avg;
end
		
			

function RDX.Location.GetAvgDistanceFromString(str)
	str = strsub(str, 3);
	local rt = 0;
	for i=1,strlen(str) do
		if tonumber(strsub(str, i, i)) and tonumber(strsub(str,i,i)) < 5 then
			local d = RDX.Location.Key[tonumber(strsub(str, i, i))];
			rt = rt+d;
		end
	end
	local avg = rt/strlen(str);
	return avg;
end


RDX.Location.Key = {
	[0] = 5.55/2,
	[1] = (5.55+10)/2,
	[2] = (10+11.11)/2,
	[3] = (11.11+30)/2,
	[4] = 40,
}

--[[ Save for later use if needed
------------------------------------------
-- Converting to/from base-100
------------------------------------------

RDX.Location.100to10lib = {
	["0"] = 0,
	["1"] = 1,
	["2"] = 2,
	["3"] = 3,
	["4"] = 4,
	["5"] = 5,
	["6"] = 6,
	["7"] = 7,
	["8"] = 8,
	["9"] = 9,
	["a"] = 10,
	["b"] = 11,
	["c"] = 12,
	["d"] = 13,
	["e"] = 14,
	["f"] = 15,
	["g"] = 16,
	["h"] = 17,
	["i"] = 18,
	["j"] = 19,
	["k"] = 20,
	["l"] = 21,
	["m"] = 22,
	["n"] = 23,
	["o"] = 24,
	["p"] = 25,
	["q"] = 26,
	["r"] = 27,
	["s"] = 28,
	["t"] = 29,
	["u"] = 30,
	["v"] = 31,
	["w"] = 32,
	["x"] = 33,
	["y"] = 34,
	["z"] = 35,
	["A"] = 36,
	["B"] = 37,
	["C"] = 38,
	["D"] = 39,
	["E"] = 40,
	["F"] = 41,
	["G"] = 42,
	["H"] = 43,
	["I"] = 44,
	["J"] = 45,
	["K"] = 46,
	["L"] = 47,
	["M"] = 48,
	["N"] = 49,
	["O"] = 50,
	["P"] = 51,
	["Q"] = 52,
	["R"] = 53,
	["S"] = 54,
	["T"] = 55,
	["U"] = 56,
	["V"] = 57,
	["W"] = 58,
	["X"] = 59,
	["Y"] = 60,
	["Z"] = 61,
	["•"] = 62, -- 7
	["¤"] = 63, -- 15
	["¶"] = 64, -- 20
	["§"] = 65, -- 21
	["!"] = 66, -- 33
	["\""] = 67, -- 34
	["#"] = 68, -- 35
	["$"] = 69, -- 36
	["%"] = 70, -- 37
	["&"] = 71, -- 38
	["'"] = 72, -- 39
	["("] = 73, -- 40
	[")"] = 74, -- 41
	["*"] = 75, -- 42
	["+"] = 76, -- 43
	[","] = 77, -- 44
	["-"] = 78, -- 45
	["."] = 79, -- 46
	["/"] = 80, -- 47
	[":"] = 81, -- 58
	[";"] = 82, -- 59
	["<"] = 83, -- 60
	["="] = 84, -- 61
	[">"] = 85, -- 62
	["?"] = 86, -- 63
	["@"] = 87, -- 64
	["["] = 88, -- 91
	["\\"] = 89, -- 92
	["]"] = 90, -- 93
	["_"] = 91, -- 95
	["`"] = 92, -- 96
	["{"] = 93, -- 123
	["|"] = 94, -- 124
	["}"] = 95, -- 125
	["~"] = 96, -- 126
	["Ç"] = 97, -- 128
	["ü"] = 98, -- 129
	["é"] = 99, -- 130
	--["â"] = 100, -- 131
}

RDX.Location.10to100charset = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ•¤¶§!\"#$%&'()*+,-./:;<=>?@[\\]_`{|}~Çüéâ"

*********
Distance Ranges:
0) 0-5.54999~
1) 5.55-9.99~
2) 10 - 11.1099~
3) 11.11-29.99~
4) 30+
**********

Base-5 System -> Base-100 :?
]]

