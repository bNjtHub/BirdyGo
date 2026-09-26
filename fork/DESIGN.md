# Direction visuelle de BirdyGo

## L'idée

Un carnet de terrain vivant. Les photos d'oiseaux portent l'interface, et chaque fiche espèce prend
ses couleurs dans la photo de l'oiseau (`ColorScheme.fromImageProvider`, calculé une fois puis mis en
cache). Le reste est calme, lisible en plein soleil et utilisable d'une main, parfois avec des gants.

Le mouvement est sobre, comme dans une app pro : court, discret, utile. Les moments d'oiseaux
(l'arrivée d'une espèce, la toute première rencontre, l'oiseau rare, un nouveau statut) sont marqués,
mais avec retenue : un fondu, un léger glissement, une teinte de la couleur de l'oiseau, une vibration
légère. Jamais de confettis, de scintillements en boucle ni d'effets empilés. Ailleurs, pas d'effet gratuit.

## Les principes

Dans l'ordre, quand deux principes se contredisent :

1. **Utile d'abord.** Chaque écran répond à une question de terrain : qu'est-ce que j'entends, est-ce
   sûr, je peux le réécouter, qui est cet oiseau, je l'envoie à la LPO.
2. **Assez simple pour qu'un enfant s'en serve.** Une action principale par écran, des images plutôt
   que des mots, de gros chiffres, des cibles d'au moins 48 dp.
3. **Rapide et fluide.** Rien ne se fige. 60 images par seconde, 120 quand l'écran le permet. L'écoute
   démarre moins d'une seconde après l'appui.
4. **Belle et colorée grâce aux oiseaux.** Le cadre reste sobre ; la couleur vient des oiseaux
   (icônes, photos, teinte de chaque fiche, célébrations) et de chaque statut du jeu.
5. **High-tech à l'écoute.** Écran sombre, spectrogramme lumineux qu'on agrandit ou réduit d'un appui,
   tableau qui s'alimente en direct avec des compteurs animés.
6. **Donne envie d'y revenir, sans pièges.** Collection à compléter, progrès, défis, belles surprises.
   Ni notification culpabilisante, ni punition pour un jour manqué.

## Couleurs

| Nom | Hex | Usage |
|---|---|---|
| Encre de nuit | #13233A | fond du thème sombre et de l'écoute, texte principal du thème clair |
| Brume | #EEF1EC | fond du thème clair |
| Martin-pêcheur | #19A7B3 | action : Écouter, lecture, liens. En texte : #0B6E77 sur fond clair (5,25:1 sur Brume ; #0E7C86 n'atteignait que 4,3:1), #4FC3CC sur fond sombre |
| Loriot | #F4C542 | nouveauté et rareté : première espèce, nouvelle de l'année, oiseau rare |
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

Un appui sur le spectrogramme (ou sur ⇕) l'agrandit à environ 60 % de l'écran, avec l'échelle en kHz
et un trait de la couleur de l'espèce sous chaque passage détecté ; un second appui le réduit. Le
modèle dit quand un oiseau chante, pas à quelle fréquence : on ne dessine jamais de cadre autour d'un son. Le tableau s'alimente en direct : une nouvelle espèce entre en
haut avec un ressort ; une espèce déjà là remonte en tête de liste (déplacement de 250 ms) et son
compteur de session (×3) fait un petit rebond, à côté de son total toutes sorties confondues. La
liste ne s'efface jamais pendant l'écoute.

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

Carte : plein écran. Aux petits zooms, hexagones Martin-pêcheur dont l'opacité suit le nombre de
contacts ; aux grands zooms, les oiseaux en marqueurs ronds (photo, puis icône de J6d). Feuille du bas
pour les filtres.

## Animations

Règle de fréquence : ce qu'on voit cent fois par jour (onglets, défilement, listes) ne s'anime pas,
ou à peine. Feuilles et dialogues : animation standard. Événements rares, comme une nouvelle espèce
ou la première de l'année : un peu plus marqués, mais toujours sobres.

Règle de retenue : un seul effet à la fois ; déplacement de 8 px au plus ; échelle jamais sous 0,97 ;
pas de rotation, de rebond ni de tremblement ; 500 ms au plus pour une célébration.

| Élément | Durée | Courbe |
|---|---|---|
| Appui sur un bouton, échelle 0,97 | 120 ms | `Cubic(0.23, 1, 0.32, 1)` |
| Entrée d'un élément | 200 à 250 ms | `Cubic(0.23, 1, 0.32, 1)` |
| Sortie | 150 ms | même courbe, toujours plus courte que l'entrée |
| Déplacement à l'écran | 250 ms | `Cubic(0.77, 0, 0.175, 1)` |
| Feuille du bas | ressort | `SpringDescription.withDampingRatio(mass: 1, stiffness: 500, ratio: 0.85)` |
| Carte de revue balayée | ressort interruptible | suit le doigt, repart avec la vitesse du geste |
| Compteur qui augmente | 180 ms | le chiffre grossit à peine (échelle 1,08 puis 1), la ligne ne bouge pas |
| Nouvelle espèce en Live | 220 ms | glisse de 8 px, échelle 0,97 vers 1, fondu, vibration légère |
| Toute première espèce | 250 ms, une seule fois | carte « Première rencontre » en fondu, légère teinte de la couleur de l'oiseau derrière (opacité 15 % au plus), vibration légère |
| Oiseau rare | attente, puis 450 ms | carte dorée immobile (fin liseré Loriot) en attendant « C'est bien lui » ; puis un seul anneau doux et la pastille « +1 espèce rare » en fondu |
| Nouveau statut | 300 ms, une seule fois | l'emblème apparaît en fondu (échelle 0,97 vers 1), le texte suit 60 ms après, vibration légère |

- Jamais `Curves.easeIn` pour l'interface, il donne une impression de lenteur.
- Jamais d'apparition depuis une échelle 0 : partir de 0,95 avec une opacité 0.
- Décalage entre les éléments d'une liste : 40 ms, sur 5 éléments au plus, sans bloquer les appuis.
- Hero sur la photo entre une liste et la fiche espèce.
- N'animer que la position, l'échelle et l'opacité. `RepaintBoundary` autour du spectrogramme.
  Pas de `BackdropFilter` sur une zone qui défile : utiliser des flous calculés à l'avance.
- Animations réduites : si `MediaQuery.disableAnimationsOf(context)` est vrai, ne garder que les fondus.
- Outils : flutter_animate pour les effets déclaratifs, le paquet animations de Google pour les
  transitions Material, Hero et `ColorScheme.fromImageProvider` fournis par Flutter.

## Mise en œuvre (J6a)

Le design system vit dans `lib/fork/design/`, et la galerie « Composants de l'interface » (Réglages,
hors version publiée) montre chaque composant en clair et en sombre.

- Jetons : `birdy_tokens.dart` (couleurs `BirdyColors.of(context)`, rayons, espacements, tailles),
  `birdy_typography.dart` (`BirdyText`), `birdy_motion.dart` (`BirdyMotion`, `BirdyHaptics`),
  `species_tint.dart` (couleur d'espèce), `birdy_theme.dart` (`BirdyTheme`, `ListeningTheme`).
- Thème appliqué à toute l'app, écrans upstream compris. Les options « couleur dynamique » et
  « contraste élevé » d'upstream restent. Rampes de score et palettes du spectrogramme inchangées.
- Rôle `primary` de Material = le Martin-pêcheur lisible en texte (#0B6E77 clair, #4FC3CC sombre).
  Le remplissage vif #19A7B3 avec texte Encre passe par `BirdyButtonStyles` et `ListenButton` : le
  thème ne peut pas le donner à `FilledButton` sans repeindre aussi `FilledButton.tonal`.
- Polices variables : la graisse passe par `fontWeight` (Flutter l'applique à l'axe `wght`), jamais
  par une variation `wght`, qui écraserait les `bold` des écrans upstream. Fraunces reçoit toujours
  `SOFT` 100 et `opsz` égal à la taille du texte (Flutter ne règle pas la taille optique seul).
- Couleur d'espèce (`SpeciesTint.fromAccent`) : `tintDark` = l'accent à 24 % sur Encre, `tintLight`
  = même teinte à luminosité 0,92 (au moins 12:1 avec Encre), `deep` = l'accent assombri vers Encre
  jusqu'à 3,2:1 sur blanc. On retrouve la table de la maquette.
- Animations : ce document prime sur `fork/maquette/SPEC.md` (section 6). Écartés de la maquette :
  entrée en 420 ms, rebond à 1,15, plumes qui tombent, rotations, anneaux et reflets en boucle.

## Mise en œuvre (J6c, Live)

Code dans `lib/fork/live/`, branché sur `LiveScreen` dans les deux orientations (la disposition
upstream reste dans le fichier, inutilisée, pour faciliter les fusions). La session, la pause du cycle
de vie, le préchargement et la réécoute restent ceux d'upstream et de J2.

- `live_table_model.dart` : une ligne par espèce de la sortie, triée sur le début du dernier contact.
  Un contact qui dure ne fait pas bouger sa ligne ; un nouveau contact la remonte en tête.
- `live_table.dart` et `flip_move.dart` : entrée `BirdyEntrance` depuis 8 px au-dessus avec vibration
  légère, remontée de 250 ms (`BirdyMotion.move`) lue dans la mise en page de la colonne, donc
  valable pour des lignes de toute hauteur. Animations réduites : les lignes sautent à leur place.
- `detection_marks.dart` : un trait par passage, de `timestamp − fenêtre d'analyse` à
  `endTimestamp` (ou maintenant s'il chante encore), sur trois rangées au plus quand ils se
  chevauchent. Noms sous les traits en mode agrandi. Jamais de cadre autour d'un son.
- `live_spectrogram_panel.dart` : bande de 120 dp, ou 60 % du corps de l'écran avec l'échelle en kHz.
  En paysage : spectre à gauche sur toute la hauteur (moitié de la largeur, 65 % d'un appui), avec
  l'échelle et les noms ; tableau et barre à droite ; une ligne de résumé à la place des tuiles.
- Couleur d'espèce : `SpeciesAccents` (`lib/fork/design/species_accents.dart`), table de SPEC.md 2.5
  et palette de repli stable, jusqu'aux icônes de J6d.
- Écarts assumés avec la maquette : pas de halo ni d'onde sur la ligne réentendue (un seul effet à la
  fois), pas de bande « niveau du micro », pas de nom de lieu sous « En écoute ». Les dialogues
  et feuilles ouverts depuis l'écoute (confirmation d'arrêt, fiche espèce, aide) sont sombres aussi.

## Photos

- Pack embarqué en WebP 480×320 pour les espèces de la région (J6b), disponible hors ligne.
- Version plus grande en ligne (iNaturalist), cache disque, fondu par-dessus la version embarquée,
  jamais de saut de mise en page.
- Crédit et licence d'un appui sur la photo.
- Icônes d'espèces en SVG dans le style du logo (J6d) pour les petites tailles : carte, tableau en
  direct, carnet. La photo reste sur la fiche.
- Silhouette sobre quand il n'y a ni photo ni icône.

Mise en œuvre (J6b), dans `lib/fork/photos/` : `SpeciesPhoto` (cadre de taille fixe, 3:2 par défaut
ou la taille du parent ; photo embarquée et grande version en `BoxFit.cover` avec le même recadrage
centré ; fondu `BirdyMotion.enter`, gardé avec les animations réduites ; pastille « © » de 48 dp),
`PhotoCreditSheet` et `PhotoCreditLine` pour le crédit. Les listes passent `loadLarge: false` : la
grande version ne se charge que sur la fiche.

## Jeu

- Statuts selon le nombre d'espèces découvertes (confirmées ou Sûr), à thème oiseau, chacun avec sa
  couleur et son emblème. Noms et seuils fixés en J6e, à partir de la maquette.
- Carnet façon collection : les espèces découvertes en couleur, et en silhouette mystère celles
  attendues ici en cette saison (géomodèle), avec un indice (« Chante au lever du jour dans les haies »).
- Badges (lève-tôt, noctambule, réviseur…), série de jours qui pardonne un jour manqué, défis de la semaine.
- Garde-fous : rien ne se gagne avec une détection Probable ou À vérifier tant qu'elle n'est pas
  confirmée, un oiseau rare se confirme avant la fête, pas de notification culpabilisante, rien qui
  pousse à déranger les oiseaux (repasse) ou à publier la position d'une espèce sensible.

## Logo

Dans `fork/brand/` : `birdygo-logo.svg` (animé en CSS, pour le README), `birdygo-logo-static.svg`
(même dessin sans animation, base de l'icône d'app et du logo de l'accueil, dont l'animation se refait
en Flutter), `birdygo-logo-small.svg` (simplifié, de 16 à 32 px).

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
