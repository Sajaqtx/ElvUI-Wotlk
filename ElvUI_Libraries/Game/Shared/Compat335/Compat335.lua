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
--> CreateFrame: the 3.3.5 frames have SetBackdrop natively, there is no BackdropTemplate to inherit

local CreateFrame = realG.CreateFrame
local function stripBackdropTemplate(template)
	if (type(template) ~= "string" or not template:find("BackdropTemplate", 1, true)) then return template end
	local out = template:gsub("%s*,?%s*BackdropTemplate%s*,?", ","):gsub("^,+", ""):gsub(",+$", ""):gsub(",,+", ",")
	if (out == "") then return nil end
	return out
end
Compat.stripBackdropTemplate = stripBackdropTemplate
rawset(env, "CreateFrame", function(frameType, name, parent, template, id)
	return CreateFrame(frameType, name, parent, stripBackdropTemplate(template), id)
end)
--what the Backdrop mixin adds to a frame on modern clients: the 3.3.5 frame already backs SetBackdrop natively
rawset(env, "BackdropTemplateMixin", {
	OnBackdropLoaded = noop, OnBackdropSizeChanged = noop, SetupTextureCoordinates = noop,
	ApplyBackdrop = noop, ClearBackdrop = function(self) self:SetBackdrop(nil) end,
})

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
--> namespaces the modern client has and ElvUI indexes at load (their functions are added one by one, see the
--  other Compat335 files): an empty table keeps "local X = C_Foo.Bar" from failing while the function is missing

for _, name in ipairs({"C_ActionBar", "C_BattleNet", "C_ChatBubbles", "C_ChatInfo", "C_ClassColor", "C_ColorUtil",
	"C_Container", "C_CreatureInfo", "C_CurrencyInfo", "C_DateAndTime", "C_EncodingUtil", "C_EquipmentSet", "C_FriendList",
	"C_GossipInfo", "C_GuildInfo", "C_Item", "C_LootHistory", "C_Map", "C_MerchantFrame", "C_NamePlate", "C_NamePlateManager",
	"C_PaperDollInfo", "C_PartyInfo", "C_PetJournal", "C_PlayerInfo", "C_PvP", "C_QuestLog", "C_Reputation",
	"C_SpecializationInfo", "C_Spell", "C_SpellBook", "C_StringUtil", "C_Texture", "C_TooltipInfo", "C_TradeSkillUI",
	"C_TransmogCollection", "C_UnitAuras", "C_Housing", "C_HouseEditor", "C_Secrets", "C_CurveUtil", "C_DurationUtil",
	"C_AssistedCombat", "C_ChallengeMode", "C_MythicPlus", "C_MajorFactions", "C_WowTokenPublic", "C_Club", "C_ClubFinder",
	"C_RecentAllies", "C_SocialQueue", "C_PetBattles", "C_Engraving", "C_Seasons", "C_GameRules", "C_ClassTalents",
	"C_StorePublic", "C_LevelLink", "C_SettingsUtil", "C_RestrictedActions", "C_TransmogOutfitInfo", "C_VoiceChat",
	"C_PlayerInteractionManager", "C_UIFileAsset", "C_SpellActivationOverlay", "C_NewItems", "C_LFGList", "C_Bank",
	"C_Timer", "C_AddOns", "C_CVar", "C_MountJournal", "C_ToyBox", "C_Heirloom"}) do
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
		"DressUpModel", "Minimap"}) do
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
