--[[
	ElvUI Wotlk: tables and constants of later clients ElvUI reads at load (see Compat335.lua for the environment).
	Enum and Constants answer an unknown sub table with an empty one, so "local X = Enum.Foo.Bar" never stops a file;
	the values ElvUI's Wrath path really uses are given here.
]]

local env = ElvUI335_ENV
local Compat = env.ElvUI335
local fill, define, noop, returnFalse = Compat.fill, Compat.define, Compat.noop, Compat.returnFalse
local realG = getmetatable(env).__index
local rawget, rawset, setmetatable, type, pairs = rawget, rawset, setmetatable, type, pairs

---------------------------------------------------------------------------------------------------------------
--> Enum: the client's (Rebuffed has some), the compat ones, then an empty table for the rest

local Enum = env.Enum
local unknownEnums = {}
Compat.unknownEnums = unknownEnums
setmetatable(Enum, {__index = function(t, name)
	local native = realG.Enum and realG.Enum[name]
	if (native ~= nil) then return native end
	unknownEnums[name] = true
	local empty = {}
	rawset(t, name, empty)
	return empty
end})
local function enum(name, values)
	local existing = rawget(Enum, name) or (realG.Enum and realG.Enum[name])
	if (existing == nil) then
		rawset(Enum, name, values)
	elseif (type(existing) == "table" and rawget(Enum, name) == nil) then
		--the client's table, completed on a copy of our own
		local copy = setmetatable({}, {__index = existing})
		for k, v in pairs(values) do if (existing[k] == nil) then copy[k] = v end end
		rawset(Enum, name, copy)
	end
end
Compat.enum = enum

enum("UIMapType", {Cosmic = 0, World = 1, Continent = 2, Zone = 3, Dungeon = 4, Micro = 5, Orphan = 6})
enum("CompressionMethod", {Deflate = 0, Zlib = 1})
enum("CompressionLevel", {Default = 0, OptimizeForSpeed = 1, OptimizeForSize = 2})
--3.3.5 power types (no holy power, soul shards, eclipse, chi... before 4.0)
enum("PowerType", {HealthCost = -2, None = -1, Mana = 0, Rage = 1, Focus = 2, Energy = 3, Happiness = 4, Runes = 5,
	RunicPower = 6, ComboPoints = 14})
enum("DispelType", {None = 0, Magic = 1, Curse = 2, Disease = 3, Poison = 4, Enrage = 9, Bleed = 11})
enum("BagIndex", {Keyring = -2, Bank = -1, Backpack = 0, Bag_1 = 1, Bag_2 = 2, Bag_3 = 3, Bag_4 = 4,
	BankBag_1 = 5, BankBag_2 = 6, BankBag_3 = 7, BankBag_4 = 8, BankBag_5 = 9, BankBag_6 = 10, BankBag_7 = 11})
enum("NamePlateType", {Friendly = 0, Enemy = 1, Self = 2})
enum("SelectionType", {Selection = 0, MouseOver = 1, Self = 2, Focus = 3})
enum("PhaseReason", {Phasing = 0, Sharding = 1, WarMode = 2, ChromieTime = 3, TimerunningHwt = 4})
enum("TooltipDataLineType", {None = 0, Blank = 1, UnitName = 2, GemSocket = 3, AzeriteEssenceSlot = 4,
	AzeriteEssencePower = 5, LearnableSpell = 6, UnitThreat = 7, QuestObjective = 8, AzeriteItemPowerDescription = 9,
	RuneforgeLegendaryPowerDescription = 10, SellPrice = 11, ProfessionCraftingQuality = 12, SpellName = 13})
enum("TooltipDataType", {Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4, Currency = 5, BattlePet = 6,
	UnitAura = 7, AzeriteEssence = 8, CompanionPet = 9, Mount = 10, PetAction = 11, Achievement = 12})
enum("ChatChannelRuleset", {None = 0, Mentor = 1, Disabled = 2, ChromieTimeCataclysm = 3, ChromieTimeBuringCrusade = 4})
enum("PlayerClubRequestStatus", {None = 0, Pending = 1, AutoApproved = 2, Declined = 3, Approved = 4, Joined = 5})
enum("ClubType", {BattleNet = 0, Character = 1, Guild = 2, Other = 3})
enum("BindingSet", {Default = 0, Account = 1, Character = 2, Current = 3})
enum("ItemBind", {None = 0, OnAcquire = 1, OnEquip = 2, OnUse = 3, Quest = 4})
enum("UnitDamageAbsorbClampMode", {MissingHealth = 0, MaximumHealth = 1})
enum("UnitHealAbsorbClampMode", {CurrentHealth = 0, MaximumHealth = 1})
enum("UnitHealAbsorbMode", {Total = 0, ReducedByIncomingHeals = 1})
enum("UnitIncomingHealClampMode", {MissingHealth = 0, MaximumHealth = 1})
enum("FontStringScaleAnimationMode", {None = 0, Center = 1})
enum("NumericRuleFormatRounding", {Truncate = 0, Round = 1})
enum("SendAddonMessageResult", {Success = 0, InvalidPrefix = 1, InvalidMessage = 2, AddonMessageThrottle = 3,
	InvalidChatType = 4, NotInGroup = 5, TargetRequired = 6, InvalidChannel = 7, ChannelThrottle = 8, GeneralError = 9})

--TooltipDataLineType is also a global on later clients
if (realG.TooltipDataLineType == nil) then rawset(env, "TooltipDataLineType", Enum.TooltipDataLineType) end

---------------------------------------------------------------------------------------------------------------
--> Constants: the client's sub tables, or an empty one

do
	local native = realG.Constants
	local Constants = setmetatable({}, {__index = function(t, name)
		local value = native and native[name]
		if (value ~= nil) then return value end
		local empty = {}
		rawset(t, name, empty)
		return empty
	end})
	rawset(env, "Constants", Constants)
	--3.3.5 honor is not a currency (GetHonorCurrency / the honor points): no id
end

---------------------------------------------------------------------------------------------------------------
--> ChatFrameUtil (10.x): the 3.3.5 ChatEdit_* / ChatFrame_* functions under their new names. InsertLink is left out
--  on purpose: AceGUI and ElvUI then hook the 3.3.5 ChatEdit_InsertLink, the one the client calls.

do
	local LEGACY = {
		FocusActiveWindow = "ChatEdit_FocusActiveWindow", GetActiveWindow = "ChatEdit_GetActiveWindow",
		SetLastActiveWindow = "ChatEdit_SetLastActiveWindow", GetLastActiveWindow = "ChatEdit_GetLastActiveWindow",
		SetLastTellTarget = "ChatEdit_SetLastTellTarget", GetLastTellTarget = "ChatEdit_GetLastTellTarget",
		ChooseBoxForSend = "ChatEdit_ChooseBoxForSend", ActivateChat = "ChatEdit_ActivateChat",
		DeactivateChat = "ChatEdit_DeactivateChat", SendTell = "ChatFrame_SendTell",
		AddMessageEventFilter = "ChatFrame_AddMessageEventFilter", RemoveMessageEventFilter = "ChatFrame_RemoveMessageEventFilter",
		GetMessageEventFilters = "ChatFrame_GetMessageEventFilters", GetChatCategory = "Chat_GetChatCategory",
		OpenChat = "ChatFrame_OpenChat", ReplyTell = "ChatFrame_ReplyTell",
	}
	local ChatFrameUtil = setmetatable({}, {__index = function(_, name)
		local legacy = LEGACY[name]
		return legacy and realG[legacy] or nil
	end})
	--later additions with a 3.3.5 meaning
	rawset(ChatFrameUtil, "ShouldColorChatByClass", function(info)
		return info and info.colorNameByClass and true or false
	end)
	rawset(ChatFrameUtil, "ResolvePrefixedChannelName", function(name) return name end)
	rawset(ChatFrameUtil, "SendBNetTell", function(name)
		if (realG.ChatFrame_SendTell) then realG.ChatFrame_SendTell(name) end
	end)
	rawset(ChatFrameUtil, "CanChatGroupPerformExpressionExpansion", returnFalse)
	rawset(env, "ChatFrameUtil", ChatFrameUtil)
end

rawset(env, "CommunitiesUtil", setmetatable({}, {__index = function() return nil end}))

---------------------------------------------------------------------------------------------------------------
--> constants and strings of later clients

if (realG.BASE_MOVEMENT_SPEED == nil) then rawset(env, "BASE_MOVEMENT_SPEED", 7) end
if (realG.MAX_NUM_TALENTS == nil) then rawset(env, "MAX_NUM_TALENTS", 40) end
if (realG.NUM_BAG_FRAMES == nil) then rawset(env, "NUM_BAG_FRAMES", 4) end

---------------------------------------------------------------------------------------------------------------
--> fonts: 3.3.5 has one font per object (no per-alphabet families)

Compat.addWidgetMethod("GetFontObjectForAlphabet", function(self) return self end, function(o) return o.GetFont ~= nil and o.SetPoint == nil end)

---------------------------------------------------------------------------------------------------------------
--> more tables, constants and strings of later clients

--bag filter flags (6.0 LE_BAG_FILTER_FLAG_*): only told apart, 3.3.5 bags have no filter
for name, value in pairs({LE_BAG_FILTER_FLAG_IGNORE_CLEANUP = 1, LE_BAG_FILTER_FLAG_EQUIPMENT = 2, LE_BAG_FILTER_FLAG_CONSUMABLES = 3,
	LE_BAG_FILTER_FLAG_TRADE_GOODS = 4, LE_BAG_FILTER_FLAG_JUNK = 5, NUM_LE_BAG_FILTER_FLAGS = 5}) do
	if (realG[name] == nil) then rawset(env, name, value) end
end
enum("UIWidgetVisualizationType", {IconAndText = 0, CaptureBar = 1, StatusBar = 2, DoubleStatusBar = 3,
	IconTextAndBackground = 4, DoubleIconAndText = 5, StackedResourceTracker = 6, IconTextAndCurrencies = 7,
	TextWithState = 8, HorizontalCurrencies = 9, BulletTextList = 10, ScenarioHeaderCurrenciesAndBackground = 11,
	TextureAndText = 12, SpellDisplay = 13, DoubleStateIconRow = 14, TextureAndTextRow = 15, ZoneControl = 16,
	CaptureZone = 17, TextureWithAnimation = 18, DiscreteProgressSteps = 19, ScenarioHeaderTimer = 20,
	TextColumnRow = 21, Spacer = 22, UnitPowerBar = 23, FillUpFrames = 24, TextWithSubtext = 25, MapPinAnimation = 26,
	ItemDisplay = 27, TugOfWar = 28, ScenarioHeaderDelves = 29, ButtonHeader = 30})

for name, text in pairs({PLAYER_DIFFICULTY1 = "Normal", PLAYER_DIFFICULTY2 = "Heroic", PLAYER_DIFFICULTY3 = "Raid Finder",
	PLAYER_DIFFICULTY6 = "Mythic"}) do
	if (realG[name] == nil) then rawset(env, name, text) end
end
if (realG.ITEM_LEVEL_ALT == nil) then rawset(env, "ITEM_LEVEL_ALT", "Item Level %d (%d)") end
if (realG.MAX_QUESTS == nil) then rawset(env, "MAX_QUESTS", 25) end

--sound output devices: the 3.3.5 Sound_GameSystem_* functions
define("GetNumOutputDrivers", function() return realG.Sound_GameSystem_GetNumOutputDrivers and realG.Sound_GameSystem_GetNumOutputDrivers() or 0 end)
define("GetOutputDriverNameByIndex", function(i) return realG.Sound_GameSystem_GetOutputDriverNameByIndex and realG.Sound_GameSystem_GetOutputDriverNameByIndex(i) end)
--difficulty ids (4.0 names of the 3.3.5 GetDungeonDifficulty / GetRaidDifficulty)
define("GetDungeonDifficultyID", function() return realG.GetDungeonDifficulty and realG.GetDungeonDifficulty() end)
define("GetRaidDifficultyID", function() return realG.GetRaidDifficulty and realG.GetRaidDifficulty() end)

--tables of later clients ElvUI only reads a function or two from (absent on 3.3.5)
rawset(env, "MapUtil", {GetMapParentInfo = function() return nil end})
fill("C_GossipInfo", {})
fill("C_PlayerInteractionManager", {IsReplacingUnit = returnFalse})
