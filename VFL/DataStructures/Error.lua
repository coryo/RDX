-- Error.lua
-- VFL
-- (C)2006 Bill Johnson and The VFL Project
--
-- A hierarchical error handling scheme.

VFL.Error = {};
VFL.Error.__index = VFL.Error;

function VFL.Error:new()
	local x = {};
	x.count = 0;
	x.context = "(none)";
	setmetatable(x, VFL.Error);
	return x;
end

function VFL.Error:AddError(msg)
	if not self.errors then self.errors = {}; end
	self.count = self.count + 1;
	table.insert(self.errors, self.context .. ":" .. msg);
end

function VFL.Error:SetContext(ctx)
	if ctx then self.context = ctx; else self.context = "(none)"; end
end

function VFL.Error:HasErrors() return (self.count > 0); end

function VFL.AddError(errs, msg)
	if errs then errs:AddError(msg); end
end
