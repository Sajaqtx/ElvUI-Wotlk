setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule('Skins')

local _G = _G
local next = next
local hooksecurefunc = hooksecurefunc

-- ElvUI Wotlk: the 3.3.5 key binding frame (named buttons, no category list), skinned as ElvUI 6.10 did
local function BindingUI335()
	local KB = _G.KeyBindingFrame
	KB:StripTextures()
	KB:SetTemplate('Transparent')
	KB:Size(596, 490)

	for i = 1, _G.KEY_BINDINGS_DISPLAYED do
		local key1, key2 = _G['KeyBindingFrameBinding'..i..'Key1Button'], _G['KeyBindingFrameBinding'..i..'Key2Button']
		S:HandleButton(key1)
		S:HandleButton(key2)
		key2:Point('LEFT', key1, 'RIGHT', 1, 0)
	end

	local scrollBar = _G.KeyBindingFrameScrollFrameScrollBar
	S:HandleScrollBar(scrollBar)
	scrollBar:Point('TOPLEFT', _G.KeyBindingFrameScrollFrame, 'TOPRIGHT', 8, -21)
	scrollBar:Point('BOTTOMLEFT', _G.KeyBindingFrameScrollFrame, 'BOTTOMRIGHT', 8, 17)

	local character = _G.KeyBindingFrameCharacterButton
	S:HandleCheckBox(character)
	character:Point('TOPLEFT', KB, 'TOPRIGHT', -204, -12)

	local default, cancel, okay, unbind = _G.KeyBindingFrameDefaultButton, _G.KeyBindingFrameCancelButton, _G.KeyBindingFrameOkayButton, _G.KeyBindingFrameUnbindButton
	S:HandleButton(default)
	S:HandleButton(cancel)
	S:HandleButton(okay)
	S:HandleButton(unbind)
	default:Point('BOTTOMLEFT', 8, 8)
	cancel:Point('BOTTOMRIGHT', -8, 8)
	okay:Point('RIGHT', cancel, 'LEFT', -3, 0)
	unbind:Point('RIGHT', okay, 'LEFT', -3, 0)
end

function S:Blizzard_BindingUI()
	if not (E.private.skins.blizzard.enable and E.private.skins.blizzard.binding) then return end
	if ElvUI335 then BindingUI335() return end

	local KB = _G.KeyBindingFrame
	for _, v in next, { 'defaultsButton', 'unbindButton', 'okayButton', 'cancelButton' } do
		S:HandleButton(KB[v])
	end

	S:HandleFrame(KB, true)
	S:HandleFrame(KB.categoryList, true)
	S:HandleFrame(KB.bindingsContainer, true)

	KB.header:StripTextures()
	KB.header:ClearAllPoints()
	KB.header:Point('TOP', KB, 'TOP', 0, -4)

	_G.KeyBindingFrameScrollFrame:StripTextures()
	S:HandleScrollBar(_G.KeyBindingFrameScrollFrameScrollBar)

	S:HandleCheckBox(KB.characterSpecificButton)

	for i = 1, _G.KEY_BINDINGS_DISPLAYED, 1 do
		local button1 = _G['KeyBindingFrameKeyBinding'..i..'Key1Button']
		local button2 = _G['KeyBindingFrameKeyBinding'..i..'Key2Button']
		button2:Point('LEFT', button1, 'RIGHT', 1, 0) -- Needed for new Pixel Perfect
	end

	hooksecurefunc('BindingButtonTemplate_SetupBindingButton', function(_, button)
		if not button.IsSkinned then
			local selected = button.selectedHighlight
			selected:SetTexture(E.media.normTex)
			selected:Point('TOPLEFT', 1, -1)
			selected:Point('BOTTOMRIGHT', -1, 1)
			selected:SetColorTexture(1, 1, 1, .25)
			S:HandleButton(button)

			button.IsSkinned = true
		end
	end)

	KB.okayButton:Point('BOTTOMLEFT', KB.unbindButton, 'BOTTOMRIGHT', 3, 0)
	KB.cancelButton:Point('BOTTOMLEFT', KB.okayButton, 'BOTTOMRIGHT', 3, 0)
	KB.unbindButton:Point('BOTTOMRIGHT', KB, 'BOTTOMRIGHT', -211, 16)
end

S:AddCallbackForAddon('Blizzard_BindingUI')
