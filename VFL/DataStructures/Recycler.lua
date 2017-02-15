-- Recycler.lua
-- VFL
-- (C)2006 Bill Johnson and The VFL Project
--
-- A Recycler is a simple data structure that allows for the reuse of tables.

VFL.Recycler = {};

function VFL.Recycler:new()
	local self = {};

	local rSpace = {};

	--- Empty the Recycler, releasing the previously used tables to be
	-- garbage-collected.
	function self:Empty() rSpace = {}; end

	--- Get an empty table from the Recycler.
	function self:Acquire()
		local ret = table.remove(rSpace);
		if ret then return ret; else return {}; end
	end

	--- Release a table back into the Recycler.
	function self:Release(t)
		VFL.empty(t); table.setn(t, 0); setmetatable(t, nil);
		table.insert(rSpace, t);
	end

	return self;
end
