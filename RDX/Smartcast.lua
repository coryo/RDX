-- Smartcast.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Smartcast is a system designed to prevent spells being cast on targets that
-- are out of range or out of LoS.

-----------------------------------
-- TARGET MANAGEMENT
-----------------------------------
function RDX.Target(unit)
	local ret = UnitName("target");
	TargetUnit(unit.uid);
	return ret;
end

function RDX.Retarget(tret)
	if UnitName("target") ~= tret then
		TargetLastTarget();
	end
end

-----------------------------------
-- BASIC BLACKLISTING
-----------------------------------
-- Global line-of-sight blacklist
RDX.losbl = {};

-- Create a blacklist entry
function RDX.Blacklist(bl, key, dt)
	bl[key] = GetTime() + dt;
end

-- Flush all expired entries from a blacklist
function RDX.TrimBlacklist(bl)
	local t = GetTime();
	for k,v in bl do
		if( t > v ) then bl[k] = nil; end
	end
end

-- Check a blacklist for the given key
function RDX.CheckBlacklist(bl, key)
	RDX.TrimBlacklist(bl);
	if bl[key] then return true; else return false; end
end

-----------------------------------
-- GUARDED CAST
-----------------------------------
-- Cast the given spell, calling the given functions if something goes wrong.
-- Returns false immediately if the system can determine that the spell will fail.
function RDX.GuardedCast(sp, cb)
	VFL.debug("RDX.GuardedCast(" .. sp.id .. ") target " .. tostring(UnitName("target")), 10);
	-- If no target, immediately fail.
	if (not UnitName("target")) then
		VFL.debug("RDX.GuardedCast(): No target.", 10);
		return false;
	end
	if (sp:GetCooldown() > 0) then
		VFL.debug("RDX.GuardedCast(): attempted to cast while on cooldown", 10);
		return false;
	end
	-- Attempt the cast
	RDX.spellcb = cb;
	CastSpell(sp.id, SpellBookFrame.bookType);
	if SpellIsTargeting() then
		VFL.debug("RDX.GuardedCast(): SpellIsTargeting() after targeted spell, bad news.", 10);
		SpellStopTargeting(); 
		RDX.spellcb = nil;
		return false;
	end
	VFL.debug("RDX.GuardedCast() success.", 10);
	return true;
end

------------------------------
-- SPELL CALLBACK HANDLING
------------------------------
-- Rebind the UI errors frame function
UIEF_OE_Old = UIErrorsFrame_OnEvent;
UIErrorsFrame_OnEvent = function(ev, msg)
	-- If there's a pending spell
	if RDX.spellcb then
		if(msg == "Target not in line of sight") then
			RDX.spellcb(false, 2, msg);
		elseif(msg == "Out of range.") then
			RDX.spellcb(false, 3, msg);
		elseif(msg == "Spell is not ready yet.") then
			RDX.spellcb(false, 4, msg);
		else
			RDX.spellcb(false, 10, msg);
		end
		RDX.spellcb = nil;
	end
	UIEF_OE_Old(ev, msg);
end

-- On spellcast stop, clear any event handlers that were in place
function RDX.OnSpellcastStop()
	if RDX.spellcb then RDX.spellcb(true); RDX.spellcb = nil; end
end
RDXEvent:Bind("SPELLCAST_STOP", nil, RDX.OnSpellcastStop);
