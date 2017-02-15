-- VFL_Deque.lua
-- VFL (Venificus' Function Library)
--
-- Double-ended queue data structure, implemented internally using a Lua array.
-- Also implements helper functions to perform common processing paradigms for queues,
-- such as timed-dequeue-and-process.
if not VFL.Deque then VFL.Deque = {}; end
VFL.Deque.__index = VFL.Deque;

function VFL.Deque:new()
	local x = {};
	x.q = {};
	setmetatable(x, self);
	return x;
end

-- Clear the deque
function VFL.Deque:Clear()
	self.q = {};
end

-- Get the number of entries in the queue
function VFL.Deque:GetSize()
	return table.getn(self.q);
end

-- Standard deque manipulations
function VFL.Deque:PushBack(x)
	table.insert(self.q, x);
end

function VFL.Deque:PopBack()
	table.remove(self.q);
end

function VFL.Deque:PushFront(x)
	table.insert(self.q, 1, x);
end

function VFL.Deque:PopFront()
	return table.remove(self.q, 1);
end

-- Consume entries from either side of the queue
function VFL.Deque:ConsumeFront(n)
	local t = {};
	for i=(n+1),self:GetSize() do
		table.insert(t, self.q[i]);
	end
	self.q = t;
end

