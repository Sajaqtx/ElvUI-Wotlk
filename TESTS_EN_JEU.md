# ElvUI Wotlk : checklist des tests en jeu

Cases cochées = déjà validé par toi en jeu. Cases vides = à tester.
Les lignes marquées **(corrigé, à revérifier)** ont eu une erreur lors d'un test précédent.

## Avant de commencer

- [ ] Premier lancement : redémarrage complet du client (nouveaux dossiers d'addons).
- [ ] BugGrabber / BugSack activés.
- [ ] Après chaque bloc : `/reload`, puis me dire « c'est fait » (je lis les erreurs moi-même).
- [ ] L'installation d'ElvUI se lance au premier démarrage : la suivre (ou la passer) puis `/reload`.

## 1. Démarrage

- [ ] Pas de fenêtre d'erreur au chargement, ElvUI affiche son message de bienvenue dans le chat.
- [ ] `/ec` ouvre les options ; on peut naviguer entre les onglets.
- [ ] `/moveui` affiche les cadres déplaçables, on peut en déplacer un et le remettre.

## 2. Cadres d'unité

- [ ] Joueur : vie, mana / rage / énergie / puissance runique, portrait, nom, niveau.
- [ ] Cible : apparaît en ciblant, vie, nom, auras (buffs / debuffs), barre d'incantation quand elle incante.
- [ ] Cible de la cible, focus (`/focus`), familier (chasseur / démoniste / chevalier de la mort).
- [ ] Clic droit sur le cadre joueur / cible : le menu s'ouvre.
- [ ] Groupe : les membres apparaissent, vie, mana, rôle ; clic gauche cible, clic droit menu.
- [ ] Raid (si possible) : cadres de raid, debuffs.
- [ ] Barre d'incantation du joueur : incantation, canalisation, interruption.

## 3. Barres d'action

- [ ] Barre 1 : sorts, temps de recharge, portée (rouge hors de portée), raccourcis affichés.
- [ ] Changement de page (Maj + molette ou raccourcis), barres 2 à 6.
- [ ] Forme / posture (guerrier, druide, voleur camouflé) : la barre 1 change de page.
- [ ] Véhicule (ex. Joug-d'hiver, quêtes à véhicule) : la barre affiche les sorts du véhicule, bouton de sortie.
- [ ] Barre de familier (auto-incantation qui brille), barre de postures, barre de totems (chaman).
- [ ] **En combat** : utiliser les barres, changer de cible : aucune « action bloquée » (taint).

## 4. Plaques de nom

- [ ] Ennemis : vie, nom, niveau, barre d'incantation, debuffs posés par toi.
- [ ] Alliés, PNJ, cible mise en évidence, marqueurs de raid.
- [ ] Les plaques Blizzard d'origine ne se voient plus derrière celles d'ElvUI.

## 5. Auras du joueur (en haut à droite)

- [ ] Buffs et debuffs avec leur durée, tri, enchantements d'arme (poison, pierre à aiguiser).
- [ ] Clic droit sur un buff hors combat : il est annulé.

## 6. Chat, sacs, minicarte, infobulles

- [ ] Chat : onglets, copier le chat, liens d'objets cliquables, chuchotements.
- [ ] Sacs (B) : un seul grand sac, tri, recherche, or, monnaies (points d'honneur / d'arène...), banque.
- [ ] Minicarte : zone, coordonnées, boutons, horloge.
- [ ] Infobulles : objets, unités (barre de vie sous l'infobulle), sorts.
- [ ] Carte du monde (M) : coordonnées joueur / souris.

## 7. Données (barres en bas)

- [ ] Or, durabilité, temps (heure, Joug-d'hiver), FPS / latence, amis, guilde.
