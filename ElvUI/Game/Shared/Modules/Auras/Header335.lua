setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)
local A = E:GetModule('Auras')

--[[
	ElvUI Wotlk: the player buff and debuff headers on 3.3.5, which has no SecureAuraHeaderTemplate (4.0).
	What the later secure header does (FrameXML/SecureGroupHeaders.lua: read the attributes ElvUI sets in
	A:UpdateHeader, list, sort and place the auras, weapon enchants first), on an insecure frame of ElvUI's own:
	its buttons are not protected, so they can move and change in combat, and a right click cancels a buff with
	CancelUnitBuff out of combat, as the 3.3.5 ElvUI did.
]]

local _G = _G
local huge, floor, max = math.huge, math.floor, math.max
local next, sort, wipe, tonumber = next, sort, wipe, tonumber

local CreateFrame = CreateFrame
local UnitAura = UnitAura
local UnitHasVehicleUI = UnitHasVehicleUI
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local GetInventoryItemTexture = GetInventoryItemTexture
local InCombatLockdown = InCombatLockdown
local CancelUnitBuff = CancelUnitBuff
local CancelItemTempEnchantment = CancelItemTempEnchantment

local MAX_AURAS = 40
local MAIN_HAND_SLOT, OFF_HAND_SLOT = 16, 17

-- attributes that change the layout (the header's own child keys do not)
local LAYOUT_ATTRIBUTES = {
	unit = true, filter = true, includeWeapons = true, separateOwn = true, sortMethod = true, sortDirection = true,
	maxWraps = true, wrapAfter = true, point = true, xOffset = true, yOffset = true, wrapXOffset = true,
	wrapYOffset = true, minWidth = true, minHeight = true, ['config-width'] = true, ['config-height'] = true,
	template = true, weaponTemplate = true,
}

local auraList, auraPool = {}, {}

local function IsOwn(caster)
	return caster == 'player' or caster == 'pet' or caster == 'vehicle'
end

local function SortAuras(header)
	local method = header:GetAttribute('sortMethod') or 'INDEX'
	local reverse = header:GetAttribute('sortDirection') == '-'
	local separateOwn = tonumber(header:GetAttribute('separateOwn')) or 0

	sort(auraList, function(a, b)
		if separateOwn ~= 0 and a.own ~= b.own then
			if separateOwn > 0 then return a.own else return b.own end
		end

		local x, y
		if method == 'NAME' then
			x, y = a.name, b.name
		elseif method == 'TIME' then
			x, y = a.expires, b.expires
		else
			x, y = a.index, b.index
		end

		if x == y then
			return a.index < b.index
		elseif reverse then
			return x > y
		else
			return x < y
		end
	end)
end

local function GetChild(header, key, index, template)
	local child = header:GetAttribute(key..index)
	if not child then
		local suffix = (key == 'tempEnchant' and 'TempEnchant') or 'AuraButton'
		child = CreateFrame('Button', header:GetName()..suffix..index, header, template)
		child:SetWidth(header:GetAttribute('config-width') or 30)
		child:SetHeight(header:GetAttribute('config-height') or 30)
		header:SetAttribute(key..index, child)
	end

	return child
end

local function PlaceChild(header, child, slot)
	local point = header:GetAttribute('point') or 'TOPRIGHT'
	local wrapAfter = header:GetAttribute('wrapAfter') or 1
	local column, row = (slot - 1) % wrapAfter, floor((slot - 1) / wrapAfter)

	local x = column * (header:GetAttribute('xOffset') or 0) + row * (header:GetAttribute('wrapXOffset') or 0)
	local y = column * (header:GetAttribute('yOffset') or 0) + row * (header:GetAttribute('wrapYOffset') or 0)

	child:ClearAllPoints()
	child:SetPoint(point, header, point, x, y)
end

local function HideChildren(header, key, from)
	local index = from
	local child = header:GetAttribute(key..index)
	while child do
		child:Hide()
		index = index + 1
		child = header:GetAttribute(key..index)
	end
end

function A:Header335_Update(header)
	local unit = header:GetAttribute('unit') or 'player'
	local filter = header:GetAttribute('filter') or 'HELPFUL'
	local maxCount = (header:GetAttribute('wrapAfter') or 1) * (header:GetAttribute('maxWraps') or 1)
	local slot = 0

	-- weapon enchants first, as the later header does with includeWeapons
	local enchants, usedHands = 0, {}
	if header:GetAttribute('includeWeapons') and filter == 'HELPFUL' and unit == 'player' then
		local hasMain, _, _, _, hasOff = GetWeaponEnchantInfo()
		local template = header:GetAttribute('weaponTemplate')

		-- one button per hand: ElvUI reads the hand from the button name (TempEnchant1 main hand, TempEnchant2 off hand)
		for hand = 1, 2 do
			local slotID = (hand == 1 and hasMain and MAIN_HAND_SLOT) or (hand == 2 and hasOff and OFF_HAND_SLOT)
			if slotID and slot < maxCount then
				enchants, slot = enchants + 1, slot + 1
				usedHands[hand] = true

				local child = GetChild(header, 'tempEnchant', hand, template)
				child:SetID(slotID)
				PlaceChild(header, child, slot)
				child:SetAttribute('target-slot', slotID)
				child:Show()

				-- the weapon's icon now: ElvUI sets it with the time left, which 3.3.5 may not have yet (just applied, login)
				if child.texture then
					child.texture:SetTexture(GetInventoryItemTexture('player', slotID))
				end

				-- A.Visibility_OnUpdate reads the expiration of header.enchants[n] at hand n (1 main, 2 off hand)
				if child.enchantIndex ~= hand then
					header.enchants[child.enchantIndex] = nil
				end
				header.enchants[hand] = child
				header.elapsedEnchants = 0
			end
		end
	end

	for hand = 1, 2 do
		local child = not usedHands[hand] and header:GetAttribute('tempEnchant'..hand)
		if child then child:Hide() end
	end

	wipe(auraList)
	for index = 1, MAX_AURAS do
		local name, _, _, _, _, _, expires, caster = UnitAura(unit, index, filter)
		if not name then break end

		local entry = auraPool[index]
		if not entry then
			entry = {}
			auraPool[index] = entry
		end

		entry.index, entry.name, entry.own = index, name, IsOwn(caster)
		entry.expires = (expires and expires > 0 and expires) or huge -- no duration: last of the shortest first

		auraList[#auraList + 1] = entry
	end

	SortAuras(header)

	local template = header:GetAttribute('template')
	local shown = 0
	for _, entry in next, auraList do
		if slot >= maxCount then break end
		shown, slot = shown + 1, slot + 1

		local child = GetChild(header, 'child', shown, template)
		child:SetID(entry.index)
		PlaceChild(header, child, slot)
		child:SetAttribute('index', entry.index)
		child:Show()

		A:UpdateAura(child, entry.index)
	end

	HideChildren(header, 'child', shown + 1)

	-- what the player buff header shows, for the in game tests (ElvDB.debug335_auras, read from the SavedVariables)
	if unit == 'player' and filter == 'HELPFUL' and ElvDB then
		local record = {}
		local hasMain, mainExpiration, _, _, hasOff, offExpiration = GetWeaponEnchantInfo()
		record.weapons = format('main %s %s, off %s %s', tostring(hasMain), tostring(mainExpiration), tostring(hasOff), tostring(offExpiration))
		for _, key in next, { 'tempEnchant', 'child' } do
			for i = 1, (key == 'tempEnchant' and 2 or shown) do
				local child = header:GetAttribute(key..i)
				if child and child:IsShown() then
					local texture = child.texture and child.texture:GetTexture()
					local name = key == 'child' and UnitAura(unit, child:GetID(), filter) or nil
					record[#record + 1] = format('%s%d id %s enchantIndex %s texture %s name %s', key, i, tostring(child:GetID()),
						tostring(child.enchantIndex), tostring(texture), tostring(name))
				end
			end
		end
		ElvDB.debug335_auras = record
	end

	header:SetWidth(max(header:GetAttribute('minWidth') or 1, 1))
	header:SetHeight(max(header:GetAttribute('minHeight') or 1, 1))
end

function A:Header335_OnEvent(event, unit)
	if event == 'UNIT_ENTERED_VEHICLE' or event == 'UNIT_EXITED_VEHICLE' then
		if unit == 'player' then
			self:SetAttribute('unit', UnitHasVehicleUI('player') and 'vehicle' or 'player')
		end
	elseif event == 'UNIT_AURA' then
		if unit == self:GetAttribute('unit') then
			self.needsUpdate = true
		end
	else -- PLAYER_ENTERING_WORLD, UNIT_INVENTORY_CHANGED (weapon enchants)
		self.needsUpdate = true
	end
end

function A:Header335_OnUpdate(elapsed)
	-- weapon enchants have no event when they run out: a light poll of their presence
	self.elapsedWeapons = (self.elapsedWeapons or 0) + elapsed
	if self.elapsedWeapons > 1 then
		self.elapsedWeapons = 0

		if self:GetAttribute('includeWeapons') then
			-- the shown enchant buttons, refreshed by A.Visibility_OnUpdate (their time left may come after they show)
			for hand = 1, 2 do
				local child = self:GetAttribute('tempEnchant'..hand)
				if child and child:IsShown() and self.enchants[hand] ~= child then
					self.enchants[hand] = child
				end
			end

			local hasMain, _, _, _, hasOff = GetWeaponEnchantInfo()
			local weapons = (hasMain and 1 or 0) + (hasOff and 2 or 0)
			if weapons ~= self.lastWeapons then
				self.lastWeapons = weapons
				self.needsUpdate = true
			end
		end
	end

	if self.needsUpdate then
		self.needsUpdate = nil
		A:Header335_Update(self)
	end
end

function A:Header335_OnAttributeChanged(name)
	if LAYOUT_ATTRIBUTES[name] then
		self.needsUpdate = true
	end
end

function A:Header335_OnShow()
	A:Header335_Update(self)
end

-- right click: cancel a buff or a weapon enchant, out of combat
function A:Button335_OnClick(mouseButton)
	if mouseButton ~= 'RightButton' or InCombatLockdown() then return end

	local slotID = self:GetAttribute('target-slot')
	if self.enchantIndex then
		if slotID then
			CancelItemTempEnchantment(slotID - 15)
		end
	elseif self.filter == 'HELPFUL' then
		CancelUnitBuff(self.header:GetAttribute('unit'), self:GetID(), self.filter)
	end
end

local CreateIcon = A.CreateIcon
function A:CreateIcon(button)
	CreateIcon(self, button)

	button:RegisterForClicks('RightButtonUp')
	button:SetScript('OnClick', A.Button335_OnClick)
end

function A:CreateAuraHeader(filter)
	local name, auraType = filter == 'HELPFUL' and 'ElvUIPlayerBuffs' or 'ElvUIPlayerDebuffs', filter == 'HELPFUL' and 'buffs' or 'debuffs'

	local header = CreateFrame('Frame', name, E.UIParent)
	header:SetClampedToScreen(true)
	header.ForEachChild = A.ForEachChild

	header.enchantButtons = {}
	header.enchants = {}
	header.spells = {}
	header.auraType = auraType
	header.filter = filter
	header.name = name

	header:SetAttribute('unit', 'player')
	header:SetAttribute('filter', filter)

	if filter == 'HELPFUL' then
		header:SetAttribute('consolidateDuration', -1)
		header:SetAttribute('includeWeapons', 1)

		local MasqueGroup = E.Masque and E.private.auras.masque.buffs and E.Masque:Group('ElvUI', 'Buffs')
		if MasqueGroup then header.MasqueGroup = MasqueGroup end
	else
		local MasqueGroup = E.Masque and E.private.auras.masque.debuffs and E.Masque:Group('ElvUI', 'Debuffs')
		if MasqueGroup then header.MasqueGroup = MasqueGroup end
	end

	-- the timers of the queued spells and enchants (A.Visibility_OnUpdate), no pet battle state on 3.3.5
	header.visibility = CreateFrame('Frame', nil, _G.UIParent)
	header.visibility:SetScript('OnUpdate', A.Visibility_OnUpdate)
	header.visibility.frame = header

	header:SetScript('OnEvent', A.Header335_OnEvent)
	header:SetScript('OnUpdate', A.Header335_OnUpdate)
	header:SetScript('OnAttributeChanged', A.Header335_OnAttributeChanged)
	header:SetScript('OnShow', A.Header335_OnShow)
	header:HookScript('OnEvent', A.Header_OnEvent)

	header:RegisterEvent('UNIT_AURA')
	header:RegisterEvent('PLAYER_ENTERING_WORLD')
	header:RegisterEvent('UNIT_ENTERED_VEHICLE')
	header:RegisterEvent('UNIT_EXITED_VEHICLE')
	header:RegisterEvent('UNIT_INVENTORY_CHANGED')

	header:Show()

	return header
end
