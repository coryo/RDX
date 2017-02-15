-- ImpliedTarget.lua
-- RDX5 - Raid Data Exchange
--
-- Provides EQ2 style implied targetting on demand
-- Explanation: If you cannot cast a particular spell
-- on your target, it will cast it on your target's
-- target. This way you can have the main assist targeted
-- and your spells will automatically target their target
-- without losing your target. Healers can do the same
-- by targetting a mob and casting heal. Additionally, 
-- melee can assist a player by attacking them.
-- 

VFL.debug("[RDX5] Loading ImpliedTarget.lua", 2);

if not RDX.ImpliedTarget then RDX.ImpliedTarget = {}; end

local oldUseAction;

-- Do stuff after variables have loaded
function RDX.ImpliedTarget.Init()
	VFL.debug("RDX.ImpliedTarget.Init()", 2);
	-- Store for safekeeping
	oldUseAction = UseAction
	
	if not RDX5Data.ImpliedTarget then RDX5Data.ImpliedTarget = 0; end
	
	if RDX5Data.ImpliedTarget == 1 then
		if UnitClass("player") == "Warrior" 
		 or UnitClass("player") == "Hunter"
		 or UnitClass("player") == "Rogue" then
			RDX.ImpliedTarget.MeleeAndHunterOn()
		else
			RDX.ImpliedTarget.StandardOn()
		end
	else
		RDX.ImpliedTarget.Off()
	end
end

function RDX.ImpliedTarget.Toggle()
	if RDX5Data.ImpliedTarget == 1 then
		RDX.ImpliedTarget.Off()
		VFL.print("[RDX] Implied Targetting Off")
	elseif RDX5Data.ImpliedTarget == 0 then
		if UnitClass("player") == "Warrior" 
		 or UnitClass("player") == "Hunter"
		 or UnitClass("player") == "Rogue" then
			RDX.ImpliedTarget.MeleeAndHunterOn()
		else
			RDX.ImpliedTarget.StandardOn()
		end
	
		VFL.print("[RDX] Implied Targetting for "..UnitClass("player").."s On")
	end
end

function RDX.ImpliedTarget.StandardOn()
	-- Hook
	UseAction = RDX.ImpliedTarget.UseActionStandardMode
	-- Set variable
	RDX5Data.ImpliedTarget = 1
end

function RDX.ImpliedTarget.MeleeAndHunterOn()
	-- Hook
	UseAction = RDX.ImpliedTarget.UseActionMeleeAndHunterMode
	-- Set variable
	RDX5Data.ImpliedTarget = 1
end

function RDX.ImpliedTarget.Off()
	-- Unhook
	UseAction = oldUseAction
	-- Set variable
	RDX5Data.ImpliedTarget = 0
end

function RDX.ImpliedTarget.UseActionStandardMode(slot, x, y)
	local uierrorframemessage = nil;
	-- Hook error frame messages
	local oldAddMessage = UIErrorsFrame.AddMessage;
	UIErrorsFrame.AddMessage = function(a, b, c, d, e, f, g, h, i, j, k) uierrorframemessage = 1; end;
	
	oldUseAction(slot, x, y);
	
	-- Unhook (so you still get the error if the targettarget doesn't work either)
	UIErrorsFrame.AddMessage = oldAddMessage
	
	if SpellIsTargeting() and SpellCanTargetUnit("targettarget") then
		SpellTargetUnit("targettarget");
		oldUseAction(slot, x, y);
	elseif uierrorframemessage and UnitName("targettarget") and not UnitIsUnit("playertarget", "playertargettarget") then
		TargetUnit("targettarget");
		oldUseAction(slot, x, y);
		TargetLastTarget();
	end
	
	uierrorframemessage = nil;
end

function RDX.ImpliedTarget.UseActionMeleeAndHunterMode(slot, x, y)
	local uierrorframemessage = nil;
	-- Hook error frame messages
	local oldAddMessage = UIErrorsFrame.AddMessage;
	UIErrorsFrame.AddMessage = function(a, b, c, d, e, f, g, h, i, j, k) uierrorframemessage = 1; end;
	
	oldUseAction(slot, x, y);
	
	-- Unhook (so you still get the error if the targettarget doesn't work)
	UIErrorsFrame.AddMessage = oldAddMessage
	
	if uierrorframemessage and UnitName("targettarget") then
		TargetUnit("targettarget");
		oldUseAction(slot, x, y);
	end
	
	uierrorframemessage = nil;
end	