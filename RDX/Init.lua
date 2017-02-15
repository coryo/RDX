-- Init.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Initialization code.
--
VFL.debug("[RDX5] Loading Init.lua", 2);

RDX.initialized = false;
RDX.CurrentVersion = 19;

-- Initialize RDX
function RDX.Init()
	VFL.debug("[RDX] RDX.Init()", 2);
	-- Don't init twice into the same namespace
	if RDX.initialized then return; end
	
	-- Player name
	RDX.pn = string.lower(UnitName("player"));
	RDX.pspace = RDX.pn .. "|" .. string.lower(GetRealmName());

	-- Player class
	RDX.playerClass = RDX.classesByName[string.lower(UnitClass("player"))];

	-- SAVED VARIABLES
	-- Base saved variables hash
	if not RDX5Data then RDX5Data = {}; end
	-- Global saved variables (not per-player)
	if not RDX5Data.Global then RDX5Data.Global = {}; end
	RDXG = RDX5Data.Global;
	if not RDXG.DataVersion then RDXG.DataVersion = RDX.DataVersion; end
	-- Check for incompatible data version
	if RDXG.DataVersion ~= RDX.DataVersion then
		VFL.schedule(10, function() VFL.CC.Popup(function() RDX.MasterReset(); end, "Data Format Changed", "A new version of RDX has been installed. This upgrade requires a master reset. Perform one? Actually, it doesn't matter what you click, it's going to happen anyway."); end);
		return;
	end
	-- Local saved variables (per-player)
	if not RDX5Data.User then RDX5Data.User = {}; end
	if not RDX5Data.User[RDX.pspace] then
		VFL.print("[RDX5] No profile for " .. RDX.pspace .. ", creating one.");
		RDX5Data.User[RDX.pspace] = {};
	end
	RDXU = RDX5Data.User[RDX.pspace];

	-- Apply default settings
	if RDXU.enabled == nil then RDXU.enabled = true; end
	RDX.SetDefaults();

	-- Tracking init
	RDX.Tracking.Init();

	----------- UI FRAME POOLS INIT
	RDX.Windows.Init();
	RDX.UnitFrame.Init();
	RDX.Alert.Init();
	
	-- Last thing we do: initialize all modules
	RDX.Modules.Init();

	-- Deferred initialization in 4 sec  (note that this is 5 seconds total from login - 1 for init, 4 more for deferred init)
	VFL.schedule(4, RDX.DeferredInit);
	-- Mark initialization as complete
	RDX.initialized = true;
end

-- Deferred initialization functions
function RDX.DeferredInit()
	VFL.debug("[RDX5] RDX.DeferredInit()", 2);
	-- Database init
	RDX.DB.Init();
	-- Chat synchronization initialization
	RDX.Sync.Init();
	-- Auto-Promote init
	RDX.AutoPromote.Init();
	-- ImpliedTarget Init
	RDX.ImpliedTarget.Init()
	-- Location Init
	RDX.Location.Init()
	-- Enumerate player spells
	RDX.EnumSpells();
	-- HOT engine
	HOT.DeferredInit();

	-- Modules init
	RDX.Modules.DeferredInit();

	-- Encounter init -- establish last active encounter
	RDXEncPane:Show();
	RDX.Encounter.Init();
	--Aggro Monitor
	RDX.AggroMonitor.Init()
	--Keyword Invite
	RDX.Raid.KeywordInit()
	
	-- Start heartbeats
	RDX.HBFast();

	-- Mark full init
	RDX.initComplete = true;
	
	--lets set the scaling, if it is valid.

	local sv_Scale = tonumber(RDX5Data.EncScaleValue);
	if sv_Scale then
		if sv_Scale >= 1 and sv_Scale <= 10 then
			RDX.DoSetEncScale(sv_Scale);
		end
	end

	--if hideall is on, lets hide the ui
	if RDX5Data.RDXHideAll then
		RDX.MasterHide()
	end
	

end


--------------
-- For debugging purposes, allow us to monitor RDX channel.
--------------
function RDX.StartMonitorChat()
	VFLEvent:NamedBind("rdxmonitorcomms", BlizzEvent("CHAT_MSG_CHANNEL"), function() if arg9=="rdxvengeance" then VFL.print("[RDX]:" .. arg2 .. "] " .. arg1); end end);
	VFL.print("[RDX] Now displaying comms.  Type /script RDX.StopMonitorChat() to discontinue");
end

function RDX.StopMonitorChat()
	VFLEvent:NamedUnbind("rdxmonitorcomms");
end


-------------------------------
-- SLASH COMMANDS
-------------------------------
SLASH_RDX1 = "/rdx";
SLASH_RDXGREETING1 = "/rdxgreeting";
SLASH_RDXSCALE1 = "/rdxscale";
SLASH_X1 = "/x";
--Slash command for supressing the greeting
SlashCmdList["RDX"] = function(str) RDX.PrintSlashCmdList(str) end 
SlashCmdList["RDXGREETING"] = function(arg1) RDX.SetGreeting(arg1) end
SlashCmdList["RDXSCALE"] = function(str) RDX.SetEncScale(str) end 
SlashCmdList["X"] = function(str) RunScript("VFL.print(" .. str .. ")") end  --shortcut to /script VFL.print(


function RDX.PrintSlashCmdList(str)
	local str = string.lower(str)
	if str == "" then
		VFL.print("RDX Version: " .. RDX.CurrentVersion);
		VFL.print("/rdx [hide/show]  : Hide/Show all of RDX.");
		VFL.print("/rdxgreeting {0,1}  :  Use 0 to stop the startup greeting .wav");
		VFL.print("/rdxscale {1-10}  :  Scales the main RDX window (the default is 8)");
	else
		if str == "hide" then
			RDX5Data.RDXHideAll = true;
			RDX.MasterHide()
		elseif str == "show" then
			RDX5Data.RDXHideAll = false;
			RDX.MasterShow()
		end
	end
end

function RDX.SetGreeting(arg1)
	if arg1 == "0" or arg1 == "false" or arg1 == "off" then 
		RDX5Data.SuppressGreeting = true; 
		VFL.print("Disabled startup greeting."); 
	else 
		RDX5Data.SuppressGreeting = false; 
		VFL.print("Enabled startup greeting."); 
	end
end



-- Bind initialization events
-- Changed 6/4/2006 so that it will join the last chat channel, instead of the first.
--RDXEvent:Bind("VARIABLES_LOADED", nil, RDX.Init);
RDXEvent:Bind("VARIABLES_LOADED", nil, function() VFL.schedule(1, function() RDX.Init(); end); end);




-----------------------------------------------
-- HELPER FUNCTIONS FOR DEVELOPMENT BELOW
-----------------------------------------------


function RDX.FindFrames()
	local frame = EnumerateFrames()
	while frame do
		if frame:IsVisible() and MouseIsOver(frame) then
			DEFAULT_CHAT_FRAME:AddMessage(frame:GetName())
		end
		frame = EnumerateFrames(frame)
	end
end

-- Event recording functions

local xf = CreateFrame("Frame", nil, UIParent)

if not RDX.EventRecordingToggle then RDX.EventRecordingToggle = nil; end;
if not RDX.RecordedEvents then RDX.RecordedEvents = {}; end;

function RDX.ToggleEventRecording()
	if not RDX.EventRecordingToggle then
		xf:SetScript("OnEvent", function() RDX.AddRecordedEvent(event); end);
		xf:RegisterAllEvents();
		RDX.EventRecordingToggle = true;
		VFL.print("Recording events to: RDX.RecordedEvents");
	else
		xf:SetScript("OnEvent", nil);
		xf:UnregisterAllEvents();
		RDX.EventRecordingToggle = false;
		VFL.print("Event recording stopped, events are in: RDX.RecordedEvents");
	end
end

function RDX.AddRecordedEvent(event)
	if string.find(event, "CHAT_MSG") then
	local i = table.getn(RDX.RecordedEvents)+1;
	RDX.RecordedEvents[i] = {}
		RDX.RecordedEvents[i].name = event;
		RDX.RecordedEvents[i][1] = arg1;
		RDX.RecordedEvents[i][2] = arg2;
		RDX.RecordedEvents[i][3] = arg3;
		RDX.RecordedEvents[i][4] = arg4;
		RDX.RecordedEvents[i][5] = arg5;
		RDX.RecordedEvents[i][6] = arg6;
		RDX.RecordedEvents[i][7] = arg7;
		RDX.RecordedEvents[i][8] = arg8;
		RDX.RecordedEvents[i][9] = arg9;
		RDX.RecordedEvents[i].time = GetTime();
	end
end

function RDX.ParseEvents(str)
	for i=1,table.getn(RDX.RecordedEvents) do
		local ostr = nil;
		for x=1,9 do
			if RDX.RecordedEvents[i][x] then
				if string.find(RDX.RecordedEvents[i][x], str) then
					ostr = RDX.RecordedEvents[i].name;
					for y=1,9 do
						if RDX.RecordedEvents[i][y] and RDX.RecordedEvents[i][y] ~= "" then
							ostr = ostr.. " arg"..y..": "..RDX.RecordedEvents[i][y]
						end
					end
					ostr = ostr.. " time: "..RDX.RecordedEvents[i].time
				end
			end
		end
		if ostr then 
			VFL.print(ostr);
		end
	end
end


