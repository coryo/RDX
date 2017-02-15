-- UI\Core.lua
-- VFL - Venificus' Function Library
-- (C)2006 Bill Johnson (Venificus of Eredar server)
--
-- Core functions for managing dynamic WoW UI primitives.

VFL:Debug(1, "Loading UI\\Core.lua");

VFLUI = RegisterVFLModule({
	name = "VFLUI";
	description = "Common UI components for VFL";
	version = {6,0,2}; devel = true;
	parent = VFL;
});

--------------------------------------------------
-- Fixed metadata
--------------------------------------------------
--- The "default" Dialog backdrop
VFLUI.DefaultDialogBackdrop = { 
	bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 16,
	edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
	insets = { left = 5, right = 5, top = 4, bottom = 5 }
};

VFLUI.DarkDialogBackdrop = { 
	bgFile="Interface\\Addons\\VFL\\Skin\\a80black", tile = true, tileSize = 16,
	edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
	insets = { left = 5, right = 5, top = 4, bottom = 5 }
};

VFLUI.BlackDialogBackdrop = {
	bgFile="Interface\\Addons\\VFL\\Skin\\black", tile = true, tileSize = 16,
	edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
	insets = { left = 5, right = 5, top = 4, bottom = 5 }
};

VFLUI.BorderlessDialogBackdrop = {
	bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", tile = true, tileSize = 16,
};

VFLUI.DefaultDialogBorder = {
	edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16,
	insets = { left = 5, right = 5, top = 4, bottom = 5 }
};

--------------------------------------------------
-- WoW Universal Coordinates
--------------------------------------------------
--- Convert a distance from frame-local coordinates to universal coordinates.
-- @param frame The local frame.
-- @param dx The amount to convert.
-- @return The distance in universal coordinates.
function ToUniversalAxis(frame, dx)
	return dx*frame:GetEffectiveScale();
end

function ToLocalAxis(frame, dx)
	return dx/frame:GetEffectiveScale();
end

function GetUniversalCoords(frame, x, y)
	local v = frame:GetEffectiveScale();
	return x*v, y*v;
end

function GetUniversalCoords4(frame, x, y, z, w)
	local v = frame:GetEffectiveScale();
	return x*v, y*v, z*v, w*v;
end

function GetLocalCoords(frame, x, y)
	local v = (1/frame:GetEffectiveScale());
	return x*v, y*v;
end

function GetLocalCoords4(frame, x, y, z, w)
	local v = (1/frame:GetEffectiveScale());
	return x*v, y*v, z*v, w*v;
end

--- Get the mouse position in the local coordinates of the given frame.
function GetLocalMousePosition(frame)
	return GetLocalCoords(frame, GetCursorPosition());
end

--- Get the mouse position in the local coordinates of the given frame RELATIVE TO THE TOPLEFT OF THAT FRAME.
function GetRelativeLocalMousePosition(frame)
	local l, t, mx, my = frame:GetLeft(), frame:GetTop(), GetLocalCoords(frame, GetCursorPosition());
	return (mx - l), (my - t);
end

--- Get the left, top, right, and bottom points of a frame in universal coordinates.
function GetUniversalBoundary(frame)
	return GetUniversalCoords4(frame, frame:GetLeft(), frame:GetTop(), frame:GetRight(), frame:GetBottom());
end

-- Global universal coordinates for the screen itself
local scx, scy = GetUniversalCoords(UIParent, UIParent:GetCenter());
VFLUI.uxScreenCenter = scx;
VFLUI.uyScreenCenter = scy;
local sl, st, sr, sb = GetUniversalBoundary(UIParent);
VFLUI.uScreenLeft = sl;
VFLUI.uScreenTop = st;
VFLUI.uScreenRight = sr;
VFLUI.uScreenBottom = sb;

----------------------------------
-- GENERIC OBJECT POOL MANAGEMENT
----------------------------------
VFLKernelRegisterCategory("FramePool");
local objp = {};
local regionp = {};

-- Cleanup a Texture
local function CleanupTexture(x)
	x:Hide(); x:SetTexture(nil); 
	x:SetParent(VFLOrphan); x:ClearAllPoints(); x:SetAlpha(1);
	x:SetDesaturated(nil);
	x:SetTexCoord(0,1,0,1);
	x:SetBlendMode("BLEND"); x:SetDrawLayer("ARTWORK");
	x:SetVertexColor(1,1,1,1);
end

-- Cleanup a FontString
local function CleanupFontString(x)
	x:Hide(); x:SetParent(VFLOrphan); x:ClearAllPoints(); x:SetAlpha(1);
	x:SetHeight(0); x:SetWidth(0);
	x:SetFontObject(nil);
	x:SetTextColor(1,1,1,1);
	x:SetAlphaGradient(0,0);
	x:SetJustifyH("CENTER"); x:SetJustifyV("CENTER");
	x:SetText("");
end

-- Cleanup a LayoutFrame.
local function CleanupLayoutFrame(x)
	x:Hide(); x:SetParent(nil); x:ClearAllPoints();
	x:SetHeight(0); x:SetWidth(0);
	x:SetAlpha(1); 
end

local function RemoveFrameScripts(x)
	x:SetScript("OnUpdate", nil);
	x:SetScript("OnShow", nil);
	x:SetScript("OnHide", nil);
	x:SetScript("OnSizeChanged", nil);
	x:SetScript("OnEvent", nil);
	x:SetScript("OnMouseUp", nil);
	x:SetScript("OnMouseDown", nil);
	x:SetScript("OnMouseWheel", nil);
	x:SetScript("OnEnter", nil);
	x:SetScript("OnLeave", nil);
	x:SetScript("OnKeyDown", nil);
	x:SetScript("OnKeyUp", nil);
end

-- Cleanup a Frame
local function CleanupFrame(x)
	-- Cleanup scripts
	x._vflht = nil;
	x:UnregisterAllEvents();
	RemoveFrameScripts(x);
	x.isLayoutRoot = nil;
	-- Stop any and all movement
	x:StopMovingOrSizing();
	x:SetMovable(nil); x:SetResizable(nil); 
	x:Hide();
	x:SetFrameStrata("MEDIUM"); x:SetFrameLevel(0); -- this will probably break a lot of things...
	-- Perform LayoutFrame cleanup...
	CleanupLayoutFrame(x);
	-- Frame specific cleanup
	x:SetScale(1);
	x:SetBackdrop(nil);
end

-- Cleanup a Button
local function CleanupButton(x)
	x:SetScript("OnClick", nil);
	x:SetScript("OnDoubleClick", nil);
	x:RegisterForClicks("LeftButtonUp");
	x:SetNormalTexture(nil); x:SetHighlightTexture(nil); x:SetDisabledTexture(nil); x:SetPushedTexture(nil);
	x:SetTextFontObject(nil); x:SetDisabledFontObject(nil); x:SetHighlightFontObject(nil);
	x:Enable(); x:SetButtonState("NORMAL", nil); x:UnlockHighlight();
	x:SetText(""); 
	x:SetTextColor(1,1,1,1); x:SetDisabledTextColor(1,1,1,1);
	CleanupFrame(x);
end

-- Cleanup a CheckButton
local function CleanupCheckButton(x)
	x:SetCheckedTexture(nil); x:SetDisabledCheckedTexture(nil); x:SetChecked(nil);
	CleanupButton(x);
end

-- Cleanup a Slider
local function CleanupSlider(x)
	x:SetScript("OnValueChanged", nil);
	x:SetThumbTexture(nil);	x:SetMinMaxValues(0,0); x:SetValue(0);
	CleanupFrame(x);
end

-- Cleanup a ScrollFrame
local function CleanupScrollFrame(x)
	x:SetScript("OnScrollRangeChanged", nil);
	x:SetScript("OnVerticalScroll", nil);
	x:SetHorizontalScroll(0); x:SetVerticalScroll(0);
	x:SetScrollChild(nil);
	CleanupFrame(x);
end

-- Cleanup an EditBox
local function CleanupEditBox(x)
	x:SetScript("OnEditFocusGained", nil);
	x:SetScript("OnEditFocusLost", nil);
	x:SetScript("OnEnterPressed", nil);
	x:SetScript("OnEscapePressed", nil);
	x:SetScript("OnTabPressed", nil);
	x:SetScript("OnTextChanged", nil);
	x:SetScript("OnTextSet", nil);
	x:SetAutoFocus(nil); x:ClearFocus();
	x:SetNumeric(nil); x:SetPassword(nil); x:SetMultiLine(nil);
	x:SetText(""); x:SetTextColor(1,1,1,1);
	CleanupFrame(x);
end

-- Cleanup a StatusBar
local function CleanupStatusBar(x)
	x:SetMinMaxValues(0,1);
	x:SetStatusBarTexture(nil);
	CleanupFrame(x);
end

-- Create a kernel region pool. Internal use only.
local function CreateRegionPool(name, onRel)
	local p = VFL.Pool:new();
	p.name = name; p.OnRelease = onRel;
	regionp[name] = p;
	VFLKernelRegisterObject("FramePool", p);
end

--- Create a new kernel frame pool. After this operation completes,
-- VFLUI.AcquireFrame() will be usable to acquire frames of the new
-- type.
-- @param name The name of the object type stored in this pool.
-- @param onRel the OnRelease handler for this pool.
-- @param onFallback the OnFallback handler for this pool.
-- @param onAcq the OnAcquire handler for this pool.
function VFLUI.CreateFramePool(name, onRel, onFallback, onAcq)
	local p = VFL.Pool:new();
	p.name = name; 
	p.OnRelease = onRel; p.OnFallback = onFallback; p.OnAcquire = onAcq;
	objp[name] = p;
	VFLKernelRegisterObject("FramePool", p);
end

-- Create the kernel frame pools for all the WoW builtin frame types.
local function CreateFramePools()
	-- Class: Texture
	CreateRegionPool("Texture", function(pool, tx) CleanupTexture(tx); end);
	-- Class: FontString
	CreateRegionPool("FontString", function(pool, fs) CleanupFontString(fs); end);
	
	-- Class: Frame
	VFLUI.CreateFramePool("Frame", function(pool, frame) CleanupFrame(frame); end, function() return CreateFrame("Frame"); end);
	-- Class: Button
	VFLUI.CreateFramePool("Button", function(pool, frame) CleanupButton(frame); end, function() return CreateFrame("Button"); end);
	-- Class: Slider
	VFLUI.CreateFramePool("Slider", function(pool, frame) CleanupSlider(frame); end, function() return CreateFrame("Slider"); end);
	-- Class: CheckButton
	VFLUI.CreateFramePool("CheckButton", function(pool, frame) CleanupCheckButton(frame); end, function() return CreateFrame("CheckButton"); end);
	-- Class: ScrollFrame
	VFLUI.CreateFramePool("ScrollFrame", function(pool, frame) CleanupScrollFrame(frame); end, function() return CreateFrame("ScrollFrame"); end);
	-- Class: EditBox
	VFLUI.CreateFramePool("EditBox", function(pool, frame) CleanupEditBox(frame); end, function() return CreateFrame("EditBox"); end);
	-- Class: StatusBar
	VFLUI.CreateFramePool("StatusBar", function(pool, frame) CleanupStatusBar(frame); end, function() return CreateFrame("StatusBar"); end);
end

CreateFramePools();

----------------------------------
-- GENERIC OBJECT POOL PUBLIC INTERFACE
----------------------------------
--- Acquire a Frame-derived object of the given type
-- @param frameType The type of object desired. ("Frame", "Button", etc.)
-- @return An object of the given type in a clean state, or NIL on failure.
function VFLUI.AcquireFrame(frameType)
	local pool = objp[frameType];
	if not pool then return nil; end
	local frame = pool:Acquire();
	frame.Destroy = function(x) pool:Release(x); x.Destroy = nil; end
	return frame;
end

--- Release a Frame-derived object.
-- @param frame An object previously returned by VFLUI.AcquireFrame.
function VFLUI.ReleaseFrame(frame)
	-- Sanity check
	if not frame then return; end
	-- Try for the Destroy method
	if frame.Destroy then 
		frame:Destroy(); 
	else
		VFLUI:Debug(1, "VFLUI: Error: VFLUI.ReleaseFrame() called on object without a Destroy method.");
	end
end

--- Acquire a FontString as a child of the given frame.
-- @param parent The frame to which this FontString will be attached.
-- @return The FontString, or NIL on failure.
function VFLUI.CreateFontString(parent)
	local pool = regionp["FontString"];
	pool.OnFallback = function() 
		return parent:CreateFontString(); 
	end
	local rgn = pool:Acquire();
	rgn:SetParent(parent);
	return rgn;
end

--- Acquire a Texture as a child of the given frame.
-- @param parent The frame to which this Texture will be attached.
-- @return The texture, or NIL on failure.
function VFLUI.CreateTexture(parent)
	local pool = regionp["Texture"];
	pool.OnFallback = function() 
		return parent:CreateTexture(); 
	end
	local rgn = pool:Acquire();
	rgn:SetParent(parent);
	return rgn;
end

--- Manually release a Region.
-- @param rgn The region to be freed.
function VFLUI.ReleaseRegion(rgn)
	-- DEBUG
	if not rgn then
		VFLUI:Debug(1, "VFLUI.ReleaseRegion(): nil region.");
		VFLUI:Debug(1, debugstack());
		return;
	end
	local pool = regionp[rgn:GetObjectType()];
	if not pool then return; end
	pool:Release(rgn);
end

----------------------------------
-- FONT OBJECT MANAGER
-- Allows for the registration of application-specific, replaceable
-- font objects.
----------------------------------
local fonts = {};

--- Acquire a font of the given face with the given size.
-- @param base The base Font object to derive a new face from.
-- @param sz The size of the desired font.
-- @return A font object matching the desired parameters, or nil on failure.
function VFLUI.GetFont(base, sz)
	-- If no size is provided, use the default.
	if (not sz) then return base; end
	-- Sanity check arguments
	sz = tonumber(sz);
	if (not base) or (sz < 1) then return nil; end
	-- Determine if the original font will suffice
	local file, origSz, flags = base:GetFont();
	if VFL.close(origSz, sz) then 
		return base; 
	end
	-- Nope, have to find a new one. See if we already created it
	local idx = base:GetName() .. sz;
	if fonts[idx] then
		VFLUI:Debug(20, "GetFont(): returning font at index " .. idx);
		return fonts[idx]; 
	end
	-- Nope, need to make a new one.
	local f2 = CreateFont(idx);
	f2:CopyFontObject(base);
	f2:SetFont(file, sz, flags);
	VFLUI:Debug(20, "GetFont(): creating font at index " .. idx);
	fonts[idx] = f2;
	return f2;
end

---------------------------------------
-- HOOKABLE UI SCRIPTING
---------------------------------------
function VFLUI.AddScript(frame, event, fn)
	local oldScript = frame:GetScript(event);
	if not oldScript then
		frame:SetScript(event, fn);
	else
		frame:SetScript(event, function() oldScript(); fn(); end);
	end
end

------------------------------------------
-- USEFUL HELPER FUNCTIONS
------------------------------------------
-- Set the parent of the given frame to the given frame, and adjust the
-- layout parameters appropriately.
function VFLUI.StdSetParent(frame, parent, flm)
	if frame and parent then
		frame:SetParent(parent); frame:SetFrameStrata(parent:GetFrameStrata());
		frame:SetFrameLevel(parent:GetFrameLevel() + (flm or 0));
	end
end
