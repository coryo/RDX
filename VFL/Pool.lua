-- Pool.lua
-- VFL - Venificus' Function Library
-- (C)2006 Bill Johnson (Venificus of Eredar server)
-- 
-- Generalized pool class, and frame pool libraries taking advantage of it.
--

------------------------------------------------------
-- @class VFL.Pool
-- 
-- A generalized pool of objects, with primitives for acquiring items from the pool
-- and releasing items into the pool.
--
-- Each Pool can additionally have event handlers bound onto it in the forms of
-- functions assigned to slots on the pool object. The following are available:
--
-- pool:OnAcquire(obj) - Called on obj when obj is acquired from the pool by a client.
-- pool:OnRelease(obj) - Called on obj when obj is released into the pool by a client.
-- pool:OnFallback() - Called when :Acquire fails to acquire an object from the actual pool. Should return a new object which will be subsequently added to the pool.
------------------------------------------------------
VFL.Pool = {};
VFL.Pool.__index = VFL.Pool;

--- Construct a new, empty pool
function VFL.Pool:new()
	local self = {};
	setmetatable(self, VFL.Pool);
	self.pool = {}; 
	self.name = "(anonymous)"; self.fallbacks = 0;
	self.Releaser = function(obj) self:Release(obj); end
	return self;
end

-- VFL kernel hooks
function VFL.Pool:KGetObjectName()
	return self.name;
end
function VFL.Pool:KGetObjectInfo()
	return "Sz " .. self:GetSize() .. " Fallbacks " .. self.fallbacks;
end

-- Get the current size of the pool
function VFL.Pool:GetSize()
	return table.getn(self.pool);
end

-- Acquire an object, removing it from this pool.
function VFL.Pool:Acquire()
	-- Attempt to get a pooled object
	local obj = table.remove(self.pool);
	
	-- If we couldn't get the object...
	if not obj then
		-- If we have a fallback...
		if(self.OnFallback) then
			-- Try for a fallback...
			obj = self:OnFallback();
			if obj then
				-- Fallback successful.
				self.fallbacks = self.fallbacks + 1;
			else
				return nil;
			end
		else
			return nil;
		end -- if(self.onFallback)
	end -- if not obj
	
	-- We successfully acquired an object; return it.
	if(self.OnAcquire) then self:OnAcquire(obj); end
	return obj;
end

-- Release an object into this pool.
function VFL.Pool:Release(o)
	if self.OnRelease then self:OnRelease(o); end
	if(o.OnRelease) then o.OnRelease(o, self); o.OnRelease = nil; end
	table.insert(self.pool, o);
end

-- Get the n'th object from this pool, resizing if necessary until there are n objects.
function VFL.Pool:Get(i)
	return self.pool[i];
end

-- Empty out the pool, calling the optional destructor function for each object in the pool.
function VFL.Pool:Empty(destr)
	if not destr then destr = VFL.Noop; end
	for _,obj in self.pool do destr(obj); end
	self.pool = {}; self.fallbacks = 0;
end

-- Shunt the pool. Destroys the pool's current contents, prevents future acquisitions,
-- and runs all future releases through the provided destructor.
function VFL.Pool:Shunt(destr)
	if not destr then destr = VFL.Noop; end
	for _,obj in self.pool do destr(obj); end
	self.pool = nil; self.fallbacks = 0;
	self.OnAcquire = nil; self.Acquire = VFL.Nil; self.Get = VFL.Nil;
	self.GetSize = VFL.Zero; self.Empty = VFL.Noop; self.Fill = VFL.Noop;
	self.OnRelease = nil; self.Release = function(s,o) destr(o); end
end

-- Fill a pool with global objects having a given prefix.
function VFL.Pool:Fill(pfx)
	local i = 1;
	while(true) do
		local pe = getglobal(pfx .. i);
		if not pe then break; end
		self:Release(pe);
		i = i + 1;
	end
end

