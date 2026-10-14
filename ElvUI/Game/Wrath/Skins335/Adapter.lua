setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)
--[[
	ElvUI Wotlk: the Blizzard window skins of ElvUI 6.10 (written for the 3.3.5 frames, Skins335\*.lua) on this
	version's skin functions. They call S as ElvUI 6.10 did: this table takes their arguments (6.10 order) to the
	functions of this version, and adds the four helpers 6.10 had and this version does not.
	The Wrath skins of the same windows are turned off on 3.3.5 (S.Unported335 in Modules\Skins\Skins.lua).
]]
local S = E:GetModule('Skins')

local _G = _G
local pairs, format, floor, find = pairs, format, floor, strfind
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local UIPanelWindows = UIPanelWindows
local UpdateUIPanelPositions = UpdateUIPanelPositions

local S610 = setmetatable({}, { __index = S })
S.Skins610 = S610

--> registration: straight to this version's skin list, past the S.Unported335 filter (that filter is for the Wrath skins)
function S610:AddCallback(_, func)
	S:RegisterSkin('ElvUI', func)
end

function S610:AddCallbackForAddon(addonName, _, func, forceLoad, bypass)
	S:RegisterSkin(addonName, func, forceLoad, bypass)
end

--> the 6.10 argument order
function S610:HandleButton(button, strip, isDeclineButton, useCreateBackdrop, noSetTemplate)
	return S:HandleButton(button, strip, isDeclineButton, noSetTemplate, useCreateBackdrop)
end

function S610:HandleScrollBar(frame) -- 6.10: (frame, horizontal), the bar's own orientation is read here
	return S:HandleScrollBar(frame)
end

function S610:HandleCheckBox(frame, noBackdrop, noReplaceTextures)
	return S:HandleCheckBox(frame, noBackdrop, noReplaceTextures)
end

function S610:HandleDropDownBox(frame, width) -- 6.10: (frame, width, direction)
	return S:HandleDropDownBox(frame, width)
end

-- 6.10's: the backdrop goes on the icon's parent (the skins then use parent.backdrop)
function S610:HandleIcon(icon, parent)
	parent = parent or icon:GetParent()

	icon:SetTexCoord(unpack(E.TexCoords))
	parent:CreateBackdrop()
	icon:SetParent(parent.backdrop)
	parent.backdrop:SetOutside(icon)
end

-- 6.10's: the icon on the button's backdrop
function S610:HandleItemButton(button, shrinkIcon)
	if button.isSkinned then return end

	local name = button:GetName()
	local icon = button.icon or button.IconTexture or button.iconTexture
	if name and _G[name..'IconTexture'] then
		icon = _G[name..'IconTexture']
	elseif name and _G[name..'Icon'] then
		icon = _G[name..'Icon']
	end

	local texture = icon and icon:GetTexture()

	button:StripTextures()
	button:CreateBackdrop(nil, true)
	button:StyleButton()

	if icon then
		icon:SetTexCoord(unpack(E.TexCoords))

		if shrinkIcon then
			button.backdrop:SetAllPoints()
			icon:SetInside(button)
		else
			button.backdrop:SetOutside(icon)
		end
		icon:SetParent(button.backdrop)

		if texture then
			icon:SetTexture(texture)
		end
	end

	button.isSkinned = true
end

-- 6.10's: a button, or a highlight texture itself (the dropdown menu lines)
function S610:HandleButtonHighlight(frame, r, g, b, a)
	local highlightTexture
	if frame.SetHighlightTexture then
		highlightTexture = frame:GetHighlightTexture()
		highlightTexture:SetAllPoints(frame)
	elseif frame.SetTexture then
		highlightTexture = frame
		frame:SetAllPoints(frame:GetParent())
	elseif frame.HighlightTexture then
		highlightTexture = frame.HighlightTexture
	else
		highlightTexture = frame:CreateTexture(nil, 'HIGHLIGHT')
		highlightTexture:SetAllPoints(frame)
		frame.HighlightTexture = highlightTexture
	end

	highlightTexture:SetTexture(E.Media.Textures.Highlight)
	highlightTexture:SetVertexColor(r or 0.9, g or 0.9, b or 0.9, a or 0.35)
end

-- the arrow of a button skinned by HandleNextPrevButton turned to another direction
function S610:SetNextPrevButtonDirection(frame, arrowDir)
	local direction = S.ArrowRotation[arrowDir or 'down']

	for _, texture in next, { frame:GetNormalTexture(), frame:GetDisabledTexture(), frame:GetPushedTexture() } do
		texture:SetRotation(direction)
	end
end

--> changes the panel attributes and hit rects wait out combat (the frames are protected)
local uiPanelQueue, hitRectQueue = {}, {}
local queueFrame = CreateFrame('Frame')

local function SetPanelWindowInfo(frame, name, value, ignoreUpdate)
	frame:SetAttribute(name, value)

	if not ignoreUpdate and frame:IsShown() then
		UpdateUIPanelPositions(frame)
	end
end

queueFrame:SetScript('OnEvent', function(frame)
	frame:UnregisterEvent('PLAYER_REGEN_ENABLED')

	for frameInfo, info in pairs(uiPanelQueue) do
		if info[3] then
			SetPanelWindowInfo(info[1], info[2], info[3], info[4])
		end
		uiPanelQueue[frameInfo] = nil
	end

	for frameRect, info in pairs(hitRectQueue) do
		frameRect:SetHitRectInsets(info[1], info[2], info[3], info[4])
		if info[5] then
			frameRect:SetClampRectInsets(info[1], info[2], info[3], info[4])
		end
		hitRectQueue[frameRect] = nil
	end
end)

local UI_PANEL_OFFSET = 7

function S610:SetUIPanelWindowInfo(frame, name, value, offset, ignoreUpdate, anyPanel)
	local frameName = frame and frame.GetName and frame:GetName()
	if not (frameName and (anyPanel or UIPanelWindows[frameName])) then return end

	name = 'UIPanelLayout-'..name

	if name == 'UIPanelLayout-width' then
		value = E:Scale(value or (frame.backdrop and frame.backdrop:GetWidth() or frame:GetWidth())) + (offset or 0) + UI_PANEL_OFFSET
	end

	local valueChanged = frame:GetAttribute(name) ~= value

	if not frame:CanChangeAttribute() then
		local frameInfo = format('%s-%s', frameName, name)
		if uiPanelQueue[frameInfo] then
			uiPanelQueue[frameInfo][3] = valueChanged and value or nil
			uiPanelQueue[frameInfo][4] = ignoreUpdate
		elseif valueChanged then
			uiPanelQueue[frameInfo] = { frame, name, value, ignoreUpdate }
			queueFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
		end
	elseif valueChanged then
		SetPanelWindowInfo(frame, name, value, ignoreUpdate)
	end
end

function S610:SetBackdropHitRect(frame, backdrop, clampRect, attempt)
	if not frame then return end

	backdrop = backdrop or frame.backdrop
	if not backdrop then return end

	local left, bleft = frame:GetLeft(), backdrop:GetLeft()
	if not left or not bleft then
		if attempt ~= 10 then
			E:Delay(0.1, S610.SetBackdropHitRect, S610, frame, backdrop, clampRect, attempt and attempt + 1 or 1)
		end
		return
	end

	left = floor(bleft + 0.5) - floor(left + 0.5)
	local right = floor(frame:GetRight() + 0.5) - floor(backdrop:GetRight() + 0.5)
	local top = floor(frame:GetTop() + 0.5) - floor(backdrop:GetTop() + 0.5)
	local bottom = floor(backdrop:GetBottom() + 0.5) - floor(frame:GetBottom() + 0.5)

	if not frame:CanChangeAttribute() then
		hitRectQueue[frame] = { left, right, top, bottom, clampRect }
		queueFrame:RegisterEvent('PLAYER_REGEN_ENABLED')
	else
		frame:SetHitRectInsets(left, right, top, bottom)
		if clampRect then
			frame:SetClampRectInsets(left, -right, -top, bottom)
		end
	end
end

--> the + / - buttons of the 3.3.5 lists (quest log, skills, reputation...)
local function collapseSetNormalTexture_Text(self, texture)
	if texture then
		if find(texture, 'MinusButton', 1, true) or find(texture, 'ZoomOutButton', 1, true) then
			self.collapseText:SetText('-')
			return
		elseif find(texture, 'PlusButton', 1, true) or find(texture, 'ZoomInButton', 1, true) then
			self.collapseText:SetText('+')
			return
		end
	end
	self.collapseText:SetText('')
end

local function collapseSetNormalTexture_Texture(self, texture)
	local textureFile
	if texture then
		if find(texture, 'MinusButton', 1, true) or find(texture, 'ZoomOutButton', 1, true) then
			textureFile = E.Media.Textures.Minus
		elseif find(texture, 'PlusButton', 1, true) or find(texture, 'ZoomInButton', 1, true) then
			textureFile = E.Media.Textures.Plus
		end
	end

	if textureFile then
		self:GetNormalTexture():SetTexture(textureFile)
		self:GetPushedTexture():SetTexture(textureFile)
		self:GetDisabledTexture():SetTexture(textureFile)
	else
		self:GetNormalTexture():SetTexture(0, 0, 0, 0)
		self:GetPushedTexture():SetTexture(0, 0, 0, 0)
		self:GetDisabledTexture():SetTexture(0, 0, 0, 0)
	end
end

function S610:HandleCollapseExpandButton(button, defaultState, useFontString, xOffset, yOffset)
	if button.isSkinned then return end

	if defaultState == 'auto' then
		local texture = button:GetNormalTexture():GetTexture()
		if texture and (find(texture, 'MinusButton', 1, true) or find(texture, 'ZoomOutButton', 1, true)) then
			defaultState = '-'
		elseif texture and (find(texture, 'PlusButton', 1, true) or find(texture, 'ZoomInButton', 1, true)) then
			defaultState = '+'
		end
	end

	button:SetNormalTexture('')
	button:SetPushedTexture('')
	button:SetHighlightTexture('')
	button:SetDisabledTexture('')

	button.SetPushedTexture = E.noop
	button.SetHighlightTexture = E.noop
	button.SetDisabledTexture = E.noop

	if useFontString then
		button.collapseText = button:CreateFontString(nil, 'OVERLAY')
		button.collapseText:FontTemplate(nil, 22)
		button.collapseText:Point('LEFT', xOffset or 5, yOffset or 0)
		button.collapseText:SetText((defaultState == '+' or defaultState == '-') and defaultState or '')

		button.SetNormalTexture = collapseSetNormalTexture_Text
	else
		local stateTexture = (defaultState == '+' and E.Media.Textures.Plus) or (defaultState == '-' and E.Media.Textures.Minus)
		for _, getter in pairs({ 'GetNormalTexture', 'GetPushedTexture', 'GetDisabledTexture' }) do
			local texture = button[getter](button)
			texture:Size(16)
			texture:ClearAllPoints()
			texture:Point('LEFT', xOffset or 3, yOffset or 0)
			texture.SetPoint = E.noop
			if stateTexture then texture:SetTexture(stateTexture) end
		end
		button:GetDisabledTexture():SetVertexColor(0.6, 0.6, 0.6)

		button.SetNormalTexture = collapseSetNormalTexture_Texture
	end

	button.isSkinned = true
end

--> the 3.3.5 icon pickers (macro, guild bank tab, equipment set): named children, no BorderBox
function S610:HandleIconSelectionFrame(frame, numIcons, buttonNameTemplate, frameNameOverride)
	local frameName = frameNameOverride or frame:GetName() -- the guild bank one is not named after its frame
	local scrollFrame = _G[frameName..'ScrollFrame']
	local editBox = _G[frameName..'EditBox']
	local okayButton = _G[frameName..'OkayButton'] or _G[frameName..'Okay']
	local cancelButton = _G[frameName..'CancelButton'] or _G[frameName..'Cancel']

	frame:StripTextures()
	scrollFrame:StripTextures()
	editBox:DisableDrawLayer('BACKGROUND')

	frame:CreateBackdrop('Transparent')
	frame.backdrop:Point('TOPLEFT', frame, 'TOPLEFT', 10, -12)
	frame.backdrop:Point('BOTTOMRIGHT', cancelButton, 'BOTTOMRIGHT', 8, -8)

	S:HandleButton(okayButton)
	S:HandleButton(cancelButton)
	S:HandleEditBox(editBox)

	for i = 1, numIcons do
		local button = _G[buttonNameTemplate..i]
		local icon = _G[button:GetName()..'Icon']
		button:StripTextures()
		button:SetTemplate()
		button:StyleButton(nil, true)
		icon:SetInside()
		icon:SetTexCoord(unpack(E.TexCoords))
	end
end

function S610:HandleColorSwatch(frame, size)
	if frame.isSkinned then return end

	frame:StripTextures()
	frame:CreateBackdrop()
	frame.backdrop:SetFrameLevel(frame:GetFrameLevel())

	if size then
		frame:Size(size)
	end

	local normalTexture = frame:GetNormalTexture()
	normalTexture:SetTexture(E.media.blankTex)
	normalTexture:SetInside(frame.backdrop)

	frame.isSkinned = true
end
