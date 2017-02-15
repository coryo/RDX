---------------------------------------
-- Stuff to fix the popup menu bug
-------------------------------------
local ToggleDropDownMenuOld = ToggleDropDownMenu;
function ToggleDropDownMenuNew(level, value, dropDownFrame, anchorName, xOffset, yOffset)
	if not getglobal(anchorName) then
		return ToggleDropDownMenuOld(level, value, dropDownFrame, anchorName, xOffset, yOffset);
	end

	VFL:Debug(7, "-> DefaultUI ToggleDropDownMenu " .. GetTime());
	if ( not level ) then
		level = 1;
	end
	UIDROPDOWNMENU_MENU_LEVEL = level;
	UIDROPDOWNMENU_MENU_VALUE = value;
	local listFrame = getglobal("DropDownList"..level);
	local listFrameName = "DropDownList"..level;
	local tempFrame;
	if ( not dropDownFrame ) then
		tempFrame = this:GetParent();
	else
		tempFrame = dropDownFrame;
	end
	if ( listFrame:IsVisible() and (UIDROPDOWNMENU_OPEN_MENU == tempFrame:GetName()) ) then
		listFrame:Hide();
	else
		-- Set the dropdownframe scale
		local uiScale = 1.0;
		if ( GetCVar("useUiScale") == "1" ) then
			if ( tempFrame ~= WorldMapContinentDropDown and tempFrame ~= WorldMapZoneDropDown ) then
				uiScale = tonumber(GetCVar("uiscale"));
			end
		end
		listFrame:SetScale(uiScale);
		-- Hide the listframe anyways since it is redrawn OnShow() 
		listFrame:Hide();
		
		-- Display stuff
		-- Level specific stuff
		if ( level == 1 ) then
			if ( not dropDownFrame ) then
				dropDownFrame = this:GetParent();
			end
			UIDROPDOWNMENU_OPEN_MENU = dropDownFrame:GetName();
			listFrame:ClearAllPoints();
			-- If there's no specified anchorName then use left side of the dropdown menu
			if ( not anchorName ) then
				anchorName = UIDROPDOWNMENU_OPEN_MENU.."Left"
				relativeTo = UIDROPDOWNMENU_OPEN_MENU.."Left"
			elseif ( anchorName == "cursor" ) then
				relativeTo = nil;
				local cursorX, cursorY = GetCursorPosition();
				cursorX = cursorX/uiScale;
				cursorY =  cursorY/uiScale;

				if ( not xOffset ) then
					xOffset = 0;
				end
				if ( not yOffset ) then
					yOffset = 0;
				end
				xOffset = cursorX + xOffset;
				yOffset = cursorY + yOffset;
			else
				relativeTo = anchorName;
			end
			if ( not xOffset or not yOffset ) then
				xOffset = 8;
				yOffset = 22;
			end
			listFrame:SetPoint("TOPLEFT", relativeTo, "BOTTOMLEFT", xOffset, yOffset);
		else
			if ( not dropDownFrame ) then
				dropDownFrame = getglobal(UIDROPDOWNMENU_OPEN_MENU);
			end
			
			listFrame:ClearAllPoints();
			if ( anchorName == "cursor" ) then
				listFrame:SetPoint(anchorPoint, relativeTo, "BOTTOMLEFT", xOffset, yOffset);
			else
				listFrame:SetPoint("TOPLEFT", this:GetParent():GetName(), "TOPRIGHT", 0, 0);
			end
		end
		
		-- Change list box appearance depending on display mode
		if ( dropDownFrame and dropDownFrame.displayMode == "MENU" ) then
			getglobal(listFrameName.."Backdrop"):Hide();
			getglobal(listFrameName.."MenuBackdrop"):Show();
		else
			getglobal(listFrameName.."Backdrop"):Show();
			getglobal(listFrameName.."MenuBackdrop"):Hide();
		end

		UIDropDownMenu_Initialize(dropDownFrame, dropDownFrame.initialize, nil, level);
		-- If no items in the drop down don't show it
		if ( listFrame.numButtons == 0 ) then
			return;
		end

		-- Check to see if the dropdownlist is off the screen, if it is anchor it to the top of the dropdown button
		listFrame:Show();
		local x, y = listFrame:GetCenter();
		
		-- Determine whether the menu is off the screen or not
		local offscreenY, offscreenX;
		if ( (y - listFrame:GetHeight()/2) < 0 ) then
			offscreenY = 1;
		end
		if ( x + listFrame:GetWidth()/2 > GetScreenWidth() ) then
			offscreenX = 1;		
		end
		
		--  If level 1 can only go off the bottom of the screen
		if ( level == 1 ) then
			if ( offscreenY ) then
				listFrame:ClearAllPoints();
				listFrame:SetPoint("BOTTOMLEFT", anchorName, "TOPLEFT", xOffset, -yOffset);
			end
		else
			local anchorPoint, relativePoint, offsetX, offsetY;
			if ( offscreenY ) then
				if ( offscreenX ) then
					anchorPoint = "BOTTOMRIGHT";
					relativePoint = "BOTTOMLEFT";
					offsetX = 0;
					offsetY = -14;
				else
					anchorPoint = "BOTTOMLEFT";
					relativePoint = "BOTTOMRIGHT";
					offsetX = 0;
					offsetY = -14;
				end
			else
				if ( offscreenX ) then
					anchorPoint = "TOPRIGHT";
					relativePoint = "TOPLEFT";
					offsetX = 0;
					offsetY = 14;
				else
					anchorPoint = "TOPLEFT";
					relativePoint = "TOPRIGHT";
					offsetX = 0;
					offsetY = 14;
				end
			end
			listFrame:ClearAllPoints();
			listFrame:SetPoint(anchorPoint, this:GetParent():GetName(), relativePoint, offsetX, offsetY);
		end
	end
	VFL:Debug(7, "<- DefaultUI ToggleDropDownMenu " .. GetTime());
end
ToggleDropDownMenu = ToggleDropDownMenuNew;