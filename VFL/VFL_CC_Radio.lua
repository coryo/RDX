-- VFL_CC_Radio.lua
-- VFL
-- Venificus' Function Library
--
-- Common Control: Radio Button/Radio Group
--
-- XML Class: VFLRadioT
--
-- Implements a mutually exclusive selection between several buttons.

---------------
-- RADIO BUTTON
---------------
if not VFL.RadioButton then VFL.RadioButton = {}; end

-- Imbue a frame of class VFLRadioT with radio button functionality.
function VFL.RadioButton.OnLoad(frame)
	if(not frame) then return; end
	-- Acquire subcontrols
	frame.btn = getglobal(frame:GetName() .. "Rad");
	frame.txt = getglobal(frame:GetName() .. "Txt");
	if(not frame.btn) or (not frame.txt) then return; end
	-- Assign functionality
	frame.Setup = VFL.RadioButton.Setup;
	frame.SetText = VFL.RadioButton.SetText;
	frame.SetChecked = VFL.RadioButton.SetChecked;
	frame.OnClick = VFL.RadioButton.OnClick;
end

-- Postproduction setup
function VFL.RadioButton:Setup(group, text)
	if(not group) then 
		return; 
	end
	self.group = group;
	self:SetText(text);
	self.group:Join(self);
end

function VFL.RadioButton:SetText(t) self.txt:SetText(t); end
function VFL.RadioButton:SetChecked(x) self.btn:SetChecked(x); end

function VFL.RadioButton:OnClick()
	self.group:SelectByID(self:GetID());
end

---------------
-- RADIO GROUP
---------------
if not VFL.RadioGroup then VFL.RadioGroup = {}; end
VFL.RadioGroup.__index = VFL.RadioGroup;

-- Construct a new RadioGroup.
function VFL.RadioGroup:new()
	local x = {};
	setmetatable(x, VFL.RadioGroup);
	x.button={};
	return x;
end

-- Join a button to the RadioGroup.
function VFL.RadioGroup:Join(rb)
	local id = rb:GetID();
	-- Don't overwrite a preexisting button
	if self.button[id] then return; end
	-- Otherwise create
	self.button[id] = rb;
	if(self.selected == id) then rb:SetChecked(true); else rb:SetChecked(false); end
end

-- Clear all buttons in the RadioGroup
function VFL.RadioGroup:Clear()
	for _,b in self.button do b:SetChecked(false); end
	self.selected = nil;
end

-- Select by ID.
function VFL.RadioGroup:SelectByID(id)
	self:Clear();
	local btn = self.button[id];
	if not btn then return; end
	btn:SetChecked(true);
	self.selected=id;
end

-- Get/set selection forcefully
function VFL.RadioGroup:Get()
	return self.selected;
end
function VFL.RadioGroup:Set(x)
	self.selected = x;
end
