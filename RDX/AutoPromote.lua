-- AutoPromote.lua
-- RDX5 - Raid Data Exchange
--
-- Automatically promote certain people in your raid.
-- 

VFL.debug("[RDX5] Loading AutoPromote.lua", 2);

if not RDX.AutoPromote then RDX.AutoPromote = {}; end

-- Do stuff after variables have loaded
function RDX.AutoPromote.Init()
	VFL.debug("RDX.AutoPromote.Init()", 2);
	-- Create tables if necessary
	if not RDX5Data.AutoPromoteList then RDX5Data.AutoPromoteList = {}; end
	VFL.debug("RDX.AutoPromote and RDX5Data.AutoPromoteList tables made", 2);
	
	-- Hook dropdown menu in raid panel (Pay attention CTRA, this is the correct way)
	-- local RDX.AutoPromote.origDropDown_Init;
	RDX.AutoPromote.origDropDown_Init = RaidFrameDropDown_Initialize;
	RaidFrameDropDown_Initialize = RDX.AutoPromote.DropDown_Init;
	-- Bind event(s)
	RDXEvent:Bind("CHAT_MSG_SYSTEM", nil, function() RDX.AutoPromote.ParseSysMsg(arg1); end);
end

function RDX.AutoPromote.ParseSysMsg(msg)
	local _, _, name = string.find(msg, "^(%w+) has joined the raid.")
	if msg == "You are now the group leader." then
		VFL.schedule(1,RDX.AutoPromote.DoPromotionLoop)
	elseif msg == "You have joined a raid group" then
		VFL.schedule(1, RDX.AutoPromote.DoPromotionLoop)
	elseif name and IsRaidLeader() then
		-- Check to see if they are on the list and not already promoted
		if RDX5Data.AutoPromoteList[name] then
			PromoteToAssistant(name)
			VFL.print("[RDX 5] Auto-Promoting "..name)
		end
	end				
end

function RDX.AutoPromote.DoPromotionLoop()
	if not IsRaidLeader() then return end
	for i=1,MAX_RAID_MEMBERS do
		local name, rank = GetRaidRosterInfo(i);
		-- Check to see if they are on the list and not already promoted
		if RDX5Data.AutoPromoteList[name] and rank == 0 then
			PromoteToAssistant(name)
			VFL.print("[RDX 5] Auto-Promoting "..name)
		end
	end
end

function RDX.AutoPromote.OnClick()
	local name, rank = GetRaidRosterInfo(this.value);
	if RDX5Data.AutoPromoteList[name] then 
		RDX5Data.AutoPromoteList[name] = nil
	else
		RDX5Data.AutoPromoteList[name] = 1
		PromoteToAssistant(name)
		VFL.print("[RDX 5] Auto-Promoting "..name)
	end	
end


function RDX.AutoPromote.DropDown_Init()
	RDX.AutoPromote.origDropDown_Init(); -- See CTRA, it's not that hard, really.
	local info = {};
	info.text = "RDX: Auto (A)";
	info.tooltipTitle = "RDX: Auto (A)";
	info.tooltipText = "When checked, this player is automatically promoted when he or she joins the raid.";
	info.checked = RDX5Data.AutoPromoteList[this.name];
	info.value = this.id;
	info.func = RDX.AutoPromote.OnClick;
	UIDropDownMenu_AddButton(info);
end
