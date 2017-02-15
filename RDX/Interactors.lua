-- Interactors.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 by Venificus of Eredar server
--
-- Interactors are operations that can be executed by hotkeys/clicks/etc.
-- An interactor description consists of a function to be called.
-- This function will be passed a configuration that's stored with the
-- interactor itself.
-- The description also contains functions to init and edit the configuration
if not RDX.Interactors then RDX.Interactors = {}; end

-- The global interactor table
RDX.idefs = {};

function RDX.RegisterInteractor(tbl)
	if(not tbl) or (not tbl.id) then return; end
	if RDX.idefs[tbl.id] then
		VFL.debug("RDX.RegisterInteractor(): duplicate id " .. tbl.id, 2);
		return;
	end
	RDX.idefs[tbl.id] = tbl;
end

function RDX.RunInteractor(targ, cfg)
	if(not cfg) or (not cfg.iid) then return; end
	RDX.idefs[cfg.iid].Go(targ, cfg);
end

-----------------------------------
-- INTERACTION SELECTION PANEL
-----------------------------------
if not RDX.IntSelPanel then RDX.IntSelPanel = {}; end
function RDX.IntSelPanel.Imbue(self)
	local n = self:GetName();
	self.btnSel = getglobal(n.."IntSel");
	self.btnArg = getglobal(n.."IntArg");
	self.btnCfg = getglobal(n.."IntCfg");
	self.title = getglobal(n.."Title"); Label_Gold(self.title);
	self.cfg = nil;
	self.allowType = nil;
	self.SetNothing = RDX.IntSelPanel.SetNothing;
	self.SetInteractor = RDX.IntSelPanel.SetInteractor;
	self.GetInteractor = RDX.IntSelPanel.GetInteractor;
	self.OnSelectInteractor = RDX.IntSelPanel.OnSelectInteractor;
	-- Functionality
	self.btnSel.OnClick = function() self:OnSelectInteractor(); end;
end

function RDX.IntSelPanel:SetNothing()
	self.btnSel:SetText("(none)"); self.cfg = nil;
	self.btnArg:Hide(); self.btnCfg:Hide();	
end

function RDX.IntSelPanel:SetInteractor(cfg)
	if (not cfg) or (not cfg.iid) then self:SetNothing(); self.cfg = nil; end
	local idef = RDX.idefs[cfg.iid];
	if not idef then self:SetNothing(); self.cfg = nil; end
	self.cfg = cfg;
	self.btnSel:SetText(idef.name);
	local panel = self;
	if idef.configurable then
		if idef.GetConfigText then
			self.btnArg:Show(); self.btnCfg:Hide();
			self.btnArg:SetText(idef.GetConfigText(cfg));
			self.btnArg.OnClick = function()
				local data = idef.BuildConfigDropdown(cfg);
				for _,x in data do
					local entry = x;
					entry.OnClick = function()
						idef.SelectConfigDropdown(panel.cfg, entry);
						panel:SetInteractor(panel.cfg);
						VFLUI.PopMenu:Release();
					end
				end
				--VFL.popwin:Show(data, 8, self.btnArg, "BOTTOMLEFT", self.btnArg:GetWidth(), 10);
				VFLUI.PopMenu:Begin(self.btnArg:GetWidth(), 10, self.btnArg, "BOTTOMLEFT", 0, 0)
				VFLUI.PopMenu:Expand(self.btnArg, data, 8);
			end
		elseif idef.OpenConfigDialog then
			self.btnArg:Hide(); self.btnCfg:Show();
		end
	else
		self.btnCfg:Hide(); self.btnArg:Hide();
	end
end

-- Display interactor dropdown
function RDX.IntSelPanel:OnSelectInteractor()
	local tbl = {};
	for _,i in ipairs(RDX.idefs) do
		local interactor = i;
		local itbl = { text = interactor.name, OnClick = function()
			self.cfg = {}; self.cfg.iid = interactor.id;
			if(interactor.InitConfig) then interactor.InitConfig(self.cfg); end
			self:SetInteractor(self.cfg);
			VFLUI.PopMenu:Release();
		end };
		if(self.allowType) and (interactor.type) then
			if(self.allowType == interactor.type) then
				table.insert(tbl, itbl);
			end
		else
			table.insert(tbl, itbl);
		end
	end
	--VFL.popwin:Show(tbl, 8, self.btnSel, "BOTTOMLEFT", self.btnSel:GetWidth(), 10);
	VFLUI.PopMenu:Begin(self.btnSel:GetWidth(), 10, self.btnSel, "BOTTOMLEFT", 0, 0)
	VFLUI.PopMenu:Expand(self.btnSel, tbl);
end

-- Get the configuration table for the interactor represented by this panel
function RDX.IntSelPanel:GetInteractor()
	if not self.cfg then
		return { iid = 1 };
	else
		return self.cfg;
	end
end

-----------------------------------
-- SMARTKEYS
-----------------------------------
if not RDX.Smartkeys then RDX.Smartkeys = {}; end

function RDX.Smartkeys.ApplyData(grid, cell, data)
	cell:SetInteractor(data);
end

function RDX.Smartkeys.ConfigOnLoad(dlg)
	dlg.framePool = VFL.Pool:new();
	dlg.framePool.OnRelease = function(pool, x) x:Hide(); end
	dlg.framePool:Fill(dlg:GetName() .. "SK");
	dlg.list = VFL.ListControl:new(dlg, dlg.framePool, RDX.Smartkeys.ApplyData, getglobal(dlg:GetName().."SB"));
end

function RDX.Smartkeys.ConfigOnShow(dlg)
	dlg.list:Build(48, 350, dlg.framePool:GetSize(), {}, dlg, "TOPLEFT", 5, -24);
end

-----------------------------------
-- BASE INTERACTORS
-----------------------------------
-- The null interactor
RDX.RegisterInteractor({
	id=1;
	name="(none)";
	configurable = false;
	Go = function() end
});

-- The basic target interactor
RDX.RegisterInteractor({
	id=2,
	name="Target",
	type="targeted", configurable = false;
	Go = function(unit, cfg) TargetUnit(unit.uid); end
});
-- The Assist Interactor
RDX.RegisterInteractor({
	id=3,
	name="Assist",
	type="targeted", configurable = false;
	Go = function(unit, cg) TargetUnit(unit.uid.."target"); end
});
-- "Cast spell at target" interactor
function RDX.Interactors.SpellConfigText(cfg)
	local sp = RDX.GetSpell(cfg.sptitle);
	if sp then return sp.title; else return "(Invalid spell.)"; end
end
function RDX.Interactors.SpellConfigDropdown(cfg)
	local ret = {};
	for _,sp in RDX.sp do
		table.insert(ret, {text = sp.title});
	end
	return ret;
end
function RDX.Interactors.SpellConfigDropdownSelect(cfg, sel)
	cfg.sptitle = string.lower(sel.text);
end
RDX.RegisterInteractor({
	id=4,
	name="Cast Spell on Target",
	type="targeted", configurable = true,
	InitConfig = function() end,
	GetConfigText = RDX.Interactors.SpellConfigText,
	BuildConfigDropdown = RDX.Interactors.SpellConfigDropdown,
	SelectConfigDropdown = RDX.Interactors.SpellConfigDropdownSelect,
	Go = function(unit,cfg)
		local sp = RDX.GetSpell(cfg.sptitle);
		if sp then
			TargetUnit(unit.uid);
			sp:Cast();
		end
	end
});
