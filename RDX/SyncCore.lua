-- SyncCore.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Synchronization algorithms.
-- 
VFL.debug("[RDX5] Loading SyncCore.lua", 2);

if not RDX.Sync then RDX.Sync = {}; end

---------------------
-- BASIC CHAT CHANNEL FUNCTIONALITY
---------------------
-- Returns the number of the channel with the given name, or nil if not found
function RDX.ChannelNumberFromName(cn)
	local n = GetChannelName(cn);
	if n>0 then return n; else return nil; end
end

-- Message-sending routines
function RDX.ChatMessage(chanNum, msg)
	SendAddonMessage("RDX", msg, "RAID");
end

-----------------------------------------------------------
-- PROTOCOL DATABASE
-----------------------------------------------------------
if not RDX.Protocol then RDX.Protocol = {}; end
RDX.Protocol.__index = RDX.Protocol;

function RDX.Protocol:new(o)
	local x = o or {};
	setmetatable(x, RDX.Protocol);
	return x;
end

-- DB mgmt
RDX.proto = {};

-- Register a new protocol
function RDX.RegisterProtocol(tbl)
	-- Validate the protocol ID
	if not tbl.id then return nil; end
	if RDX.proto[tbl.id] then
		VFL.debug("RDX.RegisterProtocol: Protocol id " .. tbl.id .. " registered twice!", 1);
		return nil;
	end
	local p = RDX.Protocol:new(tbl);
	RDX.proto[tbl.id] = p;
	return p;
end

-- Get protocol by id
function RDX.GetProtocolByID(id)
	return RDX.proto[id];
end

-- Dump all protocols
function RDX.DumpProtocols()
	VFL.debug("RDX: Active protocols");
	VFL.debug("-----------------------------------");
	for k,v in RDX.proto do
		VFL.debug("["..k.."] " .. tostring(v.name));
	end
end

----------------------------------------------------------------
-- MESSAGE QUEUE
----------------------------------------------------------------
-- The queue.
RDX.msgq = VFL.Deque:new();

-- Enqueue a message.
function RDX.EnqueueMessage(proto, msg)
	-- If it's a realtime protocol, it bypasses the queue entirely
	if(proto.realtime) then
		return RDX.ImmediateMessage(proto, msg);
	end
	-- If it's a replacement protocol, then any existing message with this protocol must be replaced
	if(proto.replace) then
		-- Search for another message on queue with this protocol
		for i=1,RDX.msgq:GetSize() do
			-- If found...
			if RDX.msgq.q[i].pid == proto.id then
				-- Replace the data and return true.
				RDX.msgq.q[i].data = msg;
				return true;
			end
		end
	end
	-- Push it into the queue
	RDX.msgq:PushBack({pid = proto.id, data = msg});
	RDX.ProcessMessageQueue();
	return true;
end

-- Immediate message processing
function RDX.ImmediateMessage(p, data)
	RDX.SendMessage(p.id, data);
end

-- Periodic queue processing
local qp_active = false;
function RDX.ProcessMessageQueue_Internal()
	-- If RDX is not even active, kill off the message queue and halt processing.
	if not qp_active then return; end
	VFL.schedule(5, RDX.ProcessMessageQueue_Internal);
	-- Pop a message
	local md = RDX.msgq:PopFront();
	if not md then qp_active = false; return; end
	-- Send it
	RDX.SendMessage(md.pid, md.data);
	-- Reschedule next qpop
	VFL.schedule(RDXG.perf.mqDelay, RDX.ProcessMessageQueue_Internal);
end

function RDX.ProcessMessageQueue()
	-- If the queue processing is already active, ignore.
	if qp_active then return; end
	-- Start it up
	qp_active = true;
	RDX.ProcessMessageQueue_Internal();
end


-- Send a message
function RDX.SendMessage(pid, data)
	-- BUGFIX: Shut off "auto clear AFK" so that we don't afk spam
	local priorValue = GetCVar("autoClearAFK");
	SetCVar("autoClearAFK", 0);
	local msg = pid .. ":" .. data;
	msg = string.gsub(msg, "\\", "\\\\");
	msg = string.gsub(msg, "\n", "\\n");
	RDX.ChatMessage(RDX.ccn, msg);
	SetCVar("autoClearAFK", priorValue);
end

----------------------------------------------------
-- MESSAGE DECODING
----------------------------------------------------
-- Core message receptor
RDXEvent:Bind("CHAT_MSG_ADDON", nil, function()
	-- Verify that the message is relevant and nonempty
	if (not RDX.initialized) then return; end
	local prefix,sender,msg = arg1,arg4,arg2;
	if (prefix ~= "RDX") or (not sender) or (sender == "") or (not msg) or (msg == "") then return; end
	
	-- Verify that the sender is in our raid group
	local sp = RDX.GetUnitByName(string.lower(sender));
	-- If so, decode the message.
	if sp then
		sp:UpdateContactTime();
		RDX.DecodeMessage(sp, msg); 
	end

end);

-- Parse the protocol name from a message and pass it to the appropriate handler.
function RDX.DecodeMessage(sender, msg)
--	VFL.debug("RDX.DecodeMessage <"..sender.name..">["..msg.."]", 10);
	-- unescape the msg
	msg = string.gsub(msg, "\\n", "\n");
	msg = string.gsub(msg, "\\\\", "\\");

	local found,_,pstr,data = string.find(msg, "^(%d+):(.*)$")
	if found then
		local proto = RDX.GetProtocolByID(tonumber(pstr));
		if proto and proto.handler then return proto:handler(sender, data); end
	end
end

---------------------------------------------
-- SYNC AND SYNC PARSING
---------------------------------------------
function RDX.IsRaidOfficer(playerName)
	-- only raid officers can broadcast MTs
	for i=1, GetNumRaidMembers() do
        	local name, rank = GetRaidRosterInfo(i);
		if string.lower(playerName) == string.lower(name) and rank == 1 then
			return 1;
		end
	end
end
function RDX.IsRaidLeader(playerName)
	-- only raid officers can broadcast MTs
	for i=1, GetNumRaidMembers() do
        	local name, rank = GetRaidRosterInfo(i);
		if string.lower(playerName) == string.lower(name) and rank == 2 then
			return 1;
		end
	end
end

---------------------------------------------
-- INIT
---------------------------------------------
function RDX.Sync.Init()
	VFL.debug("RDX.Sync.Init()", 2);
end
