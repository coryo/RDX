-- DispatchTable.lua
-- VFL - Venificus' Function Library
-- (C)2006 Bill Johnson (Venificus of Eredar server)
--
VFL:Debug(1, "Loading DispatchTable.lua");

------------------------------------------------------------------------
-- @class Signal
--
-- A Signal is a device for calling methods in sequence. Usually called
-- to handle an outside stimulus and allow multiple procedures to gain
-- input from the stimulus.
--
-- Each Signal can have optional event handling methods attached to it
-- which will be called when certain things happen. The available methods are
--
-- @field OnEmpty signal:OnEmpty() is called when the signal becomes empty.
-- @field OnNonEmpty signal:OnNonEmpty() is called when the signal becomes nonempty.
------------------------------------------------------------------------
Signal = {};
Signal.__index = Signal;
VFLKernelRegisterCategory("Signal");

--- Create a new, empty signal.
function Signal:new()
	-- Initialize the signal to empty.
	local self = {};
	self.chain = {}; self.name = "(anonymous)";
	setmetatable(self, Signal);

	return self;
end

-- VFL kernel hooks
function Signal:KGetObjectName()
	return self.name;
end
function Signal:KGetObjectInfo()
	return "Binds " .. table.getn(self.chain);
end

--- Test the signal for emptiness.
-- @return TRUE iff the signal is empty.
function Signal:IsEmpty()
	if table.getn(self.chain) > 0 then return nil; else return true; end
end

--- Actuate the signal, calling all bound methods.
-- All the arguments are passed directly onto the called methods.
function Signal:Raise(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
	for _,hsig in self.chain do
		hsig.invoke(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20);
	end
end

--- Connect a method to this signal.
-- @param obj The object to bind, or nil for a standalone method.
-- @param method The method to bind. This can either be a function (in which case the function will be invoked directly) or a string (in which case the function will be looked up)
-- @param id Optional - An ID that can be later used to unbind this object.
-- @return a handle to the connection that can be later used to manipulate it.
function Signal:Connect(obj, method, id)
	-- Verify method
	if obj and (type(method) == "string") then method = obj[method]; end
	if not method then return nil; end
	-- Add to chain
	local hsig = {id = id, obj = obj, method = method, invoke = VFL.WrapInvocation(obj, method)};
	table.insert(self.chain, hsig);
	-- Fire Nonempty handler if applicable
	if self.OnNonEmpty and (table.getn(self.chain) == 1) then self:OnNonEmpty(); end
	return hsig;
end

--- Disconnect an object or method from this signal using the handle returned by Connect()
-- @param handle A handle returned by a previous call to Signal:Connect().
function Signal:DisconnectByHandle(handle)
	if not handle then return; end
	local sc = self.chain;
	local n = table.getn(sc);
	if (n == 0) then return; end
	local i=1;
	while (i<=n) do
		if (sc[i] == handle) then table.remove(sc, i); n=n-1; else i=i+1; end
	end
	-- Fire Empty handler if applicable
	if self.OnEmpty and (n == 0) then self:OnEmpty(); end
end

--- Disconnect an object or method from this signal matching the given ID.
-- @param id An ID used in Signal:Connect() to connect a method to this signal.
function Signal:DisconnectByID(id)
	if not id then return; end
	local sc = self.chain;
	local n = table.getn(sc);
	if (n == 0) then return; end
	local i=1;
	while (i<=n) do
		if (sc[i].id == id) then table.remove(sc, i); n=n-1; else i=i+1; end
	end
	-- Fire Empty handler if applicable
	if self.OnEmpty and (n == 0) then self:OnEmpty(); end
end

--- Reconnect an object or method to this signal using the handle
-- returned by Connect(). If the handle is already connected, do nothing.
-- @param handle A handle returned by a previous call to Signal:Connect().
function Signal:ReconnectByHandle(handle)
	if not handle then return false; end
	for _,hsig in self.chain do
		if hsig == handle then return true; end
	end
	table.insert(self.chain, hsig);
	-- Fire Nonempty handler if applicable
	if self.OnNonEmpty and (table.getn(self.chain) == 1) then self:OnNonEmpty(); end
	return true;
end

--- Disconnect an object or method from this signal by object or method
-- pointer.
-- @param targ The object or method to be disconnected. If targ is a function, all bindings with matching
-- functions will be removed. If targ is a nonfunction, all bindings with matching objects will be removed.
function Signal:Disconnect(targ)
	if (table.getn(self.chain) == 0) then return; end
	local tbl = {};
	if type(targ) == "function" then
		for _,hsig in self.chain do
			if hsig.method ~= targ then table.insert(tbl, hsig); end
		end
	else
		for _,hsig in self.chain do
			if hsig.obj ~= targ then table.insert(tbl, hsig); end
		end
	end
	self.chain = tbl;
	-- Fire Empty handler if applicable
	if self.OnEmpty and (table.getn(self.chain) == 0) then self:OnEmpty(); end
end

--- Remove all objects from this signal.
function Signal:DisconnectAll()
	if(table.getn(self.chain) == 0) then return; end
	self.chain = {};
	-- Fire Empty handler if applicable
	if self.OnEmpty then self:OnEmpty(); end
end

----------------------------------------------------------------------------
-- @class DispatchTable
--
-- A dispatch table is a keyed table of signals that can be Connected and Raised
-- by key.
--
-- The DispatchTable can have optional event handling methods that are triggered
-- when certain things happen.
--
-- @field OnCreateKey dt:OnCreateKey(key, signal) is called whenever a new key is created.
--  Should return TRUE if the key creation should be allowed to proceed, NIL if not.
-- @field OnDeleteKey dt:OnDeleteKey(key, signal) is called whenever a key is deleted.
----------------------------------------------------------------------------
DispatchTable = {};
DispatchTable.__index = DispatchTable;
VFLKernelRegisterCategory("DispatchTable");

--- @return A new, empty dispatch table.
function DispatchTable:new()
	local self = {};
	setmetatable(self, DispatchTable);
	self.dtbl = {}; self.name = "(anonymous)";

	return self;
end

-- VFL kernel hooks
function DispatchTable:KGetObjectName()
	return self.name;
end
function DispatchTable:KGetObjectInfo()
	local sigList, i = {}, 0;
	for _,sig in pairs(self.dtbl) do
		table.insert(sigList, sig); i=i+1;
	end
	return "Sz " .. i, sigList;
end

--- Get the signal associated to the given key, creating it if it does not exist.
-- @param key The key to acquire.
-- @return The signal at the key, or NIL if the action is impossible.
function DispatchTable:GetSignal(key)
	-- Sanity check
	if not key then return nil; end
	-- If the key already exists, just return the signal
	local sig = self.dtbl[key];
	if sig then return sig; end
	-- If not, create a new key
	sig = Signal:new();
	-- Honor the OnCreateKey contract
	if self.OnCreateKey then
		if not self:OnCreateKey(key, sig) then return nil; end
	end
	-- Name the signal
	sig.name = tostring(key);
	-- Bind the signal's OnEmpty handler to a function that will auto-destroy the signal
	sig.OnEmpty = function()
		self:DeleteKey(key);
	end
	-- Store the new signal and return it
	self.dtbl[key] = sig;
	return sig;
end

--- Delete the signal at the given key. Don't call this unless you're sure you know what
-- you're doing. The normal method for removing dispatch entries is via proper use of :Bind(id)
-- and :Unbind(id).
-- @param key The key to destroy.
function DispatchTable:DeleteKey(key)
	local sig = self.dtbl[key];
	if not sig then return; end
	if self.OnDeleteKey then
		self:OnDeleteKey(key, sig);
	end
	self.dtbl[key] = nil;
end

--- Create a new binding on this dispatch table.
-- @see Signal:Connect
-- @param key The key to which the new binding should be associated.
-- @param object The object on which the binding will be invoked.
-- @param method The method that will be invoked when the binding is activated.
-- @param id Optional - An ID that can be used later to unbind this object.
-- @return If successful, a handle which can be later used with UnbindByHandle. If failed, NIL.
function DispatchTable:Bind(key, object, method, id)
	-- Get the signal associated with the key, creating if necessary
	local sig = self:GetSignal(key);
	if not sig then return nil; end
	-- Bind
	return sig:Connect(object, method, id);
end

--- Remove bindings from this dispatch table by ID.
-- @param id The ID used with DispatchTable:Bind(), all instances of which will be unbound.
function DispatchTable:Unbind(id)
	for _,sig in pairs(self.dtbl) do
		sig:DisconnectByID(id);
	end
end

--- Remove bindings from this dispatch table by handle.
-- @param handle The handle returned by DispatchTable:Bind(), which will be unbound.
function DispatchTable:UnbindByHandle(handle)
	for _,sig in pairs(self.dtbl) do
		sig:DisconnectByHandle(handle);
	end
end

--- Make a dispatch.
-- @param key The key to dispatch on. The remaining arguments are passed along as arguments to
-- the dispatch.
function DispatchTable:Dispatch(key, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
	local sig = self.dtbl[key];
	if not sig then return; end
	sig:Raise(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20);
end

--- Force all dispatches to pass through the given debug provider.
-- Passing nil as provider removes any debugging.
-- @param prov The debug provider through which dispatches should flow.
-- @param level The debug level to use.
function DispatchTable:DebugDispatches(prov, level)
	if not prov then self.Dispatch = nil; end
	self.Dispatch = function(self, key, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
		prov:Debug(level, self.name .. "> " .. tostring(key) .. "(" .. tostring(a1) .. "," .. tostring(a2) .. "," .. tostring(a3) .. " ...)")
		DispatchTable.Dispatch(self, key, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20);
	end
end

--- Bind this dispatch table to the OnEvent handler of a given WoW Frame.
-- Anytime a key is created on the dispatch table, the event is registered to the underlying frame.
-- WARNING: Any current contents of the dispatch table are destroyed.
-- @param frame The WoW Frame to bind to.
function DispatchTable:BindToWoWFrame(frame)
	self.dtbl = {};
	-- Key creation/deletion should auto Register/Unregister events on the target frame
	self.OnCreateKey = function(tbl, key) 
		frame:RegisterEvent(key); 
		return true; 
	end
	self.OnDeleteKey = function(tbl, key) 
		frame:UnregisterEvent(key); 
	end
	-- Smartly handle LEAVE/ENTER events to reduce load times
	-- On ENTERING_WORLD, reregister all events
	self:Bind("PLAYER_ENTERING_WORLD", nil, function()
		Root:Debug(5, "DispatchTable " .. self.name .. ": PLAYER_ENTERING_WORLD");
		for k,_ in pairs(self.dtbl) do frame:RegisterEvent(k); end
	end);
	-- On LEAVING_WORLD, deregister all non-world events
	self:Bind("PLAYER_LEAVING_WORLD", nil, function()
		Root:Debug(5, "DispatchTable " .. self.name .. ": PLAYER_LEAVING_WORLD");
		for k,_ in pairs(self.dtbl) do
			if not VFL.IsGameInitEvent(k) then frame:UnregisterEvent(k); end
		end
	end);
	-- Associate the OnEvent handler of the frame with the dispatch table
	frame:SetScript("OnEvent", function() self:Dispatch(event); end);
end
