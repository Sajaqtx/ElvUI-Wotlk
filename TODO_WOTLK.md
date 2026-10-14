# ElvUI Wotlk : état du backport et reste à faire

ElvUI v15.26 (saveur Wrath) sur le client 3.3.5 Frostmourne Rebuffed. Tout ce qui manque au client est dans
`ElvUI_Libraries\Game\Shared\Compat335` (environnement privé `ElvUI335_ENV`, invisible des autres addons).

## État dans le simulateur (`outils/wowsim/elvui.sh`)

- ElvUI s'initialise, tous les modules aussi (barres d'action, cadres d'unité, plaques, auras, chat, données,
  sacs, minicarte, infobulles, skins), et les options s'ouvrent.
- Vérifié contre les unités simulées : cadre joueur (vie, mana), cible, barre 1, buff du joueur, groupe de 5
  (le joueur puis party1-4, bonne vie), plaque ennemie native Rebuffed (nom, vie).
- 0 erreur ElvUI. Les erreurs restantes du rapport viennent du FrameXML 3.3.5 avec les fonctions natives que
  le simulateur ne fait que simuler.

## Ce que le simulateur ne peut pas vérifier (à voir en jeu)

- Taint : actions bloquées en combat (« Interface action failed because of an AddOn »).
- Rendu : tailles, textures, polices, échelle de l'interface.
- Les fonctions de rebuffed.dll (C_NamePlate, spécialisations...) avec leurs vraies valeurs.
- Pagination des barres en véhicule / possession / forme, barre de familier, totems.

## Skins pas encore portés aux cadres 3.3.5

Ces fenêtres gardent l'aspect Blizzard d'origine (liste `S.Unported335` dans `Modules\Skins\Skins.lua`).
Référence pour les porter : l'ElvUI 6.10 de `Addons ressource\ElvUI\ElvUI 3.3.5\ElvUI\Modules\Skins\Blizzard`.

- [ ] Personnage (CharacterFrame), Grimoire (SpellBookFrame), Quêtes (BlizzardQuestFrames), Dialogue PNJ (GossipFrame)
- [ ] Marchand, Courrier, Échange, Butin (LootFrame), Tabard, Cabine d'essayage, Charte de guilde
- [ ] Amis (FriendsFrame), Recherche de groupe (LookingForGroupFrames), Raid (RaidInfoFrame), Champ de bataille, PvP
- [ ] Aide, Options Blizzard, Liste des addons, Fenêtres diverses (BlizzardMiscFrames : menu Échap...)
- [ ] Battle.net, Paramètres (SettingsPanel), Éditeur (EditorManagerFrame) : retail, sans doute à retirer

## Client de test (depuis le 2026-10-14)

Les tests se font dans une copie du jeu, `C:\Users\soula\Games\WoW 3.3.5 Test ElvUI` (raccourci « WoW 3.3.5 Test
ElvUI » sur le bureau, connexion à la main). Le client de jeu habituel garde l'ElvUI Rebuffed 6.10 : plus besoin de
sauvegarder puis remettre l'ancien ElvUI entre deux tests.

## Test en jeu n°7 (2026-10-14, client de test)

Sacs et infobulle des sorts : bons. Carte : s'ouvre.

- [x] `/ec` ne s'ouvrait pas : en 3.3.5 `IsAddOnLoaded` rend `1`/`nil`, et avec DBM chargé l'option « Auto Hide »
      du suivi d'objectifs recevait `hidden = 1`, refusé par AceConfig (qui rejette alors toutes les options).
      `C_AddOns.IsAddOnLoaded` rend maintenant un booléen. **(corrigé, à revérifier)**
- [x] Carte sans skin ElvUI : skin de l'ElvUI 6.10 porté (cadres de la carte 3.3.5). **(corrigé, à revérifier)**

## Test en jeu n°8 (2026-10-14, client de test)

`/ec` et le skin de la carte : bons.

- [x] Impossible de sortir du mode AFK : le modèle 3.3.5 n'a pas `SetAnimation` (c'est `SetSequence`), l'erreur
      arrivait après avoir caché l'interface et avant de noter le mode AFK actif. Les deux corrigés. **(à revérifier)**
- [x] Ancrages (movers) : la fenêtre du mode déplacement créait un menu déroulant 11.0 (`WowStyle1DropdownTemplate`)
      et s'arrêtait avant la fenêtre d'ajustement (`MoverNudgeFrame`, 104 erreurs). Menu 3.3.5 maintenant. **(à revérifier)**
- [x] Fenêtre des raccourcis clavier : skin de l'ElvUI 6.10 porté (cadres 3.3.5). **(à revérifier)**
- [x] Import de profil au format « table Lua » (celui que l'ElvUI 6.10 sait exporter) : ElvUI v15 ajoutait une `}`
      de trop. **(à revérifier)**
- [ ] Profils entre comptes WoW (GOSAJAW -> SAANN) : chaque compte a son propre `ElvUI.lua`, passer par
      l'export / import.

## Reprise après le test en jeu n°6 (2026-10-04)

Ancien ElvUI remis en place ; la version testée est dans `Backport Wotlk\_retire du jeu (ElvUI Wotlk test 6)`.
Fonctionnent en jeu : plaques de nom, cadres joueur / cible / cible de la cible, clavier, options (`/ec`).

- [x] La carte du monde ne s'ouvre pas : la « petite carte » la rattachait à UIParent, que la carte plein écran
      3.3.5 masque. Carte Blizzard d'origine pour l'instant (+ coordonnées ElvUI). **(corrigé, à revérifier)**
- [ ] Refaire la « petite carte » d'ElvUI à la manière 3.3.5 (sans reparenter la carte).
- [x] Les sacs s'ouvraient un par un : un seul sac qui suit le sac à dos Blizzard, comme l'ElvUI 6.10. **(corrigé, à revérifier)**
- [x] `Tooltip.lua:1062` (ID du sort dans l'infobulle) : en 3.3.5 `GetSpell` donne le rang, l'ID vient du lien
      du sort. **(corrigé, à revérifier)**
- [x] Relevé de la structure des plaques natives Rebuffed : conforme au simulateur, elles sont bien vidées.
- [ ] (archive) relevé : `test6_plaque.txt` ; erreurs complètes : `test6_erreurs.txt`.

## Autres points ouverts

- [ ] Hooks ignorés (fonctions absentes en 3.3.5, liste `ElvUI335.skippedHooks` affichée par le simulateur) :
      vérifier qu'aucun ne manque à une fonction visible.
- [ ] Atlas absents de Rebuffed (`ElvUI335.missingAtlases`) : pièce de camelote et icône « à démonter » des sacs,
      point d'exclamation de quête des plaques, sac de parangon, flèches de rotation. Remplacer par des textures 3.3.5.
- [ ] Bulles de discussion : le module d'ElvUI ou l'addon ChatBubbleSkin, pas les deux.
- [ ] Données (DataTexts) liées au retail à retirer de la liste : logement, Mythique+, jetons WoW...
