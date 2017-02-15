-- Encounters.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Encounter selection and management functionality.
--
VFL.debug("[RDX5] Loading Encounters.lua", 5);
if not RDX.Encounter then RDX.Encounter = {}; end



-----------------------------------
-- ENCOUNTER DATABASE
-----------------------------------
local edb = {};

-- Encounter registration mechanism
function RDX.RegisterEncounter(tbl)
	-- No unnamed encounters.
	if not tbl.name then return false; end
	-- DO IT
	edb[tbl.name] = tbl;
	return true;
end

-- Get the name of the currently-active encounter
function RDX.GetActiveEncounter()
	if not RDX.ce then return "default"; end
	return RDX.ce.name;
end

-- Get the title of the currently active encounter
function RDX.GetActiveEncounterTitle()
	if not RDX.ce then return "Default"; end
	return RDX.ce.title;
end

-- Save button
function RDX.Encounter:SaveButtonOnClick()
	if(arg1 == "LeftButton") then
		RDX.Encounter.ToggleSave();
	elseif(arg1 == "RightButton") then
		ReloadUI();
	end
end
function RDX.Encounter.ToggleSave()
	local enc = RDX.GetActiveEncounter();
	if(enc == "default") then return; end
	-- If the encounter is saved
	if RDXU.venc[enc] then
		-- Set it to no longer saved
		RDXU.venc[enc] = nil; RDX.Encounter.SaveOff();
		-- Revert to defaults
		RDX.LoadVirtualEncounter("default");
	else
		-- Set it to be saved
		RDXU.venc[enc] = true; RDX.Encounter.SaveOn();
		RDX.SetVirtualEncounter(enc);
		RDX.SaveVirtualEncounter();
	end
end
function RDX.Encounter.SaveOn()
	RDXEncPane.btnSave:LockHighlight();
end
function RDX.Encounter.SaveOff()
	RDXEncPane.btnSave:UnlockHighlight();
end

----------------- VIRTUALIZATION
-- Load a virtual encounter
RDX.cve = nil;
function RDX.LoadVirtualEncounter(enc)
	if not edb[enc] then return; end
	-- Don't load if already loaded
	if(enc == RDX.cve) then return; end
	VFL.debug("RDX.LoadVirtualEncounter("..enc..")", 1);
	RDX.cve = enc;
	-- Instruct modules to load the encounter
	RDX.Modules.Command("LoadEncounter", enc);
end

-- Instruct all modules to save settings to the current virtual encounter
function RDX.SaveVirtualEncounter()
	RDX.Modules.Command("SaveCurrentEncounter");
end

-- Set the virtual encounter directly
function RDX.SetVirtualEncounter(enc)
	if not edb[enc] then return; end
	RDX.cve = enc;
end

-- Get the current virtual encounter
function RDX.GetVirtualEncounter()
	if RDX.cve then return RDX.cve; else return "default"; end
end

-- Activate an encounter
function RDX.SetActiveEncounter(en, nosync)
	VFL.debug("RDX.SetActiveEncounter(".. en .. ")", 1);
	if not edb[en] then 
		VFL.debug("RDX.SetActiveEncounter failed", 2);
		return false; 
	end
	-- Reset encounter-timers
	RDX.StopEncounter(nosync);
	RDX.encTimer:Reset();
	-- Update current encounter data
	local olden = nil;
	if RDX.ce then olden = RDX.ce.name; end
	RDX.ce = VFL.copy(edb[en]);
	-- Update encoutner pane
	RDX.SetEncounterPaneText(RDX.ce.title);
	-- Now command all modules to change encoutners
	RDX.Modules.Command("SetActiveEncounter", en, olden);
	if(RDXU.venc[en]) then
		RDX.LoadVirtualEncounter(en); RDX.Encounter.SaveOn();
	else
		RDX.LoadVirtualEncounter("default"); RDX.Encounter.SaveOff();
	end
	-- Save the pref
	RDXU.active_encounter = en;
	-- If we're supposed to sync, do it
	if (not nosync) then RDX.Encounter.Sync(); end
	return true;
end

function RDX.GenerateSetActiveEncounterFunction(module, enctbl)
	return function(self, enc, oldenc)
		-- Deactivate old encounter
		local et = nil;
		if oldenc then et = enctbl[oldenc]; end
		if et then et.DeactivateEncounter(); end
		-- Clear module routines
		module.StartEncounter = nil; module.StopEncounter = nil;
		-- Activate new encounter
		et = enctbl[enc];
		if et then
			module.StartEncounter = et.StartEncounter;
			module.StopEncounter = et.StopEncounter;
			if(et.ActivateEncounter) then et.ActivateEncounter(); end
		end
	end;
end

-------- Encounter timer
RDX.encTimer = VFL.CountUpTimer:new();
function RDX.ToggleEncounterTimer()
	if not RDX.encTimer:IsRunning() and IsShiftKeyDown() then 
		RDX.encTimer:Reset(); 
		return;
	end;
	if RDX.encTimer:IsRunning() then
		RDX.StopEncounter();
	else
		RDX.StartEncounter();
	end;
end;

--RDX.ToggleEncounterTimer = function() if not RDX.encTimer:IsRunning() and IsShiftKeyDown() then RDX.encTimer:Reset(); return; end; if RDX.encTimer:IsRunning() then RDX.StopEncounter(); else RDX.StartEncounter(); end; end

-- Return true iff the encounter is running
function RDX.EncounterIsRunning()
	return RDX.encTimer:IsRunning();
end

function RDX.GetEncounterRunningTime()
	return RDX.encTimer:Get();
end

-- Start encounter timer
function RDX.StartEncounter(nosync)
	-- Abort if not initialized or already running
	if (not RDXEncPane.titleFrame) or (RDX.encTimer:IsRunning()) then return; end
	-- Synchronize encounter start
	if (not nosync) and (not RDXU.noesync) then
		RDX.EnqueueMessage(RDX.proto_estart, RDX.GetActiveEncounter());
	end
	-- Start encounter timer
	RDXEncPane.btnStartStop:SetStop();
	RDX.encTimer:Reset();
	RDX.encTimer:Start();
	-- Inform all modules that the encounter has started.
	RDX.Modules.Command("StartEncounter");
end
function RDX.Encounter.StartMessage(proto, sender, data)
	VFL.debug("RDX.Encounter.StartMessage(): received start for " .. data, 5);
	-- If we're not syncing or the encounter doesn't line up, abort.
	if(RDXU.noesync) or (not sender:IsLeader()) or (data ~= RDX.GetActiveEncounter()) then return; end
	-- Start the encounter
	RDX.StartEncounter(true); -- prevent sync
end

-- Stop encounter timer
function RDX.StopEncounter(nosync)
	if(RDXEncPane.titleFrame) then -- BUGFIX, don't mess with encframe unless imbued
		RDXEncPane.btnStartStop:SetPlay();
	end
	-- Synchronize encounter stop
	if (not nosync) and (not RDXU.noesync) then
		RDX.EnqueueMessage(RDX.proto_estop, RDX.GetActiveEncounter());
	end
	-- Stop the encounter if it was started.
	if(RDX.encTimer:IsRunning()) then
		RDX.encTimer:Stop();
		RDX.Modules.Command("StopEncounter");
	end
end
function RDX.Encounter.StopMessage(proto, sender, data)
	VFL.debug("RDX.Encounter.StopMessage(): recieved stop for " .. data, 5);
	-- If we're not syncing or the encounter doesn't line up, abort.
	if(RDXU.noesync) or (not sender:IsLeader()) or (data ~= RDX.GetActiveEncounter()) then return; end
	-- Stop the encounter
	VFL.debug("Stopping encounter by request of " .. sender.name, 5);
	RDX.StopEncounter(true); -- prevent sync
end

-- Encounter autostart based on boss tracking entry
function RDX.AutoStartEncounter(trk)
	if not trk then return; end
	if not RDX.EncounterIsRunning() then
		if trk:IsTracking() and trk.targetIsRaider then
			RDX.StartEncounter();
		end
	end
end

-- Encounter auto start/stop based on boss tracking entry
function RDX.AutoStartStopEncounter(trk)
	if (not trk) or (not trk:IsTracking()) then return; end
	if RDX.EncounterIsRunning() then
		if UnitIsDead(trk.unit) then
			RDX.StopEncounter();
		end
	else
		if trk.targetIsRaider then RDX.StartEncounter(); end
	end
end

----------------------------------
-- ENCOUNTER SYNC
----------------------------------
-- Core syncbutton handler
function RDX.Encounter.SyncButtonOnClick()
	-- Right button = RDX sync
	if(arg1 == "RightButton") then 
		RDX.Encounter.ToggleSync();
	-- Left button = encounter sync
	elseif(arg1 == "LeftButton") then
		RDX.Encounter.Sync();
	end
end
-- Synchronization status
-- By default, your encounter autosyncs to raid lead/assistant broadcasts.
-- Can be toggled.
function RDX.Encounter.ToggleSync()
	if RDXU.noesync then
		RDX.Encounter.SyncOn();
	else
		RDX.Encounter.SyncOff();
	end
end
function RDX.Encounter.SyncOn()
	RDXU.noesync = nil;
	RDXEncPane.btnSync:LockHighlight();
end
function RDX.Encounter.SyncOff()
	RDXU.noesync = true;
	RDXEncPane.btnSync:UnlockHighlight();
end

-- Send encounter sync message
function RDX.Encounter.Sync()
	VFL.debug("RDX.Encounter.Sync()", 5);
	if RDXU.noesync then return; end
	-- TODO: Check if player is leader
	RDX.EnqueueMessage(RDX.proto_esync, RDX.GetActiveEncounter());
end

-- Handle encounter synchronization message
function RDX.Encounter.SyncMessage(proto, sender, enc)
	VFL.debug("RDX.Encounter.SyncMessage(): recieved sync message from "..sender.name..": " .. enc, 5);
	-- If encounter sync isn't enabled, forget about it
	if (RDXU.noesync) or (not sender:IsLeader()) then return; end
	-- Verify that it's a different encounter and that it exists...
	if(enc ~= RDX.GetActiveEncounter()) and (edb[enc]) then
		VFL.debug("Changing Encounter on request of " .. sender.name, 5);
		RDX.SetActiveEncounter(enc, true); -- Don't rebroadcast sync
	end
end

---------- Encounter sync protocols
RDX.proto_esync = RDX.RegisterProtocol({
	name = "Encounter Synchronization";
	id = 3; replace = false; highPrio = false; realtime = true;
	handler = RDX.Encounter.SyncMessage;
});
RDX.proto_estart = RDX.RegisterProtocol({
	name = "Encounter Start";
	id = 4; replace = false; highPrio = false; realtime = true;
	handler = RDX.Encounter.StartMessage;
});
RDX.proto_estop = RDX.RegisterProtocol({
	name = "Encounter Stop";
	id = 5; replace = false; highPrio = false; realtime = true;
	handler = RDX.Encounter.StopMessage;
});



--------------------------------
-- BOSSMOB MANAGEMENT
--------------------------------
-- Announce status
function RDX.Encounter.ToggleAnnounce()
	if RDXU.spam then
		RDX.Encounter.AnnounceOff();
	else
		RDX.Encounter.AnnounceOn();
	end
end
function RDX.Encounter.AnnounceOn()
	RDXU.spam = true;
	RDXEncPane.btnAnnounce:LockHighlight();
end
function RDX.Encounter.AnnounceOff()
	RDXU.spam = nil;
	RDXEncPane.btnAnnounce:UnlockHighlight();
end
function RDX.Encounter.AnnounceButtonOnClick()
	-- Right button = ?
	if(arg1 == "RightButton") then 
	-- Left button = toggle announce
	elseif(arg1 == "LeftButton") then
		RDX.Encounter.ToggleAnnounce();
	end
end

--------------------------------
-- TIMER WIDGET
--------------------------------
if not RDX.TimerWidget then RDX.TimerWidget = {}; end

-- Set a color-animation
function RDX.TimerWidget:ColorAnim(c1, c2, period)
	if c1 then
		self.anim = true; self.c1 = c1; self.c2 = c2; self.period = period;
	else
		self.t1:SetTextColor(1,1,1); self.t2:SetTextColor(1,1,1);
		self.anim = false;
	end
end

-- Set the time displayed on a timer widget, in seconds
function RDX.TimerWidget:SetTime(sec)
	if(sec < 0) then sec = 0; end
	local s = math.floor(sec); local frac = (sec - s)*100;
	local m = math.floor(sec/60); sec = math.mod(sec, 60);
	self.t1:SetText(string.format("%d:%02d", m, sec));
	self.t2:SetText(string.format("%02d", frac));
end

-- Imbue a frame with timer widget properties
function RDX.TimerWidget.Imbue(self)
	-- Map text controls
	self.t1 = getglobal(self:GetName() .. "T1");
	self.t2 = getglobal(self:GetName() .. "T2");
	-- Map functionality
	self.SetTime = RDX.TimerWidget.SetTime;
	self.ColorAnim = RDX.TimerWidget.ColorAnim;
	self.t1:SetHeight(20); self.t1:SetWidth(60);
	self.t1:SetFont(VFL.GetThinFontFile(), 20);
	self.t2:SetHeight(12); self.t2:SetWidth(20);
  self.t2:SetFont(VFL.GetThinFontFile(), 12);
	self.t2:ClearAllPoints();
	self.t2:SetPoint("BOTTOMLEFT", self.t1, "BOTTOMRIGHT", -1, 2);
end

----------------------------------
-- ENCOUNTER PANE
----------------------------------
if not RDX.EncounterPane then RDX.EncounterPane = {}; end
-- Setup encounter pane
function RDX.EncounterPane.Imbue(self)

	-- The titlebar of the encounter pane is actually a UnitFrame...
	self.titleFrame = RDX.UnitFramePool:Acquire();
	self.titleFrame:SetPurpose(6);
	self.titleFrame:SetParent(RDXEncPane);
	self.titleFrame:SetPoint("TOPLEFT", RDXEncPane, "TOPLEFT", 5, -5);
	self.titleFrame:SetSize(RDXEncPane:GetWidth()-10, 18);
	self.titleFrame:SetFontSize(12);
	getglobal(self.titleFrame:GetName().."BtnHlt"):Hide();
	self.titleFrame:SetFrameLevel(3); RDXEncPane:SetFrameLevel(1); 
	self.titleFrame:Show();
	-- Acquire buttons
	self.btnStartStop = getglobal(self:GetName() .. "StartStop");
	self.btnSync = getglobal(self:GetName() .. "Sync");
	self.btnAnnounce = getglobal(self:GetName() .. "Announce");
	self.btnSave = getglobal(self:GetName() .. "Save");
	self.btnRaid = getglobal(self:GetName() .. "Raid");
	-- Bind functionality
	self.titleFrame.MouseDown = RDX.EncounterPane.MouseDown;
	self.titleFrame.MouseUp = RDX.EncounterPane.MouseUp;
end

function RDX.SetEncounterPaneText(txt)
	RDX.SetStatusBar(RDXEncPane.titleFrame.bar1, 1, {r=0,g=0,b=1});
	RDXEncPane.titleFrame.text1:SetText(txt);
	RDXEncPane.titleFrame.text2:SetText(nil);
end

function RDX.SetEncounterPaneDisplay(txt1, txt2, pct, color, fadeColor)
	RDX.SetStatusBar(RDXEncPane.titleFrame.bar1, pct, color, fadeColor);
	RDXEncPane.titleFrame.text1:SetText(txt1);
	RDXEncPane.titleFrame.text2:SetText(txt2);
end

-- Set the encounter pane from a tracking entry
function RDX.AutoUpdateEncounterPane(trk, lockText)
	if not trk then return; end
	local color, fadeColor = RDXG.vis.cEnemyHP, RDXG.vis.cEnemyHPFade;
	if not trk:IsTracking() then
		color = RDXG.vis.cStaleData; fadeColor = RDXG.vis.cStaleData;
	end
	local pct = 1;
	if trk.healthMax > 0 then pct = trk.health / trk.healthMax; end
	RDX.SetStatusBar(RDXEncPane.titleFrame.bar1, pct, color, fadeColor);
	if not lockText then
		RDXEncPane.titleFrame.text1:SetText(trk.name);
	end
	RDXEncPane.titleFrame.text2:SetText(string.format("%0.0f%%", pct*100));
end

-- Mouse handlers for encounter pane
function RDX.EncounterPane:MouseDown(arg1)
	if(arg1 == "LeftButton") and IsShiftKeyDown() then
		self.mv = true; RDXEncPane:StartMoving(); return;
	end
end
function RDX.EncounterPane:MouseUp(arg1)
	if(arg1 == "LeftButton") then
		if(self.mv) then 
			RDXEncPane:StopMovingOrSizing();
			RDXEncPane:SetFrameLevel(1);
			self.mv = nil; 
			return; 
		end
	else
		RDX.EncounterPane.ShowEncounterMenu(VFL.poptree);
	end
end

-- Show the dropdown encounter menu
function RDX.EncounterPane.ShowEncounterMenu(menu)
	-- Convert each encounter
	local stbl = {};
	for _,v in edb do
		if(v.name ~= "default") then
			stbl[v.category] = true;
		end
	end
	local stbl2 = {};
	for k,_ in stbl do
		table.insert(stbl2, k);
	end
	stbl = nil;
	table.sort(stbl2);
	
	-- Now build the menu
	local mnu = {};
	table.insert(mnu, {
		text = "Default",
		OnClick = function() RDX.SetActiveEncounter("default"); menu:Release(); end
	});
	for _,v in stbl2 do
		local catName = v;
		table.insert(mnu, {
			text = v;
			color = {r=0.2, g=0.9, b=0.9};
			isSubmenu = true;
			OnClick = function() RDX.EncounterPane.ShowEncountersInCategory(menu, this, catName); end;
		});
	end
	stbl2 = nil;

	-- Show the menu
	menu:Begin(RDXEncPane.titleFrame:GetWidth(), RDXEncPane.titleFrame:GetHeight(), RDXEncPane.titleFrame, "BOTTOMLEFT");
	menu:Expand(nil, mnu);
end

function RDX.EncounterPane.ShowEncountersInCategory(menu, cell, category)
	-- Bunch encounters
	local stbl = {};
	for _,v in edb do
		if v.category == category then
			table.insert(stbl, v);
		end
	end
	-- Sort encounters
	table.sort(stbl, function(x1,x2)
		if x1.sort and x2.sort then
			return (x1.sort < x2.sort);
		else
			return (x1.name < x2.name);
		end
	end);
	-- Make menu
	local mnu = {};
	for _,v in stbl do
		local ename = v.name;
		table.insert(mnu, {
			text = v.title;
			OnClick = function() RDX.SetActiveEncounter(ename); menu:Release(); end
		});
	end
	menu:Expand(cell, mnu);
end


---------------------------------------
-- INIT
---------------------------------------
function RDX.Encounter.Init()
	VFL.debug("RDX.Encounter.Init()", 2);

	-- Imbue the encounter pane
	RDX.EncounterPane.Imbue(RDXEncPane);

	-- Create the unit encounter virtualization table if it doesn't exist
	if not RDXU.venc then RDXU.venc = {}; end

	-- Select the proper encounter
	if(RDXU.active_encounter) then
		RDX.SetActiveEncounter(RDXU.active_encounter, true);
	else
		RDX.SetActiveEncounter("default", true);
	end

	-- Restore sync setting
	if(RDXU.noesync) then RDX.Encounter.SyncOff(); else RDX.Encounter.SyncOn(); end
	-- Restore announce setting
	if(RDXU.spam) then RDX.Encounter.AnnounceOn(); else RDX.Encounter.AnnounceOff(); end
end



--------------------------------------
-- BUILTIN ENCOUNTERS
---------------------------------------
-- The default encounter.
RDX.RegisterEncounter({
	name = "default";
	title = "Default";
});


