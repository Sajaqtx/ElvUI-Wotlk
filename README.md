# ElvUI Wotlk

**ElvUI v16.00 for the World of Warcraft 3.3.5a client.**

This is a backport of the current ElvUI (Wrath Classic flavor, v16.00) to the 3.3.5 client. It replaces the old
ElvUI 6.x builds that 3.3.5 servers usually run. ElvUI_Enhanced and ElvUI_AddOnSkins are updated to work with it.

It is built and tested on **Whitemane – Frostmourne Rebuffed**. The Rebuffed client ships `rebuffed.dll`, which adds a few
later APIs (`C_NamePlate`, `GetSpecialization`, `Mixin`, `SetAtlas`...). The nameplates rely on them, so other 3.3.5
clients are **not supported**.

## Installation

1. Close the game.
2. Remove (or move out) any older ElvUI: the `ElvUI`, `ElvUI_Config` / `ElvUI_Options` and plugin folders in
   `Interface\AddOns`.
3. Copy the five folders of this repository into `Interface\AddOns`:

   | Folder | What it is |
   |---|---|
   | `ElvUI` | the UI |
   | `ElvUI_Libraries` | its libraries and the 3.3.5 compatibility layer (required) |
   | `ElvUI_Options` | the configuration window (`/ec`), loaded on demand |
   | `ElvUI_Enhanced` | optional plugin with extra features |
   | `ElvUI_AddOnSkins` | optional plugin, ElvUI style for other 3.3.5 addons |

4. Start the game and follow the ElvUI installer.

**Bringing your ElvUI 6.x profile.** ElvUI 6.x can export a profile as a Lua table: export it there, then import
it in this version (`/ec` → Profiles → Import). The text format of 6.x cannot be read and is refused with a message.
The settings that exist in both versions carry over. The rest falls back to the v16 defaults.

## How the port works

ElvUI v16 is written for the Wrath Classic client (3.4.x), which has far more API than 3.3.5. The port keeps
ElvUI's own code as close to upstream as possible. What the old client lacks is provided underneath:

- **A private environment.** Every ElvUI file runs in `ElvUI335_ENV` (a `setfenv` on its first line). It holds the
  later functions, `C_*` namespaces, constants, mixins and templates ElvUI expects, built on 3.3.5 calls.
  **Nothing is added to the global environment**, so other addons keep seeing a normal 3.3.5 client.
  It lives in `ElvUI_Libraries/Game/Shared/Compat335/`:
  - `Compat335.lua`: the environment, events, frames, atlases;
  - `Compat335_API.lua`: the API;
  - `Compat335_Tables.lua`: constants and tables;
  - `Compat335_HealPrediction.lua`: heal prediction;
  - `Compat335_LibStub.lua`: library isolation.
- **Events.** Later event names are mapped to their 3.3.5 equivalents (power, group, vehicle and nameplate events…).
  This includes per-unit event filtering, which 3.3.5 does not have.
- **Blizzard functions are never replaced.** The port only adds what is missing, and uses `hooksecurefunc` for the
  rest. Replacing client functions would taint the secure frames and block actions in combat.
- **Private libraries.** ElvUI's newer Ace3 GUI and newer shared libraries stay out of the global `LibStub`, so the
  other 3.3.5 addons keep the library versions they were written for.
- **Features with no 3.3.5 equivalent are removed** rather than left half-working. Examples: Mythic+, warbands,
  Edit Mode, the retail talent and profession frames, extra action buttons.

## What changed, module by module

### Unit frames
- All units and group headers work on 3.3.5. Group headers use `initialConfigFunction`, and unit menus use the 3.3.5
  dropdowns.
- Group roles come from the talent spec and are checked again when a fight starts.
- Heal prediction comes from LibHealComm-4.0, absorbs from SpecializedAbsorbs, with all four layout styles.
  An *Incoming Heals* toggle shows absorbs only.
- Groups that are disabled create no frames, which shortens login and `/reload`. The raid frames show 2 groups by
  default.

### Nameplates
- Built on the client's native plates (`rebuffed.dll` `C_NamePlate`). The stock plate parts are hidden and the
  ElvUI plate is centered on them.
- *Clickable Size* sets the real plate hitbox. Also available: *Motion Speed*, stacking with *Overlap H/V*, and a
  draw order that keeps the targeted plate on top.
- Plate auras follow their unit without a retarget. They are refreshed from the combat log, so a reapplied DoT
  restarts its sweep on plates you are not targeting.
- **Style Filters are back** (removed upstream in ElvUI 15), with mob type colors and triggers. Interruptible
  casts and cooldowns are compared against a 1.5 s global cooldown.
- One-pixel borders and the 6.x text formats are available.

### Action bars
- The bars run on LibActionButton, with 3.3.5 macro conditions: vehicle and possess pages use `[bonusbar:5]`.
  Conditions 3.3.5 does not know are removed from the state drivers.
- Secure buttons fire once per click. *Key Down* is an ElvUI setting, and *Auto Add New Spells* is hidden.
- The micro bar has the 3.3.5 buttons, in order, and up to 13 per row.

### Bags, loot, minimap, chat, tooltips, data texts
- **Bags:** one combined bag. Bank bags, sorting and empty slots are handled the 3.3.5 way.
- **Loot:** loot and loot roll frames, with 3.3.5 alert anchors.
- **Minimap:** middle-click opens the menu, right-click opens tracking, the mouse wheel zooms.
- **Chat:** tab menus, edit box, copy, URL links. *Auto accept invites* works for friends, Real ID and guild.
  *Auto Track Reputation* also reads the chat reputation lines.
- **Tooltips:** spell IDs come from the spell link. Inspect item level works without `GetInspectSpecialization`.
- **Item level on the character frame:** enchants are read from the item link. Missing enchants are flagged per
  WotLK slot (enchant table from ElvUI_ProjectZidras).
- **Data texts:** the guild member status is mapped. Retail-only data texts are removed (token, warband,
  Mythic+).
- **Other:** the AFK screen, mover popups, color picker (with hex input), cooldown text and *Apply Font To All*
  are fixed for 3.3.5.

### Blizzard windows
- The 3.3.5 frames are skinned with the ElvUI 6.10 skins, ported into this version (`ElvUI/Game/Wrath/Skins335`,
  about 40 windows). They cover the character, spellbook, talents and glyphs, quests, achievements, friends, PvP,
  LFD/LFR, mail, merchant, auction house, guild bank, trade skills, trainer, calendar, macros, key bindings, world
  map and more.
- The world map can be reduced, as in ElvUI 6.10.

### ElvUI_Enhanced (plugin)
- The 3.3.5 ElvUI_Enhanced plugin, ported to this ElvUI. Features ElvUI v16 already has were removed. The
  remaining ones include:
  - Train All, Take All Mail, buy a stack;
  - Already Known, quest level, best quest reward;
  - Lose Control, interrupt tracker, death recap;
  - minimap button grabber, minimap location, fog clear;
  - model frame controls, dress-up undress button, key press animation;
  - equipment durability, detached portrait;
  - Enhanced character frame and addon list.

### ElvUI_AddOnSkins (plugin)
- AddOnSkins 1.06 for 3.3.5, ported to this ElvUI: skins for about 90 period addons (DBM, Omen, Recount, Skada,
  AtlasLoot, Auctionator, WeakAuras, Postal, BugSack…).

## Known issues

- **Vehicles:** the cast bar can stay inactive in a vehicle, and allies' health may not update while they ride one.
  The vehicle action bar fix still has to be confirmed in game.
- Rendering and taint can only be checked in game. Please report any *"Interface action failed because of an
  AddOn"* message with what you were doing.

## Reporting a bug

Install BugGrabber + BugSack. Reproduce the bug, `/reload`, and send the first error from BugSack. Include its full
stack, your class, and what you were doing.

## Credits and license

- **ElvUI** by Elv and Simpy, and the Tukui community: https://github.com/tukui-org/ElvUI
- **ElvUI_Enhanced** (3.3.5) by Bunny, Apollyon, Loaal and Crum.
- **ElvUI_AddOnSkins** (3.3.5) by Bunny, Azilroka and Sortokk.
- Enchant table from ElvUI_ProjectZidras.
- The 3.3.5 port by Sajaqtx.

ElvUI is distributed under its own license (`ElvUI/LICENSE.txt`). It allows private modifications and publishing
on GitHub, requires the folder names to stay unchanged, and requires its copyright notice in every copy.
