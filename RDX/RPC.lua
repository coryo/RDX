-- RPC.lua
-- RDX5 - Raid Data Exchange
-- (C)2006 Bill Johnson (Venificus of Eredar server)
--
-- Remote procedure call and serialization mechanisms for RDX5.
Root:Debug(1, "[RDX5] Loading RPC.lua");

RPC = RegisterVFLModule({
	name = "RPC";
	description = "RDX Remote Procedure Call";
	parent = Root;
});


-----------------------------------------
-- Serialization subroutines
-----------------------------------------
local function GetEntryCount(tbl)
	local i = 0;
	for _,_ in tbl do i = i + 1; end
	return i;
end

function Serialize(obj)
	if(obj == nil) then
		return "";
	elseif (type(obj) == "string") then
		return string.format("%q", obj);
	elseif (type(obj) == "table") then
		local str = "{";
		if obj[1] and ( table.getn(obj) == GetEntryCount(obj) ) then
			-- Array case
			for i=1,table.getn(obj) do str = str .. Serialize(obj[i]) .. ","; end
		else
			-- Nonarray case
			for k,v in pairs(obj) do
				if (type(k) == "number") then
					str = str .. "[" .. k .. "]=";
				elseif (type(k) == "string") then
					str = str .. k .. "=";
				else
					error("bad table key type");
				end
				str = str .. Serialize(v) .. ",";
			end
		end
		-- Strip trailing comma, tack on syntax
		return string.sub(str, 0, string.len(str) - 1) .. "}";
	elseif (type(obj) == "number") then
		return tostring(obj);
	elseif (type(obj) == "boolean") then
		return obj and "true" or "false";
	else
		error("could not serialize object of type " .. type(obj));
	end
end

function Deserialize(data)
	if not data then return nil; end
	xxDeserialize = nil;
	if not pcall(RunScript, "xxDeserialize = function() return " .. data .. " end") then return nil; end
	if xxDeserialize then 
		-- Prevent the deserialization function from making external calls
		setfenv(xxDeserialize, {});
		-- Call the deserialization function
		return xxDeserialize(); 
	else 
		return nil; 
	end
end

-------------------------------------------------
-- Data chunking and dechunking subroutines
-------------------------------------------------
-- Break the string data into chunks of size at most chunkSize, calling 
-- chunkFunc(chunk, chunkNum, totalChunks) on each one.
function RPC.ChunkString(data, chunkSize, chunkFunc)
	local sz = string.len(data);
	local chunksTotal, chunkCur, chunkStart, chunkEnd = math.ceil(sz/chunkSize), 1, 1, chunkSize;
	while(true) do
		if(chunkEnd >= sz) then chunkEnd = -1; end
		-- Extract the chunk and call the chunk function
		local chunk = string.sub(data, chunkStart, chunkEnd);
		chunkFunc(chunk, chunkCur, chunksTotal);
		-- Manage indices
		if(chunkEnd == -1) then break; end
		chunkStart = chunkEnd + 1; chunkEnd = chunkEnd + chunkSize;
		chunkCur = chunkCur + 1;
	end
end

-- Dechunk a data stream one chunk at a time. Accumulates data in a buffer, which
-- is rereturned. If buf is nil, a new buffer is created.
function RPC.DechunkString(buf, chunkCur, chunkMax, data)
	if not buf then
		if(chunkCur ~= 1) then return nil; end
		buf = { cur = chunkCur, max = chunkMax, data = data };
		return buf;
	end
	-- Check for wrong buffer or out of sequence packet.
	if(buf.max ~= chunkMax) or ((buf.cur + 1) ~= chunkCur) then return nil; end
	-- Append the data
	buf.cur = chunkCur;
	buf.data = buf.data .. data;
	return buf;
end

-- Determine if dechunking is complete
function RPC.IsDechunked(buf)
	return (buf.cur == buf.max);
end

-----------------------------------------------
-- IMPLEMENTATION
-----------------------------------------------
-- State tables.
-- Local RPC endpoints
local endpoints = {};
-- Currently inbound RPCs.
local inbounds = {};
-- RPCs whose return values are being awaited.
local waits = {};
-- Individual wait state data
local waitData = {};

-- Dispatch RPC request.
local function RPCCallDispatch(fn, argAry)
	-- Generate an ID
	local id = RDX.GenerateUniqueID();
	-- Serialize the material to be dispatched
	if(table.getn(argAry) == 0) then argAry = nil; end
	local ser = Serialize({ fn, argAry });
	if not ser then return nil; end
	-- Chunk and send
	local outfunc = function(data, n0, n1)
		RPC:Debug(9, "RPCCallDispatch sending: " .. data);
		RDX.EnqueueMessage(RDX.p_rpccall, id .. ":" .. n0 .. ":" .. n1 .. ":" .. data);
	end
	RPC.ChunkString(ser, 150, outfunc);
	-- Return the id
	return id;
end

-- Dispatch RPC response.
local function RPCReturnDispatch(id, ret)
	-- Serialize the return object
	local ser = Serialize(ret);
	if not ser then return; end
	-- Chunk and send
	local outfunc = function(data, n0, n1)
		RPC:Debug(9, "RPCReturnDispatch sending: " .. data);
		RDX.EnqueueMessage(RDX.p_rpcreturn, id .. ":" .. n0 .. ":" .. n1 .. ":" .. data);
	end
	RPC.ChunkString(ser, 150, outfunc);
end

-- Called when an incoming RPC Call is received.
local function RPCCallComplete(sender, id, data)
	-- Deserialize
	local qq = Deserialize(data);
	if (not qq) or (not qq[1]) then
		RPC:Debug(1, "RPCCallComplete: Failed to deserialize " .. tostring(data));
		return;
	end
	-- Map endpoint
	local ept = endpoints[qq[1]];
	if not ept then
		RPC:Debug(1, "RPCCallComplete: Invalid endpoint " .. tostring(qq[1]));
		return;
	end
	-- Call function
	local ret = nil;
	if qq[2] then
		ret = ept(sender, unpack(qq[2]));
	else
		ret = ept(sender);
	end
	-- Send reply if necessary
	if ret then
		RPCReturnDispatch(id, ret);
	end
end

-- Called when an incoming RPC Return is received.
local function RPCReturnComplete(sender, id, func, data)
	-- Deserialize
	local qq = Deserialize(data);
	if not qq then
		RPC:Debug(1,"RPCReturnComplete: Failed to deserialize " .. tostring(data));
		return;
	end
	-- Call it
	func(sender, qq);
end

-- Line-level protocol handler for incoming RPC calls
local function RPCCallProtoHandler(proto, sender, args)
	RPC:Debug(9, "RPCCallProtoHandler [" .. args .. "]");
	-- Demarshal data
	local _,_,id,cn,ct,data = string.find(args, "^(%d+):(%d+):(%d+):(.*)$");
	if not id then return; end
	id = tonumber(id); cn = tonumber(cn); ct = tonumber(ct);
	if(not id) or (not cn) or (not ct) then return; end
	-- Associate an inbound with our data
	local ibd = nil;
	if inbounds[id] then ibd = inbounds[id]; end
	-- Move along with the decoding process
	ibd = RPC.DechunkString(ibd, cn, ct, data);
	-- Discard invalid or out-of-sequence data
	if not ibd then 
		RPC:Debug(1, "RPCCallProtoHandler: invalid inbound");
		inbounds[id] = nil; return; 
	end
	-- Store the inbound
	inbounds[id] = ibd;
	-- If we're finished, handle as appropriate
	if(RPC.IsDechunked(ibd)) then 
		RPCCallComplete(sender, id, ibd.data);
		inbounds[id] = nil;
	end
end

-- Line-level protocol handler for incoming RPC returns
local function RPCReturnProtoHandler(proto, sender, args)
	RPC:Debug(9, "RPCReturnProtoHandler " .. sender.name .. ":[" .. args .. "]");
	-- Demarshal data
	local _,_,id,cn,ct,data = string.find(args, "^(%d+):(%d+):(%d+):(.*)$");
	if not id then return; end
	id = tonumber(id); cn = tonumber(cn); ct = tonumber(ct);
	if(not id) or (not cn) or (not ct) then return; end
	-- Associate an inbound with our data
	local ept = waits[id];
	if not ept then return; end
	local sd = waitData[id];
	if not sd then
		sd = {};
		waitData[id] = sd;
	end
	-- Update inbound data
	sd[sender.name] = RPC.DechunkString(sd[sender.name], cn, ct, data);
	local blk = sd[sender.name];
	if not blk then RPC.NoWait(id); return; end
	-- If we're done, we're done
	if(RPC.IsDechunked(blk)) then 
		RPCReturnComplete(sender, id, ept.func, blk.data);
	end
end

-- Protocols
RDX.p_rpccall = RDX.RegisterProtocol({
	id=8; name = "RPC Call";
	replace = false; highPrio = false; realtime = false;
	handler = RPCCallProtoHandler;
});
RDX.p_rpcreturn = RDX.RegisterProtocol({
	id=9; name = "RPC Return";
	replace = false; highPrio = false; realtime = false;
	handler = RPCReturnProtoHandler;
});

----------------------------------------------------
-- PUBLIC INTERFACE
----------------------------------------------------
-- Bind the given local endpoint to a function
function RPC.Bind(endpoint, fn)
	RPC:Debug(3, "RPC.Bind(" .. tostring(endpoint) .. ")");
	if endpoints[endpoint] then return false; else
		endpoints[endpoint] = fn;
		return true;
	end
end

-- Unbind the given local endpoint
function RPC.Unbind(endpoint)
	RPC:Debug(3, "RPC.Unbind(" .. tostring(endpoint) .. ")");
	endpoints[endpoint] = nil;
end

-- Unbind all local endpoints matching the given regex
function RPC.UnbindPattern(pattern)
	RPC:Debug(3, "RPC.UnbindPattern(" .. tostring(pattern) .. ")");
	for k,_ in endpoints do
		if string.find(k, pattern) then
			endpoints[k] = nil;
		end
	end
end

-- Invoke the given remote endpoint with the given arguments.
function RPC.Invoke(endpoint, ...)
	return RPCCallDispatch(endpoint, arg);
end

-- Wait for the return value of the invocation with the given id
function RPC.Wait(id, fn)
	if waits[id] then return false; end
	waits[id] = { func = fn; };
	return true;
end

function RPC.NoWait(id)
	waits[id] = nil;
	waitData[id] = nil;
end

-- "Evoke" the given remote endpoint.
-- This causes the endpoint to be both invoked and waited for, and is exactly
-- equivalent to the code:
-- id = RDX.RPCInvoke(endpoint, ...);
-- RDX.RPCWait(id, waitFunc, timeout);
function RPC.Evoke(timeout, waitFunc, endpoint, ...)
	local id = RPCCallDispatch(endpoint, arg);
	if not id then return nil; end
	waits[id] = { func = waitFunc; }
	VFL.schedule(timeout, function() RPC.NoWait(id); end);
	return true;
end

