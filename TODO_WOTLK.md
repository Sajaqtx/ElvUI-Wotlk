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
- [ ] Carte du monde, Aide, Options Blizzard, Liste des addons, Fenêtres diverses (BlizzardMiscFrames : menu Échap...)
- [ ] Battle.net, Paramètres (SettingsPanel), Éditeur (EditorManagerFrame) : retail, sans doute à retirer

## Reprise après le test en jeu n°6 (2026-10-04)

Ancien ElvUI remis en place ; la version testée est dans `Backport Wotlk\_retire du jeu (ElvUI Wotlk test 6)`.
Fonctionnent en jeu : plaques de nom, cadres joueur / cible / cible de la cible, clavier, options (`/ec`).

- [ ] La carte du monde ne s'ouvre pas.
- [ ] Les sacs s'ouvrent un par un au lieu du sac unique d'ElvUI ; erreur `BagBar.lua:239`
      (`ToggleAllBags` absent en 3.3.5 : `OpenAllBags` / `ToggleBackpack`).
- [ ] `Tooltip.lua:1062` : `format` reçoit une chaîne au lieu d'un nombre (x5).
- [ ] Relevé de la structure des plaques natives Rebuffed : `test6_plaque.txt` ; erreurs complètes : `test6_erreurs.txt`.

## Autres points ouverts

- [ ] Hooks ignorés (fonctions absentes en 3.3.5, liste `ElvUI335.skippedHooks` affichée par le simulateur) :
      vérifier qu'aucun ne manque à une fonction visible.
- [ ] Atlas absents de Rebuffed (`ElvUI335.missingAtlases`) : pièce de camelote et icône « à démonter » des sacs,
      point d'exclamation de quête des plaques, sac de parangon, flèches de rotation. Remplacer par des textures 3.3.5.
- [ ] Bulles de discussion : le module d'ElvUI ou l'addon ChatBubbleSkin, pas les deux.
- [ ] Données (DataTexts) liées au retail à retirer de la liste : logement, Mythique+, jetons WoW...
