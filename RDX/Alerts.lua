-- Alerts.lua
-- RDX - Raid Data Exchange
-- (C)2005 Bill Johnson - Venificus of Eredar server
--
-- The alert system for RDX5.
--
-- An alert is a UI frame with an associated timetable. Animations, sounds,
-- and other events are executed based on this timetable.
--
-- There are two "stacks" of alerts onscreen, one stack in the center and one
-- at the top. Alerts can migrate between the two stacks.

---------------------------------------
-- ALERT OBJECT
---------------------------------------
if not RDX.Alert then RDX.Alert = {}; end

-- Imbue a frame with the properties of an alert
function RDX.Alert.Imbue(self)
	---- CONTROLS
	local n = self:GetName();
	self.txt = getglobal(n.."FGTxt");
	self.tw = getglobal(n.."FGTW");
	self.statusBar = getglobal(n.."BkdSB");
	----- DATA
	-- The alert's timeline.
	self.timeline = {};
	-- The alert's animation function
	self.animFunc = nil; self.dataFunc = nil;
	----- FUNCTIONALITY
	self.Destroy = RDX.Alert.Destroy;
	self.SetText = RDX.Alert.SetText;
	self.SetColor = RDX.Alert.SetColor;
	self.Anchor = RDX.Alert.Anchor;
	self.Schedule = RDX.Alert.Schedule;
	self.Move = RDX.Alert.Move; self.Fade = RDX.Alert.Fade;
	self.Countdown = RDX.Alert.Countdown;
	self.OnUpdate = RDX.Alert.OnUpdate;
	------- STACK FUNCTIONALITY
	self.RemoveFromStacks = RDX.Alert.RemoveFromStacks;
	self.ToTop = RDX.Alert.ToTop;
	self.ToCenter = RDX.Alert.ToCenter;
end

-- Destroy alert completely
function RDX.Alert:Destroy()
	-- Remove from data structures
	self:RemoveFromStacks(); RDX.RemoveAlert(self);
	self:SetScale(1);
	RDX.alertPool:Release(self);
end

-- Alert master update function
function RDX.Alert:OnUpdate()
	local t = GetTime();
	-- Update the control's data
	if(self.dataFunc) then self:dataFunc(t); end
	-- If there's an animation in process, do it
	if(self.animFunc) then self:animFunc(t); end
	-- Run any scheduled events
	while(self.timeline[1] and self.timeline[1].t <= t) do
		local se = table.remove(self.timeline, 1);
		se.func(self);
	end
end

-- Set this alert's text
function RDX.Alert:SetText(str)
	self.txt:Setup(str);
end

-- Set this alert's color(s)
function RDX.Alert:SetColor(c1, c2)
	if c1 then
		self.color1 = c1; self.statusBar:SetStatusBarColor(c1.r,c1.g,c1.b);
	end
	if c2 then self.color2 = c2; end
end

-- Anchor this alert (stops any pending animation)
function RDX.Alert:Anchor(...)
	if(self.moving) then self.animFunc = nil; end
	self:ClearAllPoints();
	self:SetPoint(unpack(arg));
end

-- Schedule something on this alert's timeline
function RDX.Alert:Schedule(dt, func, ...)
	local se = {
		t = GetTime() + dt;
		func = func;
	};
	table.insert(self.timeline, se);
	table.sort(self.timeline, function(se1,se2) return se1.t < se2.t; end);
end

-- Animate a motion for this alert
function RDX.Alert:Move(dt, tox, toy, froma, toa)
	local fx,fy,t0 = self:GetLeft(), self:GetTop(), GetTime();
	self.moving = true;
	self.animFunc = RDX.Alert.GenMoveFunc(self, fx, fy, tox, toy, froma, toa, t0, dt);
	self:Schedule(dt, function() self.animFunc = nil; self.moving = nil; end);
end

-- Animate a fade for this alert
function RDX.Alert:Fade(dt, toa)
	self.animFunc = RDX.Alert.GenFadeFunc(self:GetAlpha(), toa, GetTime(), dt);
	self:Schedule(dt, function() self.animFunc = nil; end);
end

-- Remove this alert from all stacks
function RDX.Alert:RemoveFromStacks()
	RDX.RemoveAlertFromStack(self, RDX.topAlertStack);
	RDX.RemoveAlertFromStack(self, RDX.centerAlertStack);
end

-- Move this alert among alert stacks, either with or without animations
function RDX.Alert:ToTop(animTime, animFade)
	self:RemoveFromStacks();
	if not animTime then
		table.insert(RDX.topAlertStack, self);
		RDX.LayoutAlertStack(RDX.topAlertStack, RDXTopStackAnchor);
	else
		local x,y = RDXTopStackAnchor:GetLeft(), RDXTopStackAnchor:GetBottom();
		if not animFade then animFade = 1; end
		self:Move(animTime, x, y, self:GetAlpha(), animFade);
		self:Schedule(animTime, function() self:ToTop(); end);
	end
end
function RDX.Alert:ToCenter(animTime, animFade)
	self:RemoveFromStacks();
	if not animTime then
		table.insert(RDX.centerAlertStack, self);
		RDX.LayoutAlertStack(RDX.centerAlertStack, RDXCenterStackAnchor);
	else
		local x,y = RDXCenterStackAnchor:GetLeft(), RDXCenterStackAnchor:GetBottom();
		if not animFade then animFade = 1; end
		self:Move(animTime, x, y, self:GetAlpha(), animFade);
		self:Schedule(animTime, function() self:ToCenter(); end);
	end
end

-- Animate a countdown for this alert
function RDX.Alert:Countdown(dt, flash)
	local endt = GetTime() + dt;
	self.GetCountdown = function() return endt - GetTime(); end
	if flash then
		self.dataFunc = RDX.Alert.GenFlashCountdownFunc(dt, endt, flash);
	else
		self.dataFunc = RDX.Alert.GenCountdownFunc(dt, endt);
	end
	self:Schedule(endt, function() self.dataFunc = nil; self.GetCountdown = nil; end);
end

------------------------------------
-- ALERT ANIMATIONS
------------------------------------
-- Generates an animator that moves the given frame through the given position/alpha arc
function RDX.Alert.GenMoveFunc(frame, fromx, fromy, tox, toy, froma, toa, t0, dt)
	VFL.debug("RDX.Alert.GenMoveFunc from ("..fromx..","..fromy..") to ("..tox..","..toy..") over "..dt, 8);
	return function(self, t)
		local f = (t-t0)/dt;
		if(f<0) or (f>1) then return; end
	 	local fp = 1-f;
		local x,y,a = fromx+((tox-fromx)*f),fromy+((toy-fromy)*f),froma+((toa-froma)*f);
		frame:ClearAllPoints(); frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y);
		frame:SetAlpha(a);
	end
end

-- Generates an animator that fades the frame.
function RDX.Alert.GenFadeFunc(froma, toa, t0, dt)
	return function(self, t)
		local f = (t-t0)/dt;
		if(f<0) or (f>1) then return; end
		self:SetAlpha(froma+((toa-froma)*f));
	end
end

-- Generates a countdown function that fills the data
function RDX.Alert.GenCountdownFunc(dt, endt)
	return function(self, t)
		local q = endt - t;
		self.tw:SetTime(q);
		if(q < 0) then return; end
		local f = 1 - (q/dt);
		self.statusBar:SetValue(f);
	end
end

-- Generates a countdown function with flashes.
function RDX.Alert.GenFlashCountdownFunc(dt, endt, dtFlash)
	return function(self, t)
		local q = endt - t;
		self.tw:SetTime(q);
		if(q < 0) then return; end
		local f = 1 - (q/dt);
		self.statusBar:SetValue(f);
		if(q < dtFlash) then
			tempcolor:blend(self.color1, self.color2, 0.5*(math.cos(q*12) + 1));
			self.statusBar:SetStatusBarColor(tempcolor.r, tempcolor.g, tempcolor.b);
		end
	end
end

---------------------------------------
-- ALERT STACKS
---------------------------------------
-- The top alert stack
RDX.topAlertStack = {};
-- The center alert stack
RDX.centerAlertStack = {};

-- Sort: highest countdowns first
function RDX.StackSortFunc(se1, se2)
	local v1,v2 = 10000,10000;
	if(se1.GetCountdown) then v1 = se1.GetCountdown(); end
	if(se2.GetCountdown) then v2 = se2.GetCountdown(); end
	return(v1>v2);
end

-- Layout an alert stack, starting with the highest countdown alert
function RDX.LayoutAlertStack(st, af)
	table.sort(st, RDX.StackSortFunc);
	for _,alert in ipairs(st) do
		alert:Anchor("TOPLEFT", af,"BOTTOMLEFT");
		af = alert;
	end
end

-- Get the coordinates of the bottom of a stack
function RDX.GetAlertStackBottom(st, af)
	local bottomFrame = st[table.getn(st)];
	if bottomFrame then
		return bottomFrame:GetLeft(), bottomFrame:GetBottom();
	else
		return af:GetLeft(), af:GetBottom();
	end
end

-- Remove an alert from an alert stack
function RDX.RemoveAlertFromStack(alert, st)
	local targ = nil;
	for i=1,table.getn(st) do
		if st[i] == alert then targ = i; break; end
	end
	if(targ) then table.remove(st, targ); end
end

----------------------------------------
-- ALERT UTILITIES
----------------------------------------
-- Extant alerts
RDX.alerts = {};

-- Remove an alert from the extant alerts table
function RDX.RemoveAlert(al)
	local targ = nil;
	for i=1,table.getn(RDX.alerts) do
		if RDX.alerts[i] == al then targ = i; break; end
	end
	if(targ) then table.remove(RDX.alerts, targ); end
end

-- Get an alert
function RDX.GetAlert()
	local alert = RDX.alertPool:Acquire();
	table.insert(RDX.alerts, alert);
	return alert;
end

-- Quash all alerts matching the given pattern
function RDX.QuashAlertsByPattern(ptn)
	local cont = true;
	while cont do
		cont = false;
		for _,alert in RDX.alerts do
			if(alert.name) and string.find(alert.name, ptn) then
				alert:Destroy(); cont = true; break;
			end
		end
	end
end

-- Spam alerts to raidchat if necessary
function RDX.Alert.Spam(txt)
	if RDXU.spam then
		if (IsRaidLeader()) then
			SendChatMessage(txt, "RAID_WARNING");
		end
	end
end

-- Dropdown countdown alert.
-- This alert counts down a timer at the top of the screen.
-- When a "Lead Time" is achieved, it drops to the center, announces a message, and
-- plays a sound effect.
-- When it expires, it fades off the screen.
function RDX.Alert.Dropdown(id, text, totalTime, leadTime, sound, c1, c2, supressSpam)
	local ldt = totalTime - leadTime;
	local alert = RDX.GetAlert();
	alert.name = id;
	alert:SetColor(c1,c2);
	alert:SetText(text); alert:Countdown(totalTime, leadTime);
	alert:ToTop(); alert:SetAlpha(.60); alert:Show();
	alert:Schedule(totalTime-leadTime, function()
		alert:ToCenter(.3);
		if(sound) then PlaySoundFile(sound); end
		if supressSpam ~= true then RDX.Alert.Spam("*** ".. text.." - "..leadTime.." SEC! ***"); end
	end);
	alert:Schedule(totalTime, function() alert:Fade(2,0); end);
	alert:Schedule(totalTime+3, function() alert:Destroy(); end);
	return alert;
end

-- Center popup countdown alert
-- This alert plays a sound right away, then displays a (short) countdown midscreen.
function RDX.Alert.CenterPopup(id, text, time, sound, flash, c1, c2, supressSpam)
	local alert = RDX.GetAlert();
	alert.name = id; alert:SetColor(c1,c2);
	alert:SetText(text); alert:Countdown(time, flash);
	alert:ToCenter(); alert:Show(); alert:SetAlpha(0.6);
	if(sound) then PlaySoundFile(sound); end
	if supressSpam ~= true then RDX.Alert.Spam("*** " .. text .. " - " .. time .. " SEC! ***"); end
	alert:Schedule(time, function() alert:Fade(2,0); end);
	alert:Schedule(time+3, function() alert:Destroy(); end);
	return alert;
end

-- Center popup, simple text
function RDX.Alert.Simple(text, sound, persist, suppressSpam)
	local alert = RDX.GetAlert();
	alert:SetText(text); alert:ToCenter(); alert:Show(); alert.tw:Hide();
	alert:SetAlpha(0.5);
	if(sound) then PlaySoundFile(sound); end
	if not suppressSpam then RDX.Alert.Spam("*** " .. text .. " ***"); end
	alert:Schedule(persist, function() alert:Fade(2,0); end);
	alert:Schedule(persist+3, function() alert:Destroy(); end);
end

----------------------------------------
-- ALERT FRAMEPOOL
----------------------------------------
function RDX.Alert.Init()
	VFL.debug("RDX.Alert.Init()", 2);
	RDX.alertPool = VFL.Pool:new();
	RDX.alertPool.OnRelease = function(pool, f)
		f.name = nil; f.tw:Show();
		f:Hide(); f.dataFunc = nil; f.animFunc = nil; f.timeline = {};
		f:SetColor({r=1,g=1,b=1},{r=1,g=0,b=0});
		f:SetAlpha(1); f.statusBar:SetValue(0);
	end
	RDX.alertPool:Fill("RDXAlert");
end

