setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)
local BL = E:GetModule('Blizzard')

local _G = _G
local min = min
local hooksecurefunc = hooksecurefunc

local CreateFrame = CreateFrame
local Tracker_Collapse = WatchFrame_Collapse
local Tracker_Expand = WatchFrame_Expand
local Tracker = WatchFrame

local function ObjectiveTracker_SetPoint(tracker, _, parent)
	if parent ~= tracker.holder then
		tracker:ClearAllPoints()
		tracker:SetPoint('TOP', tracker.holder)
	end
end

function BL:ObjectiveTracker_SetHeight()
	local top = Tracker:GetTop() or 0
	local gapFromTop = E.screenHeight - top
	local maxHeight = E.screenHeight - gapFromTop
	local frameHeight = min(maxHeight, E.db.general.objectiveFrameHeight)

	Tracker:Height(frameHeight)
end

function BL:ObjectiveTracker_AutoHideOnHide()
	if not Tracker.collapsed then
		Tracker.userCollapsed = true
		Tracker_Collapse(Tracker)
	end
end

function BL:ObjectiveTracker_AutoHideOnShow()
	if Tracker.collapsed then
		Tracker.userCollapsed = nil
		Tracker_Expand(Tracker)
	end
end

function BL:ObjectiveTracker_Setup()
	local holder = CreateFrame('Frame', 'ObjectiveFrameHolder', E.UIParent)
	holder:Point('TOPRIGHT', -135, -300)
	holder:Size(130, 22)

	E:CreateMover(holder, 'ObjectiveFrameMover', L["Objective Frame"], nil, nil, nil, nil, nil, 'general,blizzUIImprovements')
	holder:SetAllPoints(_G.ObjectiveFrameMover)

	-- prevent it from being moved by blizzard (the hook below will most likely do nothing now)
	Tracker:SetMovable(true)
	Tracker:SetUserPlaced(true)
	Tracker:SetDontSavePosition(true)
	Tracker:SetClampedToScreen(false)
	Tracker:ClearAllPoints()
	Tracker:SetPoint('TOP', holder)

	Tracker.holder = holder
	hooksecurefunc(Tracker, 'SetPoint', ObjectiveTracker_SetPoint)

	BL:ObjectiveTracker_AutoHide() -- supported but no boss frames, only works for arena
	BL:ObjectiveTracker_SetHeight()
end

-- ElvUI Wotlk: v16 starts the tracker with BL:HandleObjectiveTracker (its multi-version ObjectiveFrame); the Wrath
-- setup of v15.26, left to another quest tracker when one is loaded
function BL:HandleObjectiveTracker()
	if not BL:ObjectiveTracker_HasQuestTracker() then
		BL:ObjectiveTracker_Setup()
	end
end

-- ElvUI Wotlk: the tracker helpers of the v15.26 Blizzard module (v16 moved them into its own ObjectiveFrame)
function BL:ObjectiveTracker_HasQuestTracker()
	return E.OtherAddons.KalielsTracker or E.OtherAddons.DugisGuideViewerZ
end

function BL:ObjectiveTracker_IsCollapsed(frame)
	return frame:GetParent() == E.HiddenFrame
end

function BL:ObjectiveTracker_Collapse(frame)
	frame:SetParent(E.HiddenFrame)
end

function BL:ObjectiveTracker_Expand(frame)
	frame:SetParent(_G.UIParent)
end

do
	local AutoHider
	function BL:ObjectiveTracker_AutoHide()
		if E.OtherAddons.BigWigs or E.OtherAddons.DBM then return end

		local tracker = _G.WatchFrame
		if not tracker then return end

		if not AutoHider then
			AutoHider = CreateFrame('Frame', nil, UIParent, 'SecureHandlerStateTemplate')
			AutoHider:SetAttribute('_onstate-objectiveHider', 'if newstate == 1 then self:Hide() else self:Show() end')
			AutoHider:SetScript('OnHide', BL.ObjectiveTracker_AutoHideOnHide)
			AutoHider:SetScript('OnShow', BL.ObjectiveTracker_AutoHideOnShow)
		end

		if E.db.general.objectiveFrameAutoHide then
			RegisterStateDriver(AutoHider, 'objectiveHider', '[@arena1,exists][@arena2,exists][@arena3,exists][@arena4,exists][@arena5,exists][@boss1,exists][@boss2,exists][@boss3,exists][@boss4,exists][@boss5,exists] 1;0')
		else
			UnregisterStateDriver(AutoHider, 'objectiveHider')
			BL:ObjectiveTracker_AutoHideOnShow() -- reshow it when needed
		end
	end
end
