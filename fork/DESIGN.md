# Direction visuelle de BirdyGo

## L'idée

Un carnet de terrain vivant. Les photos d'oiseaux portent l'interface, et chaque fiche espèce prend
ses couleurs dans la photo de l'oiseau (`ColorScheme.fromImageProvider`, calculé une fois puis mis en
cache). Le reste est calme, lisible en plein soleil et utilisable d'une main, parfois avec des gants.

L'audace est concentrée à un seul endroit : l'arrivée d'une espèce pendant une écoute. La carte photo
se pose avec un ressort et le téléphone vibre légèrement. Pour une toute première espèce, une onde de
la couleur de l'oiseau traverse l'écran. Ailleurs, pas d'effet gratuit.

## Couleurs

| Nom | Hex | Usage |
|---|---|---|
| Encre de nuit | #13233A | fond du thème sombre et de l'écoute, texte principal du thème clair |
| Brume | #EEF1EC | fond du thème clair |
| Martin-pêcheur | #19A7B3 | action : Écouter, lecture, liens. Sur fond clair, texte en #0E7C86 pour le contraste |
| Loriot | #F4C542 | nouveauté : première espèce, nouvelle de l'année |
| Lichen | #9DB46A | confirmé, niveau Sûr |
| Écorce | #6B5847 | textes secondaires et séparateurs du thème clair |

L'écoute s'ouvre en thème sombre par défaut : on l'utilise souvent à l'aube, et l'écran OLED consomme moins.
Les rampes de score et les palettes du spectrogramme d'upstream ne changent pas.
Élévation par teinte de surface (Material 3), pas la même ombre grise sous chaque carte.

## Typographie

- Fraunces, variable, axe SOFT haut, graisse 500 à 650 : titres et noms d'espèces. Elle rappelle les
  planches naturalistes sans le contraste dur d'une serif de magazine.
- Fraunces italique : noms latins, comme dans les guides naturalistes.
- Atkinson Hyperlegible Next, variable : interface, chiffres, textes courants. Dessinée pour la
  lisibilité en basse vision, elle tient bien dehors en plein soleil.
- Polices embarquées dans `assets/fonts/` (licence OFL), aucun téléchargement à l'exécution.
- Échelle : 34, 26, 20, 17, 15, 13. Texte courant entre 15 et 17. Chiffres tabulaires pour les compteurs.
- Pas de libellés en capitales, pas de sur-titre au-dessus de chaque bloc, pas de mot isolé mis en
  couleur dans un titre.

## Mise en page

Alignement à gauche. Photos bord à bord dans les en-têtes. Rayons hiérarchisés : 28 pour la photo
principale, 20 pour les cartes, pilule pour les puces. Cibles tactiles de 48 dp au minimum, bouton
d'écoute atteignable au pouce.

Accueil
```
┌─────────────────────────────┐
│ Ce matin                     │
│ 14 espèces cette semaine     │
│ ┌─────────────────────────┐ │
│ │ photo du dernier oiseau  │ │
│ │ Pic épeiche       7 h 42 │ │
│ └─────────────────────────┘ │
│ Nouvelles cette année      > │
│ [photo] [photo] [photo]      │
│ 3 détections à vérifier    > │
│                              │
│        ( ●  Écouter )        │
└─────────────────────────────┘
```

Live
```
┌─────────────────────────────┐
│ spectrogramme qui défile     │
├─────────────────────────────┤
│ [photo] Rougegorge familier  │
│         Sûr  0,92  3 fois  ▶ │
│ [photo] Pouillot véloce      │
│         À vérifier  0,41   ▶ │
├─────────────────────────────┤
│  ■ Arrêter        ⏸ Pause    │
└─────────────────────────────┘
```

Fiche espèce
```
┌─────────────────────────────┐
│ photo principale (45 %)      │
│ Pic épeiche                  │
│ Dendrocopos major            │
│ Entendu 23 fois sur 9 jours, │
│ la dernière fois hier 7 h 42 │
│ 11 bonnes sur 12 vérifiées   │
│ Mes enregistrements          │
│ ▶ 0,93   12 mars   ★         │
│ ▶ 0,88   2 avril             │
│ Activité par heure ▂▅█▃▁     │
│ mini-carte                   │
│ description                  │
│ Photo : auteur, licence      │
└─────────────────────────────┘
```

Palmarès : la première espèce en grande carte photo, puis une liste compacte avec rang, vignette,
nom, barre proportionnelle et compteur.

Carte : plein écran, hexagones Martin-pêcheur dont l'opacité suit le nombre de contacts, feuille du
bas pour les filtres.

## Animations

Règle de fréquence : ce qu'on voit cent fois par jour (onglets, défilement, listes) ne s'anime pas,
ou à peine. Feuilles et dialogues : animation standard. Événements rares, comme une nouvelle espèce
ou la première de l'année : c'est là qu'on se fait plaisir.

| Élément | Durée | Courbe |
|---|---|---|
| Appui sur un bouton, échelle 0,97 | 120 ms | `Cubic(0.23, 1, 0.32, 1)` |
| Entrée d'un élément | 200 à 250 ms | `Cubic(0.23, 1, 0.32, 1)` |
| Sortie | 150 ms | même courbe, toujours plus courte que l'entrée |
| Déplacement à l'écran | 250 ms | `Cubic(0.77, 0, 0.175, 1)` |
| Feuille du bas | ressort | `SpringDescription.withDampingRatio(mass: 1, stiffness: 500, ratio: 0.85)` |
| Carte de revue balayée | ressort interruptible | suit le doigt, repart avec la vitesse du geste |
| Nouvelle espèce en Live | ressort | glisse de 12 px, échelle 0,96 vers 1, fondu, vibration légère |
| Toute première espèce | 600 ms, une seule fois | onde de la couleur de l'oiseau, vibration moyenne |

- Jamais `Curves.easeIn` pour l'interface, il donne une impression de lenteur.
- Jamais d'apparition depuis une échelle 0 : partir de 0,95 avec une opacité 0.
- Décalage entre les éléments d'une liste : 40 ms, sur 5 éléments au plus, sans bloquer les appuis.
- Hero sur la photo entre une liste et la fiche espèce.
- N'animer que la position, l'échelle et l'opacité. `RepaintBoundary` autour du spectrogramme.
  Pas de `BackdropFilter` sur une zone qui défile : utiliser des flous calculés à l'avance.
- Animations réduites : si `MediaQuery.disableAnimationsOf(context)` est vrai, ne garder que les fondus.
- Outils : flutter_animate pour les effets déclaratifs, le paquet animations de Google pour les
  transitions Material, Hero et `ColorScheme.fromImageProvider` fournis par Flutter.

## Photos

- Pack embarqué en WebP 480×320 pour les espèces de la région (J6b), disponible hors ligne.
- Version plus grande en ligne (iNaturalist), cache disque, fondu par-dessus la version embarquée,
  jamais de saut de mise en page.
- Crédit et licence d'un appui sur la photo.
- Silhouette sobre quand il n'y a pas de photo.

## Textes

Français simple, tutoiement, phrases courtes. Une action garde le même nom partout : « Écouter »,
« Arrêter », « Réécouter », « C'est bien lui », « Ce n'est pas lui », « Je ne sais pas ».

Une erreur dit ce qui se passe et quoi faire : « Le micro est bloqué. Autorise-le dans les réglages
du téléphone. »

Un écran vide invite à agir : « Aucun oiseau pour l'instant. Lance une écoute au lever du jour,
c'est l'heure où ils chantent le plus. »

Pas d'emoji dans l'interface.

## Contrôle qualité

Contraste AA, thèmes clair et sombre, paysage et tablette (exigence d'upstream), texte agrandi à
130 %, libellés pour les lecteurs d'écran sur les boutons icônes, 60 images par seconde en mode
profile sur le Xiaomi.
