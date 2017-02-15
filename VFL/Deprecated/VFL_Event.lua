-- VFL
-- Event handling utility library
-- Aids in the handling of events for a given frame by construction of a dispatch table
-- and virtualization of events (eg, the binding of a handler to multiple events)
--

-- GLOBAL API
-- Retrieve a blizzard event by name.
BlizzEvent = function(evstr)
	if not evstr then 
		VFL.debug("Call to BlizzEvent with missing event string.");
		return nil; 
	end
	if not VFL.Event._evtbl[evstr] then
		VFL.Event._evtbl[evstr] = {name = evstr; activate = VFL.Event._blizzEventActivate;  deactivate = VFL.Event._blizzEventDeactivate};
	end;
	return VFL.Event._evtbl[evstr];
end;
-- Retrieve a custom event by name.
CustomEvent = function(evstr)
	if not VFL.Event._evtbl[evstr] then 
		VFL.debug("Invalid custom event " .. evstr);
		return nil; 
	end
	return VFL.Event._evtbl[evstr];
end;

VFL.Event = {
	-- Dispatcher class.
	Dispatcher = {};
	-- Internal event def table
	_evtbl = {};

	-- Activate/passivate blizzard events.
	_blizzEventActivate = function(disp, evdef)
		disp.frame:RegisterEvent(evdef.name);
	end;
	_blizzEventDeactivate = function(disp, evdef)
		-- TODO: Temporary bugfix due to Blizzard 1.8 patch bug
		--disp.frame:UnregisterEvent(evdef.name);
	end;
	
	-- Register custom events.
	Register = function(evdef)
		if VFL.Event._evtbl[evdef.name] then 
			VFL.debug("Event " .. evdef.name .. " was registered multiple times.");
			return false;
		end
		VFL.Event._evtbl[evdef.name] = evdef;
	end;
	RegisterNamed = function(name, evdef)
		evdef.name = name;
		return VFL.Event.Register(evdef);
	end;


};

-- Create a new event dispatcher.
function VFL.Event.Dispatcher:new(o)
	local d = o or {};
	d.frame = nil; -- Frame that Blizzard events will autobind to, if registered with this dispatcher.
	d.table = {}; -- Dispatch table.
	d.eventDef = {}; -- Event defs table.

	-- Finalize dispatch object
	setmetatable(d, self);
	self.__index = self;
	return d;
end;

-- Raise an event by name.
function VFL.Event.Dispatcher:RaiseByName(ev)
	if not self.table[ev] then return; end
	for _,x in self.table[ev] do
		x.callback(self, self.eventDef[ev]);
	end
end;

-- Create a named binding.
function VFL.Event.Dispatcher:NamedBind(name, ev, callback)
	-- If we have no current bindings to this event, activate the event.
	if not self.table[ev.name] then
		self.table[ev.name] = {}; -- Create a new table entry
		if(ev.activate) then ev.activate(self, ev); end -- Activate the event, if it has an activation function.
	end;
	-- Add the binding to the table
	table.insert(self.table[ev.name], {bind = name; callback = callback;});
	-- Set the event def
	self.eventDef[ev.name] = ev;
end;

-- Create an anonymous binding.
function VFL.Event.Dispatcher:Bind(ev, callback)
	self:NamedBind("", ev, callback);
end;

-- Deactivate an event, if nothing is bound to it.
function VFL.Event.Dispatcher:_tryDeactivate(evdef)
	if not evdef then return; end
	-- Check if bindings for this event are empty.
	if (not self.table[evdef.name]) or (table.getn(self.table[evdef.name]) == 0) then
		-- If so, deactivate the event
		if(evdef.deactivate) then evdef.deactivate(self, evdef); end
		-- Remove the event def from the local cache
		self.eventDef[evdef.name] = nil;
		-- Nil out table entry for this event.
		self.table[evdef.name] = nil;
	end
end;

-- Unbind by name.
function VFL.Event.Dispatcher:NamedUnbind(name)
	-- Iterate over entire binds table
	for ev,_ in self.table do
		-- Filter, keeping only the bindings whose name do not match the given one.
		-- Keep before/after counts so we can determine how many were removed.
		local oldn = table.getn(self.table[ev]);
		self.table[ev] = VFL.filter(self.table[ev], function(x) return (x.bind ~= name); end);
		local newn = table.getn(self.table[ev]);
		-- If some bindings were removed, see if we can deactivate
		if(oldn ~= newn) then
			self:_tryDeactivate(self.eventDef[ev]);
		end
	end
end;

-- Determine if a name is bound
function VFL.Event.Dispatcher:IsBound(name)
	-- Foreach bound event
	for ev,_ in self.table do
		-- Foreach binding
		for _,x in self.table[ev] do
			-- If the name is equal, earlyout true
			if(x.bind == name) then return true; end
		end
	end
	return false;
end;

-- Unbind all events, essentially resetting the dispatcher altogether.
function VFL.Event.Dispatcher:UnbindAll()
	for ev,_ in self.table do
		self.table[ev] = nil;
		self:_tryDeactivate(ev);
	end
	self.table = {};
	self.eventDef = {};
end;

-- Set the frame for Blizzard events to bind to.
function VFL.Event.Dispatcher:SetFrame(f)
	self.frame = f;
end;

------------------------
-- Create the VFL root dispatcher
------------------------
--VFLEvent = VFL.Event.Dispatcher:new();
--VFLEvent:SetFrame(VFLRoot);
