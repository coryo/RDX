-- MainMenu.lua
-- RDX5 - Raid Data Exchange
-- (C)2005 Bill Johnson (Venificus of Eredar server)
--
-- Support code for the main menu
--

function RDX.MenuOnMouseDown(self, arg1)
	if(IsShiftKeyDown()) then self.mv = true; self:StartMoving(); return; end
end

function RDX.MenuOnMouseUp(self, arg1)

	if(self.mv) then self:StopMovingOrSizing(); self.mv = false; return; end
	RDX.MenuShow();
	
end

-- Show the main menu
function RDX.MenuShow(frame)

	-- Don't show menu if RDX isn't init
	if not RDX.initComplete then return; end
	local tbl = {};
	-- Hide/show RDX
	table.insert(tbl, {text="Tools", isSubmenu = true, OnClick = function() RDX.MenuExtras(this); end});
	-- Module menus
	for _,lModule in RDX.modules do
		if lModule:HasMenu() then
			local closeOver = lModule;
			table.insert(tbl, 
			{text = lModule.title, 
			color = {r=0.2, g=0.9, b=0.9}, 
			isSubmenu = true, 
			OnClick = function()
				closeOver:DoMenu(VFL.poptree, this);
			end});
		end
	end
	-- Gen the menu
	VFL.poptree:Begin(120, 16, frame, "CENTER");
	VFL.poptree:Expand(nil, tbl);
end

-- Tools menu
function RDX.MenuTools(cell)
	local mnu = {};
	if RDXTopStackAnchor:IsVisible() then
		table.insert(mnu,{ 
			text = "Lock Alerts",
			OnClick = function()
				RDXTopStackAnchor:Hide();
				VFL.poptree:Release();
			end });
	else
		table.insert(mnu,{ 
			text = "Unlock Alerts",
			OnClick = function()
				RDXTopStackAnchor:Show();
				VFL.poptree:Release();
			end });
	end
	table.insert(mnu,{ 
		text = "Master Reset",
		OnClick = function()
			VFL.CC.Popup(function(flg) if flg then RDX.MasterReset();  end end, "Master Reset", "Really master reset?");
			VFL.poptree:Release();
		end });
	table.insert(mnu, {
		text = "Reload UI",
		OnClick = function() ReloadUI(); end,
	});
	table.insert(mnu, {
		text = "Rehash",
		OnClick = function() RDX.Rehash(); VFL.poptree:Release(); end,
	});
	table.insert(mnu, {
		text = "Reset UI",
		OnClick = function() RDX.ResetUI(); VFL.poptree:Release(); end,
	});
	VFL.poptree:Expand(cell, mnu);
end

--Extras
function RDX.MenuExtras(cell)
	local mnu = {};
	table.insert(mnu,{
		text="UI Tools",
		isSubmenu= true,
		OnClick = function() RDX.MenuTools(this); end})
	
	local amstatus;
	if RDX5Data.AggroMonitorEnabled then amstatus = "[ON]" else amstatus = "[OFF]" end;
	
	table.insert(mnu,{
		text="Aggro Monitor " .. amstatus,
		OnClick = function() RDX.AggroMonitor.Toggle(); VFL.poptree:Release(); end});


	local itstatus;
	if RDX5Data.ImpliedTarget == 1 then itstatus = "[ON]" else itstatus = "[OFF]" end;
	
	table.insert(mnu,{
		text="Implied Target " .. itstatus,
		OnClick = function() RDX.ImpliedTarget.Toggle(); VFL.poptree:Release(); end});
		
	local nosalvstatus;
	if RDX5Data.ClickOffSalvEnabled then nosalvstatus = "[ON]" else nosalvstatus = "[OFF]" end;
	table.insert(mnu,{
		text="Anti-Salvation " .. nosalvstatus,
		OnClick = function() RDX.AggroMonitor.ToggleClickOffSalv(); VFL.poptree:Release(); end});
	
	VFL.poptree:Expand(cell, mnu);
end


--[[
OnClick = function() 
			if RDXM.Logistics then
				RDXM.Logistics.RaidStatus.Toggle();	
			else
				VFL.print("You must have the logistics module installed!");
			end
		end});
		--]]