setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')

local _G = _G
local hooksecurefunc = hooksecurefunc

-- ElvUI Wotlk: the 3.3.5 map (windowed / full screen / quest list sizes, no BorderFrame), skinned as ElvUI 6.10 did
local function WorldMapFrame335()
	local WorldMapFrame = _G.WorldMapFrame
	WorldMapFrame:DisableDrawLayer('BACKGROUND')
	WorldMapFrame:DisableDrawLayer('ARTWORK')
	WorldMapFrame:DisableDrawLayer('OVERLAY')
	WorldMapFrame:CreateBackdrop('Transparent')
	WorldMapFrame.backdrop:Point('TOPRIGHT', _G.WorldMapFrameCloseButton, -3, 0)
	WorldMapFrame.backdrop:Point('BOTTOMRIGHT', _G.WorldMapTrackQuest, 0, -3)
	WorldMapFrame:SetClampRectInsets(3, 0, 2, 1)

	_G.WorldMapFrameTitle:SetDrawLayer('BORDER')

	_G.WorldMapTitleButton:Width(530)
	_G.WorldMapTitleButton:Point('TOPLEFT', _G.WorldMapFrameMiniBorderLeft, 'TOPLEFT', 4, 1)

	local detail = _G.WorldMapDetailFrame
	detail:CreateBackdrop()
	detail.backdrop:Point('TOPLEFT', -2, 2)
	detail.backdrop:Point('BOTTOMRIGHT', 2, -1)

	local questDetail = _G.WorldMapQuestDetailScrollFrame
	questDetail:Width(348)
	questDetail:Point('BOTTOMLEFT', detail, 'BOTTOMLEFT', -25, -207)
	questDetail:CreateBackdrop('Transparent')
	questDetail.backdrop:Point('TOPLEFT', 24, 2)
	questDetail.backdrop:Point('BOTTOMRIGHT', 23, -4)
	questDetail.backdrop:SetFrameLevel(questDetail:GetFrameLevel())
	questDetail:SetHitRectInsets(24, -23, 0, -2)
	_G.WorldMapQuestDetailScrollChildFrame:SetScale(1)
	_G.WorldMapQuestDetailScrollFrameTrack:Kill()

	local questReward = _G.WorldMapQuestRewardScrollFrame
	questReward:Width(340)
	questReward:Point('LEFT', questDetail, 'RIGHT', 8, 0)
	questReward:CreateBackdrop('Transparent')
	questReward.backdrop:Point('TOPLEFT', 20, 2)
	questReward.backdrop:Point('BOTTOMRIGHT', 22, -4)
	questReward.backdrop:SetFrameLevel(questReward:GetFrameLevel())
	questReward:SetHitRectInsets(20, -22, 0, -2)
	_G.WorldMapQuestRewardScrollChildFrame:SetScale(1)
	_G.WorldMapQuestRewardScrollFrameTrack:SetTexture(nil)

	local questList = _G.WorldMapQuestScrollFrame
	questList:Point('TOPLEFT', detail, 'TOPRIGHT', 6, -1)
	questList:CreateBackdrop('Transparent')
	questList.backdrop:Point('TOPLEFT', 0, 2)
	questList.backdrop:Point('BOTTOMRIGHT', 25, -1)
	questList.backdrop:SetFrameLevel(questList:GetFrameLevel())

	_G.WorldMapQuestSelectBar:SetTexture(E.Media.Textures.Highlight)
	_G.WorldMapQuestSelectBar:SetAlpha(0.35)
	_G.WorldMapQuestHighlightBar:SetTexture(E.Media.Textures.Highlight)
	_G.WorldMapQuestHighlightBar:SetAlpha(0.35)

	S:HandleScrollBar(_G.WorldMapQuestScrollFrameScrollBar)
	S:HandleScrollBar(_G.WorldMapQuestDetailScrollFrameScrollBar)
	S:HandleScrollBar(_G.WorldMapQuestRewardScrollFrameScrollBar)

	_G.WorldMapQuestScrollFrameScrollBar:Point('TOPLEFT', questList, 'TOPRIGHT', 5, -19)
	_G.WorldMapQuestScrollFrameScrollBar:Point('BOTTOMLEFT', questList, 'BOTTOMRIGHT', 5, 20)
	_G.WorldMapQuestDetailScrollFrameScrollBar:Point('TOPLEFT', questDetail, 'TOPRIGHT', 3, -19)
	_G.WorldMapQuestDetailScrollFrameScrollBar:Point('BOTTOMLEFT', questDetail, 'BOTTOMRIGHT', 3, 17)
	_G.WorldMapQuestRewardScrollFrameScrollBar:Point('TOPLEFT', questReward, 'TOPRIGHT', 2, -19)
	_G.WorldMapQuestRewardScrollFrameScrollBar:Point('BOTTOMLEFT', questReward, 'BOTTOMRIGHT', 2, 17)

	S:HandleCloseButton(_G.WorldMapFrameCloseButton)

	local sizeDown, sizeUp = _G.WorldMapFrameSizeDownButton, _G.WorldMapFrameSizeUpButton
	sizeDown:ClearAllPoints()
	sizeDown:Point('RIGHT', _G.WorldMapFrameCloseButton, 'LEFT', 4, 0)
	sizeDown.SetPoint = E.noop
	sizeDown:GetHighlightTexture():Kill()
	S:HandleNextPrevButton(sizeDown, 'down', nil, true)
	sizeDown:Size(26)
	sizeUp:GetHighlightTexture():Kill()
	S:HandleNextPrevButton(sizeUp, 'up', nil, true)
	sizeUp:Size(26)

	S:HandleDropDownBox(_G.WorldMapLevelDropDown)
	S:HandleDropDownBox(_G.WorldMapZoneMinimapDropDown)
	S:HandleDropDownBox(_G.WorldMapContinentDropDown)
	S:HandleDropDownBox(_G.WorldMapZoneDropDown)

	_G.WorldMapLevelUpButton:Point('TOPLEFT', _G.WorldMapLevelDropDown, 'TOPRIGHT', -6, 4)
	_G.WorldMapLevelDownButton:Point('BOTTOMLEFT', _G.WorldMapLevelDropDown, 'BOTTOMRIGHT', -6, 0)

	S:HandleButton(_G.WorldMapZoomOutButton)
	_G.WorldMapZoomOutButton:Point('LEFT', _G.WorldMapZoneDropDown, 'RIGHT', 0, 3)

	S:HandleCheckBox(_G.WorldMapTrackQuest)
	S:HandleCheckBox(_G.WorldMapQuestShowObjectives)

	_G.WorldMapFrameAreaLabel:FontTemplate(nil, 50, 'OUTLINE')
	_G.WorldMapFrameAreaLabel:SetShadowOffset(2, -2)
	_G.WorldMapFrameAreaLabel:SetTextColor(0.90, 0.8294, 0.6407)
	_G.WorldMapFrameAreaDescription:FontTemplate(nil, 40, 'OUTLINE')
	_G.WorldMapFrameAreaDescription:SetShadowOffset(2, -2)
	_G.WorldMapZoneInfo:FontTemplate(nil, 27, 'OUTLINE')
	_G.WorldMapZoneInfo:SetShadowOffset(2, -2)

	-- Blizzard moves the floor dropdown on each size change: placed per size below
	local levelDropDown = _G.WorldMapLevelDropDown
	local setPoint = levelDropDown.SetPoint
	levelDropDown.SetPoint = E.noop

	local currentMapMode
	local function SmallSkin()
		if _G.WORLDMAP_SETTINGS.advanced then
			if currentMapMode == 0 then return end
			currentMapMode = 0

			WorldMapFrame.backdrop:Point('TOPLEFT', 3, 2)
			WorldMapFrame.backdrop:Point('TOPRIGHT', _G.WorldMapFrameCloseButton, -3, 0)
			detail.backdrop:Point('TOPLEFT', -2, 2)
			detail.backdrop:Point('BOTTOMRIGHT', 1, -1)
			setPoint(levelDropDown, 'TOPRIGHT', _G.WorldMapPositioningGuide, 'TOPRIGHT', -419, -24)
		else
			if currentMapMode == 1 then return end
			currentMapMode = 1

			WorldMapFrame.backdrop:Point('TOPLEFT', 11, -12)
			WorldMapFrame.backdrop:Point('TOPRIGHT', _G.WorldMapFrameCloseButton, -1, 0)
			detail.backdrop:Point('TOPLEFT', -2, 2)
			detail.backdrop:Point('BOTTOMRIGHT', 2, -1)
			setPoint(levelDropDown, 'TOPRIGHT', _G.WorldMapPositioningGuide, 'TOPRIGHT', -439, -38)
		end
	end

	local function LargeSkin(mode, x)
		if currentMapMode == mode then return end
		currentMapMode = mode

		WorldMapFrame.backdrop:Point('TOPLEFT', detail, 'TOPLEFT', x, 70)
		WorldMapFrame.backdrop:Point('TOPRIGHT', _G.WorldMapFrameCloseButton, -3, 0)
		detail.backdrop:Point('TOPLEFT', -1, 1)
		detail.backdrop:Point('BOTTOMRIGHT', 1, -1)
		setPoint(levelDropDown, 'TOPRIGHT', _G.WorldMapPositioningGuide, 'TOPRIGHT', -50, -35)
	end
	local function FullSkin() LargeSkin(2, -8) end
	local function QuestSkin() LargeSkin(3, -9) end

	local function FixSkin()
		local size = _G.WORLDMAP_SETTINGS.size
		if size == _G.WORLDMAP_FULLMAP_SIZE then
			FullSkin()
		elseif size == _G.WORLDMAP_WINDOWED_SIZE then
			SmallSkin()
		elseif size == _G.WORLDMAP_QUESTLIST_SIZE then
			QuestSkin()
		end
	end

	_G.WorldMapTitleButton:Hide()
	WorldMapFrame.backdrop:EnableMouse(true)

	FixSkin()
	hooksecurefunc('WorldMapFrame_SetQuestMapView', QuestSkin)
	hooksecurefunc('WorldMapFrame_SetFullMapView', FullSkin)
	hooksecurefunc('WorldMapFrame_SetMiniMode', SmallSkin)
	hooksecurefunc('ToggleMapFramerate', FixSkin)
	hooksecurefunc('WorldMapFrame_ToggleAdvanced', FixSkin)
end

function S:WorldMapFrame()
	if ElvUI335 then
		if E.private.skins.blizzard.enable and E.private.skins.blizzard.worldmap then WorldMapFrame335() end
		return
	end

	if not (E.private.skins.blizzard.enable and E.private.skins.blizzard.worldmap) then return end

	local WorldMapFrame = _G.WorldMapFrame
	WorldMapFrame:StripTextures()

	WorldMapFrame.BorderFrame:StripTextures()
	WorldMapFrame.BorderFrame:CreateBackdrop('Transparent')
	WorldMapFrame.BorderFrame.backdrop:Point('TOPLEFT', 0, -0.5)

	WorldMapFrame.MiniBorderFrame:StripTextures()
	WorldMapFrame.MiniBorderFrame:CreateBackdrop('Transparent')
	WorldMapFrame.MiniBorderFrame.backdrop:Point('TOPLEFT', 6, -2)

	S:HandleDropDownBox(_G.WorldMapZoneMinimapDropdown, 160)
	S:HandleDropDownBox(_G.WorldMapContinentDropdown, 160)
	S:HandleDropDownBox(_G.WorldMapZoneDropdown, 160)
	S:HandleMaxMinFrame(_G.WorldMapFrame.MaximizeMinimizeFrame)

	_G.WorldMapContinentDropdown:Point('TOPLEFT', WorldMapFrame, 'TOPLEFT', 330, -35)
	_G.WorldMapContinentDropdown:Height(26)

	_G.WorldMapZoneDropdown:Point('LEFT', _G.WorldMapContinentDropdown, 'RIGHT', 10, 0)
	_G.WorldMapZoneDropdown:Height(26)

	_G.WorldMapZoneMinimapDropdown:Point('RIGHT', _G.WorldMapContinentDropdown, 'LEFT', -10, 0)
	_G.WorldMapZoneMinimapDropdown:Height(26)

	_G.WorldMapZoomOutButton:Point('LEFT', _G.WorldMapZoneDropdown, 'RIGHT', 10, 1)
	_G.WorldMapZoomOutButton:Height(23)
	_G.WorldMapZoomOutButton:Width(100)
	_G.WorldMapZoomOutButton:OffsetFrameLevel(2, _G.WorldMapFrame.BlackoutFrame)

	S:HandleButton(_G.WorldMapZoomOutButton)
	S:HandleSliderFrame(_G.OpacityFrameSlider)
	S:HandleCheckBox(_G.WorldMapQuestShowObjectives)

	if E.OtherAddons.Questie and _G.Questie_Toggle then
		S:HandleButton(_G.Questie_Toggle)
	end

	S:HandleCloseButton(_G.WorldMapFrameCloseButton, WorldMapFrame.backdrop)
	_G.WorldMapFrameCloseButton:OffsetFrameLevel(2)
end

S:AddCallback('WorldMapFrame')
