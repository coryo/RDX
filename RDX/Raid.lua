if not RDX.Raid then RDX.Raid = {}; end

--------------------------------
-- RAID BUTTON
--------------------------------

--By default, auto-invite is off.
local autoinvitetoggle = nil;

local MAX_LEVEL = 60; --max level of a wow character

-- Core raidbutton handler
function RDX.Raid.RaidButtonOnClick()
	-- Right button = Create a new raid
	if(arg1 == "RightButton") then 
	 	if(IsShiftKeyDown()) then
			-- Shift + Right click = new raid / mass invites
			VFL.CC.Popup(function(flg) if flg then RDX.Raid.CreateNewRaid();  end end, "Create a new raid / Mass Invite?", "Would you like to invite all members of '" .. GetGuildInfo("player") .. "' into a raid?");
			
			
		else
			-- Toggle "Auto Invite" status.
			RDX.Raid.ToggleAutoInvite();
		end
	-- Left button = Auto-Join raid
	elseif(arg1 == "LeftButton") then
	 	if(IsShiftKeyDown()) then
			RDX.Raid.NewKeyword();
		else
			-- raid invite request (rpc)
			RDX.Raid.RaidInviteRequest()
		end
	end
end

function RDX.Raid.ToggleAutoInvite()
	if autoinvitetoggle then
		RDX.Raid.AutoInviteOff();
	else
		RDX.Raid.AutoInviteOn();
	end
end


function RDX.Raid.AutoInviteOn()
	autoinvitetoggle = true;
	RDXEncPane.btnRaid:LockHighlight();
end

function RDX.Raid.AutoInviteOff()
	autoinvitetoggle = nil;
	RDXEncPane.btnRaid:UnlockHighlight();
end

--------------------------------
-- Keyword
--------------------------------
function RDX.Raid.KeywordInit()
	VFLEvent:NamedUnbind("keyword_invite");
	if RDX5Data.keywordinvite then
		if RDX5Data.keywordinvite ~= "" then
			--they have a keyword, so lets hook into tells for it
			VFLEvent:NamedBind("keyword_invite", BlizzEvent("CHAT_MSG_WHISPER"), function() RDX.Raid.WhisperInc(arg1, arg2); end);
		end
	end
end

function RDX.Raid.WhisperInc(arg1, arg2)
	if string.lower(arg1) == string.lower(RDX5Data.keywordinvite) then
		InviteByName(arg2);
	end
end

function RDX.Raid.KeywordSet(input)
	RDX5Data.keywordinvite = input
	if not RDX5Data.keywordinvite or RDX5Data.keywordinvite == "" then
		VFL.print("[RDX] Keyword Invite is Disabled");
	else
		VFL.print("[RDX] Players will now be invited when they send you the tell, '" .. input .. "'");
	end
end

function RDX.Raid.NewKeyword()
	if not RDX5Data.keywordinvite then
		RDX5Data.keywordinvite = "";
	end
	-- Pop up a name prompt
	VFL.CC.Popup(RDX.Raid.NewKeywordCallback, "New Keyword", "Enter the name of the new raid invite keyword", RDX5Data.keywordinvite);
end

function RDX.Raid.NewKeywordCallback(flg, keyword)
	-- They clicked " cancel", just ignore
	if not flg then return; end
	-- Ignore preexisting names
	RDX.Raid.KeywordSet(keyword);
end

--------------------------------
-- RAID INVITE
--------------------------------
function RDX.Raid.TakeGroupInvite()
	--takes group invite and hides all open popup dialogs (noteably we're looking for the group invite one)
	AcceptGroup(); 
	local windowIndex
	for windowIndex = 1, STATICPOPUP_NUMDIALOGS do
		local currentFrame = getglobal("StaticPopup" .. windowIndex)
		if currentFrame:IsVisible() then
			currentFrame:Hide()
		end
	end
end

function RDX.Raid.RaidInviteRequest()

	if GetNumPartyMembers() == 0 then
		if UnitInRaid("player") == nil then
			--player is solo, ok to ask for raid invite.
			-- as long as they are synced.
			if RDXU.noesync == nil then
				VFL.print("[RDX] Sending raid invite request...");
				SendAddonMessage("RDX", "raid_invite_request", "GUILD");
				--now, for the next two seconds we will monitor for the invite window and click it automagically
				VFLEvent:NamedBind("awaiting_invite", BlizzEvent("PARTY_INVITE_REQUEST"), function() RDX.Raid.TakeGroupInvite(); end)																  
																						
				--schedule an unbind
				VFL.schedule(2, function() VFLEvent:NamedUnbind("awaiting_invite"); end);
			else
				VFL.print("[RDX] You are in desync mode..  Shift+Left click the sync button to turn sync mode on")
			end
		else
			VFL.print("[RDX] Raid invite request not sent - you are already in a raid!");
		end
	else
		VFL.print("[RDX] Raid invite request not sent - you are already in a group!");
	end	
end

RDXEvent:Bind("CHAT_MSG_ADDON", nil, function ()
	--someone has asked us for a raid invite.
	--Am I a raid leader / officer?
	if IsRaidLeader() and arg1 == "RDX" and arg2 == "raid_invite_request" then
		--is there room in our raid?
		if GetNumRaidMembers() < 40 then
			--is my auto invite on?
			if autoinvitetoggle then
				--lets invite them.
				InviteByName(arg4);
				VFL.print("[RDX] Invited Player: " .. arg4);
			end
		else --not enough room in our raid
			--inform them that the raid is full if we are the raid leader
			if IsRaidLeader() then
				SendChatMessage("[RDX] The raid is full.  You will be added to the wait list.", "WHISPER", nil, arg4);
				SendChatMessage("[RDX] " .. requestingPlayersName .. " requested a raid invite, but the raid was full.  Add them to the list.", "OFFICER");
			end
		end
	
	end
end);



--------------------------------
-- RAID CREATION
--------------------------------
function RDX.Raid.CreateNewRaid()

	--VFL.print("[RDX] You chose to create a new raid / mass invite.");
	
	--make sure they qualify for this function
	if not RDX.Raid.CreateRaidVerifyEligibility() then 
		return; 
	end
	
	SendChatMessage("[RDX] Raid Invites inc.", "GUILD");
	-- Toggle auto-invites on
	RDX.Raid.AutoInviteOn()
	--Now we have 3 possible scenarios
	--1)  Player is solo
	--	i)  Invite the first 4 60's
	--	ii) wait for one to join the group (bind the event)
	--  iii)launch into code for step 2
	--2)  Player is in a group, and is the leader	
	--  iv)  Make it a raid [pause 0.5 seconds]
	--  v)Invite everyone in guild who is MAX_LEVEL and not in our party
	--3)  Player is in a raid, and is the leader
	-- i) Just invite everyone in the guild who is MAX_LEVEL and not in our party
	
	
	--No matter what, we need to refresh our guild list:
	

	VFL.print("[RDX] Retrieving Raid Roster...")
	GuildRoster();
	
	if GetNumPartyMembers() == 0 then
		if UnitInRaid("player") == nil then
			--player is solo
			VFL.schedule(2, function() RDX.Raid.CreateRaidSolo(); end);
			return;
		end
	end
	
	if UnitInRaid("player") then
		--player is raid leader
		--lets invite everyone in the guild
		VFL.print("[RDX] Inviting max level guild members..");
		VFL.schedule(2, function() VFL.print("[RDX] Inviting max level guild members.."); RDX.Raid.InvitePlayersToParty(50); end);
	else
		--player is party leader
		--convert to raid
		ConvertToRaid();
		--in 2 seconds lets invite everyone in the guild who's max level, plus set loot to FFA
		VFL.schedule(2, function() VFL.print("[RDX] Inviting max level guild members.."); RDX.Raid.InvitePlayersToParty(50);SetLootMethod("freeforall"); end);
	end


end

function RDX.Raid.CreateRaidVerifyEligibility()

	if GetNumPartyMembers() > 0 then
		if not IsPartyLeader() then
			VFL.print("[RDX] You are not the party leader - Create Raid function aborting.");
			return false;
		end
	end
	if UnitInRaid("player") then
		if not IsRaidLeader() then
			VFL.print("[RDX] You are not the raid leader - Create Raid function aborting.");
			return false;
		end
	end	
	
	return true;

end


function RDX.Raid.CreateRaidSolo()

	--Step 1:  get a list of level 60's in our guild
	local listOfSixties = RDX.Raid.GetMaxLevelGuildedMembers();
	local numSixties = table.getn(listOfSixties);
	
	if numSixties == 0 then
		VFL.print("[RDX] The GetMaxLevelGuildedMembers() function returned zero members.  Try Again?");
		return;
	end
	
	if numSixties < 5 then
		VFL.print("[RDX] Only " .. numSixties .. " " .. MAX_LEVEL .. "'s are online.  Inviting them to your GROUP instead.")
		RDX.Raid.InvitePlayersToParty(listOfSixties);
		return;
	else
		VFL.print("[RDX] Inviting four Members to make a party...");
		RDX.Raid.InvitePlayersToParty(4);
		--now lets do two things
		--1) bind to the PARTY_MEMBERS_CHANGED event so we know when to form the raid and send out the rest of the invites
		--2) Schedule an unbind of this event after 5 seconds.  hopefully someone has joined by then.
		
		--Step ii:
		VFLEvent:NamedBind("guildraidinvite", BlizzEvent("PARTY_MEMBERS_CHANGED"), function() RDX.Raid.CreateRaidSolo2(); end);
		VFL.schedule(5, function() VFLEvent:NamedUnbind("guildraidinvite"); end);
		return;
	end
	
end


function RDX.Raid.CreateRaidSolo2()
	--make sure we've actually added someone since this event also fires
	--on a decline, etc etc.
	if GetNumPartyMembers() == 0 then return; end 
	
	--unbind the event so this doesn't trigger twice!
	VFLEvent:NamedUnbind("guildraidinvite");
	-- a slight deley is neccessary...
	VFL.schedule(1, function() RDX.Raid.CreateRaidSolo3(); end);
	
end

function RDX.Raid.CreateRaidSolo3()
	

	--Convert to raid
	ConvertToRaid();
	-- another slight pause...
	VFL.schedule(1, function() RDX.Raid.CreateRaidSolo4(); end);

end

function RDX.Raid.CreateRaidSolo4()

	VFL.print("[RDX] Inviting the rest of the Raid...");
		--invite the rest of the players
	RDX.Raid.InvitePlayersToParty(50);
		--and set loot to FFA
	SetLootMethod("freeforall");


end

function RDX.Raid.PlayerIsInGroupOrRaid(playersName)
	
	if UnitInRaid("player") then
		--player is in a raid
		--lets search through the raid
		local numRaiders = GetNumRaidMembers() -- Returns the number of raid members. 
		local thisPlayer = nil;
		for i=1,numRaiders do
			thisPlayer = GetRaidRosterInfo(i)
			if thisPlayer == playersName then return true; end
		end
	
	else
		--player is in a group
		--lets search through the group
		local numPartyMembers = GetNumPartyMembers() -- Returns the number of group members
		local thisPlayer = nil;
		for i=1,numPartyMembers do
			thisPlayer = GetRaidRosterInfo(i)
			if thisPlayer == playersName then return true; end
		end
	end
	
	return false;	
	
end

function RDX.Raid.InvitePlayersToParty(limit)

	--get the list and number of players
	local listOfPlayers = RDX.Raid.GetMaxLevelGuildedMembers()
	local numSixties = table.getn(listOfPlayers);
	if numSixties == 0 then
		VFL.print("Error: numSixties = 0 in InvitePlayersToParty()");
		return;
	end
	
	--loop through the array and invite everyone up to the limit
	for i=1,limit do
		--make sure they arent in our group/raid already
		if not RDX.Raid.PlayerIsInGroupOrRaid(listOfPlayers[i]) and i <= limit then
			if listOfPlayers[i] then
				if listOfPlayers[i] ~= UnitName("player") then
					InviteByName(listOfPlayers[i]);
				end
			end
		end
	end
	
end


function RDX.Raid.GetMaxLevelGuildedMembers()

	local NumGuildies = GetNumGuildMembers()
	local GuildedSixties = {}
	local numSixties = 0
	
	if NumGuildies == 0 then
		--VFL.print("[RDX] GetNumGuildMembers returned 0.  Try Again?");
		return {};
	end
	

	for i=1,NumGuildies do
		local thisMemberName = "";
		local thisMemberLevel = "";
		
		--Note: name, rank, rankIndex, level, class, zone, note, officernote, online, status = GetGuildRosterInfo(index);

		thisMemberName, _, _, thisMemberLevel = GetGuildRosterInfo(i);
		if (thisMemberLevel == MAX_LEVEL) then
			numSixties = numSixties + 1;
			GuildedSixties[numSixties] = thisMemberName;
		end
	end
	
	return GuildedSixties;
end