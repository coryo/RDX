-- VFL_Signal.lua
-- VFL
-- Venificus' Function Library
--
-- A Signal is a device for mapping a slot (object/method pair)
-- to an event.
if not VFL.Signal then VFL.Signal = {}; end
VFL.Signal.__index = VFL.Signal;

function VFL.Signal:new()
	local x = {};
	x.chain = {};
	setmetatable(x, VFL.Signal);
	return x;
end

-- Get # of obj/method pairs connected.
function VFL.Signal:GetNumConnections()
	return table.getn(self.chain);
end

-- Connect a slot to this signal
function VFL.Signal:Connect(ob, method)
	if (not method) then return false; end
	-- If method is a string, resolve it to a function
	if ob and (type(method) == "string") then
		method = ob[method];
	end
	table.insert(self.chain, {ob = ob; method = method;});
	return true;
end

function VFL.Signal:IsEmpty()
	if (table.getn(self.chain) == 0) then return true; else return false; end
end
function VFL.Signal:DisconnectAll()
	self.chain = {};
end

-- Disconnect an object from this signal
function VFL.Signal:DisconnectObject(o)
	local tbl = {};
	for _,v in self.chain do
		if v.ob ~= o then table.insert(tbl, v); end
	end
	self.chain = tbl;
end

-- Disconnect a method from this signal
function VFL.Signal:DisconnectMethod(f)
	local tbl = {};
	for _,v in self.chain do
		if v.method ~= f then table.insert(tbl, v); end
	end
	self.chain = tbl;
end

-- Raise the signal
function VFL.Signal:Raise(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
	local i;
	for _,i in self.chain do
		local o,m = i.ob, i.method;
		if m then 
			if o then 
				m(o, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20); 
			else 
				m(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20); 
			end
		end -- if m
	end -- for entry
end
