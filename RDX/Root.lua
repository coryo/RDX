-- Root.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Event dispatcher, core simple functions, loaded before all other scripts
--

VFL.debug("[RDX5] Loading Root.lua", 2);

RDX = RegisterVFLModule({
	name = "RDX";
	version = {6,0,1}; devel = true;
	description = "Raid Data Exchange";
	parent = VFL;
});

RDX.Version = 5;
RDX.Release = 4;
RDX.Beta = nil;
RDX.DataVersion = 12;


----------------------------
-- KEYBINDING NAMES
----------------------------
BINDING_HEADER_RDX = "RDX";
BINDING_NAME_RDXHIDEUI = "Show/Hide RDX";
BINDING_NAME_RDXSTARTSTOPTIMER = "Starts/Stops Timer";
BINDING_NAME_RDXBUFF = "RDXBuff";
BINDING_NAME_RDXCURE = "RDXCure";

----------------------------
-- MASTER RESET
----------------------------
function RDX.MasterReset()
	RDX5Data = {};
	ReloadUI();
end

-- Rehash RDX internal data structures
function RDX.Rehash()
	RDX.RaidRosterUpdate();
end


----------------------------
-- EVENT DISPATCHER
----------------------------
RDXEvent = DispatchTable:new();
RDXEvent:BindToWoWFrame(RDXRoot);

-----------------------
-- PRIMITIVE UNIT HANDLING
------------------------
-- UnitID <--> unit number mapping
RDX.uid2un = {};
for i=1,40 do
	RDX.uid2un["raid"..i] = i;
end

function UIDtoN(uid)
	return RDX.uid2un[uid];
end
function NtoUID(n)
	return "raid"..n;
end
-- Is this a raid unit?
function IsRaidUnit(uid)
	if string.sub(uid,1,4) ~= "raid" then 
		return false; 
	else 
		if string.sub(uid,5,7) ~= "pet" then return true; else return false; end
	end
end

-------------------
-- UI SUPPORT FUNCTIONS
-------------------
-- Massclear checkboxes
function RDX.ClearChecks(pfx, n)
	for i=1,n do
		getglobal(pfx .. i):Set(false);
	end
end

-- Spam RDX-type chat
function RDX.print(str, verbosity)
	VFL.print(str);
end

------------------------
-- DEBUG SUPPORT FUNCTIONS
------------------------
function RDX.DebugSignals()
	VFL.debug("------------ SIGNALS ANALYSIS ---------------",1);
	VFL.debug("UnitIdentitiesChanged: " .. RDX.SigUnitIdentitiesChanged:GetNumConnections() .. " connections", 1);
	VFL.debug("RaidRosterMoved: " .. RDX.SigRaidRosterMoved:GetNumConnections() .. " connections", 1);
	VFL.debug("UnitHealth: " .. RDX.SigUnitHealth:GetNumConnections() .. " connections", 1);
	VFL.debug("UnitMana: " .. RDX.SigUnitMana:GetNumConnections() .. " connections", 1);
	for i=1,4 do
		VFL.debug("UnitFlagsDirty["..i.."]: " .. RDX.SigUnitFlagsDirty[i]:GetNumConnections() .. " connections", 1);
	end
	for i=1,4 do
		VFL.debug("MuxFlagsDirty["..i.."]: " .. RDX.SigMuxFlagsDirty[i]:GetNumConnections() .. " connections", 1);
	end
end

--------------------------------
-- RDX UI RELATED FUNCTIONS
--------------------------------
function RDX.ToggleHideUI()
	VFL.debug("RDX.ToggleHideUI()", 2)
	if RDXEncPane:IsVisible() then
		RDXEncPane:Hide()
	else
		RDXEncPane:Show()
		--also cal masterShow() so they don't get confused about where their windows are
		RDX.MasterShow()		
	end
end



function RDX.MasterHide()
	--Currently this is the best "quick hack" hide-all method
	--a proper method would be to introduce a Hide() routine to each module
	--and have this call them...  and let the modules do their own hiding
		--hide all of rdx
		--frame pool windows
		for i=1,30 do 
			getglobal("RDXWin" ..i):Hide(); 
		end;
	
		-- hide main "encounters" window
		RDXEncPane:Hide();
end

function RDX.MasterShow()
	--See MasterHide comments for future implementation...
		--show all of rdx
		--frame pool windows
		for i=1,30 do 
				getglobal("RDXWin" ..i):Show(); 
		end;
		--main "encounters" window
		RDXEncPane:Show()
			
		-- We essentially need to re-initialize the windows module becuase it handles its own visibility.
		if RDXM.Windows then	
			-- Destroy all extant windows
			RDXM.Windows.ReleaseAll();
			-- Reallocate all windows based on layout table
			RDXM.Windows.ReallocateAll();
		end
end

-- Reset all UI components to their default size and position
function RDX.ResetUI()
	-- Instruct all modules to reset their UI
	RDX.Modules.Command("ResetUI");
	
	-- Move the encounters screen to the middle
	RDXEncPane:ClearAllPoints(); 
	RDXEncPane:SetPoint("CENTER", "UIParent", "CENTER")
end

function RDX.SetEncScale(arg1)
	local x = tonumber(arg1); 
	if not x or (x < 1 or x > 10) then VFL.print("Usage: /rdxscale #   where # is {1-10}"); return; end
	VFL.print("Setting Encounter Pane to Scale: " .. x);
	RDX5Data.EncScaleValue = x;
	RDX.DoSetEncScale(x)
end

function RDX.DoSetEncScale(scaleInt)
	local trueScaleToSet = (scaleInt / 10) + .2;
	RDXEncPane:SetScale(trueScaleToSet);
end

-- Generate a unique ID number
function RDX.GenerateUniqueID()
	return math.random(100000000);
end

-----------------------------
-- HEARTBEAT SIGNALS
-----------------------------
RDX.SigHeartbeatFast = VFL.Signal:new();

function RDX.HBFast()
	RDX.SigHeartbeatFast:Raise();
	VFL.schedule(RDXG.perf.hbFast, RDX.HBFast);
end