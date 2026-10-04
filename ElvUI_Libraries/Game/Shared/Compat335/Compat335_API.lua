--[[
	ElvUI Wotlk: the modern API ElvUI calls, on the 3.3.5 functions (see Compat335.lua for the environment).
	Written from the EllesmereUI Legion compat (same author), adapted to what 3.3.5 returns: GetSpellInfo has no
	spell id, the spellbook is read by index (GetSpellName), there are no spell or action charges, no instance ids
	for auras (UNIT_AURA has no payload, every aura update is a full scan), no group API of 5.0.
]]

local env = ElvUI335_ENV
local Compat = env.ElvUI335
local fill, define, noop, returnFalse = Compat.fill, Compat.define, Compat.noop, Compat.returnFalse
local realG = getmetatable(env).__index

local type, select, tonumber, tostring, pairs, ipairs, wipe, unpack, floor, max, min =
	type, select, tonumber, tostring, pairs, ipairs, wipe, unpack, math.floor, math.max, math.min
local GetSpellInfo, GetSpellLink, UnitAura, GetTime = GetSpellInfo, GetSpellLink, UnitAura, GetTime
--the environment's Enum and colors (Blizzard's ColorMixin, see below), not the client's
local function CreateColor(...) return env.CreateColor(...) end

---------------------------------------------------------------------------------------------------------------
--> spells: an id or a name in, the 3.3.5 functions take a name (or an index with a book type)

--spell name of an id or a name (3.3.5 GetSpellInfo answers both)
local function SpellName(spell)
	if (spell == nil) then return nil end
	return (GetSpellInfo(spell))
end
--spell id of a name the player knows (from its link), or the id itself
local function SpellID(spell)
	if (type(spell) == "number") then return spell end
	local link = spell and GetSpellLink(spell)
	return link and tonumber(link:match("spell:(%d+)"))
end
Compat.SpellName, Compat.SpellID = SpellName, SpellID

local GCD_SPELL = 61304 --not a 3.3.5 spell: the gcd is read from a spell of the class, see GCDInfo
local function CooldownInfo(startTime, duration, enable, modRate)
	if (not startTime) then return nil end
	local enabled = enable == 1 or enable == true
	local active = enabled and duration > 0 and startTime > 0
	return {startTime = startTime, duration = duration, isEnabled = enabled, modRate = modRate or 1, isActive = active,
		isOnGCD = active and duration <= 1.5 or false, activeCategory = nil}
end
Compat.CooldownInfo = CooldownInfo

fill("C_Spell", {
	GetSpellInfo = function(spell)
		local name, rank, icon, powerCost, isFunnel, powerType, castTime, minRange, maxRange = GetSpellInfo(spell)
		if (not name) then return nil end
		return {name = name, iconID = icon, originalIconID = icon, castTime = castTime or 0, minRange = minRange or 0,
			maxRange = maxRange or 0, spellID = SpellID(spell), rank = rank}
	end,
	GetSpellName = SpellName,
	GetSpellTexture = function(spell)
		local icon = select(3, GetSpellInfo(spell))
		return icon, icon
	end,
	GetSpellLink = function(spell) return GetSpellLink(spell) end,
	GetSpellSubtext = function(spell) return (select(2, GetSpellInfo(spell))) end,
	GetSpellDescription = function() return "" end,
	DoesSpellExist = function(spell) return GetSpellInfo(spell) ~= nil end,
	GetSpellCooldown = function(spell)
		local name = SpellName(spell)
		if (not name) then return nil end
		return CooldownInfo(GetSpellCooldown(name))
	end,
	GetSpellCharges = function() return nil end,
	GetSpellChargeDuration = function() return nil end,
	GetSpellCastCount = function() return 0 end,
	GetSpellDisplayCount = function() return "" end,
	GetSpellPowerCost = function(spell)
		local name, _, _, powerCost, _, powerType = GetSpellInfo(spell)
		if (not name or not powerCost or powerCost <= 0) then return {} end
		return {{type = powerType, cost = powerCost, minCost = powerCost, costPercent = 0, costPerSec = 0, name = ""}}
	end,
	IsSpellUsable = function(spell)
		local name = SpellName(spell)
		if (not name) then return false, false end
		local usable, noMana = IsUsableSpell(name)
		return usable and true or false, noMana and true or false
	end,
	IsSpellInRange = function(spell, unit)
		local name = SpellName(spell)
		if (not name) then return nil end
		local inRange = IsSpellInRange(name, unit or "target")
		if (inRange == nil) then return nil end
		return inRange == 1
	end,
	SpellHasRange = function(spell)
		local name = SpellName(spell)
		return name and SpellHasRange(name) == 1 or false
	end,
	IsCurrentSpell = function(spell) local name = SpellName(spell) return name and IsCurrentSpell(name) and true or false end,
	IsAutoRepeatSpell = function(spell) local name = SpellName(spell) return name and IsAutoRepeatSpell(name) and true or false end,
	IsConsumableSpell = function(spell) local name = SpellName(spell) return name and IsConsumableSpell(name) and true or false end,
	IsAutoAttackSpell = function(spell) return SpellID(spell) == 6603 end,
	IsPressHoldReleaseSpell = returnFalse,
	IsSpellPassive = function(spell)
		local name = SpellName(spell)
		return name and IsPassiveSpell and IsPassiveSpell(name) and true or false
	end,
	PickupSpell = function(spell) local name = SpellName(spell) if (name) then PickupSpell(name) end end,
	GetSpellLossOfControlCooldown = function() return 0, 0 end,
	GetSpellLossOfControlCooldownDuration = function() return nil end,
	GetSpellLossOfControlCooldownInfo = function() return nil end,
	GetSpellCooldownDuration = function() return nil end,
	GetSpellMaxCumulativeAuraApplications = function() return nil end,
	IsSpellCrowdControl = returnFalse,
	IsSpellImportant = returnFalse,
	IsExternalDefensive = returnFalse,
})

---------------------------------------------------------------------------------------------------------------
--> spellbook (11.x C_SpellBook) on the 3.3.5 index functions (GetSpellName / GetSpellTexture / IsPassiveSpell)

if (rawget(env, "Enum") == nil) then rawset(env, "Enum", setmetatable({}, {__index = realG.Enum})) end
local function enum(name, values)
	if (env.Enum[name] == nil) then rawset(env.Enum, name, values) end
end
Compat.enum = enum
enum("SpellBookItemType", {None = 0, Spell = 1, FutureSpell = 2, PetAction = 3, Flyout = 4})
enum("SpellBookSpellBank", {Player = 0, Pet = 1})
enum("ItemClass", {Consumable = 0, Container = 1, Weapon = 2, Gem = 3, Armor = 4, Reagent = 5, Projectile = 6,
	Tradegoods = 7, ItemEnhancement = 8, Recipe = 9, Quiver = 11, Questitem = 12, Key = 13, Miscellaneous = 15, Glyph = 16})
enum("ItemArmorSubclass", {Generic = 0, Cloth = 1, Leather = 2, Mail = 3, Plate = 4, Shield = 6, Libram = 7, Idol = 8,
	Totem = 9, Sigil = 10})
enum("ItemQuality", {Poor = 0, Common = 1, Standard = 1, Uncommon = 2, Good = 2, Rare = 3, Superior = 3, Epic = 4,
	Legendary = 5, Artifact = 6, Heirloom = 7})
enum("ItemBind", {None = 0, OnAcquire = 1, OnEquip = 2, OnUse = 3, Quest = 4})

do
	local function BookType(bank)
		return bank == 1 and BOOKTYPE_PET or BOOKTYPE_SPELL
	end
	--the spells of the player's book: name (+ rank) -> index, rebuilt when the book changes
	local bookIndex
	local book = CreateFrame("Frame")
	book:RegisterEvent("SPELLS_CHANGED")
	book:RegisterEvent("LEARNED_SPELL_IN_TAB")
	book:SetScript("OnEvent", function() bookIndex = nil end)
	local function BookIndex()
		if (bookIndex) then return bookIndex end
		bookIndex = {}
		for tab = 1, GetNumSpellTabs() do
			local _, _, offset, numSpells = GetSpellTabInfo(tab)
			for i = offset + 1, offset + numSpells do
				local name = GetSpellName(i, BOOKTYPE_SPELL)
				if (name) then bookIndex[name] = i end
			end
		end
		return bookIndex
	end
	local function SpellIDAt(index, bookType)
		local link = GetSpellLink(index, bookType)
		return link and tonumber(link:match("spell:(%d+)"))
	end
	local function ItemInfo(index, bank)
		local bookType = BookType(bank)
		local name, subName = GetSpellName(index, bookType)
		if (not name) then return nil end
		local spellID = SpellIDAt(index, bookType)
		return {itemType = env.Enum.SpellBookItemType.Spell, actionID = spellID, spellID = spellID, name = name,
			subName = subName, iconID = GetSpellTexture(index, bookType), isPassive = IsPassiveSpell(index, bookType) and true or false,
			isOffSpec = false, skillLineIndex = nil}
	end
	local function InBook(spell)
		local name = SpellName(spell)
		return name ~= nil and BookIndex()[name] ~= nil
	end
	fill("C_SpellBook", {
		IsSpellKnown = function(spellID, isPet) return (IsSpellKnown(spellID, isPet) or (not isPet and InBook(spellID))) and true or false end,
		IsSpellKnownOrInSpellBook = function(spellID, isPet) return (IsSpellKnown(spellID, isPet) or InBook(spellID)) and true or false end,
		IsSpellInSpellBook = function(spellID) return InBook(spellID) end,
		FindSpellBookSlotForSpell = function(spell)
			local name = SpellName(spell)
			local index = name and BookIndex()[name]
			return index, index and env.Enum.SpellBookSpellBank.Player or nil
		end,
		FindSpellOverrideByID = function(spellID) return spellID end,
		GetNumSpellBookSkillLines = function() return GetNumSpellTabs() end,
		GetSpellBookSkillLineInfo = function(index)
			local name, iconID, offset, numSpells = GetSpellTabInfo(index)
			if (not name) then return nil end
			return {name = name, iconID = iconID, itemIndexOffset = offset, numSpellBookItems = numSpells, isGuild = false, shouldHide = false}
		end,
		GetSpellBookItemType = function(index, bank)
			local info = ItemInfo(index, bank)
			if (not info) then return env.Enum.SpellBookItemType.None end
			return info.itemType, info.actionID, info.spellID
		end,
		GetSpellBookItemInfo = ItemInfo,
		GetSpellBookItemName = function(index, bank) return GetSpellName(index, BookType(bank)) end,
		GetSpellBookItemTexture = function(index, bank) return GetSpellTexture(index, BookType(bank)) end,
		GetSpellBookItemLink = function(index, bank) return GetSpellLink(index, BookType(bank)) end,
	})
	Compat.InSpellBook = InBook
end

---------------------------------------------------------------------------------------------------------------
--> auras (C_UnitAuras / AuraUtil): UnitAura scans; a 'slot' and an 'auraInstanceID' are index * 2 + harmful,
--  valid until the next UNIT_AURA (oUF and ElvUI rescan a unit fully on each one: 3.3.5 sends no payload)

do
	local lastFilter = {[0] = "HELPFUL", [1] = "HARMFUL"}
	local function isHarmful(filter) return filter and filter:find("HARMFUL") and true or false end
	local function baseFilter(filter) return isHarmful(filter) and "HARMFUL" or "HELPFUL" end
	local playerUnits = {player = true, pet = true, vehicle = true}

	local function BuildAuraData(unit, index, filter, harmful)
		local name, rank, icon, count, dispelName, duration, expirationTime, sourceUnit, isStealable, shouldConsolidate, spellId =
			UnitAura(unit, index, filter)
		if (not name) then return nil end
		return {
			name = name, icon = icon, applications = count or 0, charges = count or 0, maxCharges = count or 0,
			dispelName = dispelName, duration = duration or 0, expirationTime = expirationTime or 0,
			sourceUnit = sourceUnit, isStealable = isStealable and true or false, nameplateShowPersonal = false,
			spellId = spellId, canApplyAura = false, isBossAura = false,
			isFromPlayerOrPlayerPet = sourceUnit ~= nil and playerUnits[sourceUnit] or false,
			nameplateShowAll = false, timeMod = 1, points = {}, isHelpful = not harmful, isHarmful = harmful,
			isNameplateOnly = false, isRaid = false, auraInstanceID = index * 2 + (harmful and 1 or 0),
			index = index, filter = filter, shouldConsolidate = shouldConsolidate and true or false,
		}
	end
	Compat.BuildAuraData = BuildAuraData

	local function DataBySlot(unit, slot)
		if (not slot) then return nil end
		local kind = slot % 2
		local index = (slot - kind) / 2
		return BuildAuraData(unit, index, lastFilter[kind], kind == 1)
	end

	--does the aura at index (in its base list) also pass the other tokens of the filter: PLAYER, RAID, CANCELABLE...
	local function PassesFilter(unit, slot, filter)
		local kind = slot % 2
		local index = (slot - kind) / 2
		local harmful = kind == 1
		if (isHarmful(filter) ~= harmful) then return false end
		local base = harmful and "HARMFUL" or "HELPFUL"
		local name, _, _, _, _, _, expirationTime, sourceUnit, _, _, spellId = UnitAura(unit, index, base)
		if (not name) then return false end
		if (filter == base) then return true end
		if (filter:find("PLAYER") and not (sourceUnit and playerUnits[sourceUnit])) then return false end
		--the other tokens: the client's own filtered list
		local rest = filter:gsub("PLAYER", ""):gsub("|+", "|"):gsub("^|", ""):gsub("|$", "")
		if (rest == base) then return true end
		for i = 1, 40 do
			local n, _, _, _, _, _, exp, _, _, _, id = UnitAura(unit, i, rest)
			if (not n) then return false end
			if (id == spellId and exp == expirationTime) then return true end
		end
		return false
	end

	local UnitAuras = fill("C_UnitAuras", {
		GetAuraDataByIndex = function(unit, index, filter)
			filter = filter or "HELPFUL"
			return BuildAuraData(unit, index, filter, isHarmful(filter))
		end,
		GetBuffDataByIndex = function(unit, index, filter)
			return BuildAuraData(unit, index, filter and ("HELPFUL|" .. filter) or "HELPFUL", false)
		end,
		GetDebuffDataByIndex = function(unit, index, filter)
			return BuildAuraData(unit, index, filter and ("HARMFUL|" .. filter) or "HARMFUL", true)
		end,
		--continuationToken, slot1, slot2, ...: the slots of the base list (HELPFUL / HARMFUL) of the filter
		GetAuraSlots = function(unit, filter, maxSlots)
			filter = filter or "HELPFUL"
			local harmful = isHarmful(filter)
			local kind = harmful and 1 or 0
			local base = baseFilter(filter)
			lastFilter[kind] = base
			local slots, n = {}, 0
			maxSlots = maxSlots or 40
			for index = 1, 40 do
				if (n >= maxSlots or not UnitAura(unit, index, base)) then break end
				local slot = index * 2 + kind
				if (filter == base or PassesFilter(unit, slot, filter)) then
					n = n + 1
					slots[n] = slot
				end
			end
			return nil, unpack(slots, 1, n)
		end,
		GetAuraDataBySlot = DataBySlot,
		GetAuraDataByAuraInstanceID = DataBySlot,
		IsAuraFilteredOutByInstanceID = function(unit, auraInstanceID, filter)
			if (not auraInstanceID) then return true end
			return not PassesFilter(unit, auraInstanceID, filter or "HELPFUL")
		end,
		GetPlayerAuraBySpellID = function(spellID)
			for kind = 0, 1 do
				local filter = kind == 1 and "HARMFUL" or "HELPFUL"
				for index = 1, 40 do
					local name, _, _, _, _, _, _, _, _, _, id = UnitAura("player", index, filter)
					if (not name) then break end
					if (id == spellID) then return BuildAuraData("player", index, filter, kind == 1) end
				end
			end
		end,
		GetUnitAuraBySpellID = function(unit, spellID, filter)
			for kind = 0, 1 do
				local f = filter or (kind == 1 and "HARMFUL" or "HELPFUL")
				for index = 1, 40 do
					local name, _, _, _, _, _, _, _, _, _, id = UnitAura(unit, index, f)
					if (not name) then break end
					if (id == spellID) then return BuildAuraData(unit, index, f, isHarmful(f)) end
				end
				if (filter) then break end
			end
		end,
		GetAuraDataBySpellName = function(unit, spellName, filter)
			filter = filter or "HELPFUL"
			for index = 1, 40 do
				local name = UnitAura(unit, index, filter)
				if (not name) then break end
				if (name == spellName) then return BuildAuraData(unit, index, filter, isHarmful(filter)) end
			end
		end,
		GetAuraApplicationDisplayCount = function(unit, auraInstanceID, minCount, maxCount)
			local data = DataBySlot(unit, auraInstanceID)
			local count = data and data.applications or 0
			if (count < (minCount or 2) or count > (maxCount or 999)) then return "" end
			return tostring(count)
		end,
	})

	local function UnpackAuraData(a)
		if (not a) then return nil end
		return a.name, a.icon, a.applications, a.dispelName, a.duration, a.expirationTime, a.sourceUnit, a.isStealable,
			a.nameplateShowPersonal, a.spellId, a.canApplyAura, a.isBossAura, a.isFromPlayerOrPlayerPet, a.nameplateShowAll, a.timeMod
	end
	fill("AuraUtil", {
		UnpackAuraData = UnpackAuraData,
		ForEachAura = function(unit, filter, maxCount, func, usePackedAura)
			local harmful = isHarmful(filter)
			for index = 1, maxCount or 40 do
				local a = BuildAuraData(unit, index, filter, harmful)
				if (not a) then return end
				local stop
				if (usePackedAura) then stop = func(a) else stop = func(UnpackAuraData(a)) end
				if (stop) then return end
			end
		end,
		FindAuraByName = function(auraName, unit, filter)
			filter = filter or "HELPFUL"
			for index = 1, 40 do
				local name = UnitAura(unit, index, filter)
				if (not name) then return end
				if (name == auraName) then return UnitAura(unit, index, filter) end
			end
		end,
	})
end

---------------------------------------------------------------------------------------------------------------
--> items and bags

fill("C_Item", {
	GetItemInfo = GetItemInfo,
	GetItemInfoInstant = realG.GetItemInfoInstant,
	GetItemIconByID = GetItemIcon,
	GetItemCount = GetItemCount,
	GetItemSpell = GetItemSpell,
	GetItemCooldown = GetItemCooldown,
	GetItemQualityColor = GetItemQualityColor,
	GetItemQualityByID = function(item) return (select(3, GetItemInfo(item))) end,
	GetItemNameByID = function(item) return (GetItemInfo(item)) end,
	GetItemFamily = GetItemFamily,
	IsEquippedItem = IsEquippedItem,
	IsEquippableItem = IsEquippableItem,
	IsUsableItem = IsUsableItem,
	IsCurrentItem = IsCurrentItem,
	IsConsumableItem = IsConsumableItem,
	ItemHasRange = ItemHasRange,
	PickupItem = PickupItem,
	IsItemInRange = function(item, unit)
		local inRange = IsItemInRange(item, unit)
		if (inRange == nil) then return nil end
		return inRange == 1
	end,
	--3.3.5 has no scaled item levels: the item's own level
	GetDetailedItemLevelInfo = function(item) return (select(4, GetItemInfo(item))) end,
	GetCurrentItemLevel = function(location)
		local link = location and location.GetItemLink and location:GetItemLink()
		return link and (select(4, GetItemInfo(link))) or nil
	end,
	DoesItemExist = function(location) return location ~= nil and location.IsValid and location:IsValid() or false end,
	IsBound = returnFalse,
	IsBoundToAccountUntilEquip = returnFalse,
	CanScrapItem = returnFalse,
	IsItemDataCachedByID = function(itemID) return GetItemInfo(itemID) ~= nil end,
	RequestLoadItemDataByID = noop,
})

fill("C_Container", {
	GetContainerNumSlots = GetContainerNumSlots,
	GetContainerNumFreeSlots = GetContainerNumFreeSlots,
	GetContainerItemID = GetContainerItemID,
	GetContainerItemLink = GetContainerItemLink,
	GetContainerItemCooldown = GetContainerItemCooldown,
	GetItemCooldown = GetItemCooldown,
	ContainerIDToInventoryID = ContainerIDToInventoryID,
	GetBagName = GetBagName,
	UseContainerItem = UseContainerItem,
	PickupContainerItem = PickupContainerItem,
	SplitContainerItem = SplitContainerItem,
	GetInventoryItemLink = GetInventoryItemLink,
	GetContainerItemInfo = function(bag, slot)
		local icon, itemCount, locked, quality, readable, lootable, itemLink = GetContainerItemInfo(bag, slot)
		if (not icon) then return nil end
		local itemID = GetContainerItemID(bag, slot)
		if ((quality == nil or quality < 0) and itemLink) then quality = select(3, GetItemInfo(itemLink)) end
		return {iconFileID = icon, stackCount = itemCount or 1, isLocked = locked and true or false, quality = quality,
			isReadable = readable and true or false, hasLoot = lootable and true or false, hyperlink = itemLink,
			isFiltered = false, hasNoValue = itemLink ~= nil and (select(11, GetItemInfo(itemLink)) or 0) == 0, itemID = itemID, isBound = false}
	end,
	--3.3.5: isQuestItem / questID / isActive from GetContainerItemQuestInfo when the client has it
	GetContainerItemQuestInfo = function(bag, slot)
		if (realG.GetContainerItemQuestInfo) then
			local isQuestItem, questID, isActive = realG.GetContainerItemQuestInfo(bag, slot)
			return {isQuestItem = isQuestItem and true or false, questID = questID, isActive = isActive and true or false}
		end
		return {isQuestItem = false, isActive = false}
	end,
	CalculateTotalNumberOfFreeBagSlots = function()
		local free = 0
		for bag = 0, NUM_BAG_SLOTS do
			local n, family = GetContainerNumFreeSlots(bag)
			if (n and (family == 0 or family == nil)) then free = free + n end
		end
		return free
	end,
	--no bag sort, autosort flags or search on 3.3.5: ElvUI sorts with its own sorter
	SortBags = noop, SortBankBags = noop, SortAccountBankBags = noop, SetItemSearch = noop,
	GetBackpackAutosortDisabled = returnFalse, SetBackpackAutosortDisabled = noop,
	GetBankAutosortDisabled = returnFalse, SetBankAutosortDisabled = noop,
	GetBagSlotFlag = returnFalse, SetBagSlotFlag = noop, SetInsertItemsLeftToRight = noop,
	GetInsertItemsLeftToRight = returnFalse,
})

---------------------------------------------------------------------------------------------------------------
--> action bars (C_ActionBar) on the 3.3.5 action slot functions

do
	local function DisplayCount(action)
		if (IsConsumableAction(action) or IsStackableAction(action)) then
			local count = GetActionCount(action)
			if (count > (MAX_DISPLAY_COUNT or 9999)) then return "*" end
			return count
		end
		return ""
	end
	local function IsItemAction(action) return (GetActionInfo(action)) == "item" end
	local function VehicleBar() return UnitHasVehicleUI and UnitHasVehicleUI("player") and true or false end
	fill("C_ActionBar", {
		HasAction = HasAction,
		GetActionTexture = GetActionTexture,
		GetActionText = GetActionText,
		GetActionCount = GetActionCount,
		GetActionInfo = GetActionInfo,
		IsActionInRange = function(action, unit)
			local inRange = IsActionInRange(action, unit)
			if (inRange == nil) then return nil end
			return inRange == 1
		end,
		IsUsableAction = IsUsableAction,
		IsAttackAction = IsAttackAction,
		IsAutoRepeatAction = IsAutoRepeatAction,
		IsConsumableAction = IsConsumableAction,
		IsCurrentAction = IsCurrentAction,
		IsEquippedAction = IsEquippedAction,
		IsStackableAction = IsStackableAction,
		IsItemAction = IsItemAction,
		IsEquippedGearOutfitAction = returnFalse,
		IsAssistedCombatAction = returnFalse,
		HasAssistedCombatActionButtons = returnFalse,
		EnableActionRangeCheck = noop,
		GetActionCooldown = function(action) return Compat.CooldownInfo(GetActionCooldown(action)) end,
		GetActionCooldownDuration = function() return nil end,
		GetActionCharges = function() return nil end,
		GetActionChargeDuration = function() return nil end,
		GetActionLossOfControlCooldownInfo = function() return nil end,
		GetActionLossOfControlCooldownDuration = function() return nil end,
		GetActionDisplayCount = DisplayCount,
		GetActionUseCount = function(action) return GetActionCount(action) end,
		GetProfessionQualityInfo = function() return nil end,
		UsesActionText = function(action) return not (IsConsumableAction(action) or IsStackableAction(action)) end,
		GetSpell = function(action)
			local actionType, id = GetActionInfo(action)
			if (actionType == "spell") then return id end
			if (actionType == "macro") then local name = GetMacroSpell(id) return name and Compat.SpellID(name) end
		end,
		GetActionBarPage = GetActionBarPage,
		GetBonusBarOffset = GetBonusBarOffset,
		--3.3.5: vehicle and possess use the bonus bar (bonusbar:5 -> page 11); no override or temp shapeshift bar
		HasVehicleActionBar = VehicleBar,
		HasOverrideActionBar = returnFalse,
		HasTempShapeshiftActionBar = returnFalse,
		IsPossessBarVisible = function() return GetBonusBarOffset() == 5 and not VehicleBar() end,
		GetVehicleBarIndex = function() return 11 end,
		GetOverrideBarIndex = function() return 11 end,
		GetTempShapeshiftBarIndex = function() return 11 end,
	})
end

---------------------------------------------------------------------------------------------------------------
--> groups (5.0 API) on the 3.3.5 party / raid functions

local function NumRaid() return GetNumRaidMembers() end
local function NumParty() return GetNumPartyMembers() end
define("IsInRaid", function() return NumRaid() > 0 end)
define("IsInGroup", function() return NumRaid() > 0 or NumParty() > 0 end)
define("GetNumGroupMembers", function()
	local raid = NumRaid()
	if (raid > 0) then return raid end
	local party = NumParty()
	return party > 0 and party + 1 or 0
end)
define("GetNumSubgroupMembers", function() return NumParty() end)
define("UnitIsGroupLeader", function(unit)
	if (NumRaid() > 0) then return UnitIsRaidOfficer(unit) and UnitIsPartyLeader(unit) and true or (UnitIsPartyLeader(unit) and true or false) end
	return UnitIsPartyLeader(unit) and true or false
end)
define("UnitIsGroupAssistant", function(unit)
	return NumRaid() > 0 and UnitIsRaidOfficer(unit) and not UnitIsPartyLeader(unit) and true or false
end)
define("IsEveryoneAssistant", returnFalse)
define("IsTrialAccount", returnFalse)
define("IsVeteranTrialAccount", returnFalse)
define("IsRestrictedAccount", returnFalse)
define("GetRealmID", function() return 1 end)
define("UnitLeadsAnyGroup", function(unit) return UnitIsPartyLeader(unit) and true or false end)

fill("C_PartyInfo", {
	ConvertToRaid = ConvertToRaid,
	ConvertToParty = noop,
	DoReadyCheck = DoReadyCheck,
	DoCountdown = noop,
	InviteUnit = InviteUnit,
	RequestInviteFromUnit = InviteUnit,
	UninviteUnit = UninviteUnit,
	LeaveParty = LeaveParty,
	GetLootMethod = function()
		local method, partyMaster, raidMaster = GetLootMethod()
		return method, partyMaster, raidMaster
	end,
	IsPartyWalkIn = returnFalse,
	GetRestrictPings = returnFalse, SetRestrictPings = noop, SetEveryoneIsAssistant = noop,
	IsDelveInProgress = returnFalse,
})

---------------------------------------------------------------------------------------------------------------
--> specializations (rebuffed.dll gives GetSpecialization & co from the talent trees)

fill("C_SpecializationInfo", {
	GetSpecialization = realG.GetSpecialization,
	GetSpecializationInfo = realG.GetSpecializationInfo,
	GetSpecializationInfoForSpecID = realG.GetSpecializationInfoByID,
	GetSpecializationInfoByID = realG.GetSpecializationInfoByID,
	GetNumSpecializationsForClassID = function() return realG.GetNumSpecializations and realG.GetNumSpecializations() or 3 end,
	GetActiveSpecGroup = function() return GetActiveTalentGroup() end,
	CanPlayerUseTalentSpecUI = function() return true end,
	GetSpecializationRole = function(index)
		local role = realG.GetSpecializationInfo and select(5, realG.GetSpecializationInfo(index))
		return role
	end,
})
define("GetActiveSpecGroup", function() return GetActiveTalentGroup() end)
define("GetNumSpecGroups", function() return GetNumTalentGroups and GetNumTalentGroups() or 1 end)

---------------------------------------------------------------------------------------------------------------
--> chat, addon messages, social

fill("C_ChatInfo", {
	RegisterAddonMessagePrefix = function() return true end, --3.3.5 delivers every prefix
	IsAddonMessagePrefixRegistered = function() return true end,
	SendAddonMessage = function(prefix, message, chatType, target)
		SendAddonMessage(prefix, message, chatType, target)
		return true
	end,
	SendAddonMessageLogged = function(prefix, message, chatType, target)
		SendAddonMessage(prefix, message, chatType, target)
		return true
	end,
	SendChatMessage = function(message, chatType, language, target) SendChatMessage(message, chatType, language, target) end,
	GetChannelRuleset = function() return 0 end,
	GetChannelRulesetForChannelID = function() return 0 end,
	GetChannelShortcutForChannelID = function() return nil end,
	IsChannelRegionalForChannelID = returnFalse,
	IsChatLineCensored = returnFalse,
	IsTimerunningPlayer = returnFalse,
	InChatMessagingLockdown = returnFalse,
})

fill("C_FriendList", {
	GetNumFriends = function() return GetNumFriends() end,
	GetNumOnlineFriends = function() local _, online = GetNumFriends() return online or 0 end,
	GetFriendInfoByIndex = function(index)
		local name, level, class, area, connected, status, notes = GetFriendInfo(index)
		if (not name) then return nil end
		return {name = name, level = level, className = class, area = area, connected = connected and true or false,
			afk = status == CHAT_FLAG_AFK, dnd = status == CHAT_FLAG_DND, notes = notes, guid = nil}
	end,
	IsFriend = function(guid)
		for i = 1, GetNumFriends() do
			local name = GetFriendInfo(i)
			if (name and guid and UnitGUID(name) == guid) then return true end
		end
		return false
	end,
	ShowFriends = ShowFriends,
})

--Battle.net (3.3.5 RealID: BNGetFriendInfo / BNGetToonInfo): the account and its one game account
fill("C_BattleNet", {
	GetFriendNumGameAccounts = function(index)
		local _, _, _, toonName = BNGetFriendInfo(index)
		return toonName and 1 or 0
	end,
	GetFriendAccountInfo = function(index)
		local presenceID, givenName, surname, toonName, toonID, client, isOnline, lastOnline, isAFK, isDND, broadcast, note =
			BNGetFriendInfo(index)
		if (not presenceID) then return nil end
		return {bnetAccountID = presenceID, accountName = givenName and surname and (givenName .. " " .. surname) or givenName or "",
			battleTag = "", isFriend = true, isBattleTagFriend = false, lastOnlineTime = lastOnline, isAFK = isAFK and true or false,
			isDND = isDND and true or false, customMessage = broadcast, note = note,
			gameAccountInfo = {gameAccountID = toonID, characterName = toonName, clientProgram = client, isOnline = isOnline and true or false}}
	end,
	GetFriendGameAccountInfo = function(index)
		local presenceID, _, _, toonName, toonID, client, isOnline = BNGetFriendInfo(index)
		if (not presenceID) then return nil end
		return {gameAccountID = toonID, characterName = toonName, clientProgram = client, isOnline = isOnline and true or false}
	end,
	GetAccountInfoByID = function() return nil end,
	GetGameAccountInfoByID = function() return nil end,
	GetGameAccountInfoByGUID = function() return nil end,
	InviteFriend = noop, SetCustomMessage = function(text) if (BNSetCustomMessage) then BNSetCustomMessage(text) end end,
	SendGameData = noop,
})

---------------------------------------------------------------------------------------------------------------
--> colors

fill("C_ClassColor", {
	GetClassColor = function(classFilename)
		local c = (CUSTOM_CLASS_COLORS and CUSTOM_CLASS_COLORS[classFilename]) or RAID_CLASS_COLORS[classFilename]
		if (not c) then return nil end
		return CreateColor(c.r, c.g, c.b, 1)
	end,
})
fill("C_ColorUtil", {
	GenerateTextColorCode = function(color)
		local r, g, b = color.r or 1, color.g or 1, color.b or 1
		return ("ff%02x%02x%02x"):format(floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
	end,
	WrapTextInColor = function(text, color)
		return ("|cff%02x%02x%02x%s|r"):format(floor((color.r or 1) * 255 + 0.5), floor((color.g or 1) * 255 + 0.5), floor((color.b or 1) * 255 + 0.5), text)
	end,
})

local CLASS_IDS = {WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5, DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11}
local CLASS_BY_ID = {}
for file, id in pairs(CLASS_IDS) do CLASS_BY_ID[id] = file end
fill("C_CreatureInfo", {
	GetClassInfo = function(classID)
		local file = CLASS_BY_ID[classID]
		if (not file) then return nil end
		return {className = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file] or file, classFile = file, classID = classID}
	end,
})
define("GetClassInfo", function(classID)
	local file = CLASS_BY_ID[classID]
	if (not file) then return nil end
	return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file] or file, file, classID
end)
define("GetNumClasses", function() return 11 end)

---------------------------------------------------------------------------------------------------------------
--> unit functions of later clients

define("UnitEffectiveLevel", function(unit) return UnitLevel(unit) end)
define("UnitIsTapDenied", function(unit)
	return UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) and not UnitIsTappedByAllThreatList(unit) and true or false
end)
define("UnitGetIncomingHeals", function() return nil end)
define("UnitGetTotalAbsorbs", function() return 0 end)
define("UnitGetTotalHealAbsorbs", function() return 0 end)
define("UnitPhaseReason", function() return nil end)
define("UnitInPhase", function() return true end)
define("UnitIsWarModePhased", returnFalse)
define("UnitHasIncomingResurrection", returnFalse)
define("UnitIsOwnerOrControllerOfUnit", function(owner, unit) return UnitIsUnit(owner .. "pet", unit) or false end)
define("UnitInPartyIsAI", returnFalse)
define("UnitIsQuestBoss", returnFalse)
--4.x attribute drivers: the 3.3.5 state driver handles the state- attributes (state-visibility shows and hides)
define("RegisterAttributeDriver", function(frame, attribute, values)
	local state = attribute:match("^state%-(.+)$")
	if (state) then return RegisterStateDriver(frame, state, values) end
end)
define("UnregisterAttributeDriver", function(frame, attribute)
	local state = attribute:match("^state%-(.+)$")
	if (state) then return UnregisterStateDriver(frame, state) end
end)
define("IsUnitModelReadyForUI", function() return true end)
define("IsPlayerMoving", function() return (GetUnitSpeed("player") or 0) > 0 end)
--the 8.x level color of a creature: the quest one of the same level
define("GetCreatureDifficultyColor", function(level) return GetQuestDifficultyColor(level) end)
define("GetMaxPlayerLevel", function() return MAX_PLAYER_LEVEL_TABLE and MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()] or 80 end)
define("GetServerTime", function() return time() end)
define("Ambiguate", function(name) return name end)
define("GetPhysicalScreenSize", function()
	local resolution = ({GetScreenResolutions()})[GetCurrentResolution()]
	local w, h = (resolution or ""):match("(%d+)x(%d+)")
	return tonumber(w) or 1920, tonumber(h) or 1080
end)
define("IsPlayerSpell", function(spellID) return Compat.InSpellBook(spellID) end)
define("GetSpellCharges", function() return nil end)
define("IsItemAction", function(action) return (GetActionInfo(action)) == "item" end)
define("GetDifficultyInfo", function(id)
	return nil
end)
define("GetCurrentRegion", function() return 3 end) --EU (the realm list has no region on 3.3.5)
define("GetCurrentRegionName", function() return "EU" end)
--expansions: 3.3.5 is Wrath of the Lich King (2)
for name, value in pairs({LE_EXPANSION_CLASSIC = 0, LE_EXPANSION_BURNING_CRUSADE = 1, LE_EXPANSION_WRATH_OF_THE_LICH_KING = 2,
	LE_EXPANSION_NORTHREND = 2, LE_EXPANSION_CATACLYSM = 3, LE_EXPANSION_MISTS_OF_PANDARIA = 4, LE_EXPANSION_WARLORDS_OF_DRAENOR = 5,
	LE_EXPANSION_LEGION = 6, LE_EXPANSION_BATTLE_FOR_AZEROTH = 7, LE_EXPANSION_SHADOWLANDS = 8, LE_EXPANSION_DRAGONFLIGHT = 9,
	LE_EXPANSION_WAR_WITHIN = 10, LE_EXPANSION_MIDNIGHT = 11, LE_EXPANSION_LEVEL_CURRENT = 2}) do
	if (realG[name] == nil) then rawset(env, name, value) end
end
define("ClassicExpansionAtLeast", function(expansion) return (expansion or 0) <= 2 end)
define("ClassicExpansionAtMost", function(expansion) return (expansion or 0) >= 2 end)
define("GetClassicExpansionLevel", function() return 2 end)
define("GetExpansionForLevel", function(level) if (level and level > 70) then return 2 elseif (level and level > 60) then return 1 end return 0 end)

---------------------------------------------------------------------------------------------------------------
--> misc namespaces ElvUI reads on the Wrath path

fill("C_PvP", {
	GetZonePVPInfo = GetZonePVPInfo,
	IsRatedBattleground = returnFalse,
	IsWarModeActive = returnFalse,
	GetArenaCrowdControlInfo = function() return nil end,
	RequestCrowdControlSpell = noop,
	GetHonorRewardInfo = function() return nil end,
})
fill("C_PlayerInfo", {
	GetGlidingInfo = function() return false, false, 0 end,
	GetPlayerMythicPlusRatingSummary = function() return nil end,
	CanPlayerUseMountEquipment = returnFalse,
})
fill("C_DateAndTime", {
	GetSecondsUntilDailyReset = function() return GetQuestResetTime() end,
	GetSecondsUntilWeeklyReset = function() return nil end,
})
fill("C_GuildInfo", {
	GuildRoster = GuildRoster,
	GetMOTD = GetGuildRosterMOTD,
	GetGuildNewsInfo = function() return nil end,
})
fill("C_EquipmentSet", {
	GetEquipmentSetIDs = function()
		local ids = {}
		for i = 1, GetNumEquipmentSets() do ids[i] = i end
		return ids
	end,
	--modern: name, iconFileID, setID, isEquipped, numItems, numEquipped, numInInventory, numLost, numIgnored
	GetEquipmentSetInfo = function(setID)
		local name, icon, setIndex, isEquipped, numItems, numEquipped, numInventory, numMissing, numIgnored = GetEquipmentSetInfo(setID)
		return name, icon, setID, isEquipped, numItems, numEquipped, numInventory, numMissing, numIgnored
	end,
	UseEquipmentSet = function(setID) local name = GetEquipmentSetInfo(setID) if (name) then UseEquipmentSet(name) end end,
	PickupEquipmentSet = function(setID) if (PickupEquipmentSet) then PickupEquipmentSet(setID) end end,
})
fill("C_PaperDollInfo", {
	GetInventorySlotInfo = GetInventorySlotInfo,
})
fill("C_Texture", {
	GetAtlasInfo = function(atlas)
		if (realG.GetAtlasInfo) then return realG.GetAtlasInfo(atlas) end
		return nil
	end,
	GetTitleIconTexture = noop,
})
--3.3.5 cannot tell whether a file exists: every media path is taken
fill("C_UIFileAsset", {IsKnownFile = function() return true end})

--Blizzard's ColorMixin (the Rebuffed client has its own color object, ColorPrototype, with other methods): ElvUI's
--colors are made by this one, the global CreateColor stays the client's
do
	local ColorMixin = {}
	function ColorMixin:OnLoad(r, g, b, a) self:SetRGBA(r, g, b, a) end
	function ColorMixin:IsRGBEqualTo(o) return self.r == o.r and self.g == o.g and self.b == o.b end
	function ColorMixin:IsEqualTo(o) return self:IsRGBEqualTo(o) and self.a == o.a end
	function ColorMixin:GetRGB() return self.r, self.g, self.b end
	function ColorMixin:GetRGBAsBytes() return floor(self.r * 255 + 0.5), floor(self.g * 255 + 0.5), floor(self.b * 255 + 0.5) end
	function ColorMixin:GetRGBA() return self.r, self.g, self.b, self.a end
	function ColorMixin:GetRGBAAsBytes() local r, g, b = self:GetRGBAsBytes() return r, g, b, floor((self.a or 1) * 255 + 0.5) end
	function ColorMixin:SetRGBA(r, g, b, a) self.r, self.g, self.b, self.a = r, g, b, a end
	function ColorMixin:SetRGB(r, g, b) self:SetRGBA(r, g, b, nil) end
	function ColorMixin:GenerateHexColor() return ("ff%.2x%.2x%.2x"):format(self:GetRGBAsBytes()) end
	function ColorMixin:GenerateHexColorNoAlpha() return ("%.2x%.2x%.2x"):format(self:GetRGBAsBytes()) end
	function ColorMixin:GenerateHexColorMarkup() return "|c" .. self:GenerateHexColor() end
	function ColorMixin:WrapTextInColorCode(text) return ("|c%s%s|r"):format(self:GenerateHexColor(), tostring(text)) end
	function ColorMixin:GetHex() return self:GenerateHexColor() end
	rawset(env, "ColorMixin", ColorMixin)
	local function CreateColor(r, g, b, a)
		local color = setmetatable({}, {__index = ColorMixin})
		color:OnLoad(r, g, b, a)
		return color
	end
	rawset(env, "CreateColor", CreateColor)
	rawset(env, "CreateColorFromHexString", function(hex)
		if (type(hex) ~= "string" or #hex ~= 8) then return nil end
		local a, r, g, b = tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16), tonumber(hex:sub(7, 8), 16)
		return CreateColor(r / 255, g / 255, b / 255, a / 255)
	end)
	rawset(env, "CreateColorFromBytes", function(r, g, b, a) return CreateColor(r / 255, g / 255, b / 255, (a or 255) / 255) end)
end

fill("C_StringUtil", {
	TruncateWhenZero = function(value) if (value == 0) then return "" end return tostring(value) end,
	WrapString = function(text, prefix, suffix) return (prefix or "") .. (text or "") .. (suffix or "") end,
})

---------------------------------------------------------------------------------------------------------------
--> durations (12.x DurationObject, C_DurationUtil) and curves (C_CurveUtil), from the EllesmereUI Legion compat

do
	local Enum = env.Enum
	local DurationObject = {}
	DurationObject.__index = DurationObject

	local function NewDuration(startTime, duration, modRate)
		return setmetatable({startTime = startTime or 0, duration = duration or 0, modRate = modRate or 1}, DurationObject)
	end
	Compat.NewDuration = NewDuration

	Compat.IsDurationObject = function(value)
		return type(value) == "table" and getmetatable(value) == DurationObject
	end

	function DurationObject:SetTimeFromStart(startTime, duration, modRate)
		self.startTime, self.duration, self.modRate = startTime or 0, duration or 0, modRate or 1
	end
	function DurationObject:SetTimeFromEnd(endTime, duration, modRate)
		self.startTime, self.duration, self.modRate = (endTime or 0) - (duration or 0), duration or 0, modRate or 1
	end
	function DurationObject:SetTimeSpan(startTime, endTime)
		self.startTime, self.duration = startTime or 0, math.max(0, (endTime or 0) - (startTime or 0))
	end
	function DurationObject:Reset()
		self.startTime, self.duration, self.modRate = 0, 0, 1
	end
	function DurationObject:GetStartTime() return self.startTime end
	function DurationObject:GetEndTime() return self.startTime + self.duration end
	function DurationObject:GetTotalDuration() return self.duration end
	function DurationObject:GetModRate() return self.modRate end
	function DurationObject:GetRemainingDuration()
		if (self.duration <= 0) then return 0 end
		return math.max(0, self.startTime + self.duration - GetTime())
	end
	function DurationObject:GetElapsedDuration()
		if (self.duration <= 0) then return 0 end
		return math.min(self.duration, math.max(0, GetTime() - self.startTime))
	end
	function DurationObject:IsZero()
		return self.duration <= 0 or self:GetRemainingDuration() <= 0
	end
	function DurationObject:HasSecretValues() return false end
	--curve: optional (C_CurveUtil), evaluated on the remaining / elapsed percent
	function DurationObject:EvaluateRemainingPercent(curve)
		local pct = self.duration > 0 and self:GetRemainingDuration() / self.duration or 0
		if (curve and curve.Evaluate) then return curve:Evaluate(pct) end
		return pct
	end
	function DurationObject:EvaluateElapsedPercent(curve)
		local pct = self.duration > 0 and self:GetElapsedDuration() / self.duration or 0
		if (curve and curve.Evaluate) then return curve:Evaluate(pct) end
		return pct
	end
	function DurationObject:EvaluateRemainingDuration(curve)
		local remaining = self:GetRemainingDuration()
		if (curve and curve.Evaluate) then return curve:Evaluate(remaining) end
		return remaining
	end

	fill("C_DurationUtil", {
		CreateDuration = function() return NewDuration(0, 0, 1) end,
	})
end

enum("LuaCurveType", {Linear = 0, Step = 1})
do
	local Enum = env.Enum
	local Curve = {}
	Curve.__index = Curve
	local function NewCurve(isColor)
		return setmetatable({points = {}, curveType = Enum.LuaCurveType.Linear, isColor = isColor}, Curve)
	end
	function Curve:SetType(curveType) self.curveType = curveType end
	function Curve:GetType() return self.curveType end
	function Curve:ClearPoints() wipe(self.points) end
	function Curve:GetPointCount() return #self.points end
	function Curve:AddPoint(x, y)
		local points = self.points
		local i = #points + 1
		while (i > 1 and points[i - 1].x > x) do
			points[i] = points[i - 1]
			i = i - 1
		end
		points[i] = {x = x, y = y}
	end
	local function Blend(a, b, t, isColor)
		if (not isColor) then return a + (b - a) * t end
		local r1, g1, b1, a1 = a:GetRGBA()
		local r2, g2, b2, a2 = b:GetRGBA()
		return CreateColor(r1 + (r2 - r1) * t, g1 + (g2 - g1) * t, b1 + (b2 - b1) * t, (a1 or 1) + ((a2 or 1) - (a1 or 1)) * t)
	end
	function Curve:Evaluate(x)
		local points = self.points
		local n = #points
		if (n == 0) then return self.isColor and nil or 0 end
		x = tonumber(x) or 0
		if (x <= points[1].x) then return points[1].y end
		if (x >= points[n].x) then return points[n].y end
		for i = 1, n - 1 do
			local p, q = points[i], points[i + 1]
			if (x >= p.x and x < q.x) then
				if (self.curveType == Enum.LuaCurveType.Step or q.x == p.x) then return p.y end
				return Blend(p.y, q.y, (x - p.x) / (q.x - p.x), self.isColor)
			end
		end
		return points[n].y
	end
	Compat.NewCurve = NewCurve
	fill("C_CurveUtil", {
		CreateCurve = function() return NewCurve(false) end,
		CreateColorCurve = function() return NewCurve(true) end,
		--12.x: picks one of two values from a (possibly secret) boolean
		EvaluateColorValueFromBoolean = function(value, valueIfTrue, valueIfFalse)
			if (value) then return valueIfTrue end
			return valueIfFalse
		end,
		EvaluateColorFromBoolean = function(value, colorIfTrue, colorIfFalse)
			if (value) then return colorIfTrue end
			return colorIfFalse
		end,
	})
end


---------------------------------------------------------------------------------------------------------------
--> tables of later clients

--the item quality colors of the bags (8.x), from the client's quality colors (poor to heirloom)
if (realG.BAG_ITEM_QUALITY_COLORS == nil) then
	local colors = {}
	for quality = 0, 7 do
		local r, g, b = GetItemQualityColor(quality)
		if (r) then colors[quality] = {r = r, g = g, b = b, a = 1} end
	end
	rawset(env, "BAG_ITEM_QUALITY_COLORS", colors)
end

---------------------------------------------------------------------------------------------------------------
--> quest log (9.0 C_QuestLog) on the 3.3.5 index functions:
--  GetQuestLogTitle: title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID

do
	local function Info(index)
		local title, level, questTag, suggestedGroup, isHeader, isCollapsed, isComplete, isDaily, questID = GetQuestLogTitle(index)
		if (not title) then return nil end
		return {title = title, questLogIndex = index, questID = questID, level = level, difficultyLevel = level,
			suggestedGroup = suggestedGroup or 0, frequency = isDaily and 1 or 0, isHeader = isHeader and true or false,
			isCollapsed = isCollapsed and true or false, isComplete = isComplete, isTask = false, isBounty = false,
			isStory = false, isScaling = false, isOnMap = true, hasLocalPOI = false, isHidden = false, startEvent = false,
			isAutoComplete = false, overridesSortOrder = false, readyForTranslation = true, campaignID = 0}
	end
	local function IndexForQuestID(questID)
		for index = 1, (GetNumQuestLogEntries()) do
			local _, _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(index)
			if (not isHeader and id == questID) then return index end
		end
	end
	local function Completed(questID)
		local index = IndexForQuestID(questID)
		return index ~= nil and (select(7, GetQuestLogTitle(index))) == 1
	end
	fill("C_QuestLog", {
		GetNumQuestLogEntries = function() return GetNumQuestLogEntries() end,
		GetInfo = Info,
		GetQuestIDForLogIndex = function(index) return (select(9, GetQuestLogTitle(index))) end,
		GetLogIndexForQuestID = IndexForQuestID,
		GetTitleForQuestID = function(questID) local index = IndexForQuestID(questID) return index and (GetQuestLogTitle(index)) end,
		GetQuestDifficultyLevel = function(questID) local index = IndexForQuestID(questID) return index and (select(2, GetQuestLogTitle(index))) end,
		GetMaxNumQuestsCanAccept = function() return 25 end, --WotLK quest log size
		GetQuestWatchType = function(questID) local index = IndexForQuestID(questID) return index and IsQuestWatched(index) and 0 or nil end,
		ReadyForTurnIn = Completed,
		IsComplete = Completed,
		IsQuestFlaggedCompleted = returnFalse,
		GetSelectedQuest = function() local index = GetQuestLogSelection() return index and (select(9, GetQuestLogTitle(index))) end,
		ShouldShowQuestRewards = function() return true end,
		GetQuestObjectives = function(questID)
			local index = IndexForQuestID(questID)
			local list = {}
			if (not index) then return list end
			for i = 1, GetNumQuestLeaderBoards(index) do
				local text, objectiveType, finished = GetQuestLogLeaderBoard(i, index)
				local have, need = text and text:match("(%d+)/(%d+)")
				list[i] = {text = text, type = objectiveType, finished = finished and true or false,
					numFulfilled = tonumber(have) or 0, numRequired = tonumber(need) or 0}
			end
			return list
		end,
		GetQuestInfo = function(questID) local index = IndexForQuestID(questID) return index and (GetQuestLogTitle(index)) end,
		GetQuestLogMajorFactionReputationRewards = function() return nil end,
	})
end

---------------------------------------------------------------------------------------------------------------
--> maps (8.0 C_Map) on the 3.3.5 map: the player's zone only (SetMapToCurrentZone moves the world map, so it is
--  only called while the world map is closed)

do
	local function CurrentMap()
		if (not (WorldMapFrame and WorldMapFrame:IsShown())) then SetMapToCurrentZone() end
		return GetCurrentMapAreaID()
	end
	local function Position(x, y)
		return {x = x, y = y, GetXY = function(self) return self.x, self.y end}
	end
	fill("C_Map", {
		GetBestMapForUnit = function(unit)
			if (unit ~= "player") then return nil end
			return CurrentMap()
		end,
		GetMapInfo = function(mapID)
			if (not mapID) then return nil end
			local name = mapID == GetCurrentMapAreaID() and (GetRealZoneText()) or nil
			return {mapID = mapID, name = name or "", mapType = 3, parentMapID = 0}
		end,
		GetPlayerMapPosition = function(mapID, unit)
			local x, y = GetPlayerMapPosition(unit or "player")
			if (not x or (x == 0 and y == 0)) then return nil end
			return Position(x, y)
		end,
		GetWorldPosFromMapPos = function() return nil end,
		GetAreaInfo = function() return nil end,
		GetMapGroupID = function() return nil end,
	})
end

---------------------------------------------------------------------------------------------------------------
--> chat bubbles (7.2 C_ChatBubbles): the 3.3.5 bubbles are unnamed WorldFrame children whose backdrop pieces are
--  textures of their own (ChatBubble-Background), found the way the 3.3.5 ElvUI does

do
	local seen, bubbles = 0, {}
	local function IsBubble(frame)
		if (frame:GetName()) then return false end
		for i = 1, frame:GetNumRegions() do
			local region = select(i, frame:GetRegions())
			if (region:IsObjectType("Texture")) then
				local path = region:GetTexture()
				if (type(path) == "string" and path:lower():find("chatbubble%-background")) then return true end
			end
		end
		return false
	end
	local function Scan(...)
		for i = seen + 1, select("#", ...) do
			local frame = select(i, ...)
			if (IsBubble(frame)) then bubbles[#bubbles + 1] = frame end
		end
	end
	fill("C_ChatBubbles", {
		GetAllChatBubbles = function()
			local count = WorldFrame:GetNumChildren()
			if (count > seen) then
				Scan(WorldFrame:GetChildren())
				seen = count
			end
			local shown = {}
			for _, bubble in ipairs(bubbles) do
				if (bubble:IsShown()) then shown[#shown + 1] = bubble end
			end
			return shown
		end,
	})
end

---------------------------------------------------------------------------------------------------------------
--> helpers of later FrameXML

--secure calls (4.x securecallfunction): the function called with its arguments, errors to the error handler
define("securecallfunction", function(func, ...)
	if (type(func) ~= "function") then return end
	return securecall(func, ...)
end)
define("securecallmethod", function(object, method, ...)
	local func = object and object[method]
	if (type(func) ~= "function") then return end
	return securecall(func, object, ...)
end)

--2D vectors (7.x CreateVector2D); the client's Vector2DMixin when it has one
do
	local Vector2DMixin = realG.Vector2DMixin
	if (not Vector2DMixin) then
		Vector2DMixin = {}
		function Vector2DMixin:SetXY(x, y) self.x, self.y = x, y end
		function Vector2DMixin:GetXY() return self.x, self.y end
		function Vector2DMixin:Clone() return env.CreateVector2D(self.x, self.y) end
		function Vector2DMixin:ScaleBy(s) self.x, self.y = self.x * s, self.y * s end
		function Vector2DMixin:Add(o) self.x, self.y = self.x + o.x, self.y + o.y end
		function Vector2DMixin:Subtract(o) self.x, self.y = self.x - o.x, self.y - o.y end
		function Vector2DMixin:GetLength() return math.sqrt(self.x * self.x + self.y * self.y) end
		function Vector2DMixin:IsEqualTo(o) return self.x == o.x and self.y == o.y end
	end
	define("CreateVector2D", function(x, y)
		local v = setmetatable({}, {__index = Vector2DMixin})
		v:SetXY(x or 0, y or 0)
		return v
	end)
end

--font families (9.x CreateFontFamily: one font per alphabet): 3.3.5 has one font object, made from the roman member
define("CreateFontFamily", function(name, members)
	local font = _G[name] or CreateFont(name)
	local roman
	for _, member in ipairs(members or {}) do
		if (member.alphabet == "roman" or not roman) then roman = member end
	end
	if (roman and roman.file) then
		font:SetFont(roman.file, roman.height or 12, roman.flags or "")
	end
	return font
end)

if (realG.ENCHANTED_TOOLTIP_LINE == nil) then rawset(env, "ENCHANTED_TOOLTIP_LINE", "Enchanted: %s") end
