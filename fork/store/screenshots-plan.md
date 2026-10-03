# Captures d'écran : plan (test interne puis fiche publique)

Règles Play Store : 2 à 8 captures téléphone, PNG ou JPEG, 16:9 ou 9:16, côté court de 320 à 3 840 px.
Format conseillé : captures réelles du Xiaomi (portrait). Icône 512x512 PNG (depuis `fork/brand/`) et
image de présentation 1024x500 PNG en plus. Aucune capture n'est requise pour le test interne ; elles
serviront à la fiche publique.

Préparer le téléphone : thème clair ou sombre au choix mais le même partout, oiseau-thème identique, langue
française, barre d'état propre (batterie pleine, heure 9:41), **pas de lieu privé visible** (GPS d'un
lieu public, ou carte désactivée pour les captures qui n'en ont pas besoin). Cartes en ligne activées
seulement pour la capture n° 5.

| # | Écran | État à préparer |
|---|---|---|
| 1 | Accueil | Série de jours en cours, quelques espèces du jour (état non vide), bouton Écouter visible. |
| 2 | Écoute en cours | Session active avec 4 à 6 espèces dont au moins une Sûr, une Probable, une À vérifier ; spectrogramme en mouvement. Source : extrait audio de démonstration joué près du micro, ou session rejouée. |
| 3 | Fiche d'une espèce | Une espèce commune (merle noir ou rougegorge), photo, bloc « Entendu », description ; faire défiler pour montrer aussi la carte du monde. |
| 4 | Carte du monde de la fiche | Bouton d'agrandissement : page plein écran zoomée sur l'aire d'une espèce migratrice (hirondelle rustique) pour que les saisons se voient. |
| 5 | Carte des contacts | Cartes en ligne activées, 10 à 15 contacts autour d'un lieu public, quelques grappes. |
| 6 | Quiz | Une question avec le bouton de lecture, avant la réponse. |
| 7 | Carnet | Liste des espèces ou d'une session, statuts de revue variés. |
| 8 | Profil | Oiseau-thème, statuts gagnés, série ; données de démonstration réalistes. |

Si on garde 6 captures : 1, 2, 3, 4, 6, 8.

## Brouillons possibles : goldens de test

Ce ne sont **pas** de vraies captures (polices et photos de test, pas de vraie donnée, taille 400x900 ou
412x1900), seulement des repères de composition :

- Accueil : `test/fork/goldens/home_<oiseau>_<light|dark>.png` (loriot, martin, flamant, étourneau).
- Écoute : `test/fork/goldens/live_<oiseau>_<light|dark>.png` (400x900).
- Fiche espèce : `test/fork/goldens/species_page_<oiseau>_<light|dark>.png` (412 de large, hauteur 1900,
  donc page complète à défiler) et `species_page_never_heard_*`.
- Feuille « Plus » de l'accueil : `test/fork/home/goldens/`.

Pas de golden pour la carte, le quiz, le carnet ni le profil : captures réelles obligatoires.
