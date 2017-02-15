-- DragDrop.lua
-- VFL
-- (C)2006 Bill Johnson
--
-- The drag-and-drop interface for VFL.

--------------------------------------------
-- Drag context
--
-- The core of the drag and drop system. When a drag is started,
-- all frames registered to the DragContext of the drag are those
-- eligible to be dropped into.
--------------------------------------------
VFLUI.DragContext = {};

--- Create a new drag context.
function VFLUI.DragContext:new()
	local self = {};

	local targets, dragging, dragRoot, over = {}, nil, nil, nil;
	local oldOnUpdate, oldOnMouseUp = nil, nil;

	-- This is the routine that will be called whilst dragging is proceeding.
	local function DragUpdate()
		-- If the mouse is over a different frame...
		if (not over) or (not MouseIsOver(over)) then
			-- Inform that we left the old frame...
			if over and over.OnDragLeave then over:OnDragLeave(); end
			-- Find the new frame
			over = nil;
			for frame,_ in targets do
				if (frame:IsVisible() and MouseIsOver(frame)) then over = frame; end
			end
			-- If we're over something, inform we entered
			if over and over.OnDragEnter then over:OnDragEnter(); end
		end	
	end

	-- This is the routine that will be called when dragging is over
	local function DragDone()
		-- Stop the drag
		dragging:StopMovingOrSizing();
		for targ,_ in targets do if (targ:IsVisible() and targ.OnDragStop) then targ:OnDragStop(); end end
		
		-- If we're hovering over something, call it a drop
		if over then
			if(over.OnDragLeave) then over:OnDragLeave(); end
			if(over.OnDrop) then over:OnDrop(dragging, dragRoot); end
			over = nil;
		end

		-- Clear dragging handlers
		dragging:SetScript("OnUpdate", oldOnUpdate);
		dragRoot:SetScript("OnMouseUp", oldOnMouseUp);

		-- Notify the dragged object that it's no longer being dragged.
		if(dragging.OnDragFinished) then dragging:OnDragFinished(); end
		dragging = nil; dragRoot = nil;
	end

	-- Target management.
	self.RegisterDragTarget = function(x, targ) targets[targ] = true; end
	self.UnregisterDragTarget = function(x, targ) targets[targ] = nil; end
	self.UnregisterAllTargets = function() VFL.empty(targets); end

	-- The drag handler. Called when a drag starts.
	self.Drag = function(x, frame, dragProxy)
		-- Don't allow double calls to :Drag
		if dragging then error("VFLUI.DragContext:Drag(): called twice."); return; end
		
		-- Set up the frame's positioning.
		dragging = frame; dragRoot = frame;
		if dragProxy then -- If we're using a proxy, make sure the proxy matches the parent's properties
			dragging = dragProxy;
			dragging:SetParent(frame); dragging:SetScale(1);
			dragging:SetFrameStrata(frame:GetFrameStrata()); dragging:SetFrameLevel(frame:GetFrameLevel() + 1);
			dragging:SetPoint("TOPLEFT", frame, "TOPLEFT");
		end
		if not dragging then error("VFLUI.DragContext:Drag(): attempt to Drag a nil handle."); return; end
		dragging:Show();
		
		-- Notify all our DragTargets that something's being dragged
		for targ,_ in targets do if (targ:IsVisible() and targ.OnDragStart) then targ:OnDragStart(); end end
	
		-- Change the frame's OnUpdate handler
		oldOnUpdate = dragging:GetScript("OnUpdate");
		-- Defer the StartMoving() till the next layout engine tick (BUGFIX)
		dragging:SetScript("OnUpdate", function()
			this:StartMoving();
			this:SetScript("OnUpdate", DragUpdate);
		end);
		oldOnMouseUp = dragRoot:GetScript("OnMouseUp");
		dragRoot:SetScript("OnMouseUp", DragDone);
	end

	return self;
end

--- Create a generic drag proxy. This proxy is a Button with
-- a plain text label that will carry a payload of data, and self destruct on
-- the completion of a drag operation.
function VFLUI.CreateGenericDragProxy(parent, text, data)
	if not parent then 
		error("VFLUI.CreateGenericDragProxy(): parent argument is required.");
		return nil; 
	end
	-- Appearance
	local self = VFLUI.AcquireFrame("Button");
	self:SetParent(parent); self:SetFrameStrata(parent:GetFrameStrata()); self:SetFrameLevel(parent:GetFrameLevel() + 1);
	self:SetWidth(parent:GetWidth()); self:SetHeight(parent:GetHeight());
	self:SetMovable(true); 
	self:SetBackdrop(VFLUI.BorderlessDialogBackdrop); self:SetTextFontObject(Fonts.Default);
	if text then self:SetText(text); end

	self.data = data;

	-- Destroy handlers
	self.OnDragFinished = function(s) s:Destroy(); end
	self.Destroy = VFL.hook(function(s)
		s.data = nil; s.OnDragFinished = nil;
	end, self.Destroy);

	return self;
end
