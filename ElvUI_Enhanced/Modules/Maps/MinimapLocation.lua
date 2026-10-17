setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)
local ML = E:NewModule("Enhanced_MinimapLocation", "AceHook-3.0", "AceEvent-3.0")
local M = E:GetModule("Minimap")

-- ElvUI Wotlk: on ElvUI 16 the panel (zone text, with the coordinates on each side) is shown above the minimap as soon as
-- its option is on: 6.10 showed it for an "Above Minimap" choice of ElvUI's Location Text, and moved ElvUI's minimap
-- holder down to make room for it, which ElvUI 16 sizes again on each of its updates (the panel never showed). The
-- panel follows the minimap (its frame, scale and visibility), the holder is left alone.

local utf8sub = string.utf8sub

local GetMinimapZoneText = GetMinimapZoneText
local GetPlayerMapPosition = GetPlayerMapPosition
local InCombatLockdown = InCombatLockdown
local UIFrameFade = UIFrameFade

local cluster, panel, location, xMap, yMap

local digits = {
	[0] = {.5, "%.0f"},
	[1] = {.2, "%.1f"},
	[2] = {.03, "%.2f"}
}

local function UpdateLocation(_, elapsed)
	location.elapsed = (location.elapsed or 0) + elapsed
	local d = digits[E.db.enhanced.minimap.locationdigits] or digits[1]
	if location.elapsed < d[1] then return end

	local x, y = GetPlayerMapPosition("player")
	xMap.text:SetFormattedText(d[2], (x or 0) * 100)
	yMap.text:SetFormattedText(d[2], (y or 0) * 100)

	location.elapsed = 0
end

local function CreatePanel()
	cluster = MinimapCluster

	panel = CreateFrame("Frame", "EnhancedLocationPanel", Minimap)
	panel:SetFrameStrata(Minimap:GetFrameStrata())
	panel:SetFrameLevel(Minimap:GetFrameLevel() + 5)
	panel:Size(206, 22)

	xMap = CreateFrame("Frame", "MapCoordinatesX", panel)
	xMap:SetTemplate("Transparent")
	xMap:Point("LEFT", panel, "LEFT", 0, 0)
	xMap:Size(40, 22)

	xMap.text = xMap:CreateFontString(nil, "OVERLAY")
	xMap.text:FontTemplate()
	xMap.text:SetAllPoints(xMap)

	yMap = CreateFrame("Frame", "MapCoordinatesY", panel)
	yMap:SetTemplate("Transparent")
	yMap:Point("RIGHT", panel, "RIGHT", 0, 0)
	yMap:Size(40, 22)

	yMap.text = yMap:CreateFontString(nil, "OVERLAY")
	yMap.text:FontTemplate()
	yMap.text:SetAllPoints(yMap)

	location = CreateFrame("Frame", "EnhancedLocationText", panel)
	location:SetTemplate("Transparent")
	location:Size(40, 22)

	location.text = location:CreateFontString(nil, "OVERLAY")
	location.text:FontTemplate()
	location.text:SetAllPoints(location)
end

local function FadeFrame(frame, direction, startAlpha, endAlpha, time, func)
	UIFrameFade(frame, {
		mode = direction,
		finishedFunc = func,
		startAlpha = startAlpha,
		endAlpha = endAlpha,
		timeToFade = time
	})
end

local function FadeInMinimap()
	if not InCombatLockdown() then
		FadeFrame(cluster, "IN", 0, 1, .5, function()
			if not InCombatLockdown() then
				cluster:Show()
			end
		end)
	end
end

function ML:PLAYER_REGEN_ENABLED()
	if E.db.enhanced.minimap.fadeindelay == 0 then
		FadeInMinimap()
	else
		E:Delay(E.db.enhanced.minimap.fadeindelay, FadeInMinimap)
	end
end

function ML:PLAYER_REGEN_DISABLED()
	cluster:Hide()
end

function ML:UpdateZoneText()
	if not (panel and panel:IsShown()) then return end

	local db = E.db.general.minimap
	local font = E.LSM:Fetch("font", db.locationFont)
	location.text:FontTemplate(font, db.locationFontSize, db.locationFontOutline)
	xMap.text:FontTemplate(font, db.locationFontSize, db.locationFontOutline)
	yMap.text:FontTemplate(font, db.locationFontSize, db.locationFontOutline)

	location.text:SetTextColor(M:GetLocTextColor())
	location.text:SetText(utf8sub(GetMinimapZoneText() or "", 1, 25))
end

function ML:UpdateLayout()
	if not panel then return end

	-- over the minimap's border: as wide as it, right above it
	local border = Minimap.backdrop or Minimap
	local spacing = E.PixelMode and 1 or 3
	panel:ClearAllPoints()
	panel:Point("BOTTOMLEFT", border, "TOPLEFT", 0, spacing - (E.PixelMode and 2 or 0))
	panel:Point("BOTTOMRIGHT", border, "TOPRIGHT", 0, spacing - (E.PixelMode and 2 or 0))
	panel:Height(22)

	location:ClearAllPoints()
	if E.db.enhanced.minimap.showlocationdigits then
		location:Point("LEFT", xMap, "RIGHT", E.PixelMode and -1 or 1, 0)
		location:Point("RIGHT", yMap, "LEFT", E.PixelMode and 1 or -1, 0)
		location:Height(22)
		xMap:Show()
		yMap:Show()
		panel:SetScript("OnUpdate", UpdateLocation)
	else
		location:SetAllPoints(panel)
		xMap:Hide()
		yMap:Hide()
		panel:SetScript("OnUpdate", nil)
	end
end

function ML:UpdateSettings()
	if not E.private.general.minimap.enable then return end

	local db = E.db.enhanced.minimap
	if db.location then
		if not panel then CreatePanel() end

		panel:Show()
		self:UpdateLayout()

		if not self:IsHooked(M, "UpdateSettings") then
			self:SecureHook(M, "UpdateSettings", "UpdateLayout")
		end

		self:RegisterEvent("ZONE_CHANGED", "UpdateZoneText")
		self:RegisterEvent("ZONE_CHANGED_INDOORS", "UpdateZoneText")
		self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "UpdateZoneText")
		self:RegisterEvent("PLAYER_ENTERING_WORLD", "UpdateZoneText")
		self:UpdateZoneText()
	elseif panel then
		panel:Hide()
		panel:SetScript("OnUpdate", nil)
		self:UnhookAll()
		self:UnregisterEvent("ZONE_CHANGED")
		self:UnregisterEvent("ZONE_CHANGED_INDOORS")
		self:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end

	cluster = MinimapCluster
	if db.hideincombat then
		self:RegisterEvent("PLAYER_REGEN_DISABLED")
		self:RegisterEvent("PLAYER_REGEN_ENABLED")
	else
		self:UnregisterEvent("PLAYER_REGEN_DISABLED")
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
end

function ML:Initialize()
	if not E.private.general.minimap.enable then return end

	self:UpdateSettings()
end

local function InitializeCallback()
	ML:Initialize()
end

E:RegisterModule(ML:GetName(), InitializeCallback)
