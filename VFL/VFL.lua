-- VFL.lua
-- Venificus' Function Library
-- (C)2005-2006 Bill Johnson (Venificus of Eredar server)

--- The root World of Warcraft event dispatcher
WoWEvents = DispatchTable:new();
WoWEvents.name = "WoWEvents";
WoWEvents:BindToWoWFrame(VFLRoot);
VFLKernelRegisterObject("DispatchTable", WoWEvents);

--- The VFL root event dispatcher.
VFLEvents = DispatchTable:new();
VFLEvents.name = "VFLEvents";

-- COMPAT: Backward compatibility with VFLEvent
VFLEvent = {};
function VFLEvent:NamedBind(name, ev, callback)
	WoWEvents:Bind(ev, nil, callback, name);
end

function VFLEvent:Bind(ev, callback)
	WoWEvents:Bind(ev, nil, callback);
end

function VFLEvent:NamedUnbind(name)
	WoWEvents:Unbind(name);
end

function BlizzEvent(x) return x; end
