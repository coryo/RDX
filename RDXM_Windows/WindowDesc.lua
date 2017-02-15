-- WindowDesc.lua
-- RDX5 - Raid Data Exchange
-- (C) 2005 Bill Johnson (Venificus of Eredar server)
--
-- Windowing module - Window descriptor.
--------------------------------------------
-- WINDOW DESCRIPTOR
--------------------------------------------
if not RDXM.WindowDesc then RDXM.WindowDesc = {}; end
RDXM.WindowDesc.__index = RDXM.WindowDesc;

function RDXM.WindowDesc:new()
	local self = {};
	setmetatable(self, RDXM.WindowDesc);
	self.filterDesc = RDX.FilterDesc:new();
	return self;
end

-- Set the config table for this window descriptor
function RDXM.WindowDesc:SetConfig(name, d)
	self.name = name;
	if not d then d = {}; end
	self.cfg = d;
	if not d.filter then d.filter = {}; end
	self.filterDesc:SetConfig(d.filter);
end

-- Set defaults for a window
function RDXM.WindowDesc:SetDefaults()
	self.cfg.sort = 2;
	self.cfg.disp = 1; self.cfg.stext = 1;
	self.cfg.numeric = nil; self.cfg.truncate = nil;
	self.cfg.layout = 1; self.cfg.scale = nil; self.cfg.alpha = nil;
	self.cfg.lbtn = { iid = 2; }; self.cfg.rbtn = { iid = 1; };
	self.cfg.slbtn = { iid=1; }; self.cfg.srbtn = { iid = 1; };
	self.cfg.mbtn = { iid = 1;}; self.cfg.smbtn = {iid=1;};
	self.filterDesc:SetDefaults();
end

-- Show config dialog containing data for this descriptor
function RDXM.WindowDesc:ShowConfigDialog(cb)
	local dlg,dn,ctl,cfg = RDXWindowDescConfig, "RDXWindowDescConfig", nil, self.cfg;
	local okbtn, cancelbtn = getglobal(dn.."OK"), getglobal(dn.."Cancel");
	-- Show the dialog
	dlg:Show();
	-- Populate settings
	getglobal(dn.."FilterBtn").OnClick = function()
		self.filterDesc:ShowConfigDialog();
	end
	dlg.RGSort:SelectByID(cfg.sort);
	getglobal(dn.."SortReverse"):Set(cfg.reverse);
	getglobal(dn.."DeadBottom"):Set(cfg.deadbottom);
	dlg.RGDisp:SelectByID(cfg.disp);
	dlg.RGStatusText:SelectByID(cfg.stext);
	if cfg.truncate then
		getglobal(dn.."DispTruncate"):Set(true);
		getglobal(dn.."DispTruncateNum"):SetText(cfg.truncate);
	else
		getglobal(dn.."DispTruncate"):Set(false);
	end
	-- Layout
	getglobal(dn.."LayoutDimension"):SetText("");
	dlg.RGAxis:SelectByID(cfg.layout);
	if(cfg.layout == 2) then
		getglobal(dn.."LayoutDimension"):SetText(cfg.layoutDimension);
	end
	if(cfg.scale) then
		getglobal(dn.."ScaleChk"):Set(true);
		getglobal(dn.."Scale"):SetValue(cfg.scale);
	else
		getglobal(dn.."ScaleChk"):Set(nil);
		getglobal(dn.."Scale"):SetValue(1.0);
	end
	-- Alpha
	if(cfg.alpha) then
		getglobal(dn.."AlphaChk"):Set(true);
		getglobal(dn.."Alpha"):SetValue(cfg.alpha);
	else
		getglobal(dn.."AlphaChk"):Set(nil);
		getglobal(dn.."Alpha"):SetValue(1.0);
	end
	-- Width
	if(cfg.width) then
		getglobal(dn.."WidthChk"):Set(true);
		getglobal(dn.."Width"):SetValue(cfg.width);
	else
		getglobal(dn.."WidthChk"):Set(nil);
		getglobal(dn.."Width"):SetValue(105);
	end
	-- Height
	if(cfg.height) then
		getglobal(dn.."HeightChk"):Set(true);
		getglobal(dn.."Height"):SetValue(cfg.height);
	else
		getglobal(dn.."HeightChk"):Set(nil);
		getglobal(dn.."Height"):SetValue(15);
	end
	-- Interactions
	ctl = getglobal(dn.."IntLBtn");
	ctl.title:Setup("Left Click Action");
	ctl:SetInteractor(cfg.lbtn);
	ctl = getglobal(dn.."IntSLBtn");
	ctl.title:Setup("Shift+Left Click Action");
	ctl:SetInteractor(cfg.slbtn);
	ctl = getglobal(dn.."IntMBtn");
	ctl.title:Setup("Middle Click Action");
	ctl:SetInteractor(cfg.mbtn);
	ctl = getglobal(dn.."IntSMBtn");
	ctl.title:Setup("Shift+Middle Click Action");
	ctl:SetInteractor(cfg.smbtn);
	ctl = getglobal(dn.."IntRBtn");
	ctl.title:Setup("Right Click Action");
	ctl:SetInteractor(cfg.rbtn);
	ctl = getglobal(dn.."IntSRBtn");
	ctl.title:Setup("Shift+Right Click Action");
	ctl:SetInteractor(cfg.srbtn);
	-- Bind to OK/Cancel
	cancelbtn.OnClick = function() VFL.Escape(); end
	okbtn.OnClick = function()
		self:ReadConfigDialog();
		if(cb) then cb(); end
		VFL.Escape();
	end
	-- Setup escape handler
	VFL.AddEscapeHandler(function() dlg:Hide(); end);
end


-- Read config dialog
function RDXM.WindowDesc:ReadConfigDialog()
	local dlg,dn,ctl,cfg = RDXWindowDescConfig, "RDXWindowDescConfig", nil, self.cfg;
	cfg.sort = dlg.RGSort:Get();
	cfg.disp = dlg.RGDisp:Get();
	cfg.stext = dlg.RGStatusText:Get();
	cfg.reverse = getglobal(dn.."SortReverse"):Get();
	cfg.deadbottom = getglobal(dn.."DeadBottom"):Get();
	if(getglobal(dn.."DispTruncate"):Get()) then
		cfg.truncate = getglobal(dn.."DispTruncateNum"):GetNumber();
		if(not cfg.truncate) then cfg.truncate = 0; end
	else
		cfg.truncate = nil;
	end
	-- Layout
	cfg.layout = dlg.RGAxis:Get();
	if(cfg.layout == 2) then
		cfg.layoutDimension = getglobal(dn.."LayoutDimension"):GetNumber();
		if ((not cfg.layoutDimension) or (cfg.layoutDimension < 1)) then cfg.layoutDimension = 1; end
	end
	if(getglobal(dn.."ScaleChk"):Get()) then
		cfg.scale = getglobal(dn.."Scale"):GetValue();
	else
		cfg.scale = nil;
	end
	-- Alpha
	if(getglobal(dn.."AlphaChk"):Get()) then
		cfg.alpha = getglobal(dn.."Alpha"):GetValue();
	else
		cfg.alpha = nil;
	end
	if(getglobal(dn.."WidthChk"):Get()) then
		cfg.width = getglobal(dn.."Width"):GetValue();
	else
		cfg.width = nil;
	end
	if(getglobal(dn.."HeightChk"):Get()) then
		cfg.height = getglobal(dn.."Height"):GetValue();
	else
		cfg.height = nil;
	end

	cfg.lbtn = getglobal(dn.."IntLBtn"):GetInteractor();
	cfg.slbtn = getglobal(dn.."IntSLBtn"):GetInteractor();
	cfg.mbtn = getglobal(dn.."IntMBtn"):GetInteractor();
	cfg.smbtn = getglobal(dn.."IntSMBtn"):GetInteractor();
	cfg.rbtn = getglobal(dn.."IntRBtn"):GetInteractor();
	cfg.srbtn = getglobal(dn.."IntSRBtn"):GetInteractor();
end

------ FNAPPLYDATA Generating subroutines:
-- Generate the "apply data" function for this descriptor.
function RDXM.WindowDesc:GenFnApplyData()
	local str = "XXFnApplyData = ";
	if(self.cfg.disp == 4) then
		str = str .. self:GenFnApplyDataBodyByClass();
	else
		str = str .. self:GenFnApplyDataBody();
	end
	XXFnApplyData = nil; RunScript(str);
	-- Return appropriately
	if not XXFnApplyData then return nil; end
	local ret = XXFnApplyData(self.cfg); XXFnApplyData = nil;
	return ret;
end

function RDXM.WindowDesc:GenFnApplyDataLDHandler()
	local str = "if not u:IsOnline() then c.text1:SetTextColor(0.5,0.5,0.5);";
	str = str .. " c.bar1:SetValue(0); c.bar2:SetValue(0); c.text2:SetText(''); ";
	str = str .. " return; end ";
	return str;
end
function RDXM.WindowDesc:GenFnApplyDataBody()
	local pFunc = "Health";
	local str = "function(env) return function(u,c) ";
	-- Apply the unit's name to the left text of the frame
--	str = str .. "c.text1:SetText(u:GetProperName());  c.text1:SetTextColor(1,1,1; ";
	str = str .. "c.text1:SetText(u:GetProperName());  c.text1:SetTextColor(explodeColor(u:GetClassColor())); ";
	-- Apply onclick
	str = str .. self:GenFnApplyDataOnClickSection();
	-- Apply linkdead handler
	str = str .. self:GenFnApplyDataLDHandler();
	-- Create the "p" variable; stores whatever primary quantity we're concerned with
	if(self.cfg.disp == 2) then pFunc = "Mana"; end
	str = str .. "local p = u:Frac" .. pFunc .. "(); ";
	-- Set the bar's purpose (1 = single bar, 2 = two bars)
	local purpose = 1;
	if(self.cfg.disp == 3) then purpose = 2; end
	str = str .. "c:SetPurpose(" .. purpose .. "); ";
	-- Apply bar statistics
	if purpose == 1 then -- Singlebar
		if pFunc == "Health" then -- Single healthbar
			str = str .. "RDX.SetStatusBar(c.bar1, p, RDXG.vis.cFriendHP, RDXG.vis.cFriendHPFade); ";
		else -- Single manabar
			str = str .. "RDX.SetStatusBar(c.bar1, p, RDXG.vis.cMana, RDXG.vis.cManaFade); ";
		end
	else -- Doublebar
		str = str .. "RDX.SetStatusBar(c.bar1, p, RDXG.vis.cFriendHP, RDXG.vis.cFriendHPFade); "
		str = str .. "RDX.SetStatusBar(c.bar2, u:FracMana(), RDXG.vis.cMana, RDXG.vis.cManaFade); "
	end
	-- Apply status text
	str = str .. self:GenFnApplyDataStatusTextSection(pFunc);
	-- Close function
	str = str .. " end end";
	return str;
end
function RDXM.WindowDesc:GenFnApplyDataStatusTextSection(pFunc)
	local str = "RDX.SetStatusText(c.text2, p, RDXG.vis.cStatusText, RDXG.vis.cStatusTextFade); ";
	if(self.cfg.stext == 1) then -- percentage
		str = str .. "c.text2:SetText(string.format('%0.0f%%', p*100)); ";
	elseif(self.cfg.stext == 2) then
		str = str .. "c.text2:SetText(string.format('%d/%d', u:" .. pFunc .. "(), u:Max" .. pFunc .. "())); ";
	else
		str = str .. "c.text2:SetText(string.format('-%d', u:Max"..pFunc.."() - u:"..pFunc.."())); ";
	end
	return str;
end
function RDXM.WindowDesc:GenFnApplyDataOnClickSection()
	return "c.OnClick = function(self,arg) if(arg == 'LeftButton') then if IsShiftKeyDown() then RDX.RunInteractor(u, env.slbtn) else RDX.RunInteractor(u, env.lbtn); end elseif(arg == 'RightButton') then if IsShiftKeyDown() then RDX.RunInteractor(u, env.srbtn); else RDX.RunInteractor(u,env.rbtn) end elseif(arg == 'MiddleButton') then if IsShiftKeyDown() then RDX.RunInteractor(u, env.smbtn) else RDX.RunInteractor(u, env.mbtn) end end end; "
end
function RDXM.WindowDesc:GenFnApplyDataBodyByClass()
	local str = "function(env) return function(u,c) local purpose,p = 1,u:FracHealth(); c.text1:SetText(u:GetProperName());  c.text1:SetTextColor(1,1,1); "
	str = str .. self:GenFnApplyDataOnClickSection();
	str = str .. self:GenFnApplyDataLDHandler();
	str = str .. " if(u:PowerType() == 0) then purpose = 2; end  c:SetPurpose(purpose); if (purpose==1) then RDX.SetStatusBar(c.bar1, p, RDXG.vis.cFriendHP, RDXG.vis.cFriendHPFade); else RDX.SetStatusBar(c.bar1, p, RDXG.vis.cFriendHP, RDXG.vis.cFriendHPFade); RDX.SetStatusBar(c.bar2, u:FracMana(), RDXG.vis.cMana, RDXG.vis.cManaFade); end ";
	str = str .. self:GenFnApplyDataStatusTextSection("Health");
	str = str .. " end end";
	return str;
end

------------------- SORT generation
function RDXM.WindowDesc:GenSortFunc()
	if(self.cfg.sort == 1) then return nil; end
	local str = "XXFnSort = function(u1,u2) ";
	str = str .. self:GenSortFuncBody(); 
	str = str .. " end";
	XXFnSort = nil; RunScript(str);
	-- Return appropriately
	if not XXFnSort then return nil; end
	local ret = XXFnSort; XXFnSort = nil;
	return ret;
end

-- Example of generated %hp sort function with secondary alphabetical sort:
-- 	function (u1,u2) 
--		if u1:FracHealth() ~= u2:FracHealth then
--			return (u1:FracHealth() < u2:FracHealth());
--		else
--			return (u1:GetProperName() < u2:GetProperName());
--		end
--	end

function RDXM.WindowDesc:GenSortFuncBody()
	local statistic,cfg,str = "FracHealth",self.cfg,"";
	-- cfg.sort 1 = None 2 = %HP 3= %Mana 4= Alpha
	if(cfg.sort == 4) then
		statistic="GetProperName";
	else
		--str = str .. self:GenSortFuncLDSection();
	end
	if(cfg.sort==3) then statistic="FracMana"; end
	-- cfg.reverse TRUE = reversed
	local direction = "<";
	if cfg.reverse then direction = ">"; end
	str = str .. "return (u1:"..statistic.."() " .. direction .. " u2:"..statistic.."());";
	-- If not already sorting alphabetically, use it as a secondary sort
	if cfg.sort ~= 4 then 
		str = self:GenSortFuncLDSection() .. "if (u1:"..statistic.."() ~= u2:"..statistic.."()) then "..str.." else return (u1:GetProperName() < u2:GetProperName()); end"
	end
	if cfg.deadbottom then
		str = self:GenSortFuncDeadBottomSection() .. str;
		end
	return str;
end
function RDXM.WindowDesc.GenSortFuncDeadBottomSection()
	local str = "if (u1:IsDead() and not u2:IsDead()) or (not u1:IsDead() and u2:IsDead()) then ";
	str = str .. "if u1:IsDead() then return false; end ";
	str = str .. "if u2:IsDead() then return true; end ";
	str = str .. "end ";
	return str;
end
function RDXM.WindowDesc:GenSortFuncLDSection()
	local str = "if (u1:IsSynced() and not u2:IsSynced()) or (not u1:IsSynced() and u2:IsSynced()) then ";
	str = str .. "if not u1:IsSynced() then return false; end ";
	str = str .. "if not u2:IsSynced() then return true; end ";
	str = str .. "end ";
	return str;
end
