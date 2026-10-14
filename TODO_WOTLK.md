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

## Skins des fenêtres Blizzard (2026-10-14)

Les skins de l'ElvUI 6.10, écrits pour les cadres 3.3.5, sont importés dans `ElvUI\Game\Wrath\Skins335` (39 fenêtres,
import : `outils\elvui335_skins610.js`, puis corrigés à la main). `Skins335\Adapter.lua` traduit les appels 6.10 vers
les fonctions de cette version. Les skins Wrath des mêmes fenêtres sont coupés en 3.3.5 (`S.Unported335`).
Carte, inspection, raccourcis : branche 3.3.5 dans leur fichier Wrath.

- [ ] Vérifier en jeu chaque fenêtre (rendu, positions) : personnage, grimoire, talents, quêtes, hauts faits, amis,
      PvP, recherche de donjon, aide, menu Échap, marchand, courrier, échange, métiers, hôtel des ventes...

## Repris d'ElvUI_Enhanced (2026-10-14)

- [x] Fiche personnage d'ElvUI_Enhanced, activée par défaut (`Game\Wrath\Enhanced335\CharacterFrame`, options : Général ->
      Améliorations Blizzard -> Character Frame). **(à vérifier en jeu)**
- [x] Boutons « AddOns » (liste des addons d'ElvUI_Enhanced) et « ElvUI » du menu Échap. **(à vérifier en jeu)**
- [ ] Textes d'enchantement à côté des emplacements : viennent d'ElvUI_ProjectZidras (LibGetEnchant), pas encore repris.

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
- [x] Profils entre comptes WoW (GOSAJAW -> SAANN) : chaque compte a son propre `ElvUI.lua`, passer par
      l'export / import au format table Lua (fonctionne en jeu ; le format texte de la 6.10 est refusé avec un message clair).

## Test en jeu n°9 (2026-10-14)

- [x] Infobulle en inspectant : `GetInspectSpecialization` absent de Rebuffed (niveau d'objet calculé sans). **(à revérifier)**
- [x] Bouton OK du sélecteur de couleur : la 3.3.5 appelle `ColorPickerFrame.func` (ElvUI ne remplissait que `swatchFunc`). **(à revérifier)**
- [x] Options des plaques : lecture d'une cvar absente de la 3.3.5. **(à revérifier)**
- [x] Fenêtre d'inspection : skin de l'ElvUI 6.10 porté, niveau d'objet placé sur `InspectPaperDollFrame`. **(à revérifier)**

## Reprise après le test en jeu n°6 (2026-10-04)

Ancien ElvUI remis en place ; la version testée est dans `Backport Wotlk\_retire du jeu (ElvUI Wotlk test 6)`.
Fonctionnent en jeu : plaques de nom, cadres joueur / cible / cible de la cible, clavier, options (`/ec`).

- [x] La carte du monde ne s'ouvre pas : la « petite carte » la rattachait à UIParent, que la carte plein écran
      3.3.5 masque. Carte Blizzard d'origine pour l'instant (+ coordonnées ElvUI). **(corrigé, à revérifier)**
- [x] Carte plein écran trop grande : la « petite carte » de l'ElvUI 6.10 portée (la carte devient un panneau centré de UIParent, réglage « Smaller World Map Scale »). **(à revérifier)**
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
