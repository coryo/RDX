-- VFL
-- Time-related functions

if not VFL.Time then VFL.Time={}; end

-- Localize functions to prevent table lookups
local mathdotfloor = math.floor;
local blizzGetTime = GetTime;

--- Gets the kernel time with 1/10th second precision.
-- @return The kernel time with no more than .1 digits of precision.
function GetTimeTenths()
	return mathdotfloor(blizzGetTime()*10)/10;
end

-----------------------------------------------
-- TIMERS
-----------------------------------------------
-- Countup timer
if not VFL.CountUpTimer then VFL.CountUpTimer={}; end


-- Create a new countup timer
function VFL.CountUpTimer:new()
	local s = {};

	local baseline, t0 = 0, nil;
	function s:Start() t0 = GetTime(); end
	function s:Get()
		if t0 then return baseline + (GetTime() - t0); else return baseline; end
	end
	function s:Stop()
		baseline = self:Get(); t0 = nil;
	end
	function s:Reset() baseline = 0; t0 = nil; end
	function s:IsRunning() return t0; end

	return s;
end

-----------------------------------------------------------------
-- SCHEDULING
-----------------------------------------------------------------
-- The global schedule array.
-- Sorted by time
VFL_sched = {};

-- OnUpdate handler - Run scheduled functions.
function VFL_OnUpdate(dt)
	-- While we have a scheduled event that is expired...
	while(VFL_sched[1] and VFL_sched[1].t <= GetTime()) do
		-- Get the scheduled event
		local se = table.remove(VFL_sched, 1);
		-- Be sure it's valid
		if(se.func) then
			-- Call with appropriate args
			if(se.args) then
				se.func(unpack(se.args));
			else
				se.func();
			end
		end -- if(se.func)
	end -- while
end;

-- Sort helper method to sort in ascending time order
function VFL_SchedTimeSort(s1, s2)
	if(s1.t < s2.t) then
		return true;
	else
		return false;
	end
end;

-- Create an entry in the schedule table.
function VFL.Time.CreateScheduleEntry(name, dt, func, ...)
	-- Create a new schedule entry
	schedEntry = {
		t = GetTime() + dt;
		func = func;
		args = arg;
		name = name;
	};
	-- Add the entry to the schedule
	table.insert(VFL_sched, schedEntry);
	-- Sort by ascending time
	table.sort(VFL_sched, VFL_SchedTimeSort);
	-- Return the schedule entry.
	return schedEntry;
end;

-- Schedule a named action that can be unscheduled later.
-- (This is a compatibility alias into the VFL.Time api)
VFL.scheduleNamed = VFL.Time.CreateScheduleEntry;

-- Schedule an action to take place at a specific time.
-- (This is a compatibility alias into the VFL.Time api)
function VFL.schedule(dt, func, ...)
	return VFL.scheduleNamed(nil, dt, func, unpack(arg));
end;

--- Deschedule a previously scheduled entry.
function VFL.deschedule(se)
	if not se then return; end
	se.func = nil;
end

-- Manually create a schedule entry.
function VFL.Time.ManualSchedule(se, dt)
	se.t = GetTime() + dt;
	table.insert(VFL_sched, se);
	table.sort(VFL_sched, VFL_SchedTimeSort);
	return se;
end

-- Return the countdown to an event, in seconds
function VFL.Time.GetEventCountdown(ev)
	return ev.t - GetTime();
end;

-- Find an event by name
function VFL.Time.FindEventByName(name)
	for i=1,table.getn(VFL_sched) do
		if VFL_sched[i].name == name then
			return VFL_sched[i];
		end
	end
	return nil;
end

-- Schedule by name if not already scheduled
function VFL.scheduleExclusive(name, dt, func, ...)
	if not VFL.Time.FindEventByName(name) then
		VFL.Time.CreateScheduleEntry(name, dt, func, unpack(arg));
	end
end

function VFL.removeScheduledEventByName(eventName)
	table.foreachi(VFL_sched, 
	function(i) 
		if VFL_sched[i] then
			if (VFL_sched[i].name == eventName) then
				table.remove(VFL_sched, i);
			end
		end
	end);
end

---------------------------
-- PERIODIC LATCH
-- A periodic latch prevents the underlying function from running
-- more often than once every N seconds.
---------------------------
if not VFL.PeriodicLatch then VFL.PeriodicLatch = {}; end
VFL.PeriodicLatch.__index = VFL.PeriodicLatch;

-- Construct a new periodic latch wrapping the given function.
function VFL.PeriodicLatch:new(f, ...)
	local x = {};
	setmetatable(x,self);
	x.latch = false;
	x.defer = false;
	x.period = 1;
	x.func = f;
	x.arg = arg;
	return x;
end

function VFL.PeriodicLatch:SetPeriod(p)
	self.period = p;
end

-- Unlatch the periodic latch, executing any deferred processes.
function VFL.PeriodicLatch:Unlatch()
	self.latch = false;
	if(self.defer) then
		self:execute();
	end
end

-- Schedule a deferred unlatch.
function VFL.PeriodicLatch:UnlatchLater()
	VFL.schedule(self.period, VFL.PeriodicLatch.Unlatch, self);
end

-- Attempt to execute the latched procedure.
function VFL.PeriodicLatch:execute()
	if not self.latch then
		self.func(unpack(self.arg));
		self.defer = false;
		self.latch = true;
		self:UnlatchLater();
	else
		self.defer = true;
	end
end

--- Create a "periodic latch" around a function. The periodic latch guarantees that a function
-- won't be called more often than the period, and if the function should be spammed multiple
-- times, it'll be called again the end of the period.
function VFL.CreatePeriodicLatch(period, f)
	local latch, deferred, unlatch, go = nil, nil, nil, nil;
	
	function unlatch()
		latch = nil;
		if deferred then deferred(); end
	end

	function go(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
		if not latch then
			f(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20);
			deferred = nil; latch = true;
			VFL.schedule(period, unlatch);
		else
			if not deferred then
				deferred = function() go(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20); end
			end
		end
	end
	
	return go;
end

----------------------------------------------------------------
-- PARSING, FORMATTING
----------------------------------------------------------------
-- Convert elapsed seconds to elapsed hours, minutes, seconds
function VFL.Time.GetHMS(sec)
	local min = math.floor(sec/60); sec = math.mod(sec, 60);
	local hr = math.floor(min/60); min = math.mod(min, 60);
	return { h = hr; m = min; s = sec; };
end

-- Convert (hours, minutes, seconds) to seconds
function VFL.Time.HMSToSec(hms)
	return (hms.h * 3600) + (hms.m * 60) + hms.s;
end

-- Format a seconds time as min:sec
function VFL.Time.FormatMinSec(sec)
	local min = math.floor(sec/60); sec = math.mod(sec, 60);
	return string.format("%d:%02d", min, sec);
end

----------------------------------------------------------------
-- TIME OFFSET CONTROL
----------------------------------------------------------------

--- Get the offset from local time to server time.
-- @return the number of seconds X satisfying ServerTime = LocalTime + X
function VFL.GetServerTimeOffset() 
	-- Don't be alarmed, this function will be updated at init-time with
	-- a working version!
	return 0; 
end

local offsetDlg = nil;
--- Show the UI for altering the time offset.
function VFL.TimeSetup()
	-- If already shown, forget it
	if offsetDlg then 
		VFL:Debug(1, "Attempt to VFL.ShowSetOffsetDialog() when it was already shown.");
		return; 
	end
	
	offsetDlg = VFLUI.AcquireFrame("Frame");
	offsetDlg:SetParent(UIParent);
	offsetDlg:SetPoint("CENTER", UIParent, "CENTER");
	offsetDlg:SetFrameStrata("DIALOG");
	offsetDlg:SetBackdrop({ 
		bgFile="Interface\\DialogFrame\\UI-DialogBox-Background"; 
		edgeFile="Interface\\Tooltips\\UI-Tooltip-Border";
		insets = { left = 5; right = 5; top = 4; bottom = 5; }; tile = true; tileSize = 16; edgeSize = 16; }
	);
	offsetDlg:SetWidth(350); offsetDlg:SetHeight(225);

	local ctl = VFLUI.CreateFontString(offsetDlg);
	ctl:SetDrawLayer("OVERLAY");
	ctl:SetFontObject(Fonts.Default);
	ctl:SetPoint("TOPLEFT", offsetDlg, "TOPLEFT", 5, -5);
	ctl:SetPoint("BOTTOMRIGHT", offsetDlg, "BOTTOMRIGHT", -5, 30);
	ctl:SetJustifyH("LEFT");
	ctl:Show();
	offsetDlg.text = ctl;

	local btn = VFLUI.Button:new(offsetDlg);
	btn:SetWidth(25); btn:SetHeight(25); btn:SetText("+");
	btn:SetPoint("BOTTOMLEFT", offsetDlg, "BOTTOMLEFT", 5, 5);
	btn:Show();
	btn:SetScript("OnClick", function()
		local tdlg = this:GetParent();
		tdlg.offset = tdlg.offset + 1;
	end);
	offsetDlg.btnPlus = btn;

	btn = VFLUI.Button:new(offsetDlg);
	btn:SetWidth(25); btn:SetHeight(25); btn:SetText("-");
	btn:SetPoint("LEFT", offsetDlg.btnPlus, "RIGHT");
	btn:Show();
	btn:SetScript("OnClick", function()
		local tdlg = this:GetParent();
		tdlg.offset = tdlg.offset - 1;
	end);
	offsetDlg.btnMinus = btn;

	btn = VFLUI.Button:new(offsetDlg);
	btn:SetWidth(35); btn:SetHeight(25); btn:SetText("OK");
	btn:SetPoint("BOTTOMRIGHT", offsetDlg, "BOTTOMRIGHT", -5, 5);
	btn:Show();
	btn:SetScript("OnClick", function()
		local tdlg = this:GetParent();
		VFLConfig.tz = tdlg.offset * 3600;
		ReloadUI();
	end);
	offsetDlg.btnOK = btn;
		
	offsetDlg.offset = math.floor(VFL.GetServerTimeOffset() / 3600);

	offsetDlg:SetScript("OnUpdate", function()
		local t,h,m = time(), GetGameTime();
		local dt = t + (this.offset * 3600);
		this.text:SetText("Please set the offset between your local time and the server's time. Do this by changing the offset until the Adjusted Time is within 1 hour of the Server Time.\n\n" .. strcolor(.7,.7,.7) .. "NOTE: Make sure your PC clock (the Local Time below) is reasonably accurate before proceeding. If it is not, please logout and reset it.\n\nNOTE: Mind the date. If you are far from the server, or it is near midnight, the server's date may be different than your date!|r\n\n     Local Time: " .. date("%H:%M:%S %m/%d/%y", t) .. "\n" .. strcolor(0,1,0) .."             Offset: " .. this.offset .. ":00:00|r\nAdjusted Time: " .. date("%H:%M:%S %m/%d/%y", dt) .. "\n    Server Time: " .. h .. ":" .. m .. " (" .. GetRealmName() .. ")");
	end);

	offsetDlg:Show();
end

----------------------------------------------------------------
-- UNIVERSAL TIME
----------------------------------------------------------------
VFL.Epoch = {};
VFL.Epoch.__index = VFL.Epoch;

function VFL.Epoch:new()
	local self = {};
	setmetatable(self, VFL.Epoch);
	return self;
end

--- Establish an epoch using an exact minute (hh:mm:00.00)
function VFL.Epoch:Synchronize(kernelTime, localTime, serverHr, serverMin)
	-- First priority is to compute the discrepancy between our estimate of the
	-- server time, and the actual server time.
	
	-- Get our estimate of the server's time
	local estServerDate = date("*t", localTime + VFL.GetServerTimeOffset());

	-- Assuming our estimate isn't too far off, the EXACT server time can be
	-- obtained by setting the hour, minute, second fields appropriately
	estServerDate.hour = serverHr;
	estServerDate.min = serverMin;
	estServerDate.sec = 0;
	self.serverTime = time(estServerDate);

	self.localTime = localTime;
	self.kernelTime = kernelTime;
end

--- Get the discrepancy between server and local time as it was when
-- this epoch was synchronized.
function VFL.Epoch:GetLocalTimeCorrection()
	return self.serverTime - self.localTime - VFL.GetServerTimeOffset();
end

--- Get the discrepancy between kernel and server time, such that
-- kernelTime + GetKernelTimeCorrection() = serverTime
function VFL.Epoch:GetKernelTimeCorrection()
	return self.serverTime - self.kernelTime;
end

--- Get the server time according to this epoch.
function VFL.Epoch:GetServerTime()
	return (GetTime() - self.kernelTime) + self.serverTime;
end

--- Convert a time to epochal server time.
function VFL.Epoch:KernelToServerTime(ktime)
	return (ktime - self.kernelTime) + self.serverTime;
end

-- Print debug information about an epoch.
function VFL.Epoch:Dump()
	VFL:Debug(1, "Epoch: kernelTime(" .. self.kernelTime .. ") = localTime(" .. self.localTime ..") = serverTime(" .. self.serverTime ..") = epochTime(0)");
	local kNow, sh, sm = GetTime(), GetGameTime();
	local eSvrTm = self.serverTime + (kNow - self.kernelTime);
	local eSvrDate = date(nil, eSvrTm);
	VFL:Debug(1, "* Epochal serverTime [" .. eSvrDate .. "] -- source " .. eSvrTm);
	VFL:Debug(1, "* Actual serverTime: " .. sh .. ":" .. sm);
	VFL:Debug(1, "* Exact discrepancy: " .. (self.serverTime - self.localTime - VFL.GetServerTimeOffset()));
end

-- System epoch management
local lastmin, sysEpoch = nil, nil;
local function TimeFixUpdate()
	-- Check the game time
	local h,m = GetGameTime();
	-- If the minute ticked, we have a time fix!
	if(m ~= lastmin) then
		local kernelTime, localTime = GetTime(), time();
		sysEpoch = VFL.Epoch:new();
		sysEpoch:Synchronize(kernelTime, localTime, h, m);
		VFL:Debug(1,"System epoch established!");
		sysEpoch:Dump();
		VFLEvents:Dispatch("SYSTEM_EPOCH_ESTABLISHED", sysEpoch);
	else
		-- Keep spamming time checks (we need 0.1 sec precision)
		VFL.schedule(0.1, TimeFixUpdate);
	end
end

--- Get the VFL system epoch.
function VFL.GetSystemEpoch()
	return sysEpoch;
end

--- Initialize the VFL kernel's timing subsystem.
function VFL.InitTime()
	VFL:Debug(1, "VFL.InitTime(): Initializing timing subsystem.");
	local now, sh, sm, today = time(), GetGameTime();
	local today = date("*t");
	
	-- Initialize the timezone system
	if not VFLConfig.tz then VFLConfig.tz = 0; end
	VFL.GetServerTimeOffset = function() return VFLConfig.tz; end

	-- Figure out the projected server time based on the server time offset.
	local projServerTime = now + VFL.GetServerTimeOffset();
	local projServerDate = date("*t", projServerTime);
	projServerDate.hour = sh; projServerDate.min = sm;
	local serverTime = time(projServerDate);
	
	-- Verify that the estimated server time is somewhat accurate.
	-- If not, demand the user set the offset.
	local diff = math.abs(projServerTime - serverTime);
	VFL:Debug(1, "* Time discrepancy of " .. diff .. "s detected.");
--	if (diff > 3000) then
--		VFL.TimeSetup();
--		return;
--	end

	-- Get a time fix
	if not sysEpoch then
		VFL:Debug(1, "* Establishing system epoch.");
		_, lastmin = GetGameTime();
		TimeFixUpdate();
	end
end
