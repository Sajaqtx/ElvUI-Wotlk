setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)
local ENP = E:NewModule("Enhanced_NamePlates", "AceEvent-3.0")
local NP = E:GetModule("NamePlates")
local M = E:GetModule("Misc")
local CH = E:GetModule("Chat")

-- ElvUI Wotlk: on ElvUI 16 the plates are units (nameplateN): their class color, and the guild and NPC title
-- ([guild:brackets] and [npctitle] tags) come natively, so the 6.10 class cache and title cache are gone. Kept: the
-- chat bubbles above the plates, on ElvUI 16's plates (NP.Plates, nameplate.unit / unitName)

local _G = _G
local ipairs, next, pairs = ipairs, next, pairs
local sub, gsub = string.sub, string.gsub
local match, gmatch, format, lower = string.match, string.gmatch, string.format, string.lower
local tinsert, tremove = table.insert, table.remove

local UnitName = UnitName

-- Chat Bubbles
local events = {
	"CHAT_MSG_GUILD",
	"CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER",
	"CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_BATTLEGROUND",
	"CHAT_MSG_BATTLEGROUND_LEADER",
	"CHAT_MSG_CHANNEL",
	"CHAT_MSG_SAY",
	"CHAT_MSG_YELL",
	"CHAT_MSG_MONSTER_SAY",
	"CHAT_MSG_MONSTER_YELL"
}

local bubbleList = {}
local inactiveBubbles = {}

local function ReleaseBubble(frame)
	inactiveBubbles[#inactiveBubbles + 1] = frame
	if frame.parent and frame.parent.bubbleFrame == frame then
		frame.parent.bubbleFrame = nil
	end
	frame.parent = nil
	frame:Hide()
end

-- the plate is still the author's: a plate hidden or reused for another unit drops its bubble
local function PlateOwnsBubble(frame)
	local plate = frame.parent
	return plate and plate.unit and plate:IsVisible() and plate.unitName == frame.author
end

local delayFrame = CreateFrame("Frame")
delayFrame:Hide()
delayFrame:SetScript("OnUpdate", function(self, elapsed)
	local i, frame = 1

	while bubbleList[i] do
		frame = bubbleList[i]
		frame.delay = frame.delay - elapsed

		if not PlateOwnsBubble(frame) then
			E:UIFrameFadeRemoveFrame(frame)
			frame.delay = 0
			tremove(bubbleList, i)
			ReleaseBubble(frame)
		elseif frame.delay <= 0 then
			frame.delay = 0
			E:UIFrameFadeOut(frame, .2, frame:GetAlpha(), 0)
			tremove(bubbleList, i)
		else
			i = i + 1
		end
	end

	if #bubbleList == 0 then
		self:Hide()
	end
end)

local function SetBubbleDelay(frame, delay)
	local found

	if #bubbleList > 0 then
		for _, v in ipairs(bubbleList) do
			if v == frame then
				v.delay = delay
				found = true
				break
			end
		end
	end

	if not found then
		frame.delay = delay
		tinsert(bubbleList, frame)
		delayFrame:Show()
	end
end

local function FadeClosure(frame)
	if frame.fadeInfo.mode == "OUT" then
		ReleaseBubble(frame)
	end
end

local function CreateBubble()
	local frame = CreateFrame("Frame", nil, E.UIParent)
	frame:SetFrameStrata("BACKGROUND")
	frame:Hide()

	local option = E.private.general.chatBubbles
	if option ~= "nobackdrop" and option ~= "disabled" then
		local noBorder = option == "backdrop_noborder"
		frame:SetTemplate("Transparent", nil, true, noBorder)
		frame.hasBorder = not noBorder
	end

	local font, size, outline = E.Libs.LSM:Fetch("font", E.private.general.chatBubbleFont), E.private.general.chatBubbleFontSize, E.private.general.chatBubbleFontOutline

	frame.text = frame:CreateFontString(nil, "OVERLAY")
	frame.text:FontTemplate(font, size, outline)
	frame.text:SetJustifyH("CENTER")
	frame.text:SetJustifyV("MIDDLE")
	frame.text:SetWordWrap(true)
	frame.text:SetNonSpaceWrap(true)
	frame:SetPoint("TOPLEFT", frame.text, -10, 10)
	frame:SetPoint("BOTTOMRIGHT", frame.text, 10, -10)

	-- the author's name above the bubble, as ElvUI's own bubbles (M:AddChatBubbleName)
	frame.Name = frame:CreateFontString(nil, "OVERLAY")
	frame.Name:Height(10)
	frame.Name:Point("BOTTOMLEFT", frame, "TOPLEFT", 5, 2)
	frame.Name:SetJustifyH("LEFT")
	frame.Name:FontTemplate(font, size * 0.85, outline)

	frame.delay = 0
	frame.FadeObject = {
		finishedFuncKeep = true,
		finishedArg1 = frame,
		finishedFunc = FadeClosure
	}

	return frame
end

local function AcquireBubble()
	local numInactiveObjects = #inactiveBubbles
	if numInactiveObjects > 0 then
		local frame = inactiveBubbles[numInactiveObjects]
		inactiveBubbles[numInactiveObjects] = nil
		return frame
	end

	return CreateBubble()
end

function ENP:AddBubbleMessage(frame, msg, author, guid)
	frame.text:SetText(msg)

	if frame.text:GetStringWidth() > 300 then
		frame.text:SetWidth(300)
	end

	if E.private.general.chatBubbleName then
		M:AddChatBubbleName(frame, guid, author)
	else
		frame.Name:SetText("")
	end

	if E.private.chat.enable and E.private.general.classColorMentionsSpeech then
		local lowerCaseWord, isFirstWord, rebuiltString, tempWord, wordMatch, classMatch
		if msg and match(msg, "%s-%S+%s*") then
			for word in gmatch(msg, "%s-%S+%s*") do
				tempWord = gsub(word, "^[%s%p]-([^%s%p]+)([%-]?[^%s%p]-)[%s%p]*$","%1%2")
				lowerCaseWord = lower(tempWord)

				classMatch = CH.ClassNames[lowerCaseWord]
				wordMatch = classMatch and lowerCaseWord

				if wordMatch and not E.global.chat.classColorMentionExcludedNames[wordMatch] then
					local classColorTable = E:ClassColor(classMatch)
					if classColorTable then
						word = gsub(word, gsub(tempWord, "%-","%%-"), format("\124cff%.2x%.2x%.2x%s\124r", classColorTable.r*255, classColorTable.g*255, classColorTable.b*255, tempWord))
					end
				end

				if not isFirstWord then
					rebuiltString = word
					isFirstWord = true
				else
					rebuiltString = format("%s%s", rebuiltString, word)
				end
			end

			if rebuiltString ~= nil then
				frame.text:SetText(rebuiltString)
			end
		end
	end
end

function ENP:FindNameplateByChatMsg(event, msg, author, _, _, _, _, _, channelID, _, _, _, guid)
	if not msg or not author or author == UnitName("player") then return end
	if not next(NP.Plates) then return end

	local chatType = sub(event, 10)
	if sub(chatType, 1, 7) == "CHANNEL" then
		chatType = "CHANNEL"..(channelID or "")
	end

	local info = ChatTypeInfo[chatType]
	if not info then return end

	for plate in pairs(NP.Plates) do
		if plate.unit and plate.unitName == author and plate:IsVisible() then
			local bubbleFrame = plate.bubbleFrame
			if not bubbleFrame then
				bubbleFrame = AcquireBubble()
				plate.bubbleFrame = bubbleFrame
				bubbleFrame.text:ClearAllPoints()
				bubbleFrame.text:SetPoint("BOTTOM", plate, "TOP", 0, 20)
				bubbleFrame:Show()
				E:UIFrameFadeIn(bubbleFrame, .2, 0, 1)
			end

			bubbleFrame.parent = plate
			bubbleFrame.author = author

			bubbleFrame.text:SetSize(0, 0)
			bubbleFrame.text:SetTextColor(info.r, info.g, info.b)

			if bubbleFrame.hasBorder then
				bubbleFrame:SetBackdropBorderColor(info.r, info.g, info.b)
			end

			ENP:AddBubbleMessage(bubbleFrame, msg, author, guid)

			if bubbleFrame.delay == 0 then
				E:UIFrameFadeRemoveFrame(bubbleFrame)
				E:UIFrameFadeIn(bubbleFrame, .2, bubbleFrame:GetAlpha(), 1)
			end

			local _, delayMult = gsub(msg, "%s+", "")
			SetBubbleDelay(bubbleFrame, 2 + (0.5 * delayMult))
		end
	end
end

function ENP:ChatBubbles()
	if E.db.enhanced.nameplates.chatBubbles then
		for _, event in ipairs(events) do
			ENP:RegisterEvent(event, "FindNameplateByChatMsg")
		end
	else
		for _, event in ipairs(events) do
			ENP:UnregisterEvent(event)
		end

		for i = #bubbleList, 1, -1 do
			local frame = tremove(bubbleList, i)
			E:UIFrameFadeRemoveFrame(frame)
			frame.delay = 0
			ReleaseBubble(frame)
		end
	end
end

function ENP:UpdateAllSettings()
	self:ChatBubbles()
end

function ENP:Initialize()
	if not E.private.nameplates.enable then return end

	ENP:UpdateAllSettings()
end

local function InitializeCallback()
	ENP:Initialize()
end

E:RegisterModule(ENP:GetName(), InitializeCallback)
