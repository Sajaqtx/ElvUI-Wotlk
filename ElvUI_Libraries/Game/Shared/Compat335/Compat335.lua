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
}
--template list without the modern names; the backdrop one of them asks for
local function stripModernTemplates(template)
	if (type(template) ~= "string") then return template end
	local kept, backdrop = {}, nil
	for name in template:gmatch("[^,%s]+") do
		local modern = MODERN_TEMPLATES[name]
		if (modern == nil) then
			kept[#kept + 1] = name
		elseif (modern) then
			backdrop = modern
		end
	end
	return #kept > 0 and table.concat(kept, ",") or nil, backdrop
end
Compat.stripModernTemplates = stripModernTemplates
rawset(env, "CreateFrame", function(frameType, name, parent, template, id)
	local kept, backdrop = stripModernTemplates(template)
	local frame = CreateFrame(frameType, name, parent, kept, id)
	if (backdrop and frame.SetBackdrop) then frame:SetBackdrop(backdrop) end
	return frame
end)
--what the Backdrop mixin adds to a frame on modern clients: the 3.3.5 frame already backs SetBackdrop natively
rawset(env, "BackdropTemplateMixin", {
	OnBackdropLoaded = noop, OnBackdropSizeChanged = noop, SetupTextureCoordinates = noop,
	ApplyBackdrop = noop, ClearBackdrop = function(self) self:SetBackdrop(nil) end,
})

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
	IsAddOnLoaded = realG.IsAddOnLoaded,
	LoadAddOn = realG.LoadAddOn,
	GetNumAddOns = realG.GetNumAddOns,
	EnableAddOn = realG.EnableAddOn,
	DisableAddOn = realG.DisableAddOn,
	IsAddOnLoadOnDemand = realG.IsAddOnLoadOnDemand,
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

local function cvarExists(name)
	return (realG.GetCVar(name)) ~= nil
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
	--status bars fill left to right on 3.3.5; the flag is kept for the getter (ElvUI places its own textures)
	add("SetReverseFill", function(self, reverse) self.__elvReverseFill = reverse and true or false end, objectType("StatusBar"))
	add("GetReverseFill", function(self) return self.__elvReverseFill == true end, objectType("StatusBar"))
	--the 3.3.5 cooldown always draws its swipe, has no bling, edge or countdown numbers
	for _, name in ipairs({"SetDrawSwipe", "SetDrawBling", "SetDrawEdge", "SetHideCountdownNumbers", "SetSwipeColor",
		"SetSwipeTexture", "SetEdgeTexture", "SetBlingTexture", "SetUseCircularEdge", "SetCountdownFont",
		"SetCountdownAbbrevThreshold", "SetEdgeScale", "SetRotation", "SetCountdownFormatter"}) do
		add(name, noop, objectType("Cooldown"))
	end
	add("GetDrawSwipe", function() return true end, objectType("Cooldown"))
	--no mask textures on 3.3.5: a mask is a hidden texture, attaching it does nothing
	add("CreateMaskTexture", function(self, ...)
		local mask = self:CreateTexture(...)
		mask:Hide()
		return mask
	end, isFrame)
	add("AddMaskTexture", noop, function(o) return o.SetTexCoord ~= nil end)
	add("RemoveMaskTexture", noop, function(o) return o.SetTexCoord ~= nil end)
	add("GetNumMaskTextures", function() return 0 end, function(o) return o.SetTexCoord ~= nil end)
end

---------------------------------------------------------------------------------------------------------------
--> RegisterUnitEvent (5.0): the event registered for every unit, the units filtered before the frame's handler.
--  The filter wraps the frame's OnEvent and follows it when the frame sets another one.

do
	local filters = setmetatable({}, {__mode = "k"}) --frame -> {event -> {unit = true}}
	local wrapped = setmetatable({}, {__mode = "k"}) --frame -> original handler
	local function wrap(frame)
		local original = frame:GetScript("OnEvent")
		if (wrapped[frame] ~= nil and frame.__elvUnitEventWrapper == original) then return end
		wrapped[frame] = original or false
		local wrapper = function(self, event, unit, ...)
			local units = filters[self] and filters[self][event]
			if (units and unit ~= nil and not units[unit]) then return end
			local handler = wrapped[self]
			if (handler) then return handler(self, event, unit, ...) end
		end
		frame.__elvUnitEventWrapper = wrapper
		frame:SetScript("OnEvent", wrapper)
		if (not frame.__elvUnitEventHooked) then
			frame.__elvUnitEventHooked = true
			hooksecurefunc(frame, "SetScript", function(self, script, func)
				if (script == "OnEvent" and func ~= self.__elvUnitEventWrapper) then
					wrapped[self] = func or false
					self:SetScript("OnEvent", self.__elvUnitEventWrapper)
				end
			end)
		end
	end
	local holder = CreateFrame("Frame")
	local index = getmetatable(holder).__index
	local function registerUnitEvent(self, event, unit1, unit2)
		self:RegisterEvent(event)
		if (unit1 == nil and unit2 == nil) then
			if (filters[self]) then filters[self][event] = nil end
			return true
		end
		filters[self] = filters[self] or {}
		local units = {}
		if (unit1) then units[unit1] = true end
		if (unit2) then units[unit2] = true end
		filters[self][event] = units
		wrap(self)
		return true
	end
	Compat.RegisterUnitEvent = registerUnitEvent
	for _, frameType in ipairs({"Frame", "Button", "CheckButton", "StatusBar", "Cooldown", "Slider", "ScrollFrame", "EditBox",
		"GameTooltip", "PlayerModel", "Model"}) do
		local ok, frame = pcall(CreateFrame, frameType, nil, holder)
		local meta = ok and frame and getmetatable(frame)
		if (meta and type(meta.__index) == "table" and meta.__index.RegisterUnitEvent == nil) then
			meta.__index.RegisterUnitEvent = registerUnitEvent
		end
	end
	--a later RegisterEvent of the same event drops its unit filter, UnregisterEvent too
	hooksecurefunc(index, "UnregisterEvent", function(self, event)
		if (filters[self]) then filters[self][event] = nil end
	end)
end
