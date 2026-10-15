setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')

local _G = _G
local select, unpack = select, unpack

function S:SkinTutorial()
	if not (E.private.skins.blizzard.enable and E.private.skins.blizzard.tutorials) then return end

	-- ElvUI Wotlk: the 3.3.5 TutorialFrame (one alert button, prev/next pages), skinned as ElvUI 6.10 did
	if ElvUI335 then
		local alert = _G.TutorialFrameAlertButton
		alert:StripTextures()
		alert:CreateBackdrop(nil, true)
		alert:Size(50)

		local icon = alert:GetNormalTexture()
		icon:SetTexture([[Interface\Icons\INV_Letter_18]])
		icon:Point('TOPLEFT', 5, -5)
		icon:Point('BOTTOMRIGHT', -5, 5)
		icon:SetTexCoord(unpack(E.TexCoords))

		local frame = _G.TutorialFrame
		_G.TutorialFrameBackground:Hide()
		frame:DisableDrawLayer('BORDER')
		frame:CreateBackdrop('Transparent')
		frame.backdrop:Point('TOPLEFT', 11, -12)
		frame.backdrop:Point('BOTTOMRIGHT', -1, 2)

		_G.TutorialFrameTitle:Point('TOP', 0, -19)

		S:HandleCloseButton((select(4, frame:GetChildren())), frame.backdrop)

		local nextButton, prevButton = _G.TutorialFrameNextButton, _G.TutorialFramePrevButton
		S:HandleNextPrevButton(nextButton)
		nextButton:Point('BOTTOMRIGHT', -132, 7)
		nextButton:Size(22)
		nextButton:GetRegions():Point('RIGHT', nextButton, 'LEFT', -5, 0)

		S:HandleNextPrevButton(prevButton)
		prevButton:Point('BOTTOMLEFT', 30, 7)
		prevButton:Size(22)
		prevButton:GetRegions():Point('LEFT', prevButton, 'RIGHT', 3, 0)

		S:HandleButton(_G.TutorialFrameOkayButton)

		_G.TutorialFrameCallOut:Kill()
		return
	end

	S:HandleFrame(_G.TutorialFrame, false)

	for i = 1, _G.MAX_TUTORIAL_ALERTS do
		local button = _G['TutorialFrameAlertButton'..i]
		local icon = button:GetNormalTexture()

		button:Size(35, 45)
		button:SetTemplate(nil, true)
		button:StyleButton(nil, true)

		icon:SetInside()
		icon:SetTexCoord(0.09, 0.40, 0.11, 0.56)
	end

	S:HandleCheckBox(_G.TutorialFrameCheckButton)

	S:HandleButton(_G.TutorialFrameOkayButton)
end

S:AddCallback('SkinTutorial')
