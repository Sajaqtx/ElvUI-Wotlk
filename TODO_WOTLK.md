# ElvUI Wotlk : état du backport et reste à faire

ElvUI v16 (saveur Wrath, branche `main`, dépôt privé https://github.com/Sajaqtx/ElvUI-Wotlk) sur le client 3.3.5 Frostmourne Rebuffed (Whitemane). Tout ce qui manque au client est dans
`ElvUI_Libraries\Game\Shared\Compat335` (environnement privé `ElvUI335_ENV`, invisible des autres addons).

## Points ouverts (2026-10-17)

- [ ] Véhicules : castbar inactive et vie des alliés figée en véhicule. Relevé à faire en jeu : `/elvtest vehicle`
      (ElvUI_Diag), puis corriger la bascule d'unité d'oUF selon les noms que le client donne au véhicule.
- [ ] Barre de véhicule (relais LibActionButton, commit 91e32eb) : à confirmer en jeu.
- [x] Fenêtres Blizzard habillées : tour fait en jeu le 2026-10-17, toutes bonnes.
- [x] Addon de test `ElvUI_EnhancedAllOn` retiré du client de test (2026-10-17).
- [x] `merge-v16` fusionné dans `main` et publié (dépôt privé) le 2026-10-17.
- [x] Texture hachurée des absorptions : abandonnée.

La suite : corrections au fil du jeu.

Fait depuis le 2026-10-15 (validé en jeu sauf mention) : Style Filters (ElvUI 14) avec filtres de mobs, Kick CD et
non-attaquables ; absorptions et soins entrants (placement des 4 styles) ; ordre d'affichage des plaques ; hitbox et
vitesse des plaques ; liste CC (contrôles durs et silences) ; sacs, LootRoll, menu clic milieu de la minicarte,
invitation auto (amis, guilde), chat, hauts faits ; ElvUI_Enhanced en plugin compatible (doublons retirés) ;
enchantements et enchantements manquants de l'item level (table de Zidras) ; Apply Font To All sur toutes les polices ;
Key Down en réglage ElvUI ; un seul déclenchement par clic des boutons sécurisés ; « raidN is not in your party » ;
balayage des auras rafraîchies sur les plaques ; atlas absents remplacés (pièce de camelote, « ! » de quête).

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

- [x] Vérifier en jeu chaque fenêtre (fait le 2026-10-17 : bonnes) (rendu, positions) : personnage, grimoire, talents, quêtes, hauts faits, amis,
      PvP, recherche de donjon, aide, menu Échap, marchand, courrier, échange, métiers, hôtel des ventes...

## Repris d'ElvUI_Enhanced (2026-10-14)

- [x] Fiche personnage d'ElvUI_Enhanced, activée par défaut (`Game\Wrath\Enhanced335\CharacterFrame`, options : Général ->
      Améliorations Blizzard -> Character Frame). **(à vérifier en jeu)**
- [x] Boutons « AddOns » (liste des addons d'ElvUI_Enhanced) et « ElvUI » du menu Échap. **(à vérifier en jeu)**
- [x] Textes d'enchantement à côté des emplacements : lien de l'objet + table de LibGetEnchant (ElvUI_ProjectZidras),
      dans l'item level natif (`Game\Wrath\General\Enchants.lua`).

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

- [x] Hooks ignorés (`ElvUI335.skippedHooks`) : revus le 2026-10-17, tous visent des fonctions absentes en 3.3.5
      (cadres de raid compacts, infobulles intégrées, sorts en éventail, barres de progression d'infobulle, LFG list).
- [x] Atlas absents de Rebuffed : pièce de camelote et « ! » de quête remplacés par des textures 3.3.5 (compat
      `SetAtlas`) ; les autres (démontage, parangon, sorts en éventail) sont des fonctions absentes de la 3.3.5.
- [x] Bulles de discussion : le skin ElvUI marche sur la bulle 3.3.5 ; style « Disable » = ChatBubbleSkin, et « Replace Font »
      garde la police ElvUI sur ses bulles. **(à vérifier en jeu)**
- [x] Données (DataTexts) : jeton WoW, bataillon et Mythique+ ne s'affichent pas en 3.3.5 (réservés retail / MoP).

## Nettoyage retail et plugins (2026-10-15)

- [x] Skins : la liste ne montre que les fenêtres 3.3.5 skinnées ; Tutorial lit la bonne clé (skin 6.10 porté).
- [x] Masqués : Boss Button, Zone Button (barres et Cooldown & Duration), Alternative Power.
- Plugins ElvUI_Enhanced / ElvUI_ProjectZidras (6.10) : ils s'appuient sur les internes de la 6.10, pas chargeables tels
  quels ; ce qui manque est porté en natif (dossier Wrath/Enhanced335, désactivé par défaut), sans plugin.
  - Déjà dans la v15 (pas de doublon) : suivi de réputation auto, texte de zone, lieu sur la minicarte, bordure de
    qualité des infobulles, meilleure récompense de quête, ilvl / enchantements / gemmes des emplacements (WrathArmory),
    DataTexts (stats, munitions, combat, ilvl, courrier), icônes de rôle LFG dans le chat, tags [guild] [npctitle]
    [target] des plaques, barres de cast des plaques par unité, masquage du suivi d'objectifs.
  - Déjà portés : feuille de personnage Enhanced, liste des addons.
  - [x] Soins entrants + absorptions (LibHealComm-4.0 + SpecializedAbsorbs) : faits, validés en jeu.
  - [x] Choisi (2026-10-17) : ElvUI_Enhanced reste un plugin à part, rendu compatible, sans ce que la v16 a déjà.
        Liste d'origine : regroupement des boutons de minicarte, carte sans brouillard, Lose Control, suivi des interruptions,
        récap de mort, « tout prendre » du courrier, déjà connu, tout apprendre, achat par pile, déshabiller, refus des
        duels, libération auto en JcJ, niveau des quêtes, icône des infobulles, taille du cadre d'erreurs, animation
        des touches, liens DPS, couronne du maître de guilde dans le chat.
  - Sans objet : ProgressionInfo (raids Cataclysm), Analyzer, compatibilité addons.
