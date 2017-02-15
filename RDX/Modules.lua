-- Modules.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
-- 
-- Module management.
VFL.debug("[RDX5] Loading Modules.lua", 2);

if not RDXM then RDXM = {}; end

---------------------------------------------
-- MODULE OBJECT
---------------------------------------------
if not RDX.Module then RDX.Module = {}; end
RDX.Module.__index = RDX.Module;

function RDX.Module:HasMenu()
	if self.Menu then return true; else return false; end
end

function RDX.Module:DoMenu(tree, anchorFrame)
	self:Menu(tree, anchorFrame);
end

---------------------------------------------
-- MODULE DB
---------------------------------------------
if not RDX.Modules then RDX.Modules = {}; end
function RDX.Modules.Init()
	VFL.debug("RDX.Modules.Init()", 2);
	RDX.Modules.Command("Init");
end

function RDX.Modules.DeferredInit()
	RDX.Modules.Command("DeferredInit");
end

function RDX.Modules.Command(cmd, ...)
	for i=1,table.getn(RDX.modules) do
		local mod = RDX.modules[i];
		if mod[cmd] then
			VFL.debug("Commanding module " .. mod.name .. ": " .. cmd, 10);
			mod[cmd](RDX.modules[i], unpack(arg));
		end
	end
end

RDX.modules = {};
RDX.modulesNamed = {};

-- Register a new module
function RDX.RegisterModule(tbl)
	VFL.debug("RDX.RegisterModule("..tbl.name..")", 5);
	-- Don't allow reregistration
	if RDX.modulesNamed[tbl.name] then
		VFL.debug("Reregistration of module name: " .. tbl.name);
		return;
	end
	-- Imbue with functionality
	setmetatable(tbl, RDX.Module);
	-- Add to module tables
	table.insert(RDX.modules, tbl);
	RDX.modulesNamed[tbl.name] = tbl;
	-- Return newly created module
	return tbl;
end

