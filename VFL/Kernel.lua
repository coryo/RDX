-- Kernel.lua
-- VFL
-- (C)2006 Bill Johnson
--
-- Main code for the VFL kernel and module system.

-- Kernel start time
local kStartTime = GetTime();
local mathdotfloor = math.floor;
local blizzGetTime = GetTime;

-- Get the OS time when the kernel started.
function VFLKernelGetStartTime()
	return kStartTime;
end

-- Get the time since session start.
function VFLKernelGetTime()
	return GetTime() - kStartTime;
end

-- Get the time since session start, rounded to the tenths place.
function VFLKernelGetTimeTenths()
	return mathdotfloor((blizzGetTime() - kStartTime) * 10) / 10;
end

--- Debugger object
-- A debugger object is an interface to a system for printing VFL module debug
-- messages.
-- @field Print A function taking arguments (src, txt), where src is a string
-- indicating the source of data and txt is a string of debug data. The
-- function should render the data as appropriate.
VFL_debugger = {
	Print = function(src, txt)
		ChatFrame1:AddMessage(tostring("[" .. src .. "] " .. txt), NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
	end
};

--- Change the system debugger.
-- This can be used to differently direct debug output.
-- @param dbg A table representing the new system debugger.
function VFLSetDebugger(dbg)
	VFL_debugger = dbg;
end

-- Module-level debugging function
function VFL_DebugPrint(refLevel, level, annot, txt)
	if txt and ((not level) or (refLevel > level)) then
		VFL_debugger.Print(annot .. tostring(level), txt);
	end
end

-- Kernel objects
local kobj = {};
local kcat = {};

--- Create a new category of VFL kernel objects.
-- @param catName The string name of the new category.
function VFLKernelRegisterCategory(catName)
	local cat = {};
	local catEntries = {};
	cat.KGetObjectName = function() return catName; end
	cat.KGetObjectInfo = function() return "", catEntries; end
	cat.Add = function(cat, x) table.insert(catEntries, x); end
	kcat[catName] = cat;
end

--- Register an object as a VFL kernel object.
-- @param catName The category of kernel objects to place the object under.
-- @param obj The kernel object.
function VFLKernelRegisterObject(catName, obj)
	if (not obj) or (not kcat[catName]) then return; end
	kcat[catName]:Add(obj);
end

local function _PrintStatus(oblist, indent)
	for _,ob in pairs(oblist) do
		local str = ob:KGetObjectName();
		local inf, sub = ob:KGetObjectInfo();
		Root:Debug(nil, indent .. str .. " [" .. tostring(inf) .. "]");
		if sub then
			_PrintStatus(sub, indent .. "*");
		end
	end	
end

--- Print the status of all VFL kernel objects.
function VFLKernelPrintStatus()
	Root:Debug(nil, "--- KERNEL STATUS DUMP");
	local l = {};
	for _,ob in pairs(kcat) do
		table.insert(l, ob);
	end
	_PrintStatus(l, "");
	Root:Debug(nil, "--- END KERNEL STATUS DUMP");
end

----------------------------------------------
-- MODULE OBJECT
----------------------------------------------
if not Module then 
	Module = {}; 
else
	error("VFL: Module class already exists. Load aborted.");
end

Module.__index = Module;

Module.noop = function() end;

--- Create a new module.
-- @param x An optional base object to imbue with Modulehood.
function Module:new(x)
	-- Verify and create
	if not x.name then error("cannot create a module with no name"); end
	local self = x or {};
	
	-- Patriate this module
	self.children = {};
	if not self.parent then self.parent = Root; end
	self.parent:ModuleAddChild(self);
	-- Initial debug functionality: do nothing
	self.Debug = Module.noop;
	-- Setup
	setmetatable(self, Module);
	return self;
end

--- Get all children of this module.
-- @return A list of children of this module.
function Module:ModuleGetChildren()
	return self.children;
end

--- Add a child module
-- @param x The Module object of the child module.
function Module:ModuleAddChild(x)
	table.insert(self.children, x);
end

--- Issue a module command
-- @param cmd A string command to be executed on the module, if it exists.
-- The remaining arguments are used as arguments to this command.
function Module:ModuleCommand(cmd, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
	local x = self[cmd];
	-- If the module command exists, execute it
	if x and (type(x)=="function") then x(self, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20); end
end

--- Issue a command to this module's children
function Module:ModuleCommandChildren(cmd, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
	for _,child in self.children do
		child:ModuleCommand(cmd, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20);
	end
end

--- Determine if a module has the given command available.
-- @param cmd The string command to be checked.
-- @return TRUE iff the command exists on this module. Nil otherwise.
function Module:ModuleHasCommand(cmd)
	local x = self[cmd];
	if x and (type(x)=="function") then return true; else return nil; end
end

--- Set the debug level of a module
-- @param n The new numeric debug level for the module. 0 disables debugging
-- for the module.
function Module:ModuleSetDebugLevel(n)
	-- Apply the debug settings
	if (not n) or (n <= 0) then
		self.Debug = Module.noop;
	else
		self.Debug = function(_, lvl, txt) VFL_DebugPrint(n, lvl, self.name, txt); end
	end
	-- Persist the debug settings
	if(self._saved) then
		self._saved.debug = n;
	end
end

--- Recursively list submodules.
-- @param indent The recursion level.
function Module:ModuleListModules(indent)
	local str = "";
	for i=1,indent do str = str .. "  "; end
	Root:Debug(nil, str .. self.name);
	for _,child in self.children do
		child:ModuleListModules(indent + 1);
	end
end

--------------------------------------------
-- ROOT MODULE
--------------------------------------------
Root = {};
Root.children = {};
Root.parent = nil;
Root.name = "Root";
setmetatable(Root, Module);
Root:ModuleSetDebugLevel(0);


--------------------------------------------
-- MODULE DATABASE
--------------------------------------------
VFL_moduledb = {};
VFL_moduledb[Root.name] = Root;

--- Register a new VFL module
-- @param x A table contaning characteristics for the new module. The fields of the table are as follows:
-- @field name The name of the module. (required)
-- @field parent The parent Module of the module. (optional, if not specified, defaults to Root)
-- @field description A text description of the module. (optional)
-- @field version A table of the form {major, minor, release} representing the version of the module. (required)
-- @field devel TRUE iff the module is a development release.
function RegisterVFLModule(x)
	-- Hard reject unnamed modules
	if not x.name then
		error("modules must have name entries");
		return nil;
	end
	Root:Debug(1, "RegisterVFLModule(" .. x.name .. ")");
	-- Soft reject preexisting modules
	if VFL_moduledb[x.name] then
		Root:Debug(1, "RegisterVFLModule(): Multiple registration of name " .. x.name);
		return nil;
	end
	local m = Module:new(x);
	VFL_moduledb[m.name] = m;
	return m;
end

-- When saved variables are loaded, project them onto the modules.
function LoadModuleData()
	Root:Debug(1, "LoadModuleData()");
	if not VFLModuleData then VFLModuleData = {}; end
	-- Foreach module
	for _,m in VFL_moduledb do
		-- Get data from saved var, or create if it doesn't exist
		local md = VFLModuleData[m.name];
		if not md then
			md = {};
			VFLModuleData[m.name] = md;
		end
		-- Map saved variable
		m._saved = md;
		-- Restore persisted debug level
		m:ModuleSetDebugLevel(md.debug);
	end
end

function DebugListVFLModules()
	Root:ModuleListModules(0);
end

-- VFL module
VFL = RegisterVFLModule({
	name = "VFL";
	version = {6,0,1}; devel = true;
	description = "VFL";
});

