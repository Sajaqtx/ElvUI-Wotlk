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

--item locations (8.0 ItemLocation): the fields and methods of Rebuffed's own (SharedXML/ItemUtil.lua), so its
--Item:CreateFromItemLocation takes ours; the link is read from the bag slot or the equipment slot
do
	local Location = {}
	function Location:HasAnyLocation() return self.slotIndex ~= nil or self.equipmentSlotIndex ~= nil end
	Location.IsValid = Location.HasAnyLocation
	function Location:IsBagAndSlot() return self.bagID ~= nil and self.slotIndex ~= nil end
	function Location:IsEquipmentSlot() return self.equipmentSlotIndex ~= nil end
	function Location:GetBagAndSlot() return self.bagID, self.slotIndex end
	function Location:GetEquipmentSlot() return self.equipmentSlotIndex end
	function Location:Clear() self.bagID, self.slotIndex, self.equipmentSlotIndex = nil, nil, nil end
	function Location:SetBagAndSlot(bagID, slotIndex) self:Clear() self.bagID, self.slotIndex = bagID, slotIndex end
	function Location:SetEquipmentSlot(slotIndex) self:Clear() self.equipmentSlotIndex = slotIndex end
	function Location:GetItemLink()
		if (self:IsBagAndSlot()) then return GetContainerItemLink(self.bagID, self.slotIndex) end
		if (self:IsEquipmentSlot()) then return GetInventoryItemLink("player", self.equipmentSlotIndex) end
	end
	local meta = {__index = Location}
	rawset(env, "ItemLocation", {
		CreateEmpty = function() return setmetatable({}, meta) end,
		CreateFromBagAndSlot = function(_, bagID, slotIndex) return setmetatable({bagID = bagID, slotIndex = slotIndex}, meta) end,
		CreateFromEquipmentSlot = function(_, slotIndex) return setmetatable({equipmentSlotIndex = slotIndex}, meta) end,
	})
end

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
	DoesItemExist = function(location) return location ~= nil and location.GetItemLink ~= nil and location:GetItemLink() ~= nil end,
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

--ElvUI v16: 12.x secret values and tokens (none on 3.3.5: every unit is known and comparable), the nameplate hit test
--insets (no such setting on 3.3.5), the curves of the 12.x percent functions (only read on the Modern path)
fill("C_Secrets", {
	ShouldUnitIdentityBeSecret = returnFalse,
	CanCompareUnitTokens = function() return true end,
})
fill("C_NamePlateManager", {SetNamePlateHitTestInsets = noop})
define("CurveConstants", {})
define("strlenutf8", function(s) return string.utf8len(s) end) -- 12.x global (the UTF8 library, loaded later, gives it)
define("issecretvalue", returnFalse)
define("issecrettable", returnFalse)
define("canaccessvalue", function() return true end)
fill("C_PetBattles", {IsInBattle = returnFalse}) -- no pet battles on 3.3.5
define("UnitNameUnmodified", function(unit) return UnitName(unit) end)

define("UnitEffectiveLevel", function(unit) return UnitLevel(unit) end)
define("UnitIsTapDenied", function(unit)
	return UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit) and not UnitIsTappedByAllThreatList(unit) and true or false
end)
--heal prediction (4.x / 5.x): what the MoP client gives, from the two 3.3.5 libraries that follow it (both in the
--client's LibStub, shared with the other addons, loaded after this file): the incoming heals of LibHealComm-4.0 (its
--own casts and those of the players running it), the absorbs SpecializedAbsorbs-1.0 estimates from the combat log
local function HealComm335() return realG.LibStub:GetLibrary("LibHealComm-4.0", true) end
local function Absorbs335() return realG.LibStub:GetLibrary("SpecializedAbsorbs-1.0", true) end
define("UnitGetIncomingHeals", function(unit, healer)
	local lib, guid = HealComm335(), unit and UnitGUID(unit)
	if (not (lib and guid)) then return nil end
	local amount = lib:GetHealAmount(guid, lib.CASTED_HEALS, nil, healer and UnitGUID(healer))
	return (amount or 0) * (lib:GetHealModifier(guid) or 1)
end)
define("UnitGetTotalAbsorbs", function(unit)
	local lib, guid = Absorbs335(), unit and UnitGUID(unit)
	return (lib and guid and lib.UnitTotal(guid)) or 0
end)
define("UnitGetTotalHealAbsorbs", function(unit)
	local lib, guid = Absorbs335(), unit and UnitGUID(unit)
	local amount = lib and guid and lib.UnitTotalHealAbsorbs(guid)
	return (type(amount) == "number" and amount > 0 and amount) or 0
end)
define("UnitPhaseReason", function() return nil end)
define("UnitInPhase", function() return true end)
define("UnitIsWarModePhased", returnFalse)
define("UnitHasIncomingResurrection", returnFalse)
define("UnitIsOwnerOrControllerOfUnit", function(owner, unit) return UnitIsUnit(owner .. "pet", unit) or false end)
define("UnitInPartyIsAI", returnFalse)
define("UnitIsQuestBoss", returnFalse)
--macro conditions of later clients the 3.3.5 one does not know ([petbattle] 5.0, [overridebar] / [possessbar] /
--[extrabar] 4.x...): a [group] holding one never matches there, so it is dropped (and a clause left without any group
--with it); their no- forms always match, so they leave their group. ElvUI's state drivers and option parsing get the
--result (the 3.3.5 ElvUI only used [vehicleui], [bonusbar], [bar]...)
do
	local UNKNOWN_CONDITIONS = {petbattle = true, overridebar = true, possessbar = true, extrabar = true, shapeshift = true}

	local function cleanGroup(conditions)
		local kept = {}
		for condition in conditions:gmatch("[^,]+") do
			local text = condition:match("^%s*(.-)%s*$")
			local name = (text:match("^(%a+)") or ""):lower()
			if (UNKNOWN_CONDITIONS[name]) then
				return nil
			elseif (not (name:sub(1, 2) == "no" and UNKNOWN_CONDITIONS[name:sub(3)])) then
				kept[#kept + 1] = text
			end
		end
		return "[" .. table.concat(kept, ",") .. "]"
	end

	function Compat.MacroConditions(text)
		if (type(text) ~= "string" or not text:find("%[")) then return text end

		local clauses = {}
		for clause in (text .. ";"):gmatch("([^;]*);") do
			local rest, groups, hadGroups = clause, {}, false
			while true do
				local group, after = rest:match("^%s*(%b[])(.*)$")
				if (not group) then break end
				hadGroups = true
				groups[#groups + 1] = cleanGroup(group:sub(2, -2))
				rest = after
			end

			if (not hadGroups) then
				clauses[#clauses + 1] = clause
			elseif (#groups > 0) then
				clauses[#clauses + 1] = table.concat(groups) .. " " .. rest:match("^%s*(.-)%s*$")
			end
		end

		return table.concat(clauses, ";")
	end

	local RegisterStateDriver, SecureCmdOptionParse = realG.RegisterStateDriver, realG.SecureCmdOptionParse
	rawset(env, "RegisterStateDriver", function(frame, state, values)
		return RegisterStateDriver(frame, state, Compat.MacroConditions(values))
	end)
	rawset(env, "SecureCmdOptionParse", function(text, ...)
		return SecureCmdOptionParse(Compat.MacroConditions(text), ...)
	end)
end
--4.x attribute drivers: the 3.3.5 state driver handles the state- attributes (state-visibility shows and hides)
define("RegisterAttributeDriver", function(frame, attribute, values)
	local state = attribute:match("^state%-(.+)$")
	if (state) then return env.RegisterStateDriver(frame, state, values) end
end)
define("UnregisterAttributeDriver", function(frame, attribute)
	local state = attribute:match("^state%-(.+)$")
	if (state) then return UnregisterStateDriver(frame, state) end
end)
--3.3.5 returns three values per weapon (no enchant ID, no ranged slot): the later order, for ElvUI only
rawset(env, "GetWeaponEnchantInfo", function()
	local hasMain, mainExpiration, mainCharges, hasOff, offExpiration, offCharges = realG.GetWeaponEnchantInfo()
	return hasMain, mainExpiration, mainCharges, nil, hasOff, offExpiration, offCharges, nil
end)
--3.3.5 returns a subtext second and no spell ID: the later order, for ElvUI only (the global is untouched)
--3.3.5 casts: name, rank, text, texture, start, end, trade skill, cast ID, not interruptible (channel: no cast ID); the
--later order has no rank and a spell ID last (for ElvUI only: oUF read the rank as the text and every value after shifted)
rawset(env, "UnitCastingInfo", function(unit)
	local name, _, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = realG.UnitCastingInfo(unit)
	return name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible, nil
end)
rawset(env, "UnitChannelInfo", function(unit)
	local name, _, text, texture, startTime, endTime, isTradeSkill, notInterruptible = realG.UnitChannelInfo(unit)
	return name, text, texture, startTime, endTime, isTradeSkill, notInterruptible, nil
end)

--> what the DataTexts use from later clients (for ElvUI only)
--stat indexes and the resilience rating (3.3.5: the melee crit taken rating), labels, the base run speed (yards/s)
for name, value in next, { LE_UNIT_STAT_STRENGTH = 1, LE_UNIT_STAT_AGILITY = 2, LE_UNIT_STAT_STAMINA = 3,
	LE_UNIT_STAT_INTELLECT = 4, LE_UNIT_STAT_SPIRIT = 5, COMBAT_RATING_RESILIENCE_CRIT_TAKEN = rawget(realG, "CR_CRIT_TAKEN_MELEE") or 15,
	STAT_HASTE = rawget(realG, "SPELL_HASTE") or "Haste", STAT_ENERGY_REGEN = "Energy Regen", BASE_MOVEMENT_SPEED = 7,
	CR_CRIT_TOOLTIP = "Crit Rating %s (+%.2f%% crit chance)", STAT_HASTE_TOOLTIP = "Increases attack speed and spell casting speed.",
	STAT_HASTE_BASE_TOOLTIP = "\n\nHaste Rating: %s (+%.2f%% Haste)" } do
	if (rawget(realG, name) == nil) then rawset(env, name, value) end
end
define("GetSpellSubtext", function(spell) return (select(2, GetSpellInfo(spell))) end) -- the rank: GetSpellInfo's second value
define("FormatShortDate", function(day, month, year)
	if (year) then return format("%d/%d/%02d", day, month, year % 100) end
	return format("%d/%d", day, month)
end)
define("ToggleAllBags", function() realG.OpenAllBags() end) -- 3.3.5 OpenAllBags toggles (ElvUI's bag follows it)
define("ToggleQuestLog", function() ToggleFrame(realG.QuestLogFrame) end)
define("ToggleGuildFrame", function() realG.ToggleFriendsFrame(3) end) -- the guild tab of the 3.3.5 friends frame
define("GetFileStreamingStatus", function() return 0 end)
define("GetBackgroundLoadingStatus", function() return 0 end)
--3.3.5 gives the current speed only: the run, flight and swim speeds are the current one when moving, else the base
rawset(env, "GetUnitSpeed", function(unit)
	local current, run, flight, swim = realG.GetUnitSpeed(unit)
	local moving = (current and current > 0) and current or 7
	return current or 0, run or moving, flight or moving, swim or moving
end)

--3.3.5 loot slots: texture, name, count, quality, locked; the later order has a currency ID before the quality and the
--quest fields after (for ElvUI only). LootSlotHasItem is the 3.3.5 LootSlotIsItem.
rawset(env, "GetLootSlotInfo", function(slot)
	local texture, item, count, quality, locked = realG.GetLootSlotInfo(slot)
	return texture, item, count, nil, quality, locked, false, nil, false
end)
define("LootSlotHasItem", function(slot) return realG.LootSlotIsItem(slot) and true or false end)
rawset(env, "GetPetActionInfo", function(index)
	local name, _, texture, isToken, isActive, autoCastAllowed, autoCastEnabled = realG.GetPetActionInfo(index)
	return name, texture, isToken, isActive, autoCastAllowed, autoCastEnabled, nil
end)
define("IsUnitModelReadyForUI", function() return true end)
define("IsPlayerMoving", function() return (GetUnitSpeed("player") or 0) > 0 end)
--the 8.x level color of a creature: the quest one of the same level
define("GetCreatureDifficultyColor", function(level) return GetQuestDifficultyColor(level) end)
define("GetMaxLevelForExpansionLevel", function(level) return MAX_PLAYER_LEVEL_TABLE and MAX_PLAYER_LEVEL_TABLE[level or GetExpansionLevel()] or 80 end)
define("GetMaxPlayerLevel", function() return MAX_PLAYER_LEVEL_TABLE and MAX_PLAYER_LEVEL_TABLE[GetExpansionLevel()] or 80 end)
--the level cap tests of later clients (the experience bar hides at max level)
define("IsLevelAtEffectiveMaxLevel", function(level) return (level or 0) >= env.GetMaxPlayerLevel() end)
define("IsPlayerAtEffectiveMaxLevel", function() return UnitLevel("player") >= env.GetMaxPlayerLevel() end)
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
	if (rawget(realG, name) == nil) then rawset(env, name, value) end
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

	--12.x GetTotemDuration: the totem's time as a duration object (nil without a totem in the slot)
	define("GetTotemDuration", function(slot)
		local haveTotem, _, startTime, duration = realG.GetTotemInfo(slot)
		if (haveTotem and startTime and duration and duration > 0) then return NewDuration(startTime, duration, 1) end
	end)

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
		if (frame.isChatBubble) then return true end -- a bubble ChatBubbleSkin skinned first (its fill emptied)
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

---------------------------------------------------------------------------------------------------------------
--> unit menus: the 3.3.5 secure unit button has no "togglemenu" type; its "menu" type calls frame.menu(frame, unit),
--  which opens the unit popup from a dropdown of ElvUI's own (as the 3.3.5 oUF did). ElvUI335.SetUnitMenu(frame)
--  sets both on a unit button.

do
	local dropdown
	local function InitializeMenu(self)
		local unit = self.unit
		if (not unit) then return end

		local unitType = unit:match("^([a-z]+)[0-9]+$") or unit
		local menu
		if (unitType == "party") then
			menu = "PARTY"
		elseif (unitType == "boss") then
			menu = "BOSS"
		elseif (unitType == "focus") then
			menu = "FOCUS"
		elseif (unitType == "arenapet" or unitType == "arena") then
			menu = "ARENAENEMY"
		elseif (UnitIsUnit(unit, "player")) then
			menu = "SELF"
		elseif (UnitIsUnit(unit, "vehicle")) then
			menu = "VEHICLE"
		elseif (UnitIsUnit(unit, "pet")) then
			menu = "PET"
		elseif (UnitIsPlayer(unit)) then
			if (UnitInRaid(unit)) then
				menu = "RAID_PLAYER"
			elseif (UnitInParty(unit)) then
				menu = "PARTY"
			else
				menu = "PLAYER"
			end
		elseif (UnitIsUnit(unit, "target")) then
			menu = "TARGET"
		end

		if (menu) then
			UnitPopup_ShowMenu(self, menu, unit)
		end
	end

	function Compat.ToggleUnitMenu(frame, unit)
		unit = unit or frame:GetAttribute("unit")
		if (not unit) then return end

		if (not dropdown) then
			dropdown = CreateFrame("Frame", "ElvUI335UnitMenu", realG.UIParent, "UIDropDownMenuTemplate")
			dropdown:SetID(1)
			tinsert(UnitPopupFrames, dropdown:GetName())
			UIDropDownMenu_Initialize(dropdown, InitializeMenu, "MENU")
		end

		if (dropdown.openedFor and dropdown.openedFor ~= frame) then
			CloseDropDownMenus()
		end

		dropdown.unit = unit:lower()
		dropdown.openedFor = frame
		ToggleDropDownMenu(1, nil, dropdown, "cursor")
	end

	function Compat.SetUnitMenu(frame)
		frame:SetAttribute("*type2", "menu")
		frame.menu = Compat.ToggleUnitMenu
	end
end

---------------------------------------------------------------------------------------------------------------
--> nameplates: rebuffed.dll's C_NamePlate gives the native 3.3.5 plate (an unnamed WorldFrame child: health and cast
--  bars, then the threat, border, cast bar border / shield / icon, highlight, name, level, boss, raid and elite
--  regions). ElvUI's plate is a child of it: the native parts are emptied once, as the 3.3.5 ElvUI did (the client
--  shows and hides them on its own, so they are made invisible rather than hidden)

--what the native plates are made of on this client, saved once per session in ElvDB.debug335_plate (read from the
--WTF after a /reload: the simulator's plates are a guess)
local function DescribeRegion(region)
	local text = region:GetObjectType()
	if (region.GetTexture) then text = text .. " tex=" .. tostring(region:GetTexture()) end
	if (region.GetText) then text = text .. " text=" .. tostring(region:GetText()) end
	return text .. " shown=" .. tostring(region:IsShown()) .. " alpha=" .. tostring(region:GetAlpha())
end
local function RecordPlate(plate, when)
	if (type(ElvDB) ~= "table") then return end
	ElvDB.debug335_plate = ElvDB.debug335_plate or {}
	local record = ElvDB.debug335_plate
	if (record[when]) then return end
	local info = {name = tostring(plate:GetName()), type = plate:GetObjectType(), children = {}, regions = {}, keys = {}}
	for i = 1, select("#", plate:GetChildren()) do
		local child = select(i, plate:GetChildren())
		local entry = DescribeRegion(child) .. " name=" .. tostring(child:GetName()) .. " regions=" .. child:GetNumRegions()
			.. " children=" .. child:GetNumChildren()
		for j = 1, select("#", child:GetRegions()) do
			entry = entry .. " | " .. DescribeRegion((select(j, child:GetRegions())))
		end
		info.children[#info.children + 1] = entry
	end
	for i = 1, select("#", plate:GetRegions()) do
		info.regions[#info.regions + 1] = DescribeRegion((select(i, plate:GetRegions())))
	end
	for key, value in pairs(plate) do
		if (type(key) == "string") then info.keys[#info.keys + 1] = key .. "=" .. type(value) end
	end
	record[when] = info
end
Compat.RecordPlate = RecordPlate

function Compat.HideNativePlate(plate)
	if (plate.__elvNativeHidden) then return end
	plate.__elvNativeHidden = true
	RecordPlate(plate, "before")

	for i = 1, select("#", plate:GetChildren()) do
		local child = select(i, plate:GetChildren())
		if (child:IsObjectType("StatusBar")) then
			child:SetStatusBarTexture("")
			child:SetAlpha(0)
		end
	end

	for i = 1, select("#", plate:GetRegions()) do
		local region = select(i, plate:GetRegions())
		if (region:IsObjectType("Texture")) then
			-- the client sets the spell icon again on every cast (its own castbar, enableNameplateCastbars): with no alpha it
			-- stays out of sight (it showed as a dark square under the ElvUI castbar, its texture coords squeezed to a texel)
			region:SetTexture("")
			region:SetTexCoord(0, 0, 0, 0)
			region:SetAlpha(0)
		elseif (region:IsObjectType("FontString")) then
			region:SetWidth(0.001)
			region:SetAlpha(0)
		end
	end
	RecordPlate(plate, "after")
end

---------------------------------------------------------------------------------------------------------------
--> later functions ElvUI calls on its Wrath path, with their 3.3.5 answer

--no battle pets nor game object units on 3.3.5
define("UnitIsGameObject", returnFalse)
define("UnitIsBattlePet", returnFalse)
define("UnitIsBattlePetCompanion", returnFalse)
define("UnitIsWildBattlePet", returnFalse)
define("UnitBattlePetLevel", function() return 0 end)
define("UnitBattlePetType", Compat.returnNil)

--haste and hit: the rating part (3.3.5 has no separate talent / buff modifiers)
define("UnitSpellHaste", function() return GetCombatRatingBonus(CR_HASTE_SPELL or 20) or 0 end)
define("GetMeleeHaste", function() return GetCombatRatingBonus(CR_HASTE_MELEE or 18) or 0 end)
define("GetRangedHaste", function() return GetCombatRatingBonus(CR_HASTE_RANGED or 19) or 0 end)
define("GetHaste", function() return GetCombatRatingBonus(CR_HASTE_MELEE or 18) or 0 end)
define("GetHitModifier", function() return 0 end)
define("GetSpellHitModifier", function() return 0 end)
define("IsDualWielding", function() return OffhandHasWeapon() and true or false end)

--average item level (4.x): the equipped items' own levels, both hands for a two-hander (as the 4.x client counts it)
define("GetAverageItemLevel", function()
	local total, count = 0, 0
	for slot = 1, 18 do
		if (slot ~= 4) then -- the shirt does not count
			local link = GetInventoryItemLink("player", slot)
			local level, equipLoc
			if (link) then
				local _, _, _, itemLevel, _, _, _, _, itemEquipLoc = GetItemInfo(link)
				level, equipLoc = itemLevel, itemEquipLoc
			end
			if (level) then
				total, count = total + level, count + 1
				if (slot == 16 and equipLoc == "INVTYPE_2HWEAPON" and not GetInventoryItemLink("player", 17)) then
					total, count = total + level, count + 1
				end
			elseif (slot ~= 17 and slot ~= 18) then
				count = count + 1 -- an empty slot counts as zero
			end
		end
	end
	local average = count > 0 and total / count or 0
	return average, average, average
end)

--world PvP areas (4.x): Wintergrasp, the only one of 3.3.5
define("GetNumWorldPVPAreas", function() return 1 end)
define("GetWorldPVPAreaInfo", function(index)
	if (index ~= 1) then return end
	local name = (PVPBATTLEGROUND_WINTERGRASPTIMER or "Wintergrasp|n"):match("^(.-)|n") or "Wintergrasp"
	local waitTime = GetWintergraspWaitTime()
	return 1, name, waitTime == nil, CanQueueForWintergrasp and CanQueueForWintergrasp() or false, waitTime, UnitLevel("player") >= 75
end)

--mouse foci (11.0): the one 3.3.5 frame under the mouse
define("GetMouseFoci", function() return {GetMouseFocus()} end)

define("IsChatAFK", function() return UnitIsAFK("player") and true or false end)
define("IsChatDND", function() return UnitIsDND("player") and true or false end)

--the spell book button's slot (3.3.5 SpellBook_GetSpellID takes the button's ID)
define("SpellBook_GetSpellBookSlot", function(button) return SpellBook_GetSpellID(button:GetID()) end)

--no arena specializations (5.0), no item quality on the 3.3.5 item button (ElvUI colors the slot border itself)
define("GetArenaOpponentSpec", Compat.returnNil)
define("GetNumArenaOpponentSpecs", function() return 0 end)
define("SetItemButtonQuality", noop)

---------------------------------------------------------------------------------------------------------------
--> namespaces ElvUI calls at play time (found by the simulator's event sweep and C_ function list)

--no "new item" flags on 3.3.5
fill("C_NewItems", {IsNewItem = returnFalse, RemoveNewItem = noop, ClearAll = noop})

--currencies: the 3.3.5 list (name, isHeader, isExpanded, isUnused, isWatched, count, extraCurrencyType, icon, itemID)
fill("C_CurrencyInfo", {
	GetCurrencyListSize = GetCurrencyListSize,
	ExpandCurrencyList = ExpandCurrencyList,
	GetCoinTextureString = GetCoinTextureString,
	GetCurrencyListLink = Compat.returnNil,
	GetCurrencyInfo = function(id)
		for index = 1, GetCurrencyListSize() do
			local name, isHeader, _, _, isWatched, count, _, icon, itemID = GetCurrencyListInfo(index)
			if (not isHeader and itemID == id) then
				return {name = name, quantity = count or 0, iconFileID = icon, discovered = true, quality = 1, isShowInBackpack = isWatched}
			end
		end
	end,
})

fill("C_PvP", {GetMatchPVPStatColumns = Compat.returnNil})
fill("C_TradeSkillUI", {GetItemReagentQualityInfo = Compat.returnNil})

--profile export and sharing (12.x C_EncodingUtil): AceSerializer for the data, no compression, a pure Lua base64.
--Strings stay between clients of this backport (retail exports are CBOR, not readable here)
do
	local CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local byte, char, sub, concat, floor = string.byte, string.char, string.sub, table.concat, math.floor
	local DECODE = {}
	for i = 1, 64 do DECODE[byte(CHARS, i)] = i - 1 end

	local function EncodeBase64(data)
		local out, length = {}, #data
		for i = 1, length, 3 do
			local a, b, c = byte(data, i, i + 2)
			local n = a * 65536 + (b or 0) * 256 + (c or 0)
			local c1, c2, c3, c4 = floor(n / 262144) % 64, floor(n / 4096) % 64, floor(n / 64) % 64, n % 64
			out[#out + 1] = sub(CHARS, c1 + 1, c1 + 1) .. sub(CHARS, c2 + 1, c2 + 1)
				.. (b and sub(CHARS, c3 + 1, c3 + 1) or "=") .. (c and sub(CHARS, c4 + 1, c4 + 1) or "=")
		end
		return concat(out)
	end

	local function DecodeBase64(text)
		text = text:gsub("[^%w%+/=]", "")
		local out = {}
		for i = 1, #text, 4 do
			local d1, d2, d3, d4 = DECODE[byte(text, i)], DECODE[byte(text, i + 1)], DECODE[byte(text, i + 2)], DECODE[byte(text, i + 3)]
			if (not d1 or not d2) then break end
			local n = d1 * 262144 + d2 * 4096 + (d3 or 0) * 64 + (d4 or 0)
			out[#out + 1] = char(floor(n / 65536) % 256)
			if (d3) then out[#out + 1] = char(floor(n / 256) % 256) end
			if (d4) then out[#out + 1] = char(n % 256) end
		end
		return concat(out)
	end

	local function Serializer() return LibStub("AceSerializer-3.0") end

	fill("C_EncodingUtil", {
		SerializeCBOR = function(data) return Serializer():Serialize(data) end,
		DeserializeCBOR = function(text)
			local ok, data = Serializer():Deserialize(text)
			if (ok) then return data end
		end,
		CompressString = function(text) return text end,
		DecompressString = function(text) return text end,
		EncodeBase64 = EncodeBase64,
		DecodeBase64 = DecodeBase64,
	})
end

---------------------------------------------------------------------------------------------------------------
--> sounds: 3.3.5's PlaySound takes a sound name ("igMainMenuOpen"), not the 7.x sound kit numbers, and has no
--  SOUNDKIT table at login (Rebuffed's SharedXML SoundKit.lua is not loaded). ElvUI's keys get the 3.3.5 names;
--  the environment's PlaySound turns a number into its name (an unknown one plays the menu option click)

do
	rawset(env, "SOUNDKIT", setmetatable({
		GS_TITLE_OPTION_EXIT = "gsTitleOptionExit",
		IG_BACKPACK_CLOSE = "igBackPackClose",
		IG_BACKPACK_OPEN = "igBackPackOpen",
		IG_CHARACTER_INFO_TAB = "igCharacterInfoTab",
		IG_CHARACTER_INFO_OPEN = "igCharacterInfoOpen",
		IG_CHARACTER_INFO_CLOSE = "igCharacterInfoClose",
		IG_CHARACTER_NPC_SELECT = "igCharacterNPCSelect",
		IG_CREATURE_AGGRO_SELECT = "igCreatureAggroSelect",
		IG_CREATURE_NEUTRAL_SELECT = "igCreatureNeutralSelect",
		IG_MAINMENU_OPEN = "igMainMenuOpen",
		IG_MAINMENU_CLOSE = "igMainMenuClose",
		IG_MAINMENU_OPTION = "igMainMenuOption",
		IG_MAINMENU_OPTION_CHECKBOX_OFF = "igMainMenuOptionCheckBoxOff",
		IG_MAINMENU_OPTION_CHECKBOX_ON = "igMainMenuOptionCheckBoxOn",
		IG_PLAYER_INVITE_DECLINE = "igPlayerInviteDecline",
		INTERFACE_SOUND_LOST_TARGET_UNIT = "INTERFACESOUND_LOSTTARGETUNIT",
		TUTORIAL_POPUP = "TutorialPopup",
		UI_70_BOOST_THANKSFORPLAYING_SMALLER = "ReadyCheck",
		U_CHAT_SCROLL_BUTTON = "UChatScrollButton",
	}, {__index = function() return "igMainMenuOption" end}))

	local NUMBERS = {
		[798] = "gsTitleOptionOK", [799] = "gsTitleOptionExit", [839] = "igCharacterInfoOpen", [840] = "igCharacterInfoClose",
		[841] = "igCharacterInfoTab", [850] = "igMainMenuOpen", [851] = "igMainMenuClose", [852] = "igMainMenuOption",
		[853] = "igMainMenuContinue", [854] = "igMainMenuOption", [856] = "igMainMenuOptionCheckBoxOn",
		[857] = "igMainMenuOptionCheckBoxOff", [862] = "igBackPackOpen", [863] = "igBackPackClose",
		[882] = "igQuestListOpen", [888] = "LEVELUPSOUND", [1115] = "UChatScrollButton",
	}
	local PlaySound = realG.PlaySound
	rawset(env, "PlaySound", function(sound)
		if (type(sound) == "number") then
			sound = NUMBERS[sound] or "igMainMenuOption"
		end
		if (type(sound) == "string") then
			return PlaySound(sound)
		end
	end)
end

--atlas markup (6.0): the atlas' region of its file as a texture escape (coordinates scaled on a 1024 square, the
--escape only uses their ratios); an atlas Rebuffed lacks gives no markup
define("CreateAtlasMarkup", function(atlas, width, height, offsetX, offsetY)
	if (not Compat.AtlasExists(atlas)) then return "" end
	local info = realG.AtlasUtil:GetAtlasInfo(atlas)
	local size = 1024
	return ("|T%s:%d:%d:%d:%d:%d:%d:%d:%d:%d:%d|t"):format(info.filename, height or 0, width or 0, offsetX or 0, offsetY or 0,
		size, size, info.leftTexCoord * size, info.rightTexCoord * size, info.topTexCoord * size, info.bottomTexCoord * size)
end)

--3.3.5 GetTexture answers the file path, where later clients answer a file ID: ElvUI's ID comparisons also take
--the path (case and slashes aside)
function Compat.IsTexture(texture, filePath)
	return type(texture) == "string" and (texture:gsub("/", "\\"):lower()) == filePath:lower()
end

---------------------------------------------------------------------------------------------------------------
--> more later functions with a 3.3.5 answer (found in the third in-game test)

--GetNetStats: 3.3.5 has one latency, later clients a home and a world one
do
	local GetNetStats = realG.GetNetStats
	rawset(env, "GetNetStats", function()
		local bandwidthIn, bandwidthOut, latency = GetNetStats()
		return bandwidthIn, bandwidthOut, latency, latency
	end)
end

--CombatLogGetCurrentEventInfo (8.0): the arguments of the COMBAT_LOG_EVENT_UNFILTERED being dispatched, in the
--later layout (hideCaster after the event name, raid flags after each unit's flags). The compat's frame registers
--the event first, so it records each one before ElvUI's handlers run
do
	local current, count = {}, 0
	local recorder = CreateFrame("Frame")
	recorder:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	recorder:SetScript("OnEvent", function(_, _, ...)
		count = select("#", ...)
		for i = 1, count do current[i] = select(i, ...) end
		for i = count + 1, #current do current[i] = nil end
	end)
	rawset(env, "CombatLogGetCurrentEventInfo", function()
		--3.3.5: timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags, ...
		return current[1], current[2], false, current[3], current[4], current[5], 0, current[6], current[7], current[8], 0,
			unpack(current, 9, count)
	end)
end

--class power display modifier (7.x): 3.3.5 shows the raw amount
define("UnitPowerDisplayMod", function() return 1 end)
--5+ spaces down to 4 (FrameXML 6.x)
define("RemoveExtraSpaces", function(text) return text and (text:gsub("     +", "    ")) end)

--the 7.x title font ElvUI's installers use
if (not realG.GameFont_Gigantic) then
	local font = CreateFont("GameFont_Gigantic")
	font:SetFontObject(GameFontNormalHuge)
	local file, _, flags = GameFontNormalHuge:GetFont()
	font:SetFont(file, 32, flags)
	font:SetTextColor(1, 0.82, 0)
end

--raid target markers: the 4.x /tm command, under a name of ElvUI's own (the macros of its marker buttons)
do
	rawset(env, "SLASH_TARGET_MARKER4", "/elvuitm")
	SLASH_ELVUI335TM1 = "/elvuitm"
	SlashCmdList.ELVUI335TM = function(msg)
		local index = tonumber(msg)
		if (index and UnitExists("target")) then SetRaidTarget("target", index) end
	end
end

--totem orders (4.x names): 3.3.5 has TOTEM_PRIORITIES (earth, fire, water, air) for the shaman bar
if (realG.SHAMAN_TOTEM_PRIORITIES == nil) then rawset(env, "SHAMAN_TOTEM_PRIORITIES", realG.TOTEM_PRIORITIES or {2, 1, 3, 4}) end
if (realG.STANDARD_TOTEM_PRIORITIES == nil) then rawset(env, "STANDARD_TOTEM_PRIORITIES", {1, 2, 3, 4}) end

--cooldown helpers (7.x names): the 3.3.5 CooldownFrame_SetTimer
define("CooldownFrame_Set", function(cooldown, start, duration, enable, forceShowDrawEdge, modRate)
	return CooldownFrame_SetTimer(cooldown, start, duration, (enable and enable ~= 0) and 1 or 0)
end)
define("CooldownFrame_Clear", function(cooldown)
	cooldown:SetCooldown(0, 0)
	cooldown:Hide()
end)
--the key ring: always on 3.3.5
define("IsKeyRingEnabled", function() return true end)
--realm relationship (5.x connected realms): one realm
define("UnitRealmRelationship", Compat.returnNil)

--3.3.5 raises on a unit it does not know (rebuffed.dll's nameplate tokens with some functions): no threat then
do
	local UnitThreatSituation = realG.UnitThreatSituation
	rawset(env, "UnitThreatSituation", function(unit, mob)
		local ok, status = pcall(UnitThreatSituation, unit, mob)
		if (ok) then return status end
	end)
end
--free slots of the character's bags (4.x): the general purpose bags only, as the later client counts them
define("CalculateTotalNumberOfFreeBagSlots", function()
	local free = 0
	for bag = 0, NUM_BAG_SLOTS or 4 do
		local slots, bagType = GetContainerNumFreeSlots(bag)
		if (slots and (bagType == 0 or bagType == nil)) then free = free + slots end
	end
	return free
end)
