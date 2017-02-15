-- Primitives.lua
-- VFL - Venificus' Function Library
-- (C) 2005-2006 Bill Johnson (Venificus of Eredar server)
--
-- Contains various useful primitive operations on functions, strings, and tables.
--
-- Notational conventions are:
-- STRUCTURAL PARAMETERS
--    T is a table. k,v indicate keys and values of T respectively
--    A is an array (table with positive integer keys)
--		L is a list (table with keys ignored) L' < L indicates the sublist relation.
-- FUNCTION PARAMETERS:
--    b is a single-argument boolean predicate on an applicable domain (must return true/false)
--    f is a function to be specified.
-- OTHER PARAMETERS:
--    x is an arbitrary parameter.

---------------------------------
-- VFL VERSIONING AND METADATA
---------------------------------
VFL.v_major = 2;
VFL.v_minor = 3;
VFL.v_revision = 1;

function VFL.GetVersionString()
	return VFL.v_major .. "." .. VFL.v_minor .. "." .. VFL.v_revision;
end

function VFL.RequireVersion(major, minor, app)
	if(VFL.v_major ~= major) or (VFL.v_minor < minor) then
		VFL.print("*** WARNING ***");
		VFL.print("Version " .. major .. "." .. minor .. " of VFL is required to run the application entitled '".. tostring(app) .."'. You are running version " .. VFL.GetVersionString() .. " of VFL. Please download and install the appropriate version.");
		VFL.print("*** WARNING ***");
		return false;
	else
		return true;
	end
end

-- DEBUG VERBOSITY
VFL._dv = 0;

------------------------------------
-- PRIMITIVE FUNCTIONS
------------------------------------
-- Constant functions
function VFL.Noop() end
function VFL.True() return true; end
function VFL.False() return false; end
function VFL.Zero() return 0; end
function VFL.One() return 1; end
function VFL.Nil() return nil; end

-- Constant empty table.
VFL.emptyTable = {};

------------------------------------
-- SUPPLEMENTAL LUA OPS
------------------------------------
-- math.mod is broken on negative dividends
-- Here is a fixed version
function VFL.mod(k, n)
	return k - math.floor(k/n)*n;
end

function VFL.modf(x)
	local fx = math.floor(x);
	return fx, (x - fx);
end

-- Quick and dirty rounding
function VFL.round(x)
	local i,f = VFL.modf(x);
	if(f > 0.5) then return i+1; else return i; end
end

-- Are two numbers "close?" (within an epsilon distance)
function VFL.close(x, y)
	return (math.abs(x-y) < 0.000001);
end

-- Constrain a number to lie between certain boundaries.
function VFL.clamp(n, min, max)
	if (not n) or (not (type(n) == "number")) then return min; end
	if(n < min) then return min; elseif(n > max) then return max; else return n; end
end

------------------------------------
-- OPERATIONS ON TABLES
------------------------------------
-- isempty
-- Returns true iff the table T has no entries whatsoever.
function VFL.isempty(T)
	for k,v in pairs(T) do return false; end
	return true;
end

-- empty
-- Nils out all entries of T
function VFL.empty(T)
	for k,v in pairs(T) do T[k] = nil; end
	table.setn(T,0);
end

-- tsize
-- Return the actual size of the table T.
function VFL.tsize(T)
	local i = 0;
	for _,_ in T do i = i + 1; end
	return i;
end

-- keys
-- Returns an array containing the unique keys of the table T
function VFL.keys(T)
	if(T == nil) then return nil; end
	local ret = {};
	for k,v in pairs(T) do table.insert(ret, k); end
	return ret;
end

-- filteredIterator
-- Returns a pairs()-type iterator function over the given table that only returns
-- entries that match the given filter f(k,v).
function VFL.filteredIterator(T, f)
	local k = nil;
	return function()
		local v;
		k,v = next(T,k);
		while k and (not f(k,v)) do k,v = next(T,k); end
		return k,v;
	end;
end

-- copy
-- Creates an identical, deep copy of T
function VFL.copy(T)
	if(T == nil) then return nil; end
	local out = {};
	local k,v;
	for k,v in pairs(T) do
		if type(v) == "table" then
			out[k] = VFL.copy(v); -- deepcopy subtable
		else
			out[k] = v; -- softcopy primitives
		end
	end
	return out;
end

-- copyInto
-- Copies T[k] into D[k] for all k in keys(T)
-- T is unchanged, and all other entries of D are unchanged.
function VFL.copyInto(D, T)
	if(T == nil) then return false; end
	for k,v in pairs(T) do
		if type(v) == "table" then D[k] = VFL.copy(v); else D[k] = v; end
	end
	return true;
end

-- collapse
-- Sets to nil all entries of D that do not have a corresponding
-- entry in T, i.e. if T[k] == nil then D[k] will be made nil.
-- T is unchanged.
function VFL.collapse(D, T)
	if(T == nil) then return false; end
	for k,_ in pairs(D) do
		if T[k] == nil then D[k] = nil; end
	end
	return true;
end

-- copyOver
-- Makes the table referenced by D identical to the table referenced by T.
-- T is unchanged.
function VFL.copyOver(D, T)
	return (VFL.copyInto(D,T) and VFL.collapse(D,T));
end;

-- vfind
-- Returns k such that T[k] == v, or nil if no such k exists.
function VFL.vfind(T, v)
	if not T then return nil; end
	for k,val in T do
		if val == v then return k; end
	end
	return nil;
end

-- vmatch
-- Returns k,T[k] such that b(T[k]), or nil if no such k exists.
function VFL.vmatch(T, b)
	if not T then return nil; end
	for k,val in T do
		if b(val) then return k,val; end
	end
	return nil;
end

-- vremove
-- Locates the first i such that L[i] = v, then removes it, returning v.
function VFL.vremove(L, v)
	local n = table.getn(L);
	for i=1,n do if L[i] == v then return table.remove(L,i); end end
	return nil;
end

-- filter
-- Returns new L' < L with b(x) true for all x in L'
function VFL.filter(L, b)
	if not L then return nil; end
	local tmp = {};
	for _,v in L do
		if b(v) then table.insert(tmp, v); end
	end
	return tmp;
end

-- filterInPlace
-- Modifies L, removing all elements for which b(x) is false.
function VFL.filterInPlace(L, b)
	if (not L) or (not b) then return nil; end
	local n,i = table.getn(L),1;
	while (i <= n) do
		if b(L[i]) then i=i+1; else table.remove(L,i); n=n-1; end
	end
end

-- invert
-- Returns a table T' whose keys are the values of T and whose values are corresponding keys.
-- This function is invalid for inputs T with duplicated values.
function VFL.invert(T)
	if(T == nil) then return nil; end
	local ret = {};
	for k,v in pairs(T) do ret[v] = k; end
	return ret;
end

-- transform
-- Return a table T' whose pairs are related to pairs of T by (k',v')=f(k,v).
-- f is a two-argument function valid on the pairs of T
function VFL.transform(T, f)
	if(T == nil) then return nil; end
	local ret = {};
	local kp, vp;
	for k,v in T do
		kp,vp = f(k,v);
		ret[kp] = vp;
	end
	return ret;
end

-- asize
-- Forces the indices of the array A to be valid for the range [1..n]. Any indices outside of this range
-- are quashed, and any indices inside this range that are missing are added, with the given default value.
function VFL.asize(A, n, default)
	if(A == nil) then return; end
	local k,i;
	for k,_ in ipairs(A) do
		if(k>n) then A[k] = nil; end
	end
	for i=1,n do
		if not A[i] then A[i] = default; end
	end
end

-- asizeup
-- Like asize, only will not quash entries beyond the end.
function VFL.asizeup(A, n, default)
	if(A == nil) then return; end
	for i=1,n do
		if not A[i] then A[i] = default; end
	end
end

-- GENERALIZED SUM
-- Collapses a table along its rows, by identifying certain rows
-- as being in certain equivalence classes, then accumulating over those
-- classes.
--
-- General algorithm:
--  Foreach row R in iterator:
--   Identify similarity class of row R sc(R) [via fnClassify(R)]
--   Get the representative row rep(sc(R)), creating if nonexistent [via fnGenRep(R)]
--   rep(sc(R)) <-- rep(sc(R)) + R [via fnAddInPlace(rep, R)]
--
-- Details of arguments:
--  * ri must be a Lua iterator that returns tables to be regarded as rows.
--  * fnClassify(R) must take a row and return a classification of that row, or nil if the row is to
--  be ignored. The classification function may split the row into up to 5 separate categories, each of which
--  must be returned.
--  * fnGenRep(R, class) must take a row and its class and generate a representative row suitable for fnAddInPlace.
--  * fnAddInPlace(Rrep, R) must set Rrep=Rrep+R.
--
-- Returns:
--  The cumulated representatives of each row class.
-- 
-- Usage:
--  Given a time series of events (hits with damage, for example) one might want to classify each type of hit
--  (Eviscerate, Sinister Strike, etc) and arrive at a final table describing each TYPE of hit and the TOTAL
--  or AVERAGE damage over that type. If fnClassify were a projection onto the hit-type axis, and
--  fnAddInPlace was a sum or average cumulator, this function would perform this task.
-- 
function VFL.gsum(ri, fnClassify, fnGenRep, fnAddInPlace)
	-- Begin afresh
	local reps, classify = {}, {};
	-- Foreach row
	for R in ri do
		-- Attempt to classify row
		local c1, c2, c3, c4, c5 = fnClassify(R);
		-- If class is nil, ignore, otherwise proceed.
		if c1 then
			classify[1] = c1; classify[2] = c2; classify[3] = c3; classify[4] = c4; classify[5] = c5;
			-- For each classification...
			for _,rclass in classify do
				-- Obtain representative row, creating one if none exists
				local rrep = reps[rclass];
				if not rrep then reps[rclass] = fnGenRep(R, rclass); rrep = reps[rclass]; end
				-- Add this row to the representative row, in place (i.e. rrep <-- rrep + R)
				if rrep then fnAddInPlace(rrep, R, rclass); end
			end -- for _,rclass in classify
		end -- if c1
	end -- for R in ri
	-- Return the representative rows.
	return reps;
end

----------------------------------
-- OPERATIONS ON FUNCTIONS
----------------------------------
--- If f is a function, return f evaluated at the arguments, otherwise return f
function VFL.call(f, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
	if type(f) == "function" then return f(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20); else return f; end
end

--- Wrap a "method invocation" on an object into a portable closure.
function VFL.WrapInvocation(obj, meth)
	if obj then
		return function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20) 
			return meth(obj, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20); 
		end
	else
		return meth;
	end
end

--- Create a simple hook.
-- @param fnBefore The function to call first in the hook chain.
-- @param fnAfter The function to call second in the hook chain.
-- @return The new hook chain.
function VFL.hook(fnBefore, fnAfter)
	-- If one of the hooks is invalid, just return the other.
	if (not fnBefore) then
		return fnAfter;
	elseif (not fnAfter) then
		return fnBefore;
	end
	-- Otherwise generate the hook.
	return function(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20)
		fnBefore(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20);
		fnAfter(a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, a17, a18, a19, a20);
	end
end



-----------------------------------
-- OPERATIONS ON STRINGS
-----------------------------------
-- Convert nil to the empty string
function VFL.nonnil(str)
	return (str or "");
end

-- A "flag string" is a string where the presence of a character indicates the
-- truth of a property
-- Check if a flag string contains a given flag.
function VFL.checkFlag(str, flag)
	if(str == nil) then return false; end
	return string.find(str, flag, 1, true);
end

-- Set a flag in the given flag string.
function VFL.setFlag(str, flag)
	if(str == nil) then return flag; end
	if VFL.checkFlag(str,flag) then return str; else return str .. flag; end
end

-- Get the first space-delimited word from the given string
-- (word, rest) = VFL.word(str)
function VFL.word(str)
	if(str == nil) or (str == "") then return nil; end
	local i = string.find(str, " ", 1, true);
	if(i == nil) then return str, ""; end
	return string.sub(str, 1,  i-1), string.sub(str, i+1, -1);
end

-- Capitalize the first letter of a string
function VFL.capitalize(str)
	return string.gsub(str, "^%l", string.upper);
end

-- Trim all leading and trailing whitespace from a string
function VFL.trim(str)
	if not str then return nil; end
	_,_,str = string.find(str,"^%s*(.*)");
	if not str then return ""; end
	_,_,str = string.find(str,"(.-)%s*$");
	if not str then return ""; end
	return str;
end

-- Determines if the string is a valid identity, that is, pure alphanumerics, dashes, and underlines
function VFL.isValidIdentity(str)
	if not str then return false; end
	if string.find(str,"^[%w_-]*$") then return true; else return false; end
end

-- Determines if the string is a valid name (alphanumeric followed by alpha/space followed by alpha)
function VFL.isValidName(str)
	if not str then return false; end
	if string.find(str,"^%w[%w%s]*%w$") then return true; else return false; end
end

--------------------------------------------------
-- WOW COLORS
--------------------------------------------------
if not VFL.Color then VFL.Color = {}; end
VFL.Color.__index = VFL.Color;

-- Construct a new color on the given object.
function VFL.Color:new(o)
	x = o or {};
	setmetatable(x, VFL.Color);
	return x;
end

-- Clone this color, returning a newly allocated identical color.
function VFL.Color:clone()
	return VFL.Color:new({r=self.r, g=self.g, b=self.b, a=self.a});
end

-- Copy from the target color into this color
function VFL.Color:set(target)
	self.r = target.r; self.g = target.g; self.b = target.b; self.a = target.a;
end

-- Blend this color via interpolation between two colors.
function VFL.Color:blend(c1, c2, t)
	local d = 1-t;
	self.r = d*c1.r + t*c2.r;
	self.g = d*c1.g + t*c2.g;
	self.b = d*c1.b + t*c2.b;
end

-- Validate the color, collapsing any negative values to zero
function VFL.Color:validate()
	if(self.r < 0) then self.r = 0; end
	if(self.g < 0) then self.g = 0; end
	if(self.b < 0) then self.b = 0; end
end

-- Get the WOW text formatting string corresponding to this color
function VFL.Color:GetFormatString()
	return format("|cFF%02X%02X%02X", math.floor(self.r*255), math.floor(self.g*255), math.floor(self.b*255));
end

-- Colorize the given string with this color
function VFL.Color:colorize(str)
	return self:GetFormatString() .. str .. "|r";
end

function strcolor(r,g,b)
	return format("|cFF%02X%02X%02X", math.floor(r*255), math.floor(g*255), math.floor(b*255));
end

function strtcolor(t)
	local r,g,b = math.floor(t.r*255), math.floor(t.g*255), math.floor(t.b*255);
	return format("|cFF%02X%02X%02X", r, g, b);
end

function explodeColor(rgb)
	return rgb.r, rgb.g, rgb.b;
end

-- Global temporary color, used to reduce memory allocations during
-- blend ops
tempcolor = VFL.Color:new();

----------------------------------------------
-- BASIC IO
----------------------------------------------
-- Print a single line to the chat window.
function VFL.print(str)
	if(str == nil) then return; end
	ChatFrame1:AddMessage(str, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b);
end

-- Print a single line in the center of the screen.
function VFL.cprint(str)
	if(str == nil) then return; end
	UIErrorsFrame:AddMessage(str, RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b, 1.0, UIERRORS_HOLD_TIME);
end

-- Print a string for debugging at the given verbosity level.
function VFL.debug(str, level)
	if(not level) or (VFL._dv > level) then
		VFL.print("[Debug] " .. str);
	end
end

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
	local dsFunc = loadstring("return " .. data);
	if dsFunc then 
		-- Prevent the deserialization function from making external calls
		setfenv(dsFunc, {});
		-- Call the deserialization function
		return dsFunc(); 
	else 
		return nil; 
	end
end


------------------------------------------------
-- WoW UI related
------------------------------------------------

--- Determine if an event is a WoW game initialization event.
-- @param ev The event to check.
-- @return TRUE iff the event is a WoW init event.
local ietbl = {};
ietbl["ADDON_LOADED"] = true;
ietbl["VARIABLES_LOADED"] = true;
ietbl["SPELLS_CHANGED"] = true;
ietbl["PLAYER_LOGIN"] = true;
ietbl["PLAYER_ENTERING_WORLD"] = true;
ietbl["PLAYER_LEAVING_WORLD"] = true;

function VFL.IsGameInitEvent(ev)
	return ietbl[ev];
end
