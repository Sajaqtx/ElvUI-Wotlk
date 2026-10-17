setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)
local EI = E:NewModule("Enhanced_EquipmentInfo", "AceEvent-3.0")

-- ElvUI Wotlk: the item level of the slots (character and inspect) is gone, ElvUI 16 has it natively (Blizzard >
-- Item Level); kept: the durability of each slot on the character frame, which ElvUI 16 lacks

local _G = _G
local format = string.format
local pairs = pairs

local GetInventoryItemDurability = GetInventoryItemDurability
local GetInventorySlotInfo = GetInventorySlotInfo
local InCombatLockdown = InCombatLockdown

-- the slots with a durability
local slots = {
	"HeadSlot", "ShoulderSlot", "ChestSlot", "WristSlot", "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot",
	"MainHandSlot", "SecondaryHandSlot", "RangedSlot"
}

function EI:UpdatePaperDoll()
	if not self.initialized then return end

	if InCombatLockdown() then
		self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnEvent")
		return
	end

	local db = E.db.enhanced.equipment.durability
	for _, slotName in pairs(slots) do
		local frame = _G["Character" .. slotName]
		if frame and frame.DurabilityInfo then
			frame.DurabilityInfo:SetText()

			if db.enable then
				local current, maximum = GetInventoryItemDurability(GetInventorySlotInfo(slotName))
				if current and maximum and maximum > 0 and (not db.onlydamaged or current < maximum) then
					local r, g, b = E:ColorGradient((current / maximum), 1, 0, 0, 1, 1, 0, 0, 1, 0)
					frame.DurabilityInfo:SetFormattedText("%s%.0f%%|r", E:RGBToHex(r, g, b), (current / maximum) * 100)
				end
			end
		end
	end
end

function EI:UpdateInfoText()
	local db = E.db.enhanced.equipment

	for _, slotName in pairs(slots) do
		local frame = _G["Character" .. slotName]
		if frame then
			if not frame.DurabilityInfo then
				frame.DurabilityInfo = frame:CreateFontString(nil, "OVERLAY")
			end

			frame.DurabilityInfo:ClearAllPoints()
			frame.DurabilityInfo:Point(db.durability.position, frame, db.durability.xOffset, db.durability.yOffset)
			frame.DurabilityInfo:FontTemplate(E.LSM:Fetch("font", db.font), db.fontSize, db.fontOutline)
		end
	end
end

function EI:OnEvent(event)
	if event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end

	self:UpdatePaperDoll()
end

function EI:InitialUpdatePaperDoll()
	if self.initialized then return end

	self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	self:UpdateInfoText()

	self.initialized = true
end

function EI:UpdateText()
	self:UpdatePaperDoll()
end

function EI:UpdateTextSettings()
	self:UpdateInfoText()
end

function EI:ToggleState(init)
	if E.db.enhanced.equipment.enable then
		if not self.initialized then
			if init then
				self:RegisterEvent("PLAYER_ENTERING_WORLD", "InitialUpdatePaperDoll")
			else
				self:InitialUpdatePaperDoll()
			end
		end

		self:RegisterEvent("UPDATE_INVENTORY_DURABILITY", "OnEvent")
		self:RegisterEvent("UNIT_INVENTORY_CHANGED", "OnEvent")
		self:UpdateText()
	elseif self.initialized then
		self:UnregisterAllEvents()

		for _, slotName in pairs(slots) do
			local frame = _G["Character" .. slotName]
			if frame and frame.DurabilityInfo then
				frame.DurabilityInfo:SetText()
			end
		end
	end
end

function EI:Initialize()
	if not E.db.enhanced.equipment.enable then return end

	self:ToggleState(true)
end

local function InitializeCallback()
	EI:Initialize()
end

E:RegisterModule(EI:GetName(), InitializeCallback)
