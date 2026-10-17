setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)
local UF = E:GetModule('UnitFrames')
local LSM = E.Libs.LSM

local CreateFrame = CreateFrame

local UnitDamageAbsorbClampMode = Enum.UnitDamageAbsorbClampMode
local UnitIncomingHealClampMode = Enum.UnitIncomingHealClampMode
local UnitHealAbsorbClampMode = Enum.UnitHealAbsorbClampMode

function UF.HealthClipFrame_HealComm(frame)
	if frame.HealthPrediction then
		UF:SetAlpha_HealComm(frame.HealthPrediction, 1)
	end
end

function UF:SetAlpha_HealComm(obj, alpha)
	obj.healingPlayer:SetAlpha(alpha)
	obj.healingOther:SetAlpha(alpha)
	obj.damageAbsorb:SetAlpha(alpha)
	obj.healAbsorb:SetAlpha(alpha)
end

function UF:SetTexture_HealComm(obj, texture)
	obj.healingPlayer:SetStatusBarTexture(texture)
	obj.healingOther:SetStatusBarTexture(texture)
	obj.damageAbsorb:SetStatusBarTexture(texture)
	obj.healAbsorb:SetStatusBarTexture(texture)
end

function UF:SetFrameLevel_HealComm(obj, level)
	obj.healingPlayer:SetFrameLevel(level)
	obj.healingOther:SetFrameLevel(level)
	obj.damageAbsorb:SetFrameLevel(level)
	obj.healAbsorb:SetFrameLevel(level)
end

function UF:Construct_HealComm(frame)
	local health = frame.Health
	local parent = health.ClipFrame

	local prediction = {
		healingPlayer = CreateFrame('StatusBar', '$parent_HealingPlayerBar', parent),
		healingOther = CreateFrame('StatusBar', '$parent_HealingOtherBar', parent),
		damageAbsorb = CreateFrame('StatusBar', '$parent_AbsorbDamageBar', parent),
		healAbsorb = CreateFrame('StatusBar', '$parent_AbsorbHealBar', parent),
		PostUpdate = UF.UpdateHealComm,
		maxOverflow = 1,
		health = health,
		parent = parent,
		frame = frame
	}

	UF:SetAlpha_HealComm(prediction, 0)
	UF:SetFrameLevel_HealComm(prediction, 11)
	UF:SetTexture_HealComm(prediction, E.media.blankTex)

	return prediction
end

function UF:SetSize_HealComm(frame)
	local health = frame.Health
	local pred = frame.HealthPrediction
	local orientation = health:GetOrientation()

	local db = frame.db.healPrediction
	local width, height = health:GetSize()

	-- fallback just incase, can happen on profile switching
	if not width or width <= 0 then width = health.WIDTH end
	if not height or height <= 0 then height = health.HEIGHT end

	-- keep the clip frame at the health size for reversed style, so prediction cant overflow the frame
	local overflow = (E.Modern and db.absorbStyle == 'REVERSED' and 1) or pred.maxOverflow or 0

	if orientation == 'HORIZONTAL' then
		local barHeight = db.height or height
		if barHeight == -1 or barHeight > height then barHeight = height end

		pred.healingPlayer:SetSize(width, barHeight)
		pred.healingOther:SetSize(width, barHeight)
		pred.healAbsorb:SetSize(width, barHeight)
		pred.damageAbsorb:SetSize(width, barHeight)
		pred.parent:SetSize(width * overflow, height)
	else
		local barWidth = db.height or width -- this is really width now not height
		if barWidth == -1 or barWidth > width then barWidth = width end

		pred.healingPlayer:SetSize(barWidth, height)
		pred.healingOther:SetSize(barWidth, height)
		pred.healAbsorb:SetSize(barWidth, height)
		pred.damageAbsorb:SetSize(barWidth, height)
		pred.parent:SetSize(width, height * overflow)
	end
end

function UF:Configure_HealComm(frame)
	local db = frame.db and frame.db.healPrediction
	if db and db.enable then
		local pred = frame.HealthPrediction
		local parent = pred.parent
		local healingPlayer = pred.healingPlayer
		local healingOther = pred.healingOther
		local damageAbsorb = pred.damageAbsorb
		local healAbsorb = pred.healAbsorb

		local colors = UF.db.colors.healPrediction
		pred.maxOverflow = 1 + (colors.maxOverflow or 0)

		if E.Modern then
			local canOverflow = db.absorbStyle == 'REVERSED' or db.absorbStyle == 'OVERFLOW'
			local clampMode = (canOverflow and (pred.maxOverflow > 1) and 'MaximumHealth') or 'MissingHealth'
			pred.damageAbsorbClampMode = UnitDamageAbsorbClampMode[clampMode]
			pred.healAbsorbClampMode = UnitHealAbsorbClampMode[clampMode]
			pred.incomingHealClampMode = UnitIncomingHealClampMode[clampMode]

			pred:SetupPredictionValues()
		end

		if not frame:IsElementEnabled('HealthPrediction') then
			frame:EnableElement('HealthPrediction')
		end

		local health = frame.Health
		local orientation = health:GetOrientation()
		local reverseFill = health:GetReverseFill()
		local healthBarTexture = health:GetStatusBarTexture() -- :GetTexture() from here sometimes messes up? so use LSM

		pred.overState = nil -- let UpdateHealComm reapply the absorb anchors
		pred.reverseFill = reverseFill
		pred.healthBarTexture = healthBarTexture
		pred.healingPlayerTexture = healingPlayer:GetStatusBarTexture()
		pred.healingOtherTexture = healingOther:GetStatusBarTexture()

		UF:SetTexture_HealComm(pred, UF.db.colors.transparentHealth and E.media.blankTex or LSM:Fetch('statusbar', UF.db.statusbar))

		healingPlayer:SetReverseFill(reverseFill)
		healingOther:SetReverseFill(reverseFill)
		healAbsorb:SetReverseFill(not reverseFill)

		if db.absorbStyle == 'REVERSED' then
			damageAbsorb:SetReverseFill(not reverseFill)
		else
			damageAbsorb:SetReverseFill(reverseFill)
		end

		healingPlayer:SetStatusBarColor(colors.personal.r, colors.personal.g, colors.personal.b, colors.personal.a)
		healingOther:SetStatusBarColor(colors.others.r, colors.others.g, colors.others.b, colors.others.a)
		damageAbsorb:SetStatusBarColor(colors.absorbs.r, colors.absorbs.g, colors.absorbs.b, colors.absorbs.a)
		healAbsorb:SetStatusBarColor(colors.healAbsorbs.r, colors.healAbsorbs.g, colors.healAbsorbs.b, colors.healAbsorbs.a)

		healingPlayer:SetOrientation(orientation)
		healingOther:SetOrientation(orientation)
		damageAbsorb:SetOrientation(orientation)
		healAbsorb:SetOrientation(orientation)

		if orientation == 'HORIZONTAL' then
			local p1 = reverseFill and 'RIGHT' or 'LEFT'
			local p2 = reverseFill and 'LEFT' or 'RIGHT'

			local anchor = db.anchorPoint
			pred.anchor, pred.anchor1, pred.anchor2 = anchor, p1, p2

			healingPlayer:ClearAllPoints()
			healingPlayer:Point(anchor, health)
			healingPlayer:Point(p1, healthBarTexture, p2)

			healingOther:ClearAllPoints()
			healingOther:Point(anchor, health)
			healingOther:Point(p1, pred.healingPlayerTexture, p2)

			healAbsorb:ClearAllPoints()
			healAbsorb:Point(anchor, health)

			damageAbsorb:ClearAllPoints()
			damageAbsorb:Point(anchor, health)

			parent:ClearAllPoints()
			parent:Point(p1, health, p1)

			if db.absorbStyle == 'REVERSED' then
				damageAbsorb:Point(p2, health, p2)
			else
				damageAbsorb:Point(p1, pred.healingOtherTexture, p2)
			end
		else
			local p1 = reverseFill and 'TOP' or 'BOTTOM'
			local p2 = reverseFill and 'BOTTOM' or 'TOP'

			-- anchor converts while the health is in vertical orientation to be able to use a height
			-- (well in this case, width) other than -1 which positions the absorb on the left or right side
			local anchor = (db.anchorPoint == 'BOTTOM' and 'RIGHT') or (db.anchorPoint == 'TOP' and 'LEFT') or db.anchorPoint
			pred.anchor, pred.anchor1, pred.anchor2 = anchor, p1, p2

			healingPlayer:ClearAllPoints()
			healingPlayer:Point(anchor, health)
			healingPlayer:Point(p1, healthBarTexture, p2)

			healingOther:ClearAllPoints()
			healingOther:Point(anchor, health)
			healingOther:Point(p1, pred.healingPlayerTexture, p2)

			healAbsorb:ClearAllPoints()
			healAbsorb:Point(anchor, health)

			damageAbsorb:ClearAllPoints()
			damageAbsorb:Point(anchor, health)

			parent:ClearAllPoints()
			parent:Point(p1, health, p1)

			if db.absorbStyle == 'REVERSED' then
				damageAbsorb:Point(p2, health, p2)
			else
				damageAbsorb:Point(p1, pred.healingOtherTexture, p2)
			end
		end
	elseif frame:IsElementEnabled('HealthPrediction') then
		frame:DisableElement('HealthPrediction')
	end
end

-- ElvUI Wotlk: the bars laid out from the values, part by part. ElvUI chains them by their fill textures (heals at the end
-- of the health, others' heals at the end of those, absorbs at the end of those), but a 3.3.5 bar with nothing in it
-- still has a full size texture (measured in game: the absorbs a whole bar further, over the next frames), and 3.3.5
-- bars only fill from their start (no reverse fill). Each segment is placed at its offset from the start of the health
-- bar, as long as its value, in the health bar's direction. Absorb styles: Normal in the missing health (a sliver when
-- full), Overflow past the end up to Max Overflow, Wrapped back from the end once over the missing health, Reversed at
-- the end of the current health, over it (the part a hit takes first)
function UF:UpdateHealComm335(frame, db, myIncomingHeal, otherIncomingHeal, absorb, healAbsorbAmount, hasOverAbsorb, hasOverHealAbsorb, health, maxHealth)
	local pred = frame.HealthPrediction
	local bar = frame.Health
	local horizontal = bar:GetOrientation() == 'HORIZONTAL'
	local size = horizontal and bar:GetWidth() or bar:GetHeight()
	if not size or size <= 0 or not maxHealth or maxHealth <= 0 then return end

	local reverse = bar:GetReverseFill() -- the health fills from the right (or the top)
	local per = size / maxHealth
	local anchor = db.anchorPoint or 'BOTTOM'
	local side = (anchor == 'TOP' and 'TOP') or (anchor == 'BOTTOM' and 'BOTTOM') or ''

	local function Place(segment, start, length)
		if not length or length < 0.5 then
			segment:Hide()
			return
		end

		-- 3.3.5 bars fill from the left (bottom): a segment counted from the right (top) is placed from its far end
		local from = reverse and (size - start - length) or start

		segment:ClearAllPoints()
		if horizontal then
			segment:Point(side .. 'LEFT', bar, side .. 'LEFT', from, 0)
		else
			local vside = (anchor == 'RIGHT' and 'RIGHT') or (anchor == 'LEFT' and 'LEFT') or ''
			segment:Point('BOTTOM' .. vside, bar, 'BOTTOM' .. vside, 0, from)
		end

		segment:SetMinMaxValues(0, size)
		segment:SetValue(length)
		segment:Show()
	end

	local healthEnd = min(health or 0, maxHealth) * per
	local mine, others = (myIncomingHeal or 0) * per, (otherIncomingHeal or 0) * per
	Place(pred.healingPlayer, healthEnd, mine)
	Place(pred.healingOther, healthEnd + mine, others)

	local colors = UF.db.colors.healPrediction
	local style = db.absorbStyle
	local healsEnd = min(healthEnd + mine + others, size)
	local damageAbsorb, healAbsorb = pred.damageAbsorb, pred.healAbsorb
	local absorbLength = (absorb or 0) * per

	if style == 'NONE' or absorbLength <= 0 then
		damageAbsorb:Hide()
	elseif style == 'REVERSED' then
		local length = min(absorbLength, healthEnd)
		Place(damageAbsorb, healthEnd - length, length)
	elseif style == 'WRAPPED' then
		if absorbLength > size - healsEnd then -- over the missing health: back from the end of the bar
			local length = min(absorbLength, size)
			Place(damageAbsorb, size - length, length)
		else
			Place(damageAbsorb, healsEnd, absorbLength)
		end
	elseif style == 'OVERFLOW' then
		Place(damageAbsorb, healsEnd, min(absorbLength, size - healsEnd + (colors.maxOverflow or 0) * size))
	else -- NORMAL: in the missing health, a sliver at the end when there is none
		local room = size - healsEnd
		if room >= 1 then
			Place(damageAbsorb, healsEnd, min(absorbLength, room))
		else
			Place(damageAbsorb, size - max(1, size * 0.015), max(1, size * 0.015))
		end
	end

	-- heal absorbs: back from the end of the health (the part a heal fills first), past it when they are over the health
	local healAbsorbLength = (healAbsorbAmount or 0) * per
	if style == 'NONE' or healAbsorbLength <= 0 then
		healAbsorb:Hide()
	elseif hasOverHealAbsorb then
		Place(healAbsorb, healthEnd, min(healAbsorbLength, size - healthEnd))
	else
		local length = min(healAbsorbLength, healthEnd)
		Place(healAbsorb, healthEnd - length, length)
	end

	local absorbColor = hasOverAbsorb and colors.overabsorbs or colors.absorbs
	damageAbsorb:SetStatusBarColor(absorbColor.r, absorbColor.g, absorbColor.b, absorbColor.a)

	local healAbsorbColor = hasOverHealAbsorb and colors.overhealabsorbs or colors.healAbsorbs
	healAbsorb:SetStatusBarColor(healAbsorbColor.r, healAbsorbColor.g, healAbsorbColor.b, healAbsorbColor.a)
end

function UF:UpdateHealComm(_, myIncomingHeal, otherIncomingHeal, absorb, healAbsorbAmount, hasOverAbsorb, hasOverHealAbsorb, health, maxHealth)
	local frame = self.frame
	local db = frame and frame.db and frame.db.healPrediction
	if not db or not db.absorbStyle then return end

	local pred = frame.HealthPrediction
	local healAbsorb = pred.healAbsorb
	local damageAbsorb = pred.damageAbsorb

	UF:SetSize_HealComm(frame)

	if ElvUI335 then -- ElvUI Wotlk: laid out from the values (see UpdateHealComm335)
		return UF:UpdateHealComm335(frame, db, myIncomingHeal, otherIncomingHeal, absorb, healAbsorbAmount, hasOverAbsorb, hasOverHealAbsorb, health, maxHealth)
	end

	-- absorbs is set to none so hide both
	if E.Classic or db.absorbStyle == 'NONE' then
		healAbsorb:Hide()
		damageAbsorb:Hide()

		return -- dont proceed
	end

	-- the anchors and colors below only depend on the over states, dont redo them on every health event
	local overState = (hasOverAbsorb and 1 or 0) + (hasOverHealAbsorb and 2 or 0)
	if pred.overState == overState and (E.Modern or overState == 0) then return end
	pred.overState = overState

	-- handle over heal absorbs
	healAbsorb:ClearAllPoints()
	healAbsorb:Point(pred.anchor, frame.Health)

	local colors = UF.db.colors.healPrediction
	if hasOverHealAbsorb then -- forward fill it when its greater than health so that you can still see this is being stolen
		healAbsorb:SetReverseFill(pred.reverseFill)
		healAbsorb:Point(pred.anchor1, pred.healthBarTexture, pred.anchor2)
		healAbsorb:SetStatusBarColor(colors.overhealabsorbs.r, colors.overhealabsorbs.g, colors.overhealabsorbs.b, colors.overhealabsorbs.a)
	else -- otherwise just let it backfill so that we know how much is being stolen
		healAbsorb:SetReverseFill(not pred.reverseFill)
		healAbsorb:Point(pred.anchor2, pred.healthBarTexture, pred.anchor2)
		healAbsorb:SetStatusBarColor(colors.healAbsorbs.r, colors.healAbsorbs.g, colors.healAbsorbs.b, colors.healAbsorbs.a)
	end

	-- color absorb bar if in over state
	if hasOverAbsorb then
		damageAbsorb:SetStatusBarColor(colors.overabsorbs.r, colors.overabsorbs.g, colors.overabsorbs.b, colors.overabsorbs.a)
	else
		damageAbsorb:SetStatusBarColor(colors.absorbs.r, colors.absorbs.g, colors.absorbs.b, colors.absorbs.a)
	end

	-- no need to proceed for retail here, we cant use these modes anymore
	if E.Modern then return end

	-- if we are in normal mode and overflowing happens we should let a bit show, like blizzard does
	if db.absorbStyle == 'NORMAL' then
		if hasOverAbsorb and health == maxHealth then
			damageAbsorb:SetValue(1.5)
			damageAbsorb:SetMinMaxValues(0, 100)
		end
	elseif hasOverAbsorb then -- non normal mode overflowing
		if db.absorbStyle == 'WRAPPED' then -- engage backfilling
			damageAbsorb:SetReverseFill(not pred.reverseFill)

			damageAbsorb:ClearAllPoints()
			damageAbsorb:Point(pred.anchor, pred.health)
			damageAbsorb:Point(pred.anchor2, pred.health, pred.anchor2)
		elseif db.absorbStyle == 'OVERFLOW' then -- we need to display the overflow but adjusting the values
			local overflowAbsorb = absorb * (colors.maxOverflow or 0)
			if health == maxHealth then
				damageAbsorb:SetValue(overflowAbsorb)
			else -- fill the inner part along with the overflow amount so it smoothly transitions
				damageAbsorb:SetValue((maxHealth - health) + overflowAbsorb)
			end
		end
	elseif db.absorbStyle == 'WRAPPED' then -- restore wrapped to its forward filling state
		damageAbsorb:SetReverseFill(pred.reverseFill)

		damageAbsorb:ClearAllPoints()
		damageAbsorb:Point(pred.anchor, pred.health)
		damageAbsorb:Point(pred.anchor1, pred.healingOtherTexture, pred.anchor2)
	end
end
