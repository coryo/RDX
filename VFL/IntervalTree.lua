-- IntervalTree.lua
-- VFL - Venificus' Function Library
-- (C)2005 Bill Johnson (Venificus of Eredar serveR)
--
-- An "interval tree" is a data structure that stores a set of intervals of the real line of the form [x1, x2].
-- It is designed to efficiently answer queries of the form "Which interval does the point p lie in?" It is
-- a red-black tree, augmented with some additional information.
--
-- Each node of an interval tree has a left, right, parent, and color.
-- As each node represents an interval, there are low and high numerical fields associated to it.
-- In addition, the node has a gub (greatest upper bound) field as an intermediary.
if not VFL.IntervalTree then VFL.IntervalTree = {}; end
VFL.IntervalTree.__index = VFL.IntervalTree;

-- Create a new, empty interval tree.
function VFL.IntervalTree:new(min, max)
	local self = {};
	setmetatable(self, VFL.IntervalTree);

	-- Create the "sentinel node" for the tree
	local sentinel = {};
	sentinel.left = sentinel; sentinel.right = sentinel; sentinel.parent = sentinel;
	sentinel.low = min; sentinel.high = min; sentinel.gub = min;
	sentinel.red = false;
	self.sentinel = sentinel;

	-- Create the "root node" for the tree
	local root = {};
	root.left = sentinel; root.right = sentinel; root.parent = sentinel;
	root.low = max; root.high = max; root.gub = max;
	root.red = false;
	self.root = root;

	-- Return the new tree
	return self;
end


-- Perform left rotation on node x.
-- Moves x.parent to x.left, lifts x to x.parent, and fixes other poiners accordingly.
-- Also updates the internal max fields.
function VFL.IntervalTree:LeftRotate(x)
	local y, sentinel = x.right, self.sentinel;
	x.right = y.left;

	if(y.left ~= sentinel) then y.left.parent = x; end

	y.parent = x.parent;

	if(x == x.parent.left) then
		x.parent.left = y;
	else
		x.parent.right = y;
	end
	y.left = x;
	x.parent = y;

	x.gub = math.max(x.left.gub, x.right.gub, x.high);
	y.gub = math.max(x.high, y.right.gub, y.gub);
end

-- Perform right rotation on node y.
function VFL.IntervalTree:RightRotate(y)
	local x, sentinel = y.left, self.sentinel;
	y.left = x.right;
	
	if(sentinel ~= x.right) then x.right.parent = y; end

	x.parent = y.parent;

	if(y == y.parent.left) then
		y.parent.left = x;
	else
		y.parent.right = x;
	end
	x.right = y; y.parent = x;

	y.gub = math.max(y.left.gub, y.right.gub, y.high);
	x.gub = math.max(x.left.gub, y.gub, x.high);
end

-- Insert helper function. Treats the tree as a regular binary tree.
function VFL.IntervalTree:InsertHelper(z)
	local sentinel, root = self.sentinel, self.root;
	local x,y = root.left, root;
	-- For starters, the node is nowhere.
	z.left = sentinel; z.right = sentinel;
	-- Traverse down
	while(x ~= sentinel) do
		y = x;
		if(x.low > z.low) then -- Current node's value is bigger than desired, move left
			x = x.left;
		else -- Current node's value is smaller than desired, move right
			x = x.right;
		end
	end
	-- We found our parent node
	z.parent = y;
	-- Associate us as the proper child to our parent
	if( (y == root) or (y.low > z.low) ) then
		y.left = z;
	else
		y.right = z;
	end
end

-- GUB fixer function. Fixes the greatest-upper-bound field of all nodes between
-- us and the root.
function VFL.IntervalTree:FixGUB(x)
	local root = self.root;
	-- Traverse up
	while(x ~= root) do
		x.gub = math.max(x.high, x.left.gub, x.right.gub);
		x=x.parent;
	end
end

-- Insert an interval with the given endpoints.
function VFL.IntervalTree:Insert(low, high)
	local x,y,new;

	-- Create the new node
	x = {};
	x.low = low; x.high = high;
	-- Standard insert phase
	self:InsertHelper(x);
	self:FixGUB(x);
	new = x; x.red = true;
	-- Rebalancing phase
	while(x.parent.red) do
		if(x.parent == x.parent.parent.left) then
			y = x.parent.parent.right;
			if y.red then
				-- Recolor
				x.parent.red = false; y.red = false; x.parent.parent.red = true;
				-- Recurse
				x = x.parent.parent;
			else
				if(x == x.parent.right) then
					x = x.parent; self:LeftRotate(x);
				end
				x.parent.red = false; x.parent.parent.red = true;
				self:RightRotate(x.parent.parent);
			end
		else -- parent = parent.parent.right, similar but reversed polarity
			y = x.parent.parent.left;
			if(y.red) then
				x.parent.red = false; x.red = false; x.parent.parent.red = true;
				x = x.parent.parent;
			else
				if(x == x.parent.left) then
					x = x.parent; self:RightRotate(x);
				end
				x.parent.red = false; x.parent.parent.red = true;
				self:LeftRotate(x.parent.parent);
			end
		end
	end
	self.root.left.red = false;

	-- Return the newly created node
	return new;
end

-- Get the successor of the given node, or null if none exists.
function VFL.IntervalTree:GetSuccessorOf(x)
	local y, sentinel = x.right, self.sentinel;
	if(y ~= sentinel) then
		while(y.left ~= sentinel) do y=y.left; end
		return y;
	else
		y = x.parent;
		while(x == y.right) do x = y; y = y.parent; end
		if(y == self.root) then return nil; end
		return y;
	end
end

-- Get the predecessor of the given node, or null if none exists.
function VFL.IntervalTree:GetPredecessorOf(x)
	local y, sentinel, root = x.left, self.sentinel, self.root;
	if(y ~= sentinel) then
		while(y.right ~= sentinel) do y=y.right; end
		return y;
	else
		y = x.parent;
		while(x == y.left) do
			if(y == root) then return nil; end
			x = y; y = y.parent; 
		end
		return y;
	end
end

-- Traverses the tree in order, calling func(tree, node) each time.
function VFL.IntervalTree:InorderTraversal(func)
	self:RInorderTraversal(self.root.left, func);
end
function VFL.IntervalTree:RInorderTraversal(node, func)
	if(node ~= self.sentinel) then
		self:RInorderTraversal(node.left, func);
		func(self, node);
		self:RInorderTraversal(node.right, func);
	end
end

-- Dump the tree
function VFL.IntervalTree:Dump()
	self:InorderTraversal(function(tree, node)
		VFL.debug("[" .. node.low .. "," .. node.high .. "] gub " .. node.gub, 1);
		local str = "  PARENT: ";
		if(node.parent == tree.sentinel) then str = str .. "nil"; else str = str .. node.parent.low; end
		VFL.debug(str);
		local str = "  LEFT: ";
		if(node.left == tree.sentinel) then str = str .. "nil"; else str = str .. node.left.low; end
		VFL.debug(str);
		local str = "  RIGHT: ";
		if(node.right == tree.sentinel) then str = str .. "nil"; else str = str .. node.right.low; end
		VFL.debug(str);
	end);
end
