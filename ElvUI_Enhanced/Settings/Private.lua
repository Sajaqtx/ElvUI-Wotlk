setfenv(1, ElvUI335_ENV) local E, L, V, P, G = unpack(ElvUI)

-- ElvUI Wotlk: ElvUI holds the character frame part natively: its defaults kept over these
local native = V.enhanced

V.enhanced = {
	animatedAchievementBars = false,
	deathRecap = false,
	actionbar = {
		keyPressAnimation = false
	},
	character = {
		enable = false,
		modelFrames = true, -- ElvUI Wotlk: on by default (the rotate / zoom / drag controls of the model frames, centered)
		collapsed = false,
		player = {
			orderName = "",
			collapsedName = {
				ITEM_LEVEL = false,
				BASE_STATS = false,
				MELEE_COMBAT = false,
				RANGED_COMBAT = false,
				SPELL_COMBAT = false,
				DEFENSES = false,
				RESISTANCE = false
			}
		},
		pet = {
			orderName = "",
			collapsedName = {
				ITEM_LEVEL = false,
				BASE_STATS = false,
				MELEE_COMBAT = false,
				RANGED_COMBAT = false,
				SPELL_COMBAT = false,
				DEFENSES = false,
				RESISTANCE = false
			}
		}
	},
	timerTracker = {
		enable = false
	},
	loseControl = {
		enable = false
	},
	interruptTracker = {
		enable = false,
		everywhere = false,
		arena = true,
		battleground = false
	},
	minimapButtonGrabber = false
}

if native then E:CopyTable(V.enhanced, native) end
