--- ConfigInterface.lua
-- VFL
-- (C)2006 Bill Johnson
--
-- Primitives for the VFL configuration interface.
--
-- A configuration interface element is a frame with a few special methods:
-- OnInterfaceOpen(), OnInterfaceUpdate(), and OnInterfaceClose().
--
-- Each of these methods is passed a user-defined context object which
-- they can use to alter the configuration.
--
-- OnInterfaceOpen(context) is called when the configuration is first opened,
-- and should populate the controls with appropriate information.
--
-- OnInterfaceUpdate(context) is called after OnInterfaceOpen(), and
-- subsequently whenever relevant information has changed and the interface
-- should be updated.
--
-- OnInterfaceClose(context, successCode) is called when the "OK" or "Cancel"
-- directive is to be processed.
--
-- OnUpwardLayout(context) is called when an upward layout constraint should be propagated.
-- It should first call all of its children's OnUpwardLayout() methods, then use
-- the children's layout info to relayout itself.
--
-- The exact order in which things should be done is:
-- 1) Create a suitable container for the entire interface. (ScrollFrame at minimum)
-- 2) Create the interface root (usually a CompoundFrame)
-- 3) Set the root's parent to the container.
--
-- For every subcontrol of the root, do:
-- 4) Create the control with parent as root.
-- 5) use root:InsertFrame() to add it.
-- 6) Set its layout. DO NOT SET LAYOUT UNTIL AFTER THE CONTROL IS IN THE HIERARCHY.
-- 
-- 7) Once done setting up the hierarchy, the following should be done IN THIS ORDER. 
--    This is all handled automatically if you use one of the prefab config dialogs.
-- 		  root:OnInterfaceOpen(context); 
--		  root:SetWidth(container:GetWidth());
--		  root:OnInterfaceUpdate(context);
--		  root:Show();
--


--- Find the root of the given layout tree.
-- @param x An element of a dialog layout tree.
-- @returns The root element of the layout tree, or NIL for none.
function VFLUI.FindLayoutRoot(x)
	while x do
		if x.isLayoutRoot then return x; end
		x = x:GetParent();
	end
	return nil;
end

--- Update a dialog's layout.
function VFLUI.UpdateDialogLayout(x)
	local r = VFLUI.FindLayoutRoot(x);
	if (not r) or r._layout_dirty then return; end
	r._layout_dirty = true;
	r:SetScript("OnUpdate", function()
		this:SetScript("OnUpdate", nil);
		this._layout_dirty = nil;
		this:DialogOnLayout();
	end);
	-- Defer the layout update in case multiple subobjects spam... don't want to overprocess.
--	VFL.schedule(.01, function() r._layout_dirty = nil; r:DialogOnLayout(); end);
end

--- @class VFLUI.PassthroughFrame
-- A passthrough config frame simply passes on its requests to its subobject.
-- Passthroughs can be used as decoration or for other functionality-inert
-- purposes.
--
-- Passthroughs are automatically anchored to their children, with the given
-- offsets.
VFLUI.PassthroughFrame = {};
function VFLUI.PassthroughFrame:new(f, parent)
	local self = f or VFLUI.AcquireFrame("Frame");
	if parent then
		self:SetParent(parent);
		self:SetFrameStrata(parent:GetFrameStrata());
		self:SetFrameLevel(parent:GetFrameLevel() + 1);
	end
	
	local collapsed = nil;
	local child = nil;
	local dxLeft, dyTop, dxRight, dyBottom = 0, 0, 0, 0;

	self.DialogOnLayout = function(s)
		if child then
			if collapsed then
				child:Hide();
				s:SetHeight(dyTop + dyBottom);
			else
				-- Downward layout constraint on width
				child:Show();
				child:SetWidth(self:GetWidth() - dxLeft - dxRight);
				if child.DialogOnLayout then child:DialogOnLayout(); end
				-- Upward layout constraint on height
				self:SetHeight(child:GetHeight() + dyTop + dyBottom);
			end
		else
			s:SetHeight(dyTop + dyBottom);
		end
	end

	self.SetInsets = function(s, dxL, dyT, dxR, dyB)
		if dxL then dxLeft = dxL; end
		if dyT then dyTop = dyT; end
		if dxR then dxRight = dxR; end
		if dyB then dyBottom = dyB; end
	end

	self.SetChild = function(s, ch, dxL, dyT, dxR, dyB)
		if (not ch) or (child) then return; end
		s:SetInsets(dxL, dyT, dxR, dyB);

		-- Setup child
		child = ch;
		child:SetParent(s); child:SetScale(1);
		child:SetPoint("TOPLEFT", s, "TOPLEFT", dxLeft, -dyTop);
	end

	self.SetCollapsed = function(s, coll)
		if coll then
			if collapsed then return; end
			collapsed = true; child:Hide(); s:SetHeight(dyTop + dyBottom);
		else
			if not collapsed then return; end
			collapsed = nil; child:Show(); s:SetHeight(child:GetHeight() + dyTop + dyBottom);
		end
		VFLUI.UpdateDialogLayout(s);
	end

	self.ToggleCollapsed = function(s)
		s:SetCollapsed(not collapsed);
	end

	self.IsCollapsed = function() return collapsed; end

	-- Pass the configframe methods directly through to the child.
	self.OnInterfaceOpen = function(s, context)
		if child.OnInterfaceOpen then child:OnInterfaceOpen(context); end
	end
	self.OnInterfaceUpdate = function(s, context)
		if child.OnInterfaceUpdate then child:OnInterfaceUpdate(context); end
	end
	self.OnInterfaceClose = function(s, context, successCode)
		if child.OnInterfaceClose then child:OnInterfaceClose(context, successCode); end
	end

	-- Hook the destroy function to cleanup what we did.
	self.Destroy = VFL.hook(function(s)
		VFLUI:Debug(5, "PassthroughFrame(" .. tostring(s) .. "):Destroy()");
		-- Destroy child
		if child then child:Destroy(); child = nil; end
		-- Remove closures
		s.SetChild = nil; s.SetInsets = nil;
		s.DialogOnLayout = nil; s.SetCollapsed = nil; s.ToggleCollapsed = nil; s.IsCollapsed = nil;
		s.OnInterfaceOpen = nil; s.OnInterfaceUpdate = nil; s.OnInterfaceClose = nil;
	end, self.Destroy);

	return self;
end

--- @class VFLUI.CollapsibleFrame
-- A collapsible frame is a PassthroughFrame augmented with a button to control its collapse and
-- expansion, and a FontString to describe its contents.
VFLUI.CollapsibleFrame = {};
function VFLUI.CollapsibleFrame:new(parent)
	local self = VFLUI.PassthroughFrame:new(nil, parent);

	-- Background
	self:SetBackdrop(VFLUI.DefaultDialogBackdrop);

	-- Create the textbox and button
	local ctl = VFLUI.Button:new(self);
	ctl:SetPoint("TOPLEFT", self, "TOPLEFT", 5, -5);
	ctl:SetWidth(25); ctl:SetHeight(25); ctl:Show();
	ctl:SetText("+");
	ctl:SetScript("OnClick", function()
		local p = this:GetParent();
		if p and p.ToggleCollapsed then p:ToggleCollapsed(); end
	end);
	self.btn = ctl;

	local fs = VFLUI.CreateFontString(self);
	fs:SetPoint("LEFT", ctl, "RIGHT"); 
	fs:SetFontObject(Fonts.Default); fs:SetJustifyH("LEFT");
	fs:SetHeight(25); fs:SetWidth(0); fs:Show();
	self.text = fs;

	-- Hook necessary functions
	local oldDialogOnLayout = self.DialogOnLayout;
	self.DialogOnLayout = function(s)
		oldDialogOnLayout(s);
		s.text:SetWidth(math.max(s:GetWidth() - 25, 0));
	end

	local oldSetCollapsed = self.SetCollapsed;
	self.SetCollapsed = function(s2, coll)
		oldSetCollapsed(s2, coll);
		if coll then s2.btn:SetText("+"); else s2.btn:SetText("-"); end
	end

	local oldSetChild = self.SetChild;
	self.SetChild = function(s, child, isCollapsed)
		oldSetChild(s, child, 5, 30, 5, 5);
		s:SetCollapsed(isCollapsed);
	end

	self.SetText = function(s, txt) s.text:SetText(txt); end

	self.Destroy = VFL.hook(function(s)
		s.btn:Destroy(); s.btn = nil;
		VFLUI.ReleaseRegion(s.text); s.text = nil;
		s.SetText = nil;
	end, self.Destroy);
	
	return self;
end


--- @class VFLUI.CompoundFrame
-- A compound config frame is a grid of config frames. Any invocation of a config method on
-- a compound config frame is automatically passed on to all of its children.
VFLUI.CompoundFrame = {};
function VFLUI.CompoundFrame:new(parent)
	local self = VFLUI.Grid:new(parent);
	self:Size(1,0);

	-- Ensure that frames added to this grid will be properly destroyed.
	self.OnOrient = function(s, c)
		c.OnDeparent = c.Destroy;
	end

	-- Config methods automatically pass down to children
	self.OnInterfaceOpen = function(s, context) 
		for c in s:Iterator() do 
			if c.OnInterfaceOpen then c:OnInterfaceOpen(context); end
		end
	end;
	self.OnInterfaceUpdate = function(s, context) 
		for c in s:Iterator() do 
			if c.OnInterfaceUpdate then c:OnInterfaceUpdate(context); end
		end 
	end;
	self.OnInterfaceClose = function(s, context, successCode) 
		for c in s:Iterator() do 
			if c.OnInterfaceClose then c:OnInterfaceClose(context, successCode); end
		end 
	end;
	self.DialogOnLayout = function(s)
		VFLUI:Debug(5, "CompoundFrame(" .. tostring(s) .. "):->DialogOnLayout() (current size " .. s:GetWidth() .. "x" .. s:GetHeight() ..")");
		for c in s:Iterator() do
			if c.DialogOnLayout then c:DialogOnLayout(); end
		end
		-- Upward constraint: relayout the grid based on the cells
		s:Relayout();
		VFLUI:Debug(5, "CompoundFrame(" .. tostring(s) .. "):<-DialogOnLayout() (current size " .. s:GetWidth() .. "x" .. s:GetHeight() ..")");
	end
	
	-- Destroy cleans up what we did and destroys all children
	self.Destroy = VFL.hook(function(s)
		VFLUI:Debug(5, "CompoundFrame(" .. tostring(s) .. "):Destroy()");
		s.OnInterfaceOpen = nil; s.OnInterfaceUpdate = nil; s.OnInterfaceClose = nil;
		s.DialogOnLayout = nil;
	end, self.Destroy);

	return self;
end

--- @class VFLUI.CheckGroup
-- A check group is a numerically indexed array of checkboxes arranged in a grid.
VFLUI.CheckGroup = {};
function VFLUI.CheckGroup:new(parent)
	local self = VFLUI.Grid:new(parent);
	self:Show();

	self.checkBox = {};
	self.SetLayout = function(s, nChecks, nCols)
		-- Size the thing
		local nRows = math.ceil(nChecks / nCols);
		s:Size(nCols, nRows, function()
			local cb = VFLUI.Checkbox:new(s);
			cb.OnDeparent = cb.Destroy;
			return cb;
		end);
		-- Populate the checkboxes array
		s.checkBox = {};
		local n = 0;
		for cell in s:Iterator() do
			n = n + 1;
			if(n > nChecks) then cell:Hide() else
				cell:Show(); s.checkBox[n] = cell;
			end
		end
		-- Trip upward layout since we changed heights.
		VFLUI.UpdateDialogLayout(s);
	end

	self.OnInterfaceOpen = VFL.Noop; self.OnInterfaceUpdate = VFL.Noop; self.OnInterfaceClose = VFL.Noop; 
	self.DialogOnLayout = VFL.Noop;

	self.Destroy = VFL.hook(function(s)
		VFLUI:Debug(5, "CheckGroup(" .. tostring(s) .. "):Destroy()");
		s.checkBox = nil; s.SetLayout = nil;
		s.OnInterfaceOpen = nil; s.OnInterfaceUpdate = nil; s.OnInterfaceClose = nil;
		s.DialogOnLayout = nil;
	end, self.Destroy);

	return self;
end

--- @class VFLUI.RadioGroup
-- A radio group is a grid of mutually exclusive radio buttons.
VFLUI.RadioGroup = {};
function VFLUI.RadioGroup:new(parent)
	local self = VFLUI.Grid:new(parent);
	self:Show();

	self.buttons = {};
	self.value = nil;
	self.SetLayout = function(s, nChecks, nCols)
		-- Size the thing
		local nRows = math.ceil(nChecks / nCols);
		s:Size(nCols, nRows, function()
			local cb = VFLUI.RadioButton:new(s);
			cb.OnDeparent = cb.Destroy;
			return cb;
		end);
		-- Populate the checkboxes array
		s.buttons = {};
		local n = 0;
		for cell in s:Iterator() do
			n = n + 1;
			if(n > nChecks) then cell:Hide() else
				cell:Show(); s.buttons[n] = cell;
				local qq = n;
				cell.button:SetScript("OnClick", function() s:SetValue(qq); end);
			end
		end
		-- Relayout the dialog.
		VFLUI.UpdateDialogLayout(s);
	end

	self.SetValue = function(s, v)
		VFLUI:Debug(7, "RadioGroup(" .. tostring(s) .. "):SetValue(" .. tostring(v) .. ")");
		s.value = v;
		local n = 0;
		for cell in s:Iterator() do
			n=n+1;
			if(n == v) then cell:SetChecked(true); else cell:SetChecked(nil); end
		end
	end
	self.GetValue = function(s) return s.value; end

	self.OnInterfaceOpen = VFL.Noop; self.OnInterfaceUpdate = VFL.Noop; self.OnInterfaceClose = VFL.Noop; 
	self.DialogOnLayout = VFL.Noop;

	self.Destroy = VFL.hook(function(s)
		VFLUI:Debug(5, "RadioGroup(" .. tostring(s) .. "):Destroy()");
		s.buttons = nil; s.SetLayout = nil;
		s.SetValue = nil; s.GetValue = nil; s.value = nil;
		s.OnInterfaceOpen = nil; s.OnInterfaceUpdate = nil; s.OnInterfaceClose = nil;
		s.DialogOnLayout = nil;
	end, self.Destroy);

	return self;
end

--- @class VFLUI.LabeledEdit
-- An edit box with a label.
VFLUI.LabeledEdit = {};
function VFLUI.LabeledEdit:new(parent, editWidth)
	local self = VFLUI.AcquireFrame("Frame");
	if parent then
		self:SetParent(parent); self:SetFrameStrata(parent:GetFrameStrata()); self:SetFrameLevel(parent:GetFrameLevel());
	end

	self:SetHeight(24); self:Show();

	local editBox = VFLUI.Edit:new(self);
	editBox:SetHeight(24); editBox:SetWidth(editWidth);
	editBox:SetPoint("RIGHT", self, "RIGHT", -5, 0); editBox:SetText("");
	editBox:Show();
	self.editBox = editBox;

	local txt = VFLUI.CreateFontString(self);
	txt:SetPoint("TOPLEFT", self, "TOPLEFT");
	txt:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMLEFT");
	txt:SetFontObject(VFLUI.GetFont(Fonts.Default, 10));
	txt:SetJustifyV("CENTER"); txt:SetJustifyH("LEFT");
	txt:SetText(""); txt:Show();
	self.text = txt;

	self.SetText = function(s, t) s.text:SetText(t); end

	self.OnInterfaceOpen = VFL.Noop; self.OnInterfaceUpdate = VFL.Noop; self.OnInterfaceClose = VFL.Noop; 
	self.DialogOnLayout = VFL.Noop;
	self.Destroy = VFL.hook(function(s)
		s.OnInterfaceOpen = nil; s.OnInterfaceUpdate = nil; s.OnInterfaceClose = nil; s.DialogOnLayout = nil;
		s.SetText = nil;
		s.editBox:Destroy(); s.editBox = nil;
		VFLUI.ReleaseRegion(s.text); s.text = nil;
	end, self.Destroy);

	return self;
end

--- @class VFLUI.StringEdit
-- A shortcut to make a LabeledEdit with a ready-made function to extract and validate data.
VFLUI.StringEdit = {};
function VFLUI.StringEdit:new(parent, editWidth, contextField, strMinLen, strMaxLen)
	local self = VFLUI.LabeledEdit:new(parent, editWidth);
	self.OnInterfaceUpdate = function(s, context)
		if context[contextField] then
			s.editBox:SetText(context[contextField]);
		else
			s.editBox:SetText("");
		end
	end
	self.OnInterfaceClose = function(s, context, successFlag)
		if not successFlag then return; end
		local str = s.editBox:GetText();
		if not str then
			context.hasError = true; VFLUI.AttachErrorReport("Text must be entered in this field.", s, "TOPLEFT", 5, -5);
			return;
		end
		local len = string.len(str);
		if strMinLen and (len < strMinLen) then
			context.hasError = true; VFLUI.AttachErrorReport("Minimum length " .. strMinLen, s, "TOPLEFT", 5, -5); return;
		end
		if strMaxLen and (len < strMaxLen) then
			context.hasError = true; VFLUI.AttachErrorReport("Maximum length " .. strMaxLen, s, "TOPLEFT", 5, -5); return;
		end
		if (len > 0) then context[contextField] = str; else context[contextField] = nil; end
	end

	return self;
end

--- @class VFLUI.NumericEdit
-- A shortcut to make a LabeledEdit process and validate numerical data.
VFLUI.NumericEdit = {};
function VFLUI.NumericEdit:new(parent, editWidth, contextField, required, minVal, maxVal)
	local self = VFLUI.LabeledEdit:new(parent, editWidth);
	self.OnInterfaceUpdate = function(s, context)
		if context[contextField] then
			s.editBox:SetText(tostring(context[contextField]));
		else
			s.editBox:SetText("");
		end
	end
	self.OnInterfaceClose = function(s, context, successFlag)
		if not successFlag then return; end
		local t = s.editBox:GetText();
		if (not t) or (t == "") then
			if not required then return; end
			context.hasError = true;
			VFLUI.AttachErrorReport("This field is required.", s, "TOPLEFT", 5, -5);
			return;
		end
		local n = tonumber(t);
		if not n then 			
			context.hasError = true; VFLUI.AttachErrorReport("A number must be entered in this field.", s, "TOPLEFT", 5, -5);
			return;
		end
		if minVal and (n < minVal) then
			context.hasError = true; VFLUI.AttachErrorReport("Minimum value " .. minVal, s, "TOPLEFT", 5, -5); return;
		end
		if maxVal and (n > maxVal) then
			context.hasError = true; VFLUI.AttachErrorReport("Maximum value " .. maxVal, s, "TOPLEFT", 5, -5); return;
		end
		context[contextField] = n;
	end

	return self;
end

------------------------------
-- Error report
------------------------------
local erp = {};

--- Attach an error report to the given frame.
function VFLUI.AttachErrorReport(text, parent, ...)
	if (not text) or (not parent) or erp[parent] then return; end
	
	local self = VFLUI.AcquireFrame("Frame");
	self:SetParent(parent); self:SetFrameStrata(parent:GetFrameStrata()); self:SetFrameLevel(parent:GetFrameLevel() + 10);
	self:SetHeight(22); self:SetWidth(parent:GetWidth()); self:SetPoint("TOPLEFT", parent, unpack(arg));
	self:SetBackdrop(VFLUI.DefaultDialogBackdrop);

	local str = VFLUI.CreateFontString(self);
	str:SetFontObject(VFLUI.GetFont(Fonts.Default, 10));
	str:SetHeight(self:GetHeight()); str:SetWidth(self:GetWidth() - 10);
	str:SetPoint("LEFT", self, "LEFT", 5, 0); str:SetJustifyH("LEFT"); str:Show();
	str:SetText(strcolor(1,0,0) .. text .. "|r");
	self.text = str;

	local close = VFLUI.CloseButton:new(self);
	close:SetPoint("RIGHT", self, "RIGHT", -5, 0);
	close:Show();
	close:SetScript("OnClick", function() self:Destroy(); end);
	self.btnClose = close;

	self.Destroy = VFL.hook(function(s)
		s.btnClose:Destroy(); s.btnClose = nil;
		VFLUI.ReleaseRegion(s.text); s.text = nil;
		erp[parent] = nil;
	end, self.Destroy);

	erp[parent] = self;
	self:Show();
end

--- Destroy all extant error reports
function VFLUI.DestroyErrorReports()
	for _,e in erp do e:Destroy(); end
end

------------------------------
-- Generic config dialog
------------------------------
function VFLUI.CreateConfigDialog()
	local dlg = VFLUI.AcquireFrame("Frame");
	dlg:SetParent(UIParent); 
	dlg:SetFrameStrata("FULLSCREEN_DIALOG");
	dlg:SetHeight(350); dlg:SetWidth(350);
	dlg:SetPoint("CENTER", UIParent, "CENTER");
	dlg:SetBackdrop(VFLUI.DarkDialogBackdrop);
	dlg:Show();

	local sf = VFLUI.VScrollFrame:new(dlg);
	sf:SetWidth(320); sf:SetHeight(315);
	sf:SetPoint("TOPLEFT", dlg, "TOPLEFT", 5, -5);
	sf:Show();
	dlg.scrollFrame = sf;
	
	local btn = VFLUI.Button:new(dlg);
	btn:SetHeight(24); btn:SetWidth(50); btn:SetPoint("BOTTOMRIGHT", dlg, "BOTTOMRIGHT", -5, 5);
	btn:SetText("Cancel"); btn:Show();
	dlg.btnCancel = btn;

	btn = VFLUI.Button:new(dlg);
	btn:SetHeight(24); btn:SetWidth(50); btn:SetPoint("RIGHT", dlg.btnCancel, "LEFT");
	btn:SetText("OK"); btn:Show();
	dlg.btnOK = btn;

	dlg.SetConfigContext = function(s, cr, context, fnDone)
		s.configRoot = cr;
		cr.isLayoutRoot = true;
		cr:SetParent(sf);
		sf:SetScrollChild(cr);
		cr:OnInterfaceOpen(context); 
		cr:SetWidth(sf:GetWidth());
		cr:DialogOnLayout();
		cr:OnInterfaceUpdate(context);
		cr:Show(); s:Show();	
		VFL.AddEscapeHandler(function()
			if (not s) or (not s.configRoot) then return; end
			s.configRoot:OnInterfaceClose(context, nil);
			s:Destroy();
			fnDone(context, nil);
		end);
		s.btnCancel:SetScript("OnClick", function() VFL.Escape(); end);
		s.btnOK:SetScript("OnClick", function()
			local p = this:GetParent();
			if p then
				context.hasError = nil;
				p.configRoot:OnInterfaceClose(context, true);
				if not context.hasError then
					p:Destroy();
					fnDone(context, true);
				end
			end
		end);
	end;

	dlg.Destroy = VFL.hook(function(s)
		VFLUI.DestroyErrorReports();
		s.configRoot:Destroy(); s.configRoot = nil;
		s.scrollFrame:Destroy(); s.scrollFrame = nil;
		s.btnCancel:Destroy(); s.btnCancel = nil;
		s.btnOK:Destroy(); s.btnOK = nil;
		s.SetConfigContext = nil;
	end, dlg.Destroy);

	return dlg;
end



-- Test the config UI!
cui_sf, cui_context = nil, nil;

function cuitest()
	-- Create the generic config dialog
	local dlg = VFLUI.CreateConfigDialog();

	-- Create the root frame and context
	local context = {};
	context.OnInterfaceClose = VFL.Noop;
	local cf_Root = VFLUI.CompoundFrame:new(dlg.scrollFrame);
	
	-- Create first decor frame and add it to the root
	local cf_LE1 = VFLUI.PassthroughFrame:new(nil, cf_Root);
	cf_Root:InsertFrame(cf_LE1);
	cf_LE1:SetBackdrop(VFLUI.DefaultDialogBackdrop);
	-- Create first checkgroup and add it to the decor frame.
	local cf_LE1_CG = VFLUI.CheckGroup:new(cf_LE1);
	cf_LE1:SetChild(cf_LE1_CG, 5, 20, 5, 5);
	cf_LE1_CG.OnInterfaceOpen = function(self, context)
		self:SetLayout(9, 2);
		for i=1,9 do self.checkBox[i]:SetText(i); end
	end;
	-- Create 2
	local cf_LE2 = VFLUI.PassthroughFrame:new(nil, cf_Root);
	cf_Root:InsertFrame(cf_LE2);
	cf_LE2:SetBackdrop(VFLUI.DefaultDialogBackdrop);
	-- Create 2CG
	local cf_LE2_Thing = VFLUI.NumericEdit:new(cf_LE2, 40, "number", true);
	cf_LE2_Thing.text:SetText("How much would you like to die?");
	cf_LE2:SetChild(cf_LE2_Thing, 5, 5, 5, 5);
	-- Create 3
	local cf_LE3 = VFLUI.CollapsibleFrame:new(cf_Root);
	cf_LE3:SetText("Whores!");
	cf_Root:InsertFrame(cf_LE3);
	-- Create 3CG
	local cf_LE3_CG = VFLUI.CheckGroup:new(cf_LE3);
	cf_LE3:SetChild(cf_LE3_CG);
	cf_LE3_CG.OnInterfaceOpen = function(self, context)
		self:SetLayout(16, 2);
		for i=1,16 do self.checkBox[i]:SetText("Die " .. i); end
	end;	

	-- Oh shit, this is going to blow up so bad.
	dlg:SetConfigContext(cf_Root, context);
end

