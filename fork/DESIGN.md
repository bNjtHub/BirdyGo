# Direction visuelle de BirdyGo

## L'idée

Un carnet de terrain vivant. Les photos d'oiseaux portent l'interface, et chaque fiche espèce prend
ses couleurs dans la photo de l'oiseau (`ColorScheme.fromImageProvider`, calculé une fois puis mis en
cache). Le reste est calme, lisible en plein soleil et utilisable d'une main, parfois avec des gants.

L'audace est concentrée sur les moments d'oiseaux : l'arrivée d'une espèce pendant une écoute, la
toute première rencontre, l'oiseau rare, le passage à un nouveau statut. La carte se pose avec un
ressort et le téléphone vibre légèrement ; pour une toute première espèce, une onde de la couleur de
l'oiseau traverse l'écran. Ailleurs, pas d'effet gratuit.

## Les principes

Dans l'ordre, quand deux principes se contredisent :

1. **Utile d'abord.** Chaque écran répond à une question de terrain : qu'est-ce que j'entends, est-ce
   sûr, je peux le réécouter, qui est cet oiseau, je l'envoie à la LPO.
2. **Simple au point qu'un enfant s'en serve.** Une action principale par écran, des images plutôt
   que des mots, de gros chiffres, des cibles d'au moins 48 dp.
3. **Rapide et fluide.** Rien ne fige. 60 images par seconde, 120 quand l'écran le permet. L'écoute
   démarre moins d'une seconde après l'appui.
4. **Belle et colorée grâce aux oiseaux.** Le cadre reste sobre ; la couleur vient des oiseaux
   (icônes, photos, teinte de chaque fiche, célébrations) et de chaque statut du jeu.
5. **Hi-tech à l'écoute.** Écran sombre, spectre lumineux qu'on agrandit ou réduit d'un appui,
   tableau qui s'alimente en direct avec des compteurs animés.
6. **Donne envie d'y revenir, sans pièges.** Collection à compléter, progrès, défis, belles surprises.
   Ni notification culpabilisante, ni punition pour un jour manqué.

## Couleurs

| Nom | Hex | Usage |
|---|---|---|
| Encre de nuit | #13233A | fond du thème sombre et de l'écoute, texte principal du thème clair |
| Brume | #EEF1EC | fond du thème clair |
| Martin-pêcheur | #19A7B3 | action : Écouter, lecture, liens. Sur fond clair, texte en #0E7C86 pour le contraste |
| Loriot | #F4C542 | nouveauté : première espèce, nouvelle de l'année |
| Lichen | #9DB46A | confirmé, niveau Sûr |
| Écorce | #6B5847 | textes secondaires et séparateurs du thème clair |

Couleur d'espèce : chaque espèce a sa teinte, tirée de sa photo ou de son icône, pour sa fiche, sa
ligne dans le tableau en direct et ses célébrations. Couleur de statut : chaque statut du jeu a la
sienne (fixée en J6e). Le texte posé sur ces couleurs garde un contraste AA.

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
│ 12:47   5 espèces      ⇕     │
│ spectrogramme qui défile     │
├─────────────────────────────┤
│ [icône] Rougegorge familier  │
│   Sûr   ×3 · 142 au total  ▶ │
│ [icône] Pouillot véloce      │
│   À vérifier  ×1 · 9       ▶ │
├─────────────────────────────┤
│  ■ Arrêter        ⏸ Pause    │
└─────────────────────────────┘
```

Un appui sur le spectre (ou sur ⇕) l'agrandit à environ 60 % de l'écran, avec l'échelle en kHz et les
cris détectés entourés, puis le réduit. Le tableau s'alimente en direct : une nouvelle espèce entre en
haut avec un ressort, une espèce déjà là fait monter son compteur de session (×3) d'un petit rebond,
à côté de son total toutes sorties confondues.

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
| Compteur qui augmente | 200 ms | le chiffre rebondit (échelle 1,15 vers 1), la ligne ne bouge pas |
| Nouvelle espèce en Live | ressort | glisse de 12 px, échelle 0,96 vers 1, fondu, vibration légère |
| Toute première espèce | 600 ms, une seule fois | onde de la couleur de l'oiseau, vibration moyenne |
| Oiseau rare | 800 ms, puis attente | carte dorée (Loriot) qui scintille, anneaux ; la fête ne compte qu'après « C'est bien lui » |
| Nouveau statut | 900 ms, une seule fois | l'emblème du statut se pose, anneaux de sa couleur, vibration moyenne |

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
- Icônes d'espèces en SVG dans le style du logo (J6d) pour les petites tailles : carte, tableau en
  direct, carnet. La photo reste sur la fiche.
- Silhouette sobre quand il n'y a ni photo ni icône.

## Jeu

- Statuts selon le nombre d'espèces découvertes (confirmées ou Sûr), à thème oiseau, chacun avec sa
  couleur et son emblème. Noms et seuils fixés en J6e, à partir de la maquette.
- Carnet façon collection : les espèces découvertes en couleur, et en silhouette mystère celles
  attendues ici en cette saison (géomodèle), avec un indice (« Chante au lever du jour dans les haies »).
- Badges (lève-tôt, noctambule, réviseur…), série de jours qui pardonne un jour manqué, défis de la semaine.
- Garde-fous : rien ne se gagne avec une détection non vérifiée, un oiseau rare se confirme avant la
  fête, pas de notification culpabilisante, rien qui pousse à déranger les oiseaux (repasse) ou à
  publier la position d'une espèce sensible.

## Logo

Dans `fork/brand/` : `birdygo-logo.svg` (animé, pour le README et l'accueil), `birdygo-logo-static.svg`
(même dessin sans animation, base de l'icône d'app), `birdygo-logo-small.svg` (simplifié, de 16 à 48 px).

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
profile sur le Xiaomi (120 quand l'écran le permet), écoute lancée en moins d'une seconde.
