# Maquette de l'interface

Référence visuelle de BirdyGo pour J6 (voir `fork/PLAN.md`). Le canevas se consulte sur claude.ai :
https://claude.ai/artifact/C6XUNf7AKdf1YUZzRr1K3j (privé : visible par Benjamin seulement).

Ce dossier en garde la source, pour que les sessions cloud puissent la lire. Les fichiers `.dc.html`
ne s'ouvrent pas seuls dans un navigateur : ils ont besoin du moteur du canevas. Ce sont des
maquettes avec des données fictives, pas du code de l'app.

## Contenu

| Fichier | Écran |
|---|---|
| `Main.dc.html` | Accueil |
| `Live.dc.html` | Écoute en direct : le tableau s'alimente seul, compteurs de session et totaux |
| `LiveSpectre.dc.html` | Écoute avec le spectrogramme agrandi |
| `Resume.dc.html` | Bilan de l'écoute, envoi à Faune-France |
| `Arrivee.dc.html` | Moment : un oiseau arrive dans le tableau |
| `Premiere.dc.html` | Moment : première fois |
| `Rare.dc.html` | Moment : oiseau rare, confirmé avant la fête |
| `Niveau.dc.html` | Moment : nouveau statut |
| `Carnet.dc.html` | Carnet façon collection, silhouettes mystère |
| `Profil.dc.html` | Statut, badges, série, défis |
| `Palmares.dc.html` | Palmarès |
| `Carte.dc.html` | Carte des contacts avec les icônes d'oiseaux |
| `Fiche.dc.html` | Fiche espèce |
| `Revue.dc.html` | Revue rapide |
| `Especes.dc.html` | Planche des icônes d'espèces |

- `canvas.json` : disposition des écrans sur le canevas.
- `SPEC.md` : la spécification complète (jetons de couleur, composants, animations, système de jeu
  avec les 8 statuts et les badges, jeu de données, détail de chaque écran). Elle est en anglais.
- `birds.md`, `icons.json`, `icons_sheet.svg` : 15 icônes d'espèces dans le style du logo, point de
  départ de J6d. `icons_gen.py` les régénère : `python3 fork/maquette/icons_gen.py`.

## Ce qui fait foi

`fork/DESIGN.md` prime sur la maquette, et les écrans priment sur `SPEC.md`. Écarts connus :

- Spectrogramme : `SPEC.md` décrit encore des cadres autour des sons. C'est faux (le modèle ne situe pas
  un son en fréquence) : on met une barre de la couleur de l'espèce sous chaque passage, comme dans
  `LiveSpectre.dc.html`.
- Oiseau rare : `SPEC.md` fait partir des anneaux pendant l'attente. La bonne version est celle de
  `Rare.dc.html` : scintillement doux en attendant, fête seulement après « C'est bien lui ».
- Tableau Live : les écrans gardent les lignes à leur place. Benjamin préfère que l'oiseau entendu
  remonte en tête de liste (voir `fork/DESIGN.md`).
- Texte Martin-pêcheur sur fond clair : `#0B6E77`, comme la maquette (tranché en J6a), car
  `#0E7C86` n'atteint que 4,3:1 sur Brume.
- Animations : `fork/DESIGN.md` prime sur la section 6 de `SPEC.md` (tranché en J6a) : pas d'entrée
  en 420 ms, de rebond à 1,15, de plumes, de rotation ni d'effet en boucle hors écoute.
