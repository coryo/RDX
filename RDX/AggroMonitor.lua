---------------------------------------
-- Aggro Monitor
-- Displays a warning when you get aggro on a raid.
-- This mod monitors the targettarget of the raid, and if that's you
-- and their target is hostile, it displays a centerpopup warning.
-- It will only display one warning per 10 seconds.
---------------------------------------


if not RDX.AggroMonitor then RDX.AggroMonitor = {}; end

local aggroWarningLock = false;

function RDX.AggroMonitor.Start()
	aggroWarningLock = false;
	RDX.AggroMonitor.HeartBeat() --start heartbeat
end

function RDX.AggroMonitor.Toggle()
	if RDX5Data.AggroMonitorEnabled == true then
		VFL.print("[RDX] Aggro Monitor: Off")
		RDX5Data.AggroMonitorEnabled = false;
		RDX.AggroMonitor.Stop();
	else
		VFL.print("[RDX] Aggro Monitor: On")
		RDX5Data.AggroMonitorEnabled = true;
		RDX.AggroMonitor.Start();
	end
end

function RDX.AggroMonitor.HeartBeat()
	
	if aggroWarningLock == false then
		if UnitInRaid("player") then --only check aggro if we're in a raid
			RDX.AggroMonitor.CheckForAggro()
		end
	end
	--VFL.schedule(RDXG.perf.uiWindowUpdateDelay, RDX.AggroMonitor.Heartbeat); --currently .25 sec heartbeat
	VFL.scheduleExclusive("aggro_monitor_heartbeat", .25, function() RDX.AggroMonitor.HeartBeat(); end); --currently .25 sec heartbeat
	
end

function RDX.AggroMonitor.CheckForAggro()
	--VFL.print("Checking For Aggro....")
	--loop through the raid
	for i=1,40 do
		if RDX.unit[i].valid then
			--for each valid raid member, check their target's target
			--we know we have aggro when thta is ourself
			local thistt = UnitName(RDX.unit[i].uid .. "targettarget") 
			if thistt then
				-- ok they have a targettarget.  is that us?
				if thistt == UnitName("player") then
					--Yikes!  yes it is!
					-- if this unit is not friendly then we have aggro
					if not UnitIsFriend("player", RDX.unit[i].uid .. "target") then
						--ok we have aggro.  lets display an alert, and set a lockout
						RDX.AggroMonitor.AggroWarn(i)
						--stop looping
						return;
					end
				end
			end
		end
	end
	
end

function RDX.AggroMonitor.AggroWarn(unitIndex)
						
	aggroWarningLock = true;
	VFL.scheduleExclusive("aggro_monitor_lockout", 10, function() aggroWarningLock = false; end);
	
	local alert = RDX.GetAlert();
	alert:SetText(" AGGRO: " .. UnitName(RDX.unit[unitIndex].uid .. "target")); 
	alert:ToCenter(); 
	alert:Show(); 
	alert.tw:Hide();
	alert:SetColor({r=1, g=.1, b=.1},nil)
	alert:SetAlpha(0.5);
	alert.statusBar:SetValue(1,1);
	PlaySoundFile("Sound\\Spells\\PVPFlagTakenHorde.wav");
	alert:Schedule(3, function() alert:Fade(2,0); end);
	alert:Schedule(6, function() alert:Destroy(); end);
end

function RDX.AggroMonitor.Stop()
	VFL.removeScheduledEventByName("aggro_monitor_heartbeat");
	VFL.removeScheduledEventByName("aggro_monitor_lockout");
end



function RDX.AggroMonitor.Init()
	if RDX5Data.AggroMonitorEnabled == true then RDX.AggroMonitor.Start(); end
	if RDX5Data.ClickOffSalvEnabled == true then 
		RDX.AggroMonitor.RegisterForSalvCheck() 
		RDX.AggroMonitor.RemoveSalv()
	end
end



--
--  THIS CODE IS FOR AUTO Click-Off  Salvation feature
--

function RDX.AggroMonitor.ToggleClickOffSalv()
	if RDX5Data.ClickOffSalvEnabled then
		--disable salv
		RDX5Data.ClickOffSalvEnabled = false;
		RDX.AggroMonitor.UnRegisterForSalvCheck()
		VFL.print("[RDX] Auto-Remove Salvation has been disabled.");
	else
		--enable salv
		RDX5Data.ClickOffSalvEnabled = true;
		RDX.AggroMonitor.RegisterForSalvCheck()
		VFL.print("[RDX] Auto-Remove Salvation has been enabled.");
		--in case they currently have salv...
		RDX.AggroMonitor.RemoveSalv()
	end
end

function RDX.AggroMonitor.RegisterForSalvCheck()
	VFLEvent:NamedBind("clickoffsalv", BlizzEvent("CHAT_MSG_SPELL_PERIODIC_SELF_BUFFS"), function() RDX.AggroMonitor.RemoveSalvCheck(arg1); end);
end

function RDX.AggroMonitor.RemoveSalvCheck(arg1)
	if string.find(arg1, "Blessing of Salvation") then
		VFL.schedule(.1, function() RDX.AggroMonitor.RemoveSalv(); end);
	end
end

function RDX.AggroMonitor.RemoveSalv()
	--remove the buff
	for cnt=1,16 do
		if not GetPlayerBuffTexture(cnt) then return; end
		local buffTex = GetPlayerBuffTexture(cnt);	
	
		if string.find(buffTex, "Salvation") then
			CancelPlayerBuff(cnt);
			VFL.print("[RDX] Salvation has been Auto-Removed");
		end
	end
end

function RDX.AggroMonitor.UnRegisterForSalvCheck()
	VFLEvent:NamedUnbind("clickoffsalv");
end


 

function mytest()
	local loaded,reason = LoadAddOn("RDXM_ThreatMeter")
	 if (not loaded) then
	  VFL.print("Could not load the Threat Meter module: " .. reason);
	 else
		--VFL.print("load mod");
	 end
end
