--[[
	ElvUI Wotlk: what the ElvUI v15 Wrath flavor (written for the Wrath Classic client) needs from the 3.3.5 client
	it does not have (Whitemane, Frostmourne Rebuffed: base 3.3.5 + rebuffed.dll + a modernized SharedXML).

	Every Lua file of ElvUI, ElvUI_Libraries and ElvUI_Options starts with setfenv(1, ElvUI335_ENV): its globals are
	read through this environment, so the missing APIs (C_ namespaces, WOW_PROJECT_ID...) exist for ElvUI only and
	the other addons of the session never see them. Reads fall back to the real globals; writes go to the real
	globals (a file that defines a global defines it for everyone, as before). _G inside ElvUI is the environment.

	The one global change: methods the 3.3.5 widgets lack are added to the shared widget method tables, only where
	absent (as ElvUI's Toolkit already does for its own methods), so a frame of any addon answers them.
]]

local realG = _G
local rawget, rawset, type, pairs, select, setmetatable = rawget, rawset, type, pairs, select, setmetatable

local env = setmetatable({}, {__index = realG, __newindex = realG})
rawset(env, "_G", env)
ElvUI335_ENV = env

local Compat = {}
rawset(env, "ElvUI335", Compat)

local function noop() end
local function returnFalse() return false end
local function returnNil() return nil end
Compat.noop, Compat.returnFalse, Compat.returnNil = noop, returnFalse, returnNil

--a namespace of the environment: the native one when the client has it (rebuffed.dll fills some), with the
--missing functions added on a table of our own (the native table is never written to)
local function fill(name, functions)
	local ns = rawget(env, name)
	if (not ns) then
		local native = realG[name]
		ns = native and setmetatable({}, {__index = native}) or {}
		rawset(env, name, ns)
	end
	for k, v in pairs(functions or {}) do
		if (ns[k] == nil) then rawset(ns, k, v) end
	end
	return ns
end
Compat.fill = fill

--a global function of the environment, when the client has none
local function define(name, func)
	if (realG[name] == nil and rawget(env, name) == nil) then rawset(env, name, func) end
end
Compat.define = define

---------------------------------------------------------------------------------------------------------------
--> xpcall with arguments (later clients pass the extra arguments to the function, Lua 5.1 as 3.3.5 ships it does
--  not: oUF's event validation, AceAddon and CallbackHandler rely on it)

if (select(2, xpcall(function(a) return a end, function() end, true)) ~= true) then
	local xpcall, select, unpack = realG.xpcall, select, unpack
	rawset(env, "xpcall", function(func, handler, ...)
		local n = select("#", ...)
		if (n == 0) then return xpcall(func, handler) end
		local args = {...}
		return xpcall(function() return func(unpack(args, 1, n)) end, handler)
	end)
end

---------------------------------------------------------------------------------------------------------------
--> client flavor: ElvUI and its libraries tell Retail / Classic / Wrath... apart by WOW_PROJECT_ID

rawset(env, "WOW_PROJECT_MAINLINE", 1)
rawset(env, "WOW_PROJECT_CLASSIC", 2)
rawset(env, "WOW_PROJECT_BURNING_CRUSADE_CLASSIC", 5)
rawset(env, "WOW_PROJECT_WRATH_CLASSIC", 11)
rawset(env, "WOW_PROJECT_CATACLYSM_CLASSIC", 14)
rawset(env, "WOW_PROJECT_MISTS_CLASSIC", 19)
rawset(env, "WOW_PROJECT_ID", 11)

---------------------------------------------------------------------------------------------------------------
--> CreateFrame: templates of later clients 3.3.5 lacks. BackdropTemplate: the 3.3.5 frames have SetBackdrop natively.
--  The dialog borders get their look from a backdrop of the 3.3.5 dialog art.

local CreateFrame = realG.CreateFrame
local DIALOG_BACKDROP = {bgFile = "Interface\DialogFrame\UI-DialogBox-Background", edgeFile = "Interface\DialogFrame\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 32, insets = {left = 11, right = 12, top = 12, bottom = 11}}
local MODERN_TEMPLATES = {
	BackdropTemplate = false,
	DialogBorderOpaqueTemplate = DIALOG_BACKDROP,
	DialogBorderTemplate = DIALOG_BACKDROP,
	DialogBorderDarkTemplate = DIALOG_BACKDROP,
	TooltipBackdropTemplate = false,
	--the 3.3.5 template of that name is a backpack model, not the item button animation
	ItemAnimTemplate = false,
	--renamed: the 3.3.5 template of the same widget
	MainMenuFrameButtonTemplate = "GameMenuButtonTemplate",
	StanceButtonTemplate = "ShapeshiftButtonTemplate",
	--a template that only adds behavior: done on the frame after its creation
	TitleDragAreaTemplate = function(frame)
		local parent = frame:GetParent()
		frame:EnableMouse(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function() if (parent:IsMovable()) then parent:StartMoving() end end)
		frame:SetScript("OnDragStop", function() parent:StopMovingOrSizing() end)
	end,
}
--template list without the modern names; the backdrop one of them asks for, the behavior to add
local function stripModernTemplates(template)
	if (type(template) ~= "string") then return template end
	local kept, backdrop, behavior = {}, nil, nil
	for name in template:gmatch("[^,%s]+") do
		local modern = MODERN_TEMPLATES[name]
		if (modern == nil) then
			kept[#kept + 1] = name
		elseif (type(modern) == "string") then
			kept[#kept + 1] = modern
		elseif (type(modern) == "function") then
			behavior = modern
		elseif (modern) then
			backdrop = modern
		end
	end
	return #kept > 0 and table.concat(kept, ",") or nil, backdrop, behavior
end
Compat.stripModernTemplates = stripModernTemplates
--3.3.5 templates only name their children ($parentScrollBar) where later ones also give them a parentKey (ScrollBar):
--the frames ElvUI makes from a template get the key of each named child, where the key is free
--(the action button's icon and cooldown have lower case keys on later clients)
local LOWER_KEYS = {Icon = "icon", IconTexture = "icon", Cooldown = "cooldown"}
local function addParentKeys(frame, name, ...)
	local length = #name
	for i = 1, select("#", ...) do
		local child = select(i, ...)
		local childName = child.GetName and child:GetName()
		if (childName and #childName > length and childName:sub(1, length) == name) then
			local key = childName:sub(length + 1)
			if (key:match("^%u%w*$")) then
				if (frame[key] == nil) then frame[key] = child end
				local lower = LOWER_KEYS[key]
				if (lower and frame[lower] == nil) then frame[lower] = child end
			end
		end
	end
end
--the same keys on a stock frame ElvUI reaches by them (chat tabs...)
function Compat.AddParentKeys(frame)
	local name = frame and frame:GetName()
	if (not name or frame.__elvParentKeys) then return frame end
	frame.__elvParentKeys = true
	addParentKeys(frame, name, frame:GetChildren())
	addParentKeys(frame, name, frame:GetRegions())
	return frame
end
--the overlays of the later item button (10.0 ItemButton type, ItemButtonTemplate keys) the 3.3.5 one lacks:
--hidden textures over the icon, so the code that colors or shows them has something to work on
local function addItemButtonParts(button)
	for _, key in ipairs({"IconBorder", "IconOverlay", "IconOverlay2", "searchOverlay", "ItemContextOverlay"}) do
		if (button[key] == nil) then
			local texture = button:CreateTexture(nil, "OVERLAY")
			texture:SetAllPoints(button.icon or button)
			texture:Hide()
			button[key] = texture
		end
	end
end
Compat.AddItemButtonParts = addItemButtonParts
rawset(env, "CreateFrame", function(frameType, name, parent, template, id)
	local itemButton = (type(frameType) == "string" and frameType:lower() == "itembutton")
	if (itemButton) then frameType = "Button" end
	local kept, backdrop, behavior = stripModernTemplates(template)
	local frame = CreateFrame(frameType, name, parent, kept, id)
	if (backdrop and frame.SetBackdrop) then frame:SetBackdrop(backdrop) end
	if (behavior) then behavior(frame) end
	if (kept and type(name) == "string") then
		addParentKeys(frame, name, frame:GetChildren())
		addParentKeys(frame, name, frame:GetRegions())
	end
	if (itemButton or (kept and kept:find("ItemButton"))) then addItemButtonParts(frame) end
	--the 3.3.5 UIPanelButtonTemplate has no size (later ones: 40 x 22) and its text has no parentKey
	if (kept and kept:find("UIPanelButtonTemplate")) then
		if (frame:GetHeight() == 0) then frame:SetHeight(22) end
		if (frame:GetWidth() == 0) then frame:SetWidth(40) end
	end
	if (kept and frame.GetFontString and frame.Text == nil) then
		frame.Text = frame:GetFontString()
	end
	return frame
end)
--what the Backdrop mixin adds to a frame on modern clients: the 3.3.5 frame already backs SetBackdrop natively
rawset(env, "BackdropTemplateMixin", {
	OnBackdropLoaded = noop, OnBackdropSizeChanged = noop, SetupTextureCoordinates = noop,
	ApplyBackdrop = noop, ClearBackdrop = function(self) self:SetBackdrop(nil) end,
})

---------------------------------------------------------------------------------------------------------------
--> atlases: Rebuffed's Lua Texture:SetAtlas raises on a name its atlas table lacks (most later atlases). ElvUI's calls
--  go through ElvUI335.SetAtlas (node outils/elvui335_atlas.js), which leaves the texture empty instead; the client
--  method itself stays untouched. The names missing in the session are listed in ElvUI335.missingAtlases

do
	local missing = {}
	Compat.missingAtlases = missing
	function Compat.AtlasExists(atlas)
		return type(atlas) == "string" and realG.AtlasUtil ~= nil and realG.AtlasUtil:AtlasExists(atlas)
	end
	function Compat.SetAtlas(region, atlas, ...)
		if (atlas == nil or atlas == "" or Compat.AtlasExists(atlas)) then
			if (atlas == "") then atlas = nil end
			return region:SetAtlas(atlas, ...)
		end
		missing[atlas] = true
		region:SetTexture(nil)
	end
end

---------------------------------------------------------------------------------------------------------------
--> hooksecurefunc: a hook on a function 3.3.5 does not have (MarkNewActionHighlight, ChatFrameUtil.InsertLink...)
--  is skipped instead of raising; the skipped targets are listed in ElvUI335.skippedHooks

do
	local hook = realG.hooksecurefunc
	local skipped = {}
	Compat.skippedHooks = skipped
	rawset(env, "hooksecurefunc", function(target, name, func)
		if (type(target) == "string") then
			if (type(realG[target]) ~= "function" and type(rawget(env, target)) ~= "function") then
				skipped[target] = true
				return
			end
			if (type(rawget(env, target)) == "function" and type(realG[target]) ~= "function") then
				--a function of the environment (a compat one): hooked in place
				local original = rawget(env, target)
				rawset(env, target, function(...)
					local r = {original(...)}
					name(...)
					return unpack(r)
				end)
				return
			end
			return hook(target, name)
		end
		if (type(target) ~= "table" or type(target[name]) ~= "function") then
			skipped[tostring(name)] = true
			return
		end
		return hook(target, name, func)
	end)
end

--the AceHook methods of an ElvUI module (its own table) skip a target 3.3.5 does not have, as hooksecurefunc above,
--instead of raising and stopping the module's setup at the first later function (EditModeManagerFrame...)
do
	local skipped = Compat.skippedHooks
	local function functionExists(object, method)
		if (object == nil) then
			return type(realG[method]) == "function" or type(rawget(env, method)) == "function"
		end
		return type(object) == "table" and type(object[method]) == "function"
	end
	local function scriptExists(frame, script)
		return type(frame) == "table" and frame.HasScript ~= nil and frame:HasScript(script) and true or false
	end
	function Compat.SafeHooks(obj)
		if (obj.__elvSafeHooks) then return end
		obj.__elvSafeHooks = true
		for _, name in ipairs({"Hook", "RawHook", "SecureHook"}) do
			local original = obj[name]
			if (original) then
				obj[name] = function(self, object, method, ...)
					if (type(object) == "string") then
						if (not functionExists(nil, object)) then skipped[object] = true return end
					elseif (not functionExists(object, method)) then
						skipped[tostring(method)] = true
						return
					end
					return original(self, object, method, ...)
				end
			end
		end
		for _, name in ipairs({"HookScript", "RawHookScript", "SecureHookScript"}) do
			local original = obj[name]
			if (original) then
				obj[name] = function(self, frame, script, ...)
					if (not scriptExists(frame, script)) then
						skipped[tostring(script)] = true
						return
					end
					return original(self, frame, script, ...)
				end
			end
		end
	end
end

---------------------------------------------------------------------------------------------------------------
--> C_Timer (the session may have one from another addon: ElvUI uses its own, with cancelable handles)

do
	local timers = {}
	local driver = CreateFrame("Frame")
	driver:Hide()
	local GetTime = realG.GetTime
	driver:SetScript("OnUpdate", function(self)
		local now = GetTime()
		local i, any = 1, false
		while (i <= #timers) do
			local t = timers[i]
			if (t._cancelled) then
				table.remove(timers, i)
			elseif (now >= t._at) then
				local ok, err = pcall(t._callback, t)
				if (not ok) then geterrorhandler()(err) end
				t._remaining = t._remaining and (t._remaining - 1) or nil
				if (t._repeat and not t._cancelled and (t._remaining == nil or t._remaining > 0)) then
					t._at = now + t._delay
					i = i + 1
				else
					t._cancelled = true
					table.remove(timers, i)
				end
			else
				i = i + 1
			end
		end
		if (#timers == 0) then self:Hide() end
	end)

	local Handle = {}
	Handle.__index = Handle
	function Handle:Cancel() self._cancelled = true end
	function Handle:IsCancelled() return self._cancelled == true end

	local function start(delay, callback, rep, iterations)
		local t = setmetatable({_delay = delay or 0, _callback = callback, _repeat = rep, _remaining = iterations}, Handle)
		t._at = GetTime() + t._delay
		timers[#timers + 1] = t
		driver:Show()
		return t
	end

	fill("C_Timer", {
		After = function(delay, callback) start(delay, function() callback() end, false) end,
		NewTimer = function(delay, callback) return start(delay, callback, false) end,
		NewTicker = function(delay, callback, iterations) return start(delay, callback, true, iterations) end,
	})
end

---------------------------------------------------------------------------------------------------------------
--> C_AddOns, C_CVar: the 3.3.5 globals under their modern names

fill("C_AddOns", {
	GetAddOnMetadata = realG.GetAddOnMetadata,
	--3.3.5 returns 1 or nil: ElvUI puts the result in option tables, where AceConfig wants a boolean
	IsAddOnLoaded = function(addon) local loaded = realG.IsAddOnLoaded(addon) and true or false return loaded, loaded end, -- loaded or loading, loaded
	LoadAddOn = realG.LoadAddOn,
	GetNumAddOns = realG.GetNumAddOns,
	EnableAddOn = realG.EnableAddOn,
	DisableAddOn = realG.DisableAddOn,
	IsAddOnLoadOnDemand = function(addon) return realG.IsAddOnLoadOnDemand(addon) and true or false end,
	--modern: name, title, notes, loadable, reason, security, updateAvailable; 3.3.5 has enabled in 4th place
	GetAddOnInfo = function(addon)
		local name, title, notes, enabled, loadable, reason, security = realG.GetAddOnInfo(addon)
		return name, title, notes, loadable, reason, security, false
	end,
	--0 disabled, 2 enabled (3.3.5 knows only the account-wide state)
	GetAddOnEnableState = function(addon, character)
		if (type(addon) ~= "string" and type(character) == "string") then addon = character end
		local name, _, _, enabled = realG.GetAddOnInfo(addon)
		if (not name) then return 0 end
		return enabled and 2 or 0
	end,
	DoesAddOnExist = function(addon) return realG.GetAddOnInfo(addon) ~= nil end,
})

--a later cvar (most nameplate ones, unless rebuffed.dll adds them) is absent: nil, or an error on some builds
local function cvarExists(name)
	local ok, value = pcall(realG.GetCVar, name)
	return ok and value ~= nil
end
fill("C_CVar", {
	GetCVar = function(name) if (cvarExists(name)) then return realG.GetCVar(name) end end,
	SetCVar = function(name, value) if (cvarExists(name)) then realG.SetCVar(name, value) return true end return false end,
	GetCVarBool = function(name) if (cvarExists(name)) then return realG.GetCVarBool(name) end end,
	GetCVarDefault = function(name) if (realG.GetCVarDefault and cvarExists(name)) then return realG.GetCVarDefault(name) end end,
	RegisterCVar = function(name, value) if (realG.RegisterCVar) then realG.RegisterCVar(name, value) end end,
})

---------------------------------------------------------------------------------------------------------------
--> namespaces ElvUI indexes unconditionally at load ("local X = C_Foo.Bar" at file level), from the ones it
--  needs that 3.3.5 lacks: a table keeps the load from failing while a function is missing (filled one by one in
--  Compat335_API.lua). The namespaces ElvUI only reaches behind a test ("C_Foo and C_Foo.Bar()": Housing, Seasons,
--  MythicPlus, ChatBubbles, TooltipInfo...) stay absent, so it takes its 3.3.5-shaped path.

for _, name in ipairs({"C_ActionBar", "C_AddOns", "C_BattleNet", "C_ChatInfo", "C_ClassColor", "C_ColorUtil", "C_Container",
	"C_CreatureInfo", "C_CurrencyInfo", "C_CurveUtil", "C_CVar", "C_DateAndTime", "C_DurationUtil", "C_EncodingUtil",
	"C_EquipmentSet", "C_FriendList", "C_GuildInfo", "C_Heirloom", "C_Item", "C_LFGList", "C_LootHistory", "C_Map",
	"C_MerchantFrame", "C_MountJournal", "C_NewItems", "C_PaperDollInfo", "C_PartyInfo", "C_PlayerInfo", "C_PvP",
	"C_QuestLog", "C_Reputation", "C_SpecializationInfo", "C_Spell", "C_SpellBook", "C_StorePublic", "C_StringUtil",
	"C_Texture", "C_Timer", "C_TradeSkillUI", "C_TransmogCollection", "C_UnitAuras", "C_VoiceChat", "C_WowTokenPublic",
	"C_Club", "C_ClubFinder", "C_UIFileAsset", "C_GameRules"}) do
	fill(name, {})
end

---------------------------------------------------------------------------------------------------------------
--> widget methods the 3.3.5 widgets lack (shared method tables, only where absent)

do
	local holder = CreateFrame("Frame")
	holder:Hide()
	local samples = {holder, holder:CreateTexture(), holder:CreateFontString(), holder:CreateAnimationGroup(), GameFontNormal}
	for _, frameType in ipairs({"Button", "CheckButton", "EditBox", "ScrollFrame", "Slider", "StatusBar", "Cooldown",
		"GameTooltip", "MessageFrame", "ScrollingMessageFrame", "SimpleHTML", "ColorSelect", "Model", "PlayerModel",
		"DressUpModel", "Minimap", "TabardModel", "MovieFrame", "QuestPOIFrame"}) do
		local ok, frame = pcall(CreateFrame, frameType, nil, holder)
		if (ok and frame and frameType == "EditBox") then -- 3.3.5: autoFocus is on by default
			frame:SetAutoFocus(false)
			frame:ClearFocus()
			frame:Hide()
		end
		if (ok and frame) then samples[#samples + 1] = frame end
	end
	local group = samples[4]
	for _, animType in ipairs({"Alpha", "Scale", "Translation", "Rotation", "Path", "Animation"}) do
		local ok, anim = pcall(group.CreateAnimation, group, animType)
		if (ok and anim) then samples[#samples + 1] = anim end
	end

	local added = {}
	Compat.addedWidgetMethods = added
	--name -> function, on every sample whose type passes `want` (object -> bool)
	local function add(name, func, want)
		for _, object in ipairs(samples) do
			local meta = getmetatable(object)
			local index = meta and meta.__index
			if (type(index) == "table" and index[name] == nil and (not want or want(object))) then
				index[name] = func
				added[name] = true
			end
		end
	end
	Compat.addWidgetMethod = add
	local function isFrame(o) return o.GetFrameStrata ~= nil end
	local function isRegionOrFrame(o) return o.SetPoint ~= nil end
	local function objectType(t) return function(o) return o.GetObjectType and o:GetObjectType() == t end end

	add("IsForbidden", returnFalse)
	add("SetIgnoreParentAlpha", noop, isRegionOrFrame)
	add("SetIgnoreParentScale", noop, isRegionOrFrame)
	add("IsIgnoringParentAlpha", returnFalse, isRegionOrFrame)
	add("IsIgnoringParentScale", returnFalse, isRegionOrFrame)
	add("SetClipsChildren", noop, isFrame)
	add("DoesClipChildren", returnFalse, isFrame)
	add("SetFixedFrameStrata", noop, isFrame)
	add("SetFixedFrameLevel", noop, isFrame)
	add("SetFlattensRenderLayers", noop, isFrame)
	add("SetSnapToPixelGrid", noop, isRegionOrFrame)
	add("SetTexelSnappingBias", noop, isRegionOrFrame)
	add("GetDebugName", function(self) return self:GetName() or tostring(self) end, isRegionOrFrame)
	add("SetResizeBounds", function(self, minW, minH, maxW, maxH)
		if (minW and self.SetMinResize) then self:SetMinResize(minW, minH or minW) end
		if (maxW and self.SetMaxResize) then self:SetMaxResize(maxW, maxH or maxW) end
	end, isFrame)
	add("GetResizeBounds", function(self)
		local minW, minH = 0, 0
		if (self.GetMinResize) then minW, minH = self:GetMinResize() end
		local maxW, maxH = 0, 0
		if (self.GetMaxResize) then maxW, maxH = self:GetMaxResize() end
		return minW, minH, maxW, maxH
	end, isFrame)
	add("SetObeyStepOnDrag", noop, objectType("Slider"))
	add("IsAnchoringRestricted", returnFalse, isRegionOrFrame)
	--mouse propagation (10.x): no equivalent on 3.3.5, the frame keeps its own mouse handling
	add("SetPassThroughButtons", noop, isFrame)
	add("SetPropagateMouseMotion", noop, isFrame)
	add("SetPropagateMouseClicks", noop, isFrame)
	add("SetMouseClickEnabled", function(self, enabled) if (not enabled) then self:EnableMouse(false) end end, isFrame)
	add("SetMouseMotionEnabled", noop, isFrame)

	--status bars fill left to right on 3.3.5; the flag is kept for the getter (ElvUI places its own textures)
	add("SetReverseFill", function(self, reverse) self.__elvReverseFill = reverse and true or false end, objectType("StatusBar"))
	add("GetReverseFill", function(self) return self.__elvReverseFill == true end, objectType("StatusBar"))
	--the 3.3.5 cooldown always draws its swipe, has no bling, edge or countdown numbers
	for _, name in ipairs({"SetDrawSwipe", "SetDrawBling", "SetDrawEdge", "SetHideCountdownNumbers", "SetSwipeColor",
		"SetSwipeTexture", "SetEdgeTexture", "SetBlingTexture", "SetUseCircularEdge", "SetCountdownFont",
		"SetCountdownAbbrevThreshold", "SetEdgeScale", "SetRotation", "SetCountdownFormatter", "SetMinimumCountdownDuration",
		"SetEdgeColor", "SetBlingColor"}) do
		add(name, noop, objectType("Cooldown"))
	end
	add("GetDrawSwipe", function() return true end, objectType("Cooldown"))
	add("Clear", function(self) self:SetCooldown(0, 0) end, objectType("Cooldown"))
	--models: the 3.3.5 model has no separate model alpha, the frame's alpha is the model's
	add("SetModelAlpha", function(self, alpha) self:SetAlpha(alpha) end, function(o) return o.SetModel ~= nil end)
	add("GetModelAlpha", function(self) return self:GetAlpha() end, function(o) return o.SetModel ~= nil end)
	--no camera distance on the 3.3.5 model: it keeps its default framing
	add("SetCamDistanceScale", noop, function(o) return o.SetModel ~= nil end)
	--the 3.3.5 model plays an animation with SetSequence (the same ids: 67 wave, 69 dance...)
	--11.x FontString:ClearText (AceGUI's Heading on release)
	add("ClearText", function(self) self:SetText("") end, objectType("FontString"))
	add("SetAnimation", function(self, id) self:SetSequence(id or 0) end, function(o) return o.SetSequence ~= nil end)
	--7.0 absolute animation values on the 3.3.5 relative ones: an alpha change, a scale factor (from the region's
	--alpha and scale when the animation starts, which is what the start value is in ElvUI's animations)
	local isAlpha, isScale = objectType("Alpha"), objectType("Scale")
	add("SetFromAlpha", function(self, from)
		self.__elvFromAlpha = from
		self:SetChange((self.__elvToAlpha or from) - from)
	end, isAlpha)
	add("SetToAlpha", function(self, to)
		self.__elvToAlpha = to
		self:SetChange(to - (self.__elvFromAlpha or 1))
	end, isAlpha)
	add("GetFromAlpha", function(self) return self.__elvFromAlpha or 1 end, isAlpha)
	add("GetToAlpha", function(self) return self.__elvToAlpha or (1 + self:GetChange()) end, isAlpha)
	local function applyScale(self)
		local fromX, fromY = self.__elvFromScaleX or 1, self.__elvFromScaleY or 1
		local toX, toY = self.__elvToScaleX or fromX, self.__elvToScaleY or fromY
		self:SetScale(fromX ~= 0 and toX / fromX or toX, fromY ~= 0 and toY / fromY or toY)
	end
	add("SetScaleFrom", function(self, x, y) self.__elvFromScaleX, self.__elvFromScaleY = x, y or x applyScale(self) end, isScale)
	add("SetScaleTo", function(self, x, y) self.__elvToScaleX, self.__elvToScaleY = x, y or x applyScale(self) end, isScale)
	add("SetFromScale", function(self, x, y) self.__elvFromScaleX, self.__elvFromScaleY = x, y or x applyScale(self) end, isScale)
	add("SetToScale", function(self, x, y) self.__elvToScaleX, self.__elvToScaleY = x, y or x applyScale(self) end, isScale)
	add("SetToFinalAlpha", noop, function(o) return o.GetAnimations ~= nil end)
	--no mask textures on 3.3.5: a mask is a hidden texture, attaching it does nothing
	add("CreateMaskTexture", function(self, ...)
		local mask = self:CreateTexture(...)
		mask:Hide()
		return mask
	end, isFrame)
	--4.x SetDesaturation(amount) on the 3.3.5 SetDesaturated(on)
	add("SetDesaturation", function(self, amount) self:SetDesaturated(amount and amount > 0) end, function(o) return o.SetDesaturated ~= nil end)
	add("AddMaskTexture", noop, function(o) return o.SetTexCoord ~= nil end)
	add("RemoveMaskTexture", noop, function(o) return o.SetTexCoord ~= nil end)
	add("GetNumMaskTextures", function() return 0 end, function(o) return o.SetTexCoord ~= nil end)
end

---------------------------------------------------------------------------------------------------------------
--> events: the names and the unit filter of later clients on a 3.3.5 frame, without replacing a client method
--  (the client's own code would then run ours and carry the taint into protected frames).
--  ElvUI335.RegisterEvent / UnregisterEvent / RegisterUnitEvent / IsEventRegistered (obj, event, ...): for a frame,
--  a later event name is registered as its 3.3.5 events and handed back under the later name (UNIT_MANA "player"
--  -> UNIT_POWER_UPDATE "player", "MANA"); RegisterUnitEvent filters the units. For anything else (an AceEvent
--  object) the object's own method is called. Used by AceEvent, oUF and the frames ElvUI registers directly
--  (outils/elvui335_events.js rewrites those calls). The frame's OnEvent is wrapped and follows SetScript.

do
	local POWER_EVENTS = {"UNIT_MANA", "UNIT_RAGE", "UNIT_ENERGY", "UNIT_FOCUS", "UNIT_RUNIC_POWER", "UNIT_HAPPINESS"}
	local MAXPOWER_EVENTS = {"UNIT_MAXMANA", "UNIT_MAXRAGE", "UNIT_MAXENERGY", "UNIT_MAXFOCUS", "UNIT_MAXRUNIC_POWER", "UNIT_MAXHAPPINESS"}
	local POWER_TOKEN = {UNIT_MANA = "MANA", UNIT_RAGE = "RAGE", UNIT_ENERGY = "ENERGY", UNIT_FOCUS = "FOCUS",
		UNIT_RUNIC_POWER = "RUNIC_POWER", UNIT_HAPPINESS = "HAPPINESS", UNIT_MAXMANA = "MANA", UNIT_MAXRAGE = "RAGE",
		UNIT_MAXENERGY = "ENERGY", UNIT_MAXFOCUS = "FOCUS", UNIT_MAXRUNIC_POWER = "RUNIC_POWER", UNIT_MAXHAPPINESS = "HAPPINESS"}
	--later name -> its 3.3.5 events
	local ALIASES = {
		UNIT_POWER_UPDATE = POWER_EVENTS,
		UNIT_POWER_FREQUENT = POWER_EVENTS,
		UNIT_MAXPOWER = MAXPOWER_EVENTS,
		UNIT_HEALTH_FREQUENT = {"UNIT_HEALTH"},
		GROUP_ROSTER_UPDATE = {"PARTY_MEMBERS_CHANGED", "RAID_ROSTER_UPDATE"},
		GROUP_JOINED = {"PARTY_MEMBERS_CHANGED"},
		GROUP_LEFT = {"PARTY_MEMBERS_CHANGED"},
		PLAYER_SPECIALIZATION_CHANGED = {"ACTIVE_TALENT_GROUP_CHANGED"},
		PLAYER_LEVEL_CHANGED = {"PLAYER_LEVEL_UP"},
		UPDATE_POSSESS_BAR = {"UPDATE_BONUS_ACTIONBAR"},
		UPDATE_VEHICLE_ACTIONBAR = {"UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE"},
		UPDATE_OVERRIDE_ACTIONBAR = {"UPDATE_BONUS_ACTIONBAR"},
		UNIT_CONNECTION = {"PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE"},
	}
	Compat.EVENT_ALIASES = ALIASES
	--the arguments under the later name
	local function Translate(modern, legacy, ...)
		if (modern == "UNIT_POWER_UPDATE" or modern == "UNIT_POWER_FREQUENT" or modern == "UNIT_MAXPOWER") then
			local unit = ...
			return unit, POWER_TOKEN[legacy]
		elseif (modern == "PLAYER_SPECIALIZATION_CHANGED" or modern == "UPDATE_VEHICLE_ACTIONBAR") then
			return "player"
		elseif (modern == "PLAYER_LEVEL_CHANGED") then
			local level = ...
			return (level or 1) - 1, level
		elseif (modern == "UNIT_CONNECTION") then
			local unit = ...
			return unit, legacy == "PARTY_MEMBER_ENABLE"
		end
		return ...
	end

	local direct = setmetatable({}, {__mode = "k"})  --frame -> {event -> true} registered under its own name
	local aliased = setmetatable({}, {__mode = "k"}) --frame -> {legacy -> {modern -> true}}
	local filters = setmetatable({}, {__mode = "k"}) --frame -> {event -> {unit -> true}}
	local handlers = setmetatable({}, {__mode = "k"}) --frame -> its own OnEvent

	--hidden: its sample children must never show (a 3.3.5 edit box shown with autoFocus takes the keyboard)
	local holder = CreateFrame("Frame")
	holder:Hide()
	local index = getmetatable(holder).__index
	local nativeRegister, nativeUnregister, nativeIsRegistered = index.RegisterEvent, index.UnregisterEvent, index.IsEventRegistered

	local function Passes(frame, event, unit)
		local units = filters[frame] and filters[frame][event]
		return not units or unit == nil or units[unit] ~= nil
	end
	local function Wrapper(self, event, ...)
		local handler = handlers[self]
		if (not handler) then return end
		local d = direct[self]
		local a = aliased[self] and aliased[self][event]
		if (d and d[event]) then
			if (Passes(self, event, (...))) then handler(self, event, ...) end
		elseif (not a) then
			--registered with the frame's own RegisterEvent (the client method, not ours): it reaches the frame as is
			handler(self, event, ...)
		end
		if (a) then
			for modern in pairs(a) do
				if (Passes(self, modern, (...))) then
					handler(self, modern, Translate(modern, event, ...))
				end
			end
		end
	end
	local function Wrap(frame)
		if (frame.__elv335Wrapped) then return end
		frame.__elv335Wrapped = true
		handlers[frame] = frame:GetScript("OnEvent")
		frame:SetScript("OnEvent", Wrapper)
		hooksecurefunc(frame, "SetScript", function(self, script, func)
			if (script == "OnEvent" and func ~= Wrapper) then
				handlers[self] = func
				self:SetScript("OnEvent", Wrapper)
			end
		end)
	end
	local function IsFrame(obj)
		return type(obj) == "table" and type(rawget(obj, 0)) == "userdata"
	end

	local function RegisterEvent(frame, event, ...)
		direct[frame] = direct[frame] or {}
		local legacy = ALIASES[event]
		if (legacy) then
			aliased[frame] = aliased[frame] or {}
			for _, l in ipairs(legacy) do
				aliased[frame][l] = aliased[frame][l] or {}
				aliased[frame][l][event] = true
				nativeRegister(frame, l)
			end
		else
			direct[frame][event] = true
			--a name 3.3.5 does not know: nothing to register (the client would ignore it or raise)
			pcall(nativeRegister, frame, event)
		end
		Wrap(frame)
		return true
	end
	local function StillNeeded(frame, l)
		if (direct[frame] and direct[frame][l]) then return true end
		local a = aliased[frame] and aliased[frame][l]
		return a ~= nil and next(a) ~= nil
	end
	local function UnregisterEvent(frame, event, ...)
		if (filters[frame]) then filters[frame][event] = nil end
		local legacy = ALIASES[event]
		if (legacy) then
			for _, l in ipairs(legacy) do
				local a = aliased[frame] and aliased[frame][l]
				if (a) then a[event] = nil end
				if (not StillNeeded(frame, l)) then nativeUnregister(frame, l) end
			end
		else
			if (direct[frame]) then direct[frame][event] = nil end
			if (not StillNeeded(frame, event)) then pcall(nativeUnregister, frame, event) end
		end
	end
	local function RegisterUnitEvent(frame, event, unit1, unit2, ...)
		RegisterEvent(frame, event)
		filters[frame] = filters[frame] or {}
		if (unit1 == nil and unit2 == nil) then
			filters[frame][event] = nil
		else
			local units = {}
			if (unit1) then units[unit1] = true end
			if (unit2) then units[unit2] = true end
			filters[frame][event] = units
		end
		return true
	end
	local function IsEventRegistered(frame, event)
		if (ALIASES[event]) then
			for _, a in pairs(aliased[frame] or {}) do
				if (a[event]) then return true end
			end
			return false
		end
		if (direct[frame] and direct[frame][event]) then return true end
		return nativeIsRegistered(frame, event) and true or false
	end
	--raw, on a frame (oUF and AceEvent call these from their own methods)
	Compat.FrameRegisterEvent, Compat.FrameUnregisterEvent = RegisterEvent, UnregisterEvent
	Compat.FrameRegisterUnitEvent, Compat.FrameIsEventRegistered = RegisterUnitEvent, IsEventRegistered
	--for any object (the rewritten call sites): a frame with the client's methods is translated, anything with
	--methods of its own (an oUF frame, an AceEvent object) gets its own method called
	local function Own(obj, method, native)
		return not IsFrame(obj) or obj[method] ~= native
	end
	Compat.RegisterEvent = function(obj, event, ...)
		if (Own(obj, "RegisterEvent", nativeRegister)) then return obj:RegisterEvent(event, ...) end
		return RegisterEvent(obj, event)
	end
	Compat.UnregisterEvent = function(obj, event, ...)
		if (Own(obj, "UnregisterEvent", nativeUnregister)) then return obj:UnregisterEvent(event, ...) end
		return UnregisterEvent(obj, event)
	end
	Compat.RegisterUnitEvent = function(obj, event, ...)
		if (Own(obj, "RegisterUnitEvent", RegisterUnitEvent)) then return obj:RegisterUnitEvent(event, ...) end
		return RegisterUnitEvent(obj, event, ...)
	end
	Compat.IsEventRegistered = function(obj, event, ...)
		if (Own(obj, "IsEventRegistered", nativeIsRegistered)) then return obj:IsEventRegistered(event, ...) end
		return IsEventRegistered(obj, event)
	end

	--RegisterUnitEvent as a method, for the frames that call it themselves: a method the 3.3.5 frames lack, so the
	--client never calls it (no taint path)
	for _, frameType in ipairs({"Frame", "Button", "CheckButton", "StatusBar", "Cooldown", "Slider", "ScrollFrame", "EditBox",
		"GameTooltip", "PlayerModel", "Model", "MessageFrame", "ScrollingMessageFrame"}) do
		local ok, frame = pcall(CreateFrame, frameType, nil, holder)
		if (ok and frame and frameType == "EditBox") then -- 3.3.5: autoFocus is on by default
			frame:SetAutoFocus(false)
			frame:ClearFocus()
			frame:Hide()
		end
		local meta = ok and frame and getmetatable(frame)
		if (meta and type(meta.__index) == "table" and meta.__index.RegisterUnitEvent == nil) then
			meta.__index.RegisterUnitEvent = RegisterUnitEvent
		end
	end
end
