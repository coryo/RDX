-- Filter.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Supporting code for custom filter generation
--


---------------------------------------
-- SUPPORTING CODE FOR FILTER CONFIG DLG
---------------------------------------
-- Onload for class check boxes
function RDX.FilterCCOnLoad(this)
	local c = RDX.classes[this:GetID()]; 
	this:Setup(VFL.capitalize(c.name)); 
	CC_ColorFromTbl(this, c.color);
end

-- Map type to type button text
function RDX.TypeToButton(ty, btn)
	if(ty == 1) then
		btn:SetText("%");
	elseif(ty == 2) then
		btn:SetText("#");
	elseif(ty == 3) then
		btn:SetText("%M");
	else
		btn:SetText("#M");
	end
end

function RDX.TypeFromButton(btn)
	local t = btn:GetText();
	if(t == "%") then
		return 1;
	elseif(t == "#") then
		return 2;
	elseif(t == "%M") then
		return 3;
	else
		return 4;
	end
end

-------------------------
-- FILTER DESCRIPTOR
-- Describes a simple custom filter.
-------------------------
if not RDX.FilterDesc then RDX.FilterDesc = {}; end
RDX.FilterDesc.__index = RDX.FilterDesc;

function RDX.FilterDesc:new()
	local x = {};
	setmetatable(x, RDX.FilterDesc);
	return x;
end

-- Set the table into which this descriptor should be stored
function RDX.FilterDesc:SetConfig(d)
	if not d then d = {}; end
	self.data = d;
end

-- Update the data table to default values
function RDX.FilterDesc:SetDefaults()
	local cfg = self.data;
	cfg.list = nil;
	cfg.cg = false;
	cfg.hm = false;
	cfg.dead = 1; cfg.desync = 1; cfg.followdistance = 1;
end

-- Show the configuration dialog for this filter
function RDX.FilterDesc:ShowConfigDialog(okCallback, cancelCallback)
	local dlg, dn, ctl, cfg = RDXFilterConfig, "RDXFilterConfig", nil, self.data;
	-- Show the dialog
	dlg:Show();
	-- List
	ctl = getglobal(dn.."ListList");
	ctl.list.data = {};
	if cfg.list then
		if cfg.listExclude then
			getglobal(dn.."ListIncExc"):SetText("excl");
		else
			getglobal(dn.."ListIncExc"):SetText("incl");
		end
		getglobal(dn.."ListChk"):Set(true);
		for i=1,table.getn(cfg.list) do
			table.insert(ctl.list.data, {text = cfg.list[i]});
		end
	else
		ctl.list.data = {};
		getglobal(dn.."ListIncExc"):SetText("incl");
		getglobal(dn.."ListChk"):Set(false);
	end
	ctl.list:UpdateContent();
	-- Grps/Classes
	if cfg.cg then
		getglobal(dn.."ClassGrpChk"):Set(true);
		-- Groups
		for i=1,8 do
			ctl = getglobal(dn.."G"..i);
			if cfg.groups[i] then ctl:Set(true); else ctl:Set(false); end
		end
		-- Classes
		for i=1,9 do
			ctl = getglobal(dn.."C"..i);
			if cfg.classes[i] then ctl:Set(true); else ctl:Set(false); end
		end
	else
		getglobal(dn.."ClassGrpChk"):Set(false);
		RDX.ClearChecks(dn.."G", 8);
		RDX.ClearChecks(dn.."C", 9);
	end
	-- HP/mana
	getglobal(dn.."HMChk"):Set(cfg.hm);
	local fapply = function(ptu, ptl)
		if(cfg.hm) and (cfg[ptl]) then
			getglobal(dn..ptu.."Chk"):Set(true);
			getglobal(dn..ptu.."Min"):SetText(cfg[ptl.."min"]);
			getglobal(dn..ptu.."Max"):SetText(cfg[ptl.."max"]);
			RDX.TypeToButton(cfg[ptl.."type"], getglobal(dn..ptu.."Type"));
		else
			getglobal(dn..ptu.."Chk"):Set(false);
			getglobal(dn..ptu.."Min"):SetText("");
			getglobal(dn..ptu.."Max"):SetText("");
			RDX.TypeToButton(1, getglobal(dn..ptu.."Type"));
		end
	end
	fapply("HP", "hp"); fapply("MP", "mp"); fapply = nil;
	-- Other filters
	dlg.RGDead:SelectByID(cfg.dead);
	dlg.RGDesync:SelectByID(cfg.desync);
	dlg.RGFollow:SelectByID(cfg.followdistance);
	-- Bind OK/Cancel/esch
	getglobal(dn.."Cancel").OnClick = function() 
		dlg:Hide();
		if(cancelCallback) then cancelCallback(self); end
	end
	getglobal(dn.."OK").OnClick = function()
		self:ReadConfigDialog();
		dlg:Hide();
		if(okCallback) then okCallback(self); end
	end
end

-- Read the configuration dialog for this filter
function RDX.FilterDesc:ReadConfigDialog()
	local dlg, dn, ctl, cfg = RDXFilterConfig, "RDXFilterConfig", nil, self.data;
	-- List
	ctl = getglobal(dn.."ListList");
	if getglobal(dn.."ListChk"):Get() then
		if (getglobal(dn.."ListIncExc"):GetText() == "excl") then
			cfg.listExclude = true;
		else
			cfg.listExclude = false;
		end
		cfg.list = {};
		for i=1,table.getn(ctl.list.data) do
			table.insert(cfg.list, string.lower(ctl.list.data[i].text));
		end
	else
		cfg.list = nil;
	end
	-- Grps/Classes
	if getglobal(dn.."ClassGrpChk"):Get() then
		cfg.cg = true;
		-- Grps
		cfg.groups = {};
		for i=1,8 do
			if getglobal(dn.."G"..i):Get() then cfg.groups[i] = true; end
		end
		-- Classes
		cfg.classes = {};
		for i=1,9 do
			if getglobal(dn.."C"..i):Get() then cfg.classes[i] = true; end
		end
	else
		cfg.cg = false;
		cfg.groups = nil; cfg.classes = nil;
	end
	-- HP/mana
	local funapply = function(ptu, ptl)
		if getglobal(dn..ptu.."Chk"):Get() then
			cfg[ptl] = true;
			cfg[ptl.."min"] = getglobal(dn..ptu.."Min"):GetNumber();
			cfg[ptl.."max"] = getglobal(dn..ptu.."Max"):GetNumber();
			cfg[ptl.."type"] = RDX.TypeFromButton(getglobal(dn..ptu.."Type"));
		else
			cfg[ptl] = false;
		end
	end
	cfg.hm = getglobal(dn.."HMChk"):Get();
	if cfg.hm then
		funapply("HP", "hp"); funapply("MP", "mp");
	else
		cfg.hp = false; cfg.mp = false;
	end
	funapply = nil;
	-- Others
	cfg.dead = dlg.RGDead:Get();
	cfg.desync = dlg.RGDesync:Get();
	cfg.followdistance = dlg.RGFollow:Get();
end

--------------------------------------
-- FILTER METADATA
--------------------------------------
function RDX.FilterDesc:FiltersHealth()
	if self.data.hm and self.data.hp then return true; else return false; end
end
function RDX.FilterDesc:FiltersMana()
	if self.data.hm and self.data.mp then return true; else return false; end
end
function RDX.FilterDesc:FiltersGroupsAndClasses()
	return self.data.cg;
end
function RDX.FilterDesc:FiltersDead()
	return self.data.dead;
end
function RDX.FilterDesc:FiltersFollowDistance()
	return self.data.followdistance;
end

--------------------------------------
-- FILTER GENERATION
--------------------------------------
-- Generate filter closure precursor
function RDX.FilterDesc:GenFilterClosure()
	local cfg,body = self.data,"";
	-- If there's a list, we need to generate a closure for the list
	if cfg.list then
		body = body .. "local f_list = {"
		for i=1,table.getn(cfg.list) do
			body = body .. "['" .. cfg.list[i] .. "']=" .. i .. ";";
		end
		body = body .. "};";
	end
	-- If there's a group/class filter
	if cfg.cg then
		-- Generate group closure
		body = body .. "local f_grp = {};";
		for i=1,8 do
			if cfg.groups[i] then body = body .. "f_grp["..i.."] = true;"; end
		end
		-- Generate class closure
		body = body .. "local f_cls = {};";
		for i=1,9 do
			if cfg.classes[i] then body = body .. "f_cls["..i.."] = true;"; end
		end
	end
	return body;
end

function RDX.FilterDesc.GenTypeStatFilter(stat, ty, min, max)
	-- Renormalize percentage figures
	local pfx = "";
	if(ty == 1) or (ty == 3) then min = min/100; max = max/100; pfx = "Frac"; end
	if(ty == 3) or (ty == 4) then pfx = pfx .. "Missing"; end
	if(stat == 1) then pfx = pfx .. "Health"; else pfx = pfx .. "Mana"; end
	return "n = unit:"..pfx.."(); if(n<"..min..") or (n>"..max..") then return nil; end ";
end

-- Generate filter function body
function RDX.FilterDesc:GenFilterBody()
	local cfg,body = self.data,"function(unit) ";
	-- If filter by class, add rejection script for group/class
	if cfg.cg then
		body = body .. "if not f_grp[unit.group] then return nil; end if not f_cls[unit.class] then return nil; end "
	end
	-- Dead/desync/follow distance filters
	if cfg.dead == 2 then
		body = body .. "if not unit:IsDead() then return nil; end "
	elseif cfg.dead == 3 then
		body = body .. "if unit:IsDead() then return nil; end "
	end
	if cfg.desync == 2 then
		body = body .. "if unit:IsSynced() then return nil; end "
	elseif cfg.desync == 3 then
		body = body .. "if not unit:IsSynced() then return nil; end "
	end
	if cfg.followdistance == 2 then
		body = body .. "if not unit:IsFollowDistance() then return nil; end "
	elseif cfg.followdistance == 3 then
		body = body .. "if unit:IsFollowDistance() then return nil; end "
	end
	-- If filter by hp/mana...
	if cfg.hm then
		body = body .. "local n; "
		if cfg.hp then
			body = body .. RDX.FilterDesc.GenTypeStatFilter(1, cfg.hptype, cfg.hpmin, cfg.hpmax);
		end
		if cfg.mp then
			body = body .. RDX.FilterDesc.GenTypeStatFilter(2, cfg.mptype, cfg.mpmin, cfg.mpmax);
		end
	end
	-- If filter by list...
	if cfg.list then
		if not cfg.listExclude then
			body = body .. "return f_list[unit.name]; end";
		else
			body = body .. "if not f_list[unit.name] then return 1; else return nil; end end";
		end
	else
		body = body .. "return 1; end"
	end
	return body;
end

function RDX.MakeFilterFromDescriptor(desc)
	-- Zero out the global filterbuild function
	XXFiltBuild = nil;
	local fdef = "XXFiltBuild = function() " .. desc:GenFilterClosure() .. " return " .. desc:GenFilterBody() .. " end";
	VFL.debug("RDX.MakeFilterFromDescriptor: " .. fdef, 10);
	RunScript(fdef);
	if not XXFiltBuild then return nil; end
	return XXFiltBuild();
end

-- A temporary filter descriptor.
RDX.tempfd = RDX.FilterDesc:new();
