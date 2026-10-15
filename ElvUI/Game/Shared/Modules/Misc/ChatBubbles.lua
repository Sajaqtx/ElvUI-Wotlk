setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)
local M = E:GetModule('Misc')
local CH = E:GetModule('Chat')

local format, wipe, pairs, select = format, wipe, pairs, select
local strmatch, strlower, gmatch, gsub = strmatch, strlower, gmatch, gsub

local Ambiguate = Ambiguate
local CreateFrame = CreateFrame
local RemoveExtraSpaces = RemoveExtraSpaces
local PRIEST_COLOR = RAID_CLASS_COLORS.PRIEST
local C_ChatBubbles_GetAllChatBubbles = C_ChatBubbles.GetAllChatBubbles

--Message caches
local messageToGUID = {}
local messageToSender = {}

function M:UpdateBubbleBorder()
	local holder = self.holder
	local str = holder and holder.String
	if not str then return end

	local option = E.private.general.chatBubbles
	if option == 'backdrop' then
		holder:SetBackdropBorderColor(str:GetTextColor())
	elseif option == 'backdrop_noborder' then
		holder:SetBackdropBorderColor(0,0,0,0)
	end

	local name = self.Name and self.Name:GetText()
	if name then self.Name:SetText('') end

	local text = str:GetText()
	if not text then return end

	if E.private.general.chatBubbleName then
		M:AddChatBubbleName(self, messageToGUID[text], messageToSender[text])
	end

	if E.private.chat.enable and E.private.general.classColorMentionsSpeech then
		local isFirstWord, rebuiltString
		if text and strmatch(text, '%s-%S+%s*') then
			for word in gmatch(text, '%s-%S+%s*') do
				local tempWord = gsub(word, '^[%s%p]-([^%s%p]+)([%-]?[^%s%p]-)[%s%p]*$', '%1%2')
				local lowerCaseWord = strlower(tempWord)

				local classMatch = CH.ClassNames[lowerCaseWord]
				local wordMatch = classMatch and lowerCaseWord
				if wordMatch and not E.global.chat.classColorMentionExcludedNames[wordMatch] then
					local classColorTable = E:ClassColor(classMatch)
					local classColorName = classColorTable and classColorTable:WrapTextInColorCode(tempWord)
					if classColorName then
						local tempstr = gsub(tempWord, '%-','%%-')
						word = gsub(word, tempstr, classColorName)
					end
				end

				if not isFirstWord then
					rebuiltString = word
					isFirstWord = true
				else
					rebuiltString = format('%s%s', rebuiltString, word)
				end
			end

			if rebuiltString then
				str:SetText(RemoveExtraSpaces(rebuiltString))
			end
		end
	end
end

function M:AddChatBubbleName(chatBubble, guid, name)
	if not name then return end

	local color = PRIEST_COLOR
	local data = guid and guid ~= '' and CH:GetPlayerInfoByGUID(guid)
	if data and data.classColor then
		color = data.classColor
	end

	chatBubble.Name:SetFormattedText('|c%s%s|r', color.colorStr, name)
	chatBubble.Name:Width(chatBubble:GetWidth()-10)
end

local yOffset --Value set in M:LoadChatBubbles()
function M:SkinBubble(frame, holder)
	local option = E.private.general.chatBubbles
	if option == 'nobackdrop' then
		holder:DisableDrawLayer('BORDER')
	else
		local noBorder = option == 'backdrop_noborder'
		holder:SetTemplate('Transparent', nil, true, noBorder)
		holder.Center:SetDrawLayer('BACKGROUND')

		if noBorder then
			holder.Center:SetInside(holder, 4, 4)
		end
	end

	if not frame.Name then
		local name = holder:CreateFontString(nil, 'BORDER')
		name:Height(10) -- width set in M:AddChatBubbleName()
		name:Point('BOTTOM', frame, 'TOP', 0, yOffset)
		name:SetFontObject('ChatBubbleFont')
		name:SetJustifyH('LEFT')

		local font, size, outline = name:GetFont()
		name:FontTemplate(font, size * 0.85, outline)

		frame.Name = name
	end

	if not frame.holder then
		frame.holder = holder
		holder.Tail:Hide()

		frame:HookScript('OnShow', M.UpdateBubbleBorder)
		M.UpdateBubbleBorder(frame)
	end

	frame.IsSkinnedElvUI = true
end

-- ElvUI Wotlk: a 3.3.5 bubble is the WorldFrame child itself, no holder frame: its backdrop pieces and its tail are
-- textures of its own next to the text, and there is no ChatBubbleFont object, so the font goes on each bubble's text
function M:BubbleFont335(frame)
	local text = frame.String335
	if not text then
		for i = 1, frame:GetNumRegions() do
			local region = select(i, frame:GetRegions())
			if region:IsObjectType('FontString') then
				text = region
				frame.String335 = text
				break
			end
		end
	end

	if text and E.private.general.replaceBubbleFont then
		text:FontTemplate(E.Libs.LSM:Fetch('font', E.private.general.chatBubbleFont), E.private.general.chatBubbleFontSize, E.private.general.chatBubbleFontOutline)
	end

	return text
end

local function BubbleFont335_OnShow(frame)
	M:BubbleFont335(frame)
end

function M:SkinBubble335(frame)
	local text = M:BubbleFont335(frame)
	if not text then return end

	for i = 1, frame:GetNumRegions() do
		local region = select(i, frame:GetRegions())
		if region:IsObjectType('Texture') then
			region:SetTexture(nil)
		end
	end

	local option = E.private.general.chatBubbles
	if option ~= 'nobackdrop' then
		local noBorder = option == 'backdrop_noborder'
		frame:SetTemplate('Transparent', nil, true, noBorder)

		if noBorder and frame.Center then
			frame.Center:SetInside(frame, 4, 4)
		end
	end

	local name = frame:CreateFontString(nil, 'OVERLAY')
	name:Height(10)
	name:Point('BOTTOM', frame, 'TOP', 0, yOffset)
	name:SetJustifyH('LEFT')
	name:FontTemplate(E.Libs.LSM:Fetch('font', E.private.general.chatBubbleFont), E.private.general.chatBubbleFontSize * 0.85, E.private.general.chatBubbleFontOutline)
	frame.Name = name

	frame.holder = frame
	frame.String = text

	frame:HookScript('OnShow', BubbleFont335_OnShow)
	frame:HookScript('OnShow', M.UpdateBubbleBorder)
	M.UpdateBubbleBorder(frame)

	frame.IsSkinnedElvUI = true
end

-- the bubble style set to Disable (another bubble skin, ChatBubbleSkin): the font of the bubbles still follows the
-- Chat Bubbles font settings when Replace Font is on
local function ChatBubbleFont335_OnUpdate(eventFrame, elapsed)
	eventFrame.lastupdate = (eventFrame.lastupdate or -2) + elapsed
	if eventFrame.lastupdate < 0.1 then return end
	eventFrame.lastupdate = 0

	for _, frame in pairs(C_ChatBubbles_GetAllChatBubbles()) do
		if not frame.FontElvUI335 then
			frame.FontElvUI335 = true
			M:BubbleFont335(frame)
			frame:HookScript('OnShow', BubbleFont335_OnShow)
		end
	end
end

local function ChatBubble_OnEvent(_, event, msg, sender, _, _, _, _, _, _, _, _, _, guid)
	if event == 'PLAYER_ENTERING_WORLD' then --Clear caches
		wipe(messageToGUID)
		wipe(messageToSender)
	elseif E.private.general.chatBubbleName and E:NotSecretValue(guid) and E:NotSecretValue(msg) then
		messageToGUID[msg] = guid
		messageToSender[msg] = Ambiguate(sender, 'none')
	end
end

local function ChatBubble_OnUpdate(eventFrame, elapsed)
	eventFrame.lastupdate = (eventFrame.lastupdate or -2) + elapsed
	if eventFrame.lastupdate < 0.1 then return end
	eventFrame.lastupdate = 0

	for _, frame in pairs(C_ChatBubbles_GetAllChatBubbles()) do
		if ElvUI335 then
			if not frame.IsSkinnedElvUI then
				M:SkinBubble335(frame)
			end
		end

		local holder = not ElvUI335 and frame:GetChildren()
		if holder and not holder:IsForbidden() and not frame.IsSkinnedElvUI then
			M:SkinBubble(frame, holder)
		end
	end
end

function M:LoadChatBubbles()
	yOffset = (E.private.general.chatBubbles == 'backdrop' and 2) or (E.private.general.chatBubbles == 'backdrop_noborder' and -2) or 0

	M.BubbleFrame = CreateFrame('Frame')
	M.BubbleFrame:RegisterEvent('CHAT_MSG_SAY')
	M.BubbleFrame:RegisterEvent('CHAT_MSG_YELL')
	M.BubbleFrame:RegisterEvent('CHAT_MSG_MONSTER_SAY')
	M.BubbleFrame:RegisterEvent('CHAT_MSG_MONSTER_YELL')
	M.BubbleFrame:RegisterEvent('PLAYER_ENTERING_WORLD')

	if E.private.general.chatBubbles ~= 'disabled' then
		M.BubbleFrame:SetScript('OnEvent', ChatBubble_OnEvent)
		M.BubbleFrame:SetScript('OnUpdate', ChatBubble_OnUpdate)
	elseif ElvUI335 and E.private.general.replaceBubbleFont then
		M.BubbleFrame:SetScript('OnEvent', nil)
		M.BubbleFrame:SetScript('OnUpdate', ChatBubbleFont335_OnUpdate)
	else
		M.BubbleFrame:SetScript('OnEvent', nil)
		M.BubbleFrame:SetScript('OnUpdate', nil)
	end
end
