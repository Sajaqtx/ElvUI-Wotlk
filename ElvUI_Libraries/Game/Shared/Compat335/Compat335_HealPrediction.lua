setfenv(1, ElvUI335_ENV)
--[[
	ElvUI Wotlk: heal prediction as on the MoP client (loaded after LibHealComm-4.0 and SpecializedAbsorbs-1.0).
	The values come through UnitGetIncomingHeals / UnitGetTotalAbsorbs (Compat335_API.lua); this file makes the absorbs
	follow every unit (the MoP client knows them all) and raises the events the 3.3.5 client never sends:
	UNIT_ABSORB_AMOUNT_CHANGED / UNIT_HEAL_ABSORB_AMOUNT_CHANGED from SpecializedAbsorbs, UNIT_HEAL_PREDICTION from
	LibHealComm (the heal prediction bars, the absorbs and incoming heals tags).
]]

local select = select
local FireUnitEventByGUID = ElvUI335.FireUnitEventByGUID

local SA = LibStub:GetLibrary("SpecializedAbsorbs-1.0", true)
if SA then
	SA.CheckFlags = false -- every unit, not only the group's

	SA.RegisterUnitCallbacks({}, function(_, guid)
		if not guid then return end
		FireUnitEventByGUID("UNIT_ABSORB_AMOUNT_CHANGED", guid)
		FireUnitEventByGUID("UNIT_HEAL_ABSORB_AMOUNT_CHANGED", guid)
	end)
end

local HealComm = LibStub:GetLibrary("LibHealComm-4.0", true)
if HealComm then
	local relay = {}

	-- HealStarted / Updated / Delayed / Stopped: caster, spell, heal type, end time (or interrupted), then the targets
	local function Targets(_, _, _, _, _, ...)
		for i = 1, select('#', ...) do
			local guid = select(i, ...)
			if guid then FireUnitEventByGUID("UNIT_HEAL_PREDICTION", guid) end
		end
	end
	local function Target(_, guid)
		if guid then FireUnitEventByGUID("UNIT_HEAL_PREDICTION", guid) end
	end

	HealComm.RegisterCallback(relay, "HealComm_HealStarted", Targets)
	HealComm.RegisterCallback(relay, "HealComm_HealUpdated", Targets)
	HealComm.RegisterCallback(relay, "HealComm_HealDelayed", Targets)
	HealComm.RegisterCallback(relay, "HealComm_HealStopped", Targets)
	HealComm.RegisterCallback(relay, "HealComm_ModifierChanged", Target)
	HealComm.RegisterCallback(relay, "HealComm_GUIDDisappeared", Target)
end
