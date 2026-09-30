# Direction visuelle de BirdyGo

## L'idée

Un carnet de terrain vivant. Les photos d'oiseaux portent l'interface, et chaque fiche espèce prend
ses couleurs dans la photo de l'oiseau (`ColorScheme.fromImageProvider`, calculé une fois puis mis en
cache). Le reste est calme, lisible en plein soleil et utilisable d'une main, parfois avec des gants.

Le mouvement est sobre, comme dans une app pro : court, discret, utile. Les moments d'oiseaux
(l'arrivée d'une espèce, la toute première rencontre, l'oiseau rare, un nouveau statut) sont marqués,
mais avec retenue : un fondu, un léger glissement, une teinte de la couleur de l'oiseau, une vibration
légère. Pas de scintillements en boucle ni d'effets empilés ; des confettis seulement pour une
première rencontre, un nouveau statut et le quiz, en une seule gerbe. Ailleurs, pas d'effet gratuit.

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

### Thèmes d'oiseau (J6i)

L'enfant choisit son oiseau : la couleur de marque, le logo et le splash suivent. Le thème par défaut
et tant que rien n'est choisi est le **Loriot**, qui garde exactement les jetons d'avant J6i (le
« Martin-pêcheur » #19A7B3 ci-dessus est l'accent du thème Loriot ; le jaune du bec est le loriot).
Valeurs exactes dans `fork/handoff/maquettes/themes.js`, reprises dans
`lib/fork/design/birdy_theme_choice.dart` (seul endroit avec ces couleurs en dur).

| Thème (`BirdyBird`) | acc | accText clair | accText sombre | bec / barre 2 |
|---|---|---|---|---|
| `loriot` (défaut) | #19A7B3 | #0B6E77 | #4FC3CC | #F4C542 |
| `martin` | #3A9BE0 | #1565A8 | #7DBBF0 | #F28C38 |
| `flamant` | #E86A9A | #A8305F | #F59BC0 | #3A2F4F |
| `etourneau` | #9D82E0 | #5B3FB0 | #BBA6F0 | #E9C46A |

Ce qui change : `accent` (action, anneaux, halo `glow`), `accentText`, `tonal`, `navIndicator`, le
logo, le point du wordmark. `BirdyColors.forBird(bird, brightness)` donne les jetons du thème,
`BirdyBrandColors.of(context)` les rôles de marque (`accentHi`, `accentDeep`, `accentLight`,
`highlight`, `highlightDeep`, `wordmarkDot`, `accentTextDark`). Le choix est dans
`birdyBirdProvider` (SharedPreferences `fork_birdy_bird_v1`), lu avant `runApp` : le splash est
dans le bon thème dès la première image.

Ce qui ne change jamais : niveaux Sûr / Probable / À vérifier, loriot doré (récompense, série, rare),
médailles et emblèmes de niveau, confettis, teintes d'espèces, modes Vent / Boost / Ville, encre du
texte sur `accent`. Le mode Normal suit `accentText`. Le logo du quiz (disque sombre aux barres
turquoise) reste tel quel : c'est son emblème.

Contraste vérifié pour chaque thème (`test/fork/design/birdy_theme_choice_test.dart`) : encre sur
`accent`, `accentText` sur blanc, Brume, `tonal` et `navIndicator`, `accentTextDark` sur Encre et sur
les surfaces sombres, tous ≥ 4,5:1. Goldens de l'Accueil, 4 thèmes × clair / sombre :
`test/fork/goldens/` (tolérance de 2 % : l'Accueil affiche la date et une salutation). Références générées sous Windows, comparées
seulement sous Windows (CI Linux : test de fumée par thème) ; les régénérer avec
`flutter test --update-goldens test/fork/goldens`.

## Typographie

- Nunito, variable, graisse 800 : titres (`display` 34, `title` 26, `heading` 20) et grands chiffres
  (`numberXL`). Ronde et chaleureuse, sans fantaisie sur le j ni le g (audit typo J6i, option 1d).
  Approche resserrée de 1 % de la taille dès 26, neutre en dessous.
- Fraunces, variable, axe SOFT haut, graisse 600 : noms d'espèces (`species`, `speciesCompact`) et le
  « ? » d'un oiseau mystère. Rien d'autre.
- Atkinson Hyperlegible Next italique 400 : noms latins (`latin`, `latinCompact`). Fichier italique
  dédié, pas d'inclinaison synthétique.
- Atkinson Hyperlegible Next, variable : interface, chiffres (sauf `numberXL`), textes courants.
  Dessinée pour la lisibilité en basse vision, elle tient bien dehors en plein soleil.
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
│            ╭───╮             │
├────────────┤ ● ├─────────────┤
│ Accueil Carnet Écouter Carte Profil │
└─────────────────────────────┘
```
Depuis J6j, « Écouter » est le disque du milieu de la barre du bas, qui dépasse de 22 dp.

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
| Appui sur le disque « Écouter » de la barre, échelle 0,95 (exception explicite, voir plus bas) | 120 ms | `Cubic(0.23, 1, 0.32, 1)` |
| Entrée d'un élément | 200 à 250 ms | `Cubic(0.23, 1, 0.32, 1)` |
| Sortie | 150 ms | même courbe, toujours plus courte que l'entrée |
| Déplacement à l'écran | 250 ms | `Cubic(0.77, 0, 0.175, 1)` |
| Feuille du bas | ressort | `SpringDescription.withDampingRatio(mass: 1, stiffness: 500, ratio: 0.85)` |
| Carte de revue balayée | ressort interruptible | suit le doigt, repart avec la vitesse du geste |
| Compteur qui augmente | 180 ms | le chiffre grossit à peine (échelle 1,08 puis 1), la ligne ne bouge pas |
| Nouvelle espèce en Live | 220 ms | glisse de 8 px, échelle 0,97 vers 1, fondu, vibration légère |
| Toute première espèce | 250 ms pour la carte, séquence d'environ 2,5 s, une seule fois | carte « Première rencontre » (fondu, 0,97 vers 1), légère teinte de la couleur de l'oiseau derrière (opacité 15 % au plus), puis l'oiseau, son anneau, les textes et une gerbe de confettis (détail en J6f), vibration légère |
| Oiseau rare | arrivée d'environ 2,4 s, une fois ; attente sans décompte ; puis réponse | carte dorée (fin liseré Loriot). À l'arrivée : anneau pointillé Loriot qui se dessine en tournant de −90° à 120°, halo Loriot qui pulse 2 fois, 3 losanges qui scintillent l'un après l'autre (décalage 220 ms), pastille en pop ; l'anneau reste ensuite pointillé. « C'est lui » : anneau plein et halo, confettis dorés, « +1 espèce rare », décompte 6 s ; « Je ne sais pas » et « Pas lui » : encadré de réponse, décompte 3 s |
| Nouveau statut | 300 ms, une seule fois | l'emblème apparaît en fondu (échelle 0,97 vers 1), le texte suit 60 ms après, une gerbe de confettis part de l'emblème une fois celui-ci arrivé, vibration légère |

- Jamais `Curves.easeIn` pour l'interface, il donne une impression de lenteur.
- Jamais d'apparition depuis une échelle 0 : partir de 0,95 avec une opacité 0.
- Décalage entre les éléments d'une liste : 40 ms, sur 5 éléments au plus, sans bloquer les appuis.
- Hero sur la photo entre une liste et la fiche espèce.
- N'animer que la position, l'échelle et l'opacité. `RepaintBoundary` autour du spectrogramme.
  Pas de `BackdropFilter` sur une zone qui défile : utiliser des flous calculés à l'avance.
- Animations réduites : si `MediaQuery.disableAnimationsOf(context)` est vrai, ne garder que les fondus.
- Exception autorisée : le quiz « Qui chante ? » (J6e, maquette « Quiz v2 », `lib/fork/game/quiz_fx.dart`)
  a droit à un léger rebond (pop 0,6 → 1,08 → 1), aux confettis, aux boucles (oiseau qui flotte,
  rayons qui tournent, barres de son, halo pulsé), au balancement doux d'une mauvaise réponse et à des
  effets de plus de 500 ms (« +1 Oreille fine » 1,4 s, barre 900 ms). C'est un jeu, pas un écran de
  terrain. Avec les animations réduites, tout s'arrête : états finaux immobiles, aucun confetti.
  Les bruitages (jingle, fanfare) suivent l'interrupteur « Avec son / Sans son » et jamais pendant
  une écoute Live.
- Confettis (J6f) : un seul composant partagé, `BirdyConfetti` (`lib/fork/design/widgets/birdy_confetti.dart`,
  paquet confetti), en gerbe (`.burst`) ou en pluie (`.rain`). Couleurs `BirdyConfettiColors`, durées et
  physique `BirdyConfettiMotion` (émission 300 ms, 110 particules, fondu sur les 400 dernières ms, retiré
  de l'arbre après 2,3 s ; pluie 4,6 s). Permis seulement pour : le quiz (gerbe d'une bonne réponse, pluie
  d'un bon score), la « Première rencontre » en Live et l'écran « Nouveau statut ». Une seule émission,
  jamais en boucle, jamais sur une interface calme (listes, Bilan, onglets). Animations réduites : aucun
  confetti. La séquence « Première rencontre » (environ 2,5 s avec l'anneau et les confettis) dépasse
  `celebrationMax` (500 ms) : exception acceptée, comme le quiz, car rien n'attend la fin (la carte et ses
  boutons sont là dès 250 ms, l'écoute continue) et ce moment n'arrive qu'une fois par espèce dans une vie.
- Exception autorisée : un double appui sur le logo de l'accueil (J6h, `lib/fork/home/logo_flight.dart`)
  fait décoller l'oiseau, qui vole jusqu'au centre de l'écran (3,5 fois sa taille), penche la tête et
  fait un clin d'œil (l'œil devient un trait courbe), puis s'envole par la droite et revient se poser
  dans l'en-tête : 4,4 s (l'oiseau chante avec ses notes à l'arrivée) (`BirdyMotion.logoWink*`, un seul contrôleur), au-delà des 500 ms. Explicite
  et voulu par la personne (deux appuis, jamais tout seul), donc pas une célébration au sens de la
  règle. Le cri BirdyGo joue une fois à l'arrivée, un retour haptique léger au clin d'œil ; pendant ce
  temps le logo de l'en-tête est masqué (un seul oiseau à l'écran). Animations réduites : un clin
  d'œil rapide sur place (450 ms). Les appuis pendant la séquence sont ignorés.
- Première rencontre en série (J6h) : les Sûres entendues pendant qu'une carte est ouverte, ou app en arrière-plan,
  forment une file (rang figé, « 1 sur 3 nouvelles », points `BirdyStepDots`) ; un rare passe devant. Barre de
  décompte 6 px (`BirdyProgressBar`, 6 s linéaires, `firstEncounterShown`) et texte « Se referme seul dans n s » /
  « Suivante dans n s », figés en pause (« · en pause »), la carte passe à la suivante ou se ferme à zéro.
  Logo « L'écoute continue » = `BirdyListeningLogo` (barres 0,45 à 1, 1 s, décalage 0,18 ; même logo à 24 px dans
  l'en-tête), figé en pause. Feu d'artifice : deux salves de confettis (22 puis 14, `BirdyConfettiBurst`) et
  4 étincelles (`BirdySparkles`), une fois. Animations réduites : barre en paliers d'une seconde, texte mis à
  jour, ni confetti ni étincelles, logo immobile.
- Carte de l'oiseau rare (J6h, `lib/fork/live/live_moments.dart`, `rare_halo.dart`) : logo « L'écoute continue »,
  pastille « Rare ici · à confirmer », oiseau 96 (`BirdySizes.momentAvatar`) dans son anneau pointillé, nom sans nom
  latin (`BalancedText`, lignes équilibrées), ligne Loriot « ◆ 1 chance sur n de l'entendre ici » (n = 1 / score
  de présence arrondi, « moins de 1 sur 100 » sous 1 %), rejouer 56 rond + « C'est bien lui ? », les trois verdicts
  de la Revue rapide (`VerdictButtons`, libellés courts), légende. Écarts de 20 entre groupes, resserrés sous
  `momentCompactBelow` ; défilement en dernier recours seulement. La carte de première rencontre suit la même
  règle (oiseau 96, sans nom latin). Arrivée : jetons `BirdyMotion.rare*` (anneau 2,4 s, halo 2 × 1,4 s, losanges
  `BirdySparkles` avec l'icône `diamond`). Décomptes : 6 s après « C'est lui », 3 s après les deux autres
  (`rareConfirmedShown`, `rareAnsweredShown`), mêmes barre et pause que la première rencontre. « Je ne sais pas »
  n'écrit rien : les détections restent « à vérifier » et la Revue rapide les reprend. Animations réduites : anneau
  pointillé immobile, ni halo, ni losanges, ni confettis.
- Outils : flutter_animate pour les effets déclaratifs, le paquet animations de Google pour les
  transitions Material, Hero et `ColorScheme.fromImageProvider` fournis par Flutter.
- Squelettes de chargement (`BirdySkeleton`, `lib/fork/design/widgets/birdy_skeleton.dart`) : seule
  boucle permise, et seulement tant que le chargement dure. Une bande de lumière diagonale (inclinée de
  20°, large de la moitié de l'écran) balaie toutes les formes de gauche à droite en 1,1 s (ease-in-out,
  `BirdyMotion.shimmerSweep`), puis repose 0,3 s (`shimmerPause`) : un cycle de 1,4 s. Un seul ticker
  partagé (`BirdyShimmerClock`, compté par référence) pour tout l'écran : les formes sont synchronisées
  et la bande se lit en coordonnées d'écran. Il démarre avec le premier squelette visible et s'arrête
  avec le dernier (retiré de l'arbre, ou masqué par un `TickerMode`). Couleurs : `skeleton` de base,
  `skeletonSheen` par-dessus (clair : blanc à 55 %, sombre : blanc à 12 %). Animations réduites : aucun
  ticker, aplat fixe. Les formes et leurs dimensions ne changent pas. Toutes sont arrondies (ligne de
  texte = pilule, un bloc prend le rayon de la carte qu'il remplace : `card`, `hero`, `pill` pour barres et
  disques ; `BirdySkeleton.circle` et `.bar`) et remplies d'un léger dégradé (`skeleton` vers `skeleton`
  + 35 % de la lueur). La bande a une chute douce (`shimmerBandAlphas`), sans bord visible.
- Seconde exception, plus discrète : le logo de l'écoute (J6f, `lib/fork/live/live_header.dart`
  `_LiveLogo`, `BirdyGoLogoPainter`). Il remplace le point vivant qui pulsait ; tant que l'écoute
  est active, ses quatre barres d'aile oscillent seules, comme un petit vumètre, décalées entre
  elles, calmes (courbe standard, jamais de rebond, période `BirdyMotion.listeningLevelPeriod`,
  1,3 s) ; l'oiseau ne bouge jamais. En pause, les barres se figent à une longueur moyenne. Hors
  écoute ou animations réduites : le logo plein, immobile. Une seule `AnimationController`, un
  seul `CustomPainter` (`repaint: level`), aucune reconstruction de l'en-tête à chaque image.
- Troisième exception, l'appui sur le disque « Écouter » de la barre du bas (J6j) : échelle 0,95
  (`BirdyMotion.listenDiscPressScale`) au lieu de 0,97. C'est le bouton le plus important de l'app et
  il est rond : à 0,97 l'appui ne se verrait pas. Même durée et même courbe que les autres appuis,
  rien de plus, et rien du tout avec les animations réduites.

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
  par une variation `wght`, qui écraserait les `bold` des écrans upstream (Nunito 800 compris).
  Fraunces reçoit toujours
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
- `detection_marks.dart` : un trait par passage, du début de la première fenêtre analysée
  (`DetectionRecord.timestamp`, qui est déjà ce début) à `endTimestamp` (ou maintenant s'il chante
  encore), sur trois rangées au plus quand ils se chevauchent. La fin ne recule jamais : quand le
  contact se ferme, le trait garde l'instant où il s'est arrêté à l'écran si `endTimestamp` (fin de
  la dernière fenêtre, une à deux secondes plus tôt) tombe avant. Noms sous les traits en mode
  agrandi. Jamais de cadre autour d'un son.
- En pause et pendant une réécoute, rien ne « chante » : le symbole s'éteint en fondu et le trait
  en cours s'arrête. Le symbole a sa place réservée dans la ligne, qui ne bouge donc pas ; masqué,
  il ne s'anime plus. Le tableau se trie sur les détections de la session, pas sur celles du cycle.
- `live_header.dart` : statut sur une ligne (points de suspension), nouveau texte en fondu par-dessus
  l'ancien, hauteur constante quel que soit le texte.
- `live_spectrogram_panel.dart` : bande de 120 dp, ou 60 % du corps de l'écran avec l'échelle en kHz.
  En paysage : spectre à gauche sur toute la hauteur (moitié de la largeur, 65 % d'un appui), avec
  l'échelle et les noms ; tableau et barre à droite ; une ligne de résumé à la place des tuiles.
- Couleur d'espèce : `SpeciesAccents` (`lib/fork/design/species_accents.dart`), table de SPEC.md 2.5
  et palette de repli stable, jusqu'aux icônes de J6d.
- Écarts assumés avec la maquette : pas de halo ni d'onde sur la ligne réentendue (un seul effet à la
  fois), pas de bande « niveau du micro », pas de nom de lieu sous « En écoute ». Les dialogues
  et feuilles ouverts depuis l'écoute (confirmation d'arrêt, fiche espèce, aide) sont sombres aussi.

## Mise en œuvre (J6c-bis-b, Live : « Analyse… » et fin rapide)

- « Analyse… » : l'en-tête passe en fondu de « En écoute » à « Analyse… » (même fondu que les autres
  statuts) quand la dernière fenêtre contient un candidat : un oiseau (Aves) dont le score de cette
  seule fenêtre atteint le seuil de support du lissage, admis par le filtre d'espèces actif et
  l'intersection géo, pas encore confirmé. Ni nom, ni ligne, ni vibration. Rien en lissage off, avg
  ou max (aucune porte de support). Le texte reste un cycle de plus après la confirmation, pour que
  l'en-tête ne s'anime pas en même temps que l'entrée de la ligne. Code : `live_candidates.dart`.
- Symbole « chante » (`LiveTableEntry.singingVisual`) : il s'allume à l'ouverture du contact et
  s'éteint après 2 fenêtres de suite sous le seuil de support, même si le lissage garde encore
  l'espèce dans les résultats ; une seule fenêtre manquée entre deux phrases ne l'éteint pas.
  `singing` (présence dans les résultats) garde son sens : l'extrait en attente en dépend. Code :
  `live_heard.dart`, seuils dans `reliability_config.dart`.
- Trait sous le spectre : il court jusqu'à maintenant tant que le symbole est allumé, puis s'arrête
  là où il est à l'écran (jamais de recul). Redessiné à neuf (rotation, contact fermé), il finit à
  `heardUntil`, la fin de la dernière fenêtre au-dessus du seuil de support. **Cette fin affichée
  diffère de `endTimestamp` dans le JSON de la session**, qui reste la fin de la dernière fenêtre où
  l'espèce était dans les résultats lissés (plus tard de quelques secondes). Le JSON ne change pas.
- En pause et pendant une réécoute : ni « Analyse… » ni symbole ; les fins de traits sont gardées.

## Mise en œuvre (J6c, Bilan)

Code dans `lib/fork/summary/`. `LiveScreen` l'ouvre après « Arrêter » (une ligne FORK), seulement
quand la session est déjà enregistrée ; sinon la revue upstream s'ouvre comme avant.

- `listening_summary.dart` : modèle pur. Niveau d'une espèce = le meilleur de ses contacts
  (`reliabilityFor`, avec l'avis du géomodèle au lieu et à la semaine de la sortie). « Première fois » :
  Sûr ou confirmée ici, jamais vérifiée dans une autre sortie (`ObservationIndex.verifiedSpecies` :
  confirmée, ou non revue avec un score Sûr ; l'index ne garde pas l'avis du géomodèle). Les
  détections à vérifier sont les contacts non revus des espèces qui ne sont pas Sûr.
- `listening_summary_view.dart` : widgets sans providers ; `listening_summary_screen.dart` branche
  l'index, le géomodèle, la revue rapide (filtrée sur les détections de la sortie), la fiche espèce,
  la carte, le détail upstream et `LpoSendButton`. Au retour d'une revue, la session est relue.
- Thème de l'app (clair ou sombre), colonne de 560 dp au plus en paysage et sur tablette, cinq blocs
  qui entrent en décalé (fondu seul avec les animations réduites).
- Écarts assumés avec la maquette : heures au format de la langue (07:26), pas de carte de statut ni
  de puce de badge avant J6e, bandeau qui défile au lieu d'être coupé, partage sans lieu.

## Mise en œuvre (J6c, Accueil)

Code dans `lib/fork/home/`, affiché par `HomeScreen` (un seul branchement `// FORK` dans `build` ;
la disposition upstream reste dans le fichier, et le préchargement `_warmUpApp` ne change pas).
On suit SPEC.md 9.1, plus récente que le croquis « Accueil » ci-dessus.

- Logo : l'oiseau qui chante de l'écran de démarrage (`SingingLogo`, `singing_logo.dart`, qui
  réutilise `BirdyGoSingingPainter`), à la taille de la maquette (40 × 32 dp), suivi du nom
  « BirdyGo ». Seconde exception explicite, après le démarrage, aux règles des 500 ms et de
  l'absence de rotation : à l'arrivée de l'accueil, l'oiseau apparaît et chante une phrase (trois
  syllabes, notes qui s'envolent, environ 3,3 s), puis reste immobile ; il rechante une seule phrase
  toutes les 2 minutes (`SingingLogo.singEvery`) tant que l'accueil est visible. Jamais de boucle :
  le ticker ne tourne que pendant une phrase (`RepaintBoundary` autour du dessin), et rien n'est
  programmé quand l'accueil est caché (autre onglet, écran ouvert par-dessus, application en
  arrière-plan). Un appui sur l'oiseau ou le nom le fait chanter une fois et joue le cri BirdyGo
  (`assets/fork/sounds/birdygo_tweet.wav`, 1,6 s, lecteur à part, muet pendant une écoute pour que
  le micro ne l'entende pas ; joué même sous animations réduites) (pas annoncé au lecteur
  d'écran : ce n'est pas une commande). Animations réduites : la marque immobile, jamais animée.
  L'ancien `BirdyGoLogo` (aile dessinée une fois) n'est plus affiché ; son peintre garde les
  couleurs de la marque. Un double appui (J6h, `logo_flight.dart`) lui fait faire un clin d'œil au
  centre de l'écran : voir l'exception de la section Animations.
- Salutation selon l'heure (mêmes bornes que le Bilan, `dayPartOf`), date et lieu du téléphone
  (cache de géocodage, ou réseau si autorisé ; jamais de demande de localisation depuis l'accueil).
- Ordre (maquette `Main.dc.html`) : salutation, objectif du jour, carte de statut, tuiles du jour,
  dernier oiseau, défi de la semaine, détections à vérifier. Le haut (logo, pastille de série, menu)
  n'a pas d'entrée ; seul le logo bouge, quand il chante (voir Logo).
- Objectif du jour, carte principale (`lib/fork/daily_goal/daily_goal_card.dart`) : carte blanche
  (`surface1`, rayon 28, sans ombre ni dégradé) sur Brume, pastille drapeau, titre, « 5/8 espèces
  entendues » (le rapport en gras), chevron ; dessous les oiseaux de l'objectif en ronds de 60 dp,
  2 rangées de 4 (le rond rétrécit si la colonne est trop étroite). Oiseau entendu : rond sur sa
  teinte d'espèce (`SpeciesAccents`, `tintLight` ou `tintDark`), visuel de 46 dp, coche de 22 dp sur
  le vert du niveau Sûr (`sure.foreground`, Lichen foncé) cerclée de la couleur de la carte. Oiseau à
  trouver : visuel gris estompé de 40 dp dans un cercle en pointillé (`dashed`). Chaque rond annonce
  « <nom> : entendu » ou « <nom> : pas encore entendu ». Toute la carte ouvre l'écran de l'objectif
  (une seule cible, bien plus grande que 48 dp). Sans objectif du jour : phrase d'invitation et
  « Choisir les oiseaux du jour », aucun appel GPS depuis l'accueil.
- La couleur ne vient que des oiseaux (ronds, dernier oiseau) et du statut (anneau de la carte de
  statut). Depuis J6j, plus aucun `FilledButton` sur l'écran : « Écouter » est le disque du milieu de
  la barre du bas (voir J6e-a). La liste descend jusqu'à la barre : marge basse de 38
  (`BirdySpace.page` + `BirdySizes.listenDiscLift`) pour que le disque ne cache jamais le dernier
  bloc, et un fondu de 28 dp (`BirdySizes.listFade`, du transparent au fond, sans toucher aux
  appuis) adoucit la coupe au-dessus de la barre.
- Mouvement : les 5 premiers blocs montent une fois (220 ms, 40 ms d'écart), les suivants arrivent
  sans animation ; rien en boucle ; animations réduites : aucune entrée, pas même un fondu.
- Tuiles du jour depuis l'index : espèces, contacts, nouvelles (Sûres ou confirmées aujourd'hui,
  jamais vérifiées avant : même règle que « Première fois » du Bilan, via `verifiedSpecies(before:)`).
  Sans écoute du jour : phrase d'invitation à la place des tuiles.
- « Dernier oiseau entendu » sur la teinte de l'espèce (niveau, heure au format de la langue, total),
  vers la fiche. « N détections à vérifier » (cachée à 0), vers la revue rapide. « Écouter » est au
  milieu de la barre du bas, au pouce.
- Les chiffres se chargent après la première image et se remettent à jour quand l'index change.
- Menu (en haut à droite) en attendant la barre de navigation de J6e : Sessions, Palmarès, Carte,
  Revue rapide, Sonothèque, Oiseaux des jardins, Explorer ; Point d'écoute, Transect, ARU, Analyse de
  fichier ; Réglages, Aide, À propos. Rien d'upstream ne disparaît.
- Paysage large : salutation et objectif du jour à gauche ; statut, tuiles et cartes à droite (chaque
  colonne a sa marge basse et son fondu). Colonne de 600 dp au plus sur tablette.
- Viennent avec le jeu (J6e) : pastille de série, carte de statut, défi de la semaine, barre de
  navigation (Accueil, Carnet, Carte, Profil).

## Mise en œuvre (J6c, Fiche espèce)

Code dans `lib/fork/species_page/`. `SpeciesInfoOverlay.show` ouvre cette fiche (une ligne `// FORK`,
constante `kForkSpeciesPage`) ; la feuille upstream reste dans son fichier. On suit SPEC.md 9.13.

- Page plein écran avec retour ; pendant une écoute (`liveStateProvider` actif ou en pause), feuille
  qui garde le thème de l'écran d'écoute, pour ne pas le quitter.
- En-tête : photo de J6b bord à bord (3:2) sur la teinte claire ou sombre de l'espèce
  (`SpeciesAccents`), rayon 28 en bas, nom en Fraunces 34, nom latin. Les icônes de J6d
  remplaceront la photo seulement aux petites tailles.
- Blocs, dans cet ordre : phrase « Entendu… » (ou « Tu ne l'as pas encore entendu. »), badge Sûr
  (confirmée ou score Sûr, même règle que le Bilan) et « N bonnes sur M vérifiées » ; « Mes sons »
  (J7 : le meilleur son ouvre la liste avec le grand bouton `BirdySizes.mainAction` et une ligne en
  `BirdyText.body`, les autres restent en taille normale) ; « Ici en ce moment » avec les 48 semaines
  du géomodèle (barres `ActivityBars`, seuil de la liste Explorer, semaine courante marquée par le
  point, une lettre par mois ; pleine largeur du bloc sous la phrase, jamais dans une colonne de 150 dp :
  `BirdySizes.seasonsChartHeight`, au moins 4 dp par barre dès 320 dp, test à 320/360/412 dp et 130 %). Phrase : migrateur « Arrive début mars · repart fin septembre »
  (début, vers la mi-, fin du mois de la première et de la dernière semaine présentes), sédentaire
  « Présent toute l'année. » ; le résumé Semantics ajoute le mois du pic et la nidification. Bande
  « Nidification : avril à juillet » (`NestingBand`, `BirdySizes.nestingBandHeight`, couleur
  d'accent) sous la courbe, seulement si la fiche IA a le champ `nesting` ; fiche IA
  (résumé en tête, puces SPEC.md 5.10, paragraphe en fondu court) ou description upstream ;
  activité par heure (couleur `deep` de l'espèce) et mini-carte non interactive, côte à côte, l'une
  sous l'autre avec le texte agrandi ; liens eBird, iNaturalist, Wikipédia ; rappel « Garde le son
  pour toi ».
- Chant de référence : aucun son embarqué, le bouton ouvre la page d'écoute eBird (icône de lien).
- Colonne de 600 dp au plus en paysage et sur tablette.

## Mise en œuvre (J6c, Revue rapide)

Code dans `lib/fork/reliability/quick_review_screen.dart` (état, lecture, geste) et
`quick_review_widgets.dart` (barre, progression, pile, carte, indices, boutons). On suit SPEC.md 9.9
et 5.11.

- Thème de l'app (clair ou sombre), colonne de 600 dp au plus, la page défile si le texte est agrandi.
- Geste : la carte suit le doigt ; relâchée sous les seuils (`answerForDrag`), elle revient avec un
  ressort interruptible ; au-delà, elle sort de l'écran en 260 ms dans le sens de la réponse. Pas de
  rotation. La carte suivante arrive en fondu et à l'échelle 0,97 vers 1 (220 ms).
- Pendant le glissement, le contour de la carte prend la couleur de la réponse (Lichen, rouille de
  « À vérifier », bleu de « Probable »).
- Animations réduites : pas de déplacement, la carte s'efface en 150 ms.

## Mise en œuvre (J6c, Palmarès)

Code dans `lib/fork/ranking/ranking_screen.dart` (données, période, options) et
`ranking_widgets.dart` (en-tête, podium, lignes). On suit SPEC.md 9.12.

- Podium : 2e à gauche (150 dp), 1er au centre (184 dp), 3e à droite (136 dp), fond `tintLight` ou
  `tintDark` de l'espèce, disque de rang or (Loriot), argent (`line`) ou bronze (Écorce à 25 %).
  Avec une ou deux espèces, le podium n'a qu'une ou deux marches.
- Lignes : rang en Écorce, photo 36, nom et barre de 8 dp (couleur `deep`, relative au premier),
  nombre en chiffres tabulaires.
- Dates de la période : « du 27 août au 26 septembre », « depuis le 1er septembre », « en 2026 »,
  « depuis le 4 octobre 2025 » (premier contact de la liste).

## Mise en œuvre (J6c, Carte)

Code dans `lib/fork/map/` (écran, feuilles). On suit SPEC.md 9.14, 5.9 et 5.10.

- Marqueur : disque blanc de 44 dp, anneau de 3 dp Martin-pêcheur (Loriot pour le lieu choisi),
  ombre légère, photo de 34 dp, pastille Encre du nombre de contacts en haut à droite.
- Groupe : disque Martin-pêcheur de 56 dp, bord blanc de 3 dp, nombre d'espèces distinctes et
  « espèces » en dessous.
- Puces et boutons au-dessus de la carte : blancs avec l'ombre des couches flottantes.
- Position de l'utilisateur : point de 14 dp et halo fixe, sans animation.
- Petits zooms (J6f) : chaque lieu (case de la grille hexagonale) est le logo BirdyGo en
  couleurs (dégradé Martin-pêcheur, ailes en barres, bec Loriot, œil), centré sur la case, sur un
  halo blanc de 3 dp qui le détache de n'importe quel fond. Le nombre de contacts se lit à la
  taille, de 24 à 40 dp, jamais à l'opacité : un lieu calme est un petit oiseau, pas un oiseau
  délavé. Les plus gros sont dessinés en dernier. Logo enregistré une fois en image, puis
  seulement déplacé et mis à l'échelle (`place_bird_layer.dart`).

## Mise en œuvre (J6e-a, navigation et Carnet)

- Barre du bas (`lib/fork/shell/fork_nav_bar.dart`, J6j) : 5 emplacements, Accueil, Carnet,
  « Écouter », Carte, Profil, dans cet ordre pour le focus et les lecteurs d'écran. Le `NavigationBar`
  de Material ne peut pas porter un emplacement plus haut que lui : la barre est dessinée à la main
  et reprend le look du thème (80 dp, pastille de 64 × 32 sur l'onglet actif, styles d'icône et
  d'étiquette lus dans `NavigationBarTheme`), sans animation de l'indicateur (vue cent fois par
  jour). Le fond et le filet du haut (1 px, `line`) ne couvrent que les 80 dp du bas (plus la zone
  sûre) ; les 22 dp au-dessus sont transparents et laissent passer les appuis vers la page, sauf sur
  le disque. Les pages s'arrêtent au fond de la barre (`Stack` du `ForkShell`), la barre flotte
  dessus. Clavier ouvert (champ de recherche d'une feuille) : la barre se cache et les pages
  descendent jusqu'en bas. Le reste s'ouvre en plein écran par-dessus. Le menu de l'Accueil garde toutes ses entrées ;
  sur Profil, son bouton en haut à droite est le même menu (Palmarès est la première entrée).
- Disque « Écouter » : 68 dp (`BirdySizes.listenDisc`), fond `accent`, liseré de 4 dp de la couleur
  de la barre (`listenDiscRim`), lueur `listenGlow`, haut du disque à 22 dp au-dessus de la barre
  (`listenDiscLift`). Aile de 30 dp au centre (`BirdyGlyph.x6l`), étiquette « Écouter » en
  `accentText` sous le disque, alignée sur la ligne de base des autres étiquettes. Appui à 0,95
  (exception explicite à la règle des 0,97, voir Animations). Tout l'emplacement (disque et
  étiquette) est une cible ; la bande vide à côté du disque n'en est pas une. Un appui ne change
  jamais d'onglet : il ouvre l'écoute (`LiveScreen(forceAutoStart: true)`) ou, si une écoute est en
  cours ou en pause, rouvre son écran sans la relancer.
- Écoute en cours (active ou en pause) : l'aile du disque fait le vumètre du logo de l'écoute
  (`BirdyGoLogoPainter.levelFraction`, `BirdyMotion.listeningLevelPeriod`), à l'arrêt avec les
  animations réduites ou hors écran. Sinon, une vague toutes les 7 s pile, sans variation.
- Gestes (J6f) : un balayage horizontal passe à l'onglet voisin, dans l'ordre de la barre, et la
  pastille suit dès que la page voisine dépasse la moitié de l'écran. Sur l'onglet Carte, le
  balayage est coupé (la carte se déplace au doigt) : on en sort par la barre ou par le retour ;
  entrer dans la carte depuis Carnet ou Profil par un balayage reste possible. Les défileurs
  horizontaux des onglets (puces du Carnet, rangée « Aujourd'hui ») gardent leur geste. Un appui
  sur la barre fait glisser les pages (`BirdyMotion.reorder`, 250 ms, courbe `BirdyMotion.move`) ;
  avec les animations réduites, l'onglet change d'un coup (le balayage suit toujours le doigt).
  Chaque onglet reste en vie hors de l'écran (défilement, filtres, carte) et n'est construit
  qu'à sa première visite ; une fois entièrement hors de l'écran, il est masqué pour
  `Visibility.of` (le logo de l'Accueil ne chante pas quand on ne le voit pas). Le retour
  système depuis un autre onglet ramène à l'Accueil, puis quitte l'application.
- Carnet (`lib/fork/notebook/`) : titre « Mon carnet » et bouton podium, carte de progression
  (découvertes, « N sur M espèces attendues ici cette semaine », barre Martin-pêcheur sans gain
  animé), puces en ligne qui défile, grille de 3 cartes `SpeciesCard` (écart 10). Ordre de « Toutes » :
  nouvelles, à confirmer, puis par nombre de contacts, un mystère toutes les 3 cartes. Pas d'entrée
  décalée : c'est un onglet. Marques en haut à droite : demi-disque Écorce (peu commun), losange et
  étoile Loriot (rare, exceptionnel ici).


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
- Quiz « Qui chante ? » v2 (`lib/fork/game/fine_ear_quiz_screen.dart`, pièces dans
  `fine_ear_quiz_widgets.dart`, `quiz_intro.dart`, `quiz_trail.dart`, `quiz_stage.dart`,
  `quiz_choices.dart`, `quiz_result.dart`, mouvement dans `quiz_fx.dart`, bruitages dans
  `quiz_sfx.dart` ; maquette Claude Design « Quiz v2 ») en trois temps. Icônes d'oiseaux dessinées
  (`assets/fork/species_icons`, `SpeciesIcons`, rendues avec flutter_svg) pour les espèces qui en ont,
  photo ronde (`SpeciesAvatar`, crédit d'un appui) sinon ; oiseau mystère = icône « mystere »
  éclaircie comme la maquette (`brightness(2.2)`, matrice de couleur). Couleurs propres au quiz dans
  `BirdyQuizColors`.
  Accueil : en-tête retour + interrupteur « Avec son / Sans son » (volume_up / volume_off, piste
  Martin-pêcheur, choix mémorisé, `kQuizSoundPref`) qui coupe les bruitages, jamais le chant. Puits
  sombre de 290 dp (dégradé Encre, un filet à 5 % tous les 24 px, rayon 28) : quatre de tes oiseaux
  flottent dans les coins, au centre l'oiseau mystère (disque pointillé de 128) et cinq barres de son
  animées. Titre en 34, une phrase, une bande blanche en trois colonnes séparées d'un filet (icône,
  chiffre 20 en 800, libellé 13 : « 10 chants », « 4 choix », « N de tes oiseaux »), la carte Oreille
  fine (médaille, « 5 sur 10 », barre Lichen), le bouton « C'est parti ! » de 72 dp avec sa lueur.
  Question : une croix (« Quitter le quiz », retour à l'accueil) et le chemin de 10 étapes de 24 px
  fixes : trait de 3 px `line` derrière, trait Martin-pêcheur par-dessus (450 ms) jusqu'au centre de
  l'étape courante ; étapes à venir = points de 12 cerclés de 3 px de la couleur du fond (le trait ne
  les traverse jamais), étape courante = cercle de 30 bordé Martin-pêcheur avec son numéro et un halo
  pulsé, bonne réponse = cercle de 26 sur la teinte claire avec l'icône de l'oiseau (pop), mauvaise =
  cercle de 20 avec une petite croix. Dessous, « Chant 3 sur 10 » et la pastille Loriot « 3 d'affilée ! ».
  Scène d'écoute de 212 dp (moins sur petit écran, 128 au moins) : « Oiseau mystère », disque pointillé
  de 116 qui flotte (±6 px, 3 s), bouton de lecture de 64 entre deux groupes de trois barres qui
  s'animent seulement pendant la lecture (900 ms, décalées), figées à 45 % sinon. Réponses en grille
  2 × 2 de cartes de 136 dp (écart 10, rayon 24), icône de 76 sur son halo (elle rétrécit si le nom
  prend de la place), nom en Fraunces 17 équilibré sur ses lignes. La hauteur de la scène et des cartes
  s'adapte pour que les deux cartes du bas et « Touche l'oiseau qui chante » / « Continuer » restent
  visibles en 360 × 640 ; défilement en dernier recours seulement.
  Bonne réponse : confettis (package confetti, ~110, couleurs de l'oiseau + Loriot, Martin-pêcheur,
  Lichen) partis de la carte touchée, disparus en ~2 s ; la scène passe sur la teinte claire avec des
  rayons qui tournent (12 %, un tour en 14 s), l'oiseau apparaît (0,6 → 1,08 → 1, 500 ms), un
  encouragement en Fraunces 34, puis « C'est bien le merle noir » (article déduit du nom,
  `french_article.dart`, « C'est bien : Nom » si le genre est inconnu). La bonne carte passe en Lichen
  (bordure 2,5) avec une coche et un pop, « +1 Oreille fine » s'envole (1,4 s) ; jingle et vibration
  légère. Mauvaise réponse : carte blanche, « Presque ! », « C'était le … », la carte choisie se
  balance (420 ms) et prend une croix Écorce, les autres passent à 40 %, la bonne en Lichen ; une
  note douce, pas de confettis. « Réécouter » (48 dp) en haut à droite de la scène, jamais sur le texte.
  Bilan : carte héros blanche rayon 28 dont le halo Loriot (32 % → 0 sur 190 px) est la décoration
  même ; trois étoiles pleines (42/56/42, Loriot ou `line`) qui apparaissent l'une après l'autre, le
  score en 64, un mot et une phrase ; « Tes oiseaux du jour » en grille 5 × 2 (en couleur avec coche,
  grisés avec croix, en cascade de 50 ms) ; la carte Oreille fine dont la barre se remplit en 900 ms,
  « Nouvelle plume » si un palier est franchi ; pluie de confettis et fanfare dès la moitié de bonnes
  réponses (`GameConfig.quizPartyShare`) ; « Terminer » (contour) et « Rejouer » côte à côte.
  Mouvement : exception autorisée aux règles de retenue (voir « Animations »), animations réduites =
  tout est immobile et sans confettis.
- Médailles des badges (`BadgeMedal`) : bronze, argent, or pour 1, 2, 3 plumes, avec un dégradé
  métallique (reflet en haut à gauche, ombre en bas à droite), un liseré et un anneau gravé. Le métal
  est le même dans les deux thèmes ; la médaille verrouillée est un disque neutre du thème
  (`lineOpaque`, bordure `border`, icône `text2`). Couleurs dans `GameConfig.badgeMedals`, qui
  remplace les pastilles de SPEC.md 2.7 ; l'icône garde un contraste de 3:1 sur le métal (test).
- Profil en couleur (J6f), langage de blocs de l'Accueil : statut sur bloc Sûr, échelle dans un bloc
  blanc avec le statut en cours sur une pastille tonale (seuil en Martin-pêcheur texte), série sur
  bloc Loriot, badges en mini-blocs Loriot / tonal / Sûr en alternance (jamais deux voisins pareils),
  « Qui chante ? » sur bloc tonal avec un disque Martin-pêcheur de 60 dp (casque) et un « ? » Loriot,
  défi réussi en bloc Loriot avec une coche sur disque Loriot (aussi sur l'Accueil).
- Garde-fous : rien ne se gagne avec une détection Probable ou À vérifier tant qu'elle n'est pas
  confirmée, un oiseau rare se confirme avant la fête, pas de notification culpabilisante, rien qui
  pousse à déranger les oiseaux (repasse) ou à publier la position d'une espèce sensible.

## Logo

Dans `fork/brand/` : `birdygo-logo.svg` (animé en CSS, pour le README), `birdygo-logo-static.svg`
(même dessin sans animation, base de l'icône d'app et du logo de l'accueil, dont l'animation se refait
en Flutter), `birdygo-logo-small.svg` (simplifié, de 16 à 32 px).

Recoloration par thème (J6i) : les painters (`BirdyGoLogoPainter`, `BirdyGoSingingPainter`,
`BirdyWingIcon`, splash) reçoivent un `BirdyBrandColors` (Loriot par défaut). Corps et queue :
dégradé `accentHi` → `accentDeep` ; bec supérieur et barre 2 : `highlight` ; bec inférieur :
`highlightDeep` ; barres 1 et 3 : Brume ; barre 4 : `accentLight` ; notes du chant : `accent`,
`highlightDeep`, `accentDeep`. L'œil et le reflet ne changent pas.

Wordmark 2c (`BirdyGoWordmark`, accueil, écran de démarrage, onboarding) : « Birdy » en Nunito 800
couleur encre, puis un point de diamètre 0,2 × la taille (`dotRatio`), avec la même marge de chaque
côté (0,125 × la taille, soit 3 px à 24 ; `dotMarginRatio`), centré à mi-hauteur des minuscules
(x-height de Nunito 0,484 em, `nunitoXHeight`), couleur `wordmarkDot` du thème ; puis « Go » en
Nunito 900, même taille, en `accentText` (`accentTextDark` en sombre). Le point suit l'échelle du
texte. Libellé d'accessibilité « BirdyGo », jamais traduit ; les trois parties sont exclues.

## Textes

Français simple, tutoiement, phrases courtes. Une action garde le même nom partout : « Écouter »,
« Arrêter », « Réécouter », « C'est bien lui », « Ce n'est pas lui », « Je ne sais pas ».

Une erreur dit ce qui se passe et quoi faire : « Le micro est bloqué. Autorise-le dans les réglages
du téléphone. »

Un écran vide invite à agir (voir « Écrans vides » ci-dessous) : « Aucun oiseau pour l'instant »,
puis « Lance une écoute au lever du jour, c'est l'heure où ils chantent le plus. »

Pas d'emoji dans l'interface.

## Écrans vides

Un seul composant, `BirdyEmptyState` (`lib/fork/design/widgets/empty_state.dart`), pour tout écran ou
bloc qui n'a rien à montrer. Il se lit de haut en bas comme une phrase : l'icône dit ce qui remplira
l'écran, le titre dit ce qui manque, la phrase dit quoi faire (et quand), le bouton le fait.

Trois situations, qui choisissent la couleur du disque et le ton :

| Situation | `kind` | Disque | Icône | Ton | Bouton |
|---|---|---|---|---|---|
| Rien encore : l'app n'a jamais rien eu à montrer ici | `firstUse` | Martin-pêcheur clair (`tonal`) | ce qui remplit l'écran (oreille pour une écoute, note pour la sonothèque, plus pour un ajout) | invitation, avec le bon moment (« au lever du jour ») | principal, seulement si l'écran n'a pas déjà l'action (l'Accueil a déjà « Écouter ») |
| Rien avec ces filtres : il y a des données, pas pour cette période ou ce filtre | `filtered` | gris (`borderOpaque`) | loupe barrée, ou le filtre lui-même (étoile pour « Favoris ») | court, propose d'élargir | tonal, qui élargit quand c'est possible (« Toute la période », « Tous les enregistrements ») |
| Tout est fait : vide parce que le travail est terminé | `done` | Lichen (`sure`) | coche | positif, avec le chiffre de ce qui a été fait | aucun |

Règles :

- Le titre dit ce qui manque, en une ligne, sans point final : « Aucun oiseau pour l'instant ». La
  phrase dit l'action qui remplit l'écran, jamais un reproche (« Tu n'as pas… » est interdit).
- Toujours une icône (`AppIcons`), jamais d'illustration ni d'emoji. L'icône montre ce qui viendra,
  pas le vide : pas de « boîte vide » ni de point d'interrogation.
- Pleine page (`BirdyEmptyState`) quand l'écran n'a rien d'autre à montrer : Palmarès, Sonothèque,
  Revue rapide. Carte en ligne (`BirdyEmptyState.inline`) quand le vide n'est qu'un bloc parmi
  d'autres : tuiles du jour de l'Accueil, liste de l'Envoi à la LPO, comptage au jardin, et par-dessus
  la Carte (avec l'ombre des couches flottantes).
- Distinguer « rien encore » de « rien avec ces filtres » dès que l'écran a un filtre : le Palmarès
  compare à la période « Tout », la Carte sait si l'index est vide, la Sonothèque regarde le filtre
  « Favoris seulement ». Le cas « rien encore » ne doit jamais s'afficher alors que d'autres réglages
  montreraient quelque chose.
- Un chargement n'est pas un vide : indicateur de progression ou squelettes (balayage de lumière) tant que les données ne sont pas là,
  puis l'écran vide en fondu (`BirdyEntrance`, fondu seul en animations réduites).
- Textes : clé `<écran>EmptyTitle` pour le titre, `<écran>Empty` pour la phrase, dans `app_fr.arb`
  et `app_en.arb`. Les trois situations sont visibles dans la galerie du design system.

## Astuces (« Le saviez-vous ? »)

Un seul composant, `BirdyTipCard` (`lib/fork/design/widgets/tip_card.dart`), pour toute astuce ou
anecdote montrée pendant une attente (écoute sans oiseau, chargement long, fin de liste) ;
`BirdyTipCarousel` pour en faire défiler plusieurs.

- Carte `surface1`, bordure, rayon 20, largeur 460 au plus. À gauche, l'icône de l'astuce (`AppIcons`)
  dans un disque Loriot clair (`orioleContainer` / `orioleText`) : le Loriot dit « petite découverte ».
- En tête, une ampoule et « Le saviez-vous ? » en légende Loriot, en minuscules (clé `forkTipHeader`).
  C'est le seul sur-titre admis, et il reste dans la carte. Puis le titre (`label`) et une ou deux
  phrases (`bodyCompact`, `text2`).
- Carrousel : départ au hasard, un appui passe à la suivante (léger enfoncement `Pressable`), défilement
  seul toutes les 15 s sauf avec un lecteur d'écran, fondu enchaîné de 220 ms (aucun en animations
  réduites). Des points en bas disent où on en est. La carte garde la hauteur de l'astuce la plus
  longue : rien ne bouge autour.
- Icône animée (`BirdyAnimatedIcon`, `lib/fork/design/widgets/birdy_animated_icon.dart`) : nos
  Material Symbols, joués une fois quand l'astuce arrive, 150 ms après le fondu de la carte, en
  450 ms. Quatre mouvements : `fill` (l'icône se remplit, par défaut), `drift` (glisse de 6 px :
  vent, distance), `drop` (descend en place : téléchargement), `pulse` (1 → 1,08 → 1 : son, score).
  Ni rotation, ni rebond, ni boucle ; état final direct en animations réduites. Pas de pack d'icônes
  animées externe : les packs gratuits ne couvrent pas nos sujets dans un style unique, et Lordicon
  gratuit exige un crédit et interdit de publier ses fichiers dans le dépôt public.
- Une astuce ne fait jamais la leçon : elle donne un truc de terrain ou une curiosité sur les oiseaux.

## Chiffres des tuiles

Le chiffre d'une `StatTile` tient toujours sur une ligne : trop long (« 1:02:47 » après une heure
d'écoute), il rétrécit à la largeur de la tuile au lieu de passer à la ligne.

## Contrôle qualité

Contraste AA, thèmes clair et sombre, paysage et tablette (exigence d'upstream), texte agrandi à
130 %, libellés pour les lecteurs d'écran sur les boutons icônes, 60 images par seconde en mode
profile sur le Xiaomi (120 quand l'écran le permet), écoute lancée en moins d'une seconde.


## Startup screen (J6c)

The Claude Design board « BirdyGo Splash » defines the Mist background, the singing bird
in a 310 × 245 dp frame (narrower screens shrink it), the wordmark « Birdy » in Fraunces
44 dp, an Oriole dot, then « Go » in Atkinson 42 dp extra-bold (variant « Point Loriot »
of the board, the user's choice), and the bottom loading status with BirdNET
attribution. The tagline is "Le monde chante. Écoute." / "The world is singing. Listen."
No synthetic bird audio is played. The startup follows the device theme, like App by
default: Mist with Ink text in light mode, Ink with Mist text (secondary text `text2` of the
dark theme) in dark mode. The native Android launch screen is the same plain color with no
mark (transparent Android 12+ icon, `values-night/birdygo_colors.xml` for dark), so the bird
appears only once, fading in with the Flutter splash.

The startup plays in three acts (times from the moment the splash appears, all in
`BirdyGoSplashTimeline`). Arrival, 0 to 1 s: the bird fades in (380 ms), rises 12 view-box
units and grows from 0.9 with a slight back-ease overshoot (850 ms); the wing bars draw
from 450 ms, 60 ms apart, 500 ms each. Song, from 1.15 s: phrases of three syllables
(400 ms apart, 360 ms each), every 6.5 s. On each syllable the beak opens, the body swells,
the tail (extended into the body so no gap opens, swinging 5° about its root, as on the
Claude Design board) and the wing bars move, and a note leaves the beak (Kingfisher, gold,
deep teal) and flies for 1.3 s. From 2.4 s the bird breathes (scale ±0.7 %), and it blinks
at 4.3 s, then every 4.2 s. Name: the centred block (mark, wordmark, tagline) starts 56 dp
lower and rises from 2.15 s over 800 ms (cubic in-out); the wordmark enters at 2.35 s,
« Le monde chante. » at 2.75 s and « Écoute. » at 3.3 s, each in 650 ms with 10 dp of
travel and a blur fading from 4 dp; the footer (loading bar, « Propulsé par BirdNET »)
fades in from 3.8 s over 700 ms. The phrase repeats for as long as initialization runs.
This startup-only motion (rotation, back-ease overshoot, breathing, blur, longer
durations) is an explicit exception to the general 500 ms/no-rotation rules. Home reuses
the same painter for its logo, one phrase at a time (see « Mise en œuvre (J6c, Accueil) »);
other app animations are unchanged.
The splash is a real loading screen. After initialization (preferences, notifications,
launch intents), it loads in App's provider container the audio model, the geo-model,
the taxonomy, audio labels and species sheets, and opens (or fills) the observation
index (`lib/fork/splash/birdygo_warm_up.dart`). The steps run side by side. The bottom
bar (120 × 3 dp, Ink at 8 % on Mist, Mist at 12 % on Ink, Kingfisher fill) fills with the
weighted share of the steps done (never a made-up percentage; the board's sweep is not
used). As on the board, no step caption is shown; a screen reader still hears the first
step still loading, then « C'est prêt. » (live region). A failed step counts
as done: the screen that needs the resource reports the error. App opens when loading
is done and the minimum display of 4.5 s (`BirdyGoSplash.minimumDisplay`: the whole
intro, until the footer has faded in) has passed; past 25 s of loading
(`BirdyGoStartup.loadTimeout`) it opens anyway. The location is not loaded here: it may
ask for a permission, which belongs to the screen that needs it.
Reduced motion draws the settled composition immediately and adds no wait. Explicit audio
shares and Quick Listen bypass any remaining wait once their route is ready,
so an active recording's controls are never hidden just to finish the animation.
After a startup error the bird stops singing.
A startup error offers a localized retry. Audio shares and Quick Listen launch intents
are retained across retries. App mounts behind the splash while their storage checks
prepare the destination, so Home does not flash during a cold handoff. The upstream
five-second safety timeout remains. The models load earlier, not twice: the splash awaits
the same futures the home screen warms up. No network image or dependency is added.

The content remains centered within 480 dp, with a compact logo in landscape and scrolling
as a fallback for large text or a short viewport. Android 12 uses a padded VectorDrawable;
older Android versions use the same mark in a layer-list. The native iOS launch assets are
unchanged; the Flutter startup screen also works on iOS.

## Mise en œuvre (J6f, interface finale)

Maquettes : page « App finale » du canevas. Design system : cartes Block, TabHeader, FilterChip,
ListeningMode, ExpectedSpecies.

- Mise en page en blocs (`lib/fork/design/widgets/birdy_block.dart`) : marge de page 16 dp
  (`BirdySpace.page`), 10 dp entre les blocs (`BirdySpace.block`). Un bloc se distingue par la
  teinte de son fond (blanc, tonal, Sûr, Loriot, ou pointillé « À vérifier »), jamais par une
  bordure grise. Boutons ronds blancs sans bordure en thème clair.
- Règle des titres : un onglet (Accueil, Carnet, Carte, Profil) a un grand titre display 34, une
  légende dessous et ses boutons ronds à droite (`BirdyTabHeader`). Un écran ouvert par-dessus
  (Palmarès, Bilan, Revue) a le bouton retour et un titre heading 20 (`BirdyOverlayHeader`) ; une
  croix « Fermer » quand l'écran clôt un parcours (Bilan, Revue), grisée pendant une sauvegarde.
  La Fiche garde son bouton retour sur la photo.
- Filtres (`BirdyFilterChip`) : blancs sans bordure, 48 dp ; le choisi prend sa couleur (Carnet :
  Toutes en encre, Découvertes en Sûr, À découvrir en tonal, Rares en Loriot ; Carte et Palmarès :
  tonal). Sur la carte, ombre flottante.

Accueil
- Ordre : salutation (display 34), « date · lieu · lever du soleil HH:mm » (`estimateAruSunTimes`,
  position déjà connue, jamais de demande) ; héros « Dernier oiseau entendu » (teinte de l'espèce,
  rayon 28, disque d'accent à 18 %, oiseau de 120 dp, nom en title 26, nom latin, Réécouter rond de
  48 dp sur l'accent, icône Encre ou Brume selon le contraste, niveau et total ; tout le bloc ouvre
  la fiche) ; grille de 2 colonnes : objectif du jour sur tonal (anneau Martin-pêcheur, « Encore N
  espèces », 3 silhouettes au plus), série sur Loriot (7 pastilles de la semaine remplies en
  `orioleText` pour garder 3:1), « À vérifier » en pointillé (« N min de revue », 10 s par
  détection) ; statut sur Sûr avec barre ; « Aujourd'hui » (3 chiffres sur une ligne, cartes
  teintées qui défilent, la plus récente d'abord) ; défi de la semaine ; « Écouter » au milieu de la
  barre du bas.
- Un bloc sans donnée disparaît et l'objectif prend toute la largeur. La pastille de série quitte le
  haut de l'écran.
- « Écouter » (disque de la barre, et « Commencer à écouter » de l'objectif) lance l'écoute tout de suite :
  `LiveScreen(forceAutoStart: true)`, aucun écran intermédiaire.

Écoute : état vide
- Tant qu'aucune espèce n'est entrée : « Attendus ici ce matin / cet après-midi / ce soir / cette
  nuit » (`dayPartOf`), « Ils s'allument dès qu'ils chantent. », plus « N comptent pour ton
  objectif du jour. » si N > 0.
- `ReliabilityConfig.liveExpectedCount` (5) espèces, les plus probables cette semaine d'après la
  carte de fréquence du Live (aucun calcul de modèle en plus), sans les non-oiseaux ni celles que
  le Live dirait inattendues. Silhouette grise dans un cercle pointillé de 52 dp, nom, raison
  honnête : « Parmi les plus fréquents ici en <mois> », « En pleine saison ici » (semaine ≥ 80 %
  du pic annuel) ou « Peut chanter ici en <mois> ». Aucun modèle ne connaît l'heure : pas de
  « Chante souvent à cette heure ». Pastille Loriot « Objectif » sur les espèces de l'objectif
  pas encore trouvées. Conseil d'une ligne sur `orioleContainer` en bas.
- L'état s'efface en 150 ms quand la première espèce entre (rien sous animations réduites). Sans
  géomodèle : titre et conseil seulement. Une écoute d'enregistrement garde le carrousel d'astuces.
- En-tête : retour, le logo BirdyGo (`_LiveLogo`, voir Animations) à la place de l'ancien point
  vivant, statut et ligne de lieu en caption dessous (cache de géocodage ou OSM avec accord, jamais
  de demande), puis un seul bouton rond de 48 dp « Options d'écoute » (style `BirdyIconButton`, le
  menu ⋮, le bouton « i » et la pilule de mode ont disparu). Statut et lieu prennent toute la
  largeur restante et ne s'ellipsent qu'en dernier recours (320 dp à 130 %). Le mode actif reste
  toujours visible dans le statut, y compris Normal : « En écoute · Vent », « En écoute · Normal »,
  « En écoute · Personnalisé », son mot et son icône (petite, avant le mot) dans la couleur du mode.
  Les moments (Première fois, Oiseau rare) gardent l'en-tête et ce bouton.

Moment « Première rencontre » (`lib/fork/live/live_moments.dart`, maquette AppPremiere)
- Séquence : voile en fondu (220 ms) ; carte en pop (bg-pop, fondu et 0,97 vers 1, 250 ms), avec ses
  boutons, utilisables tout de suite ; l'oiseau en pop 60 ms plus tard ; derrière lui un halo (bg-glow,
  couleur de l'oiseau à 15 % au plus) et un anneau (bg-ring : opacité 0 → 0,6 → 0, échelle 1 → 1,1,
  1,2 s), une seule fois ; une gerbe de confettis part du centre de l'oiseau à 250 ms (couleurs de
  l'oiseau + Loriot, Martin-pêcheur, Lichen) ; noms, titre et « Ajouté à ton carnet » montent (bg-rise,
  8 px, 220 ms) à partir de 120 ms, 40 ms d'écart ; le statut atterrit (bg-land, 250 ms), puis la
  ligne « Encore N espèces ». Jetons : `BirdyMotion.firstEncounter*`, `ring*`, `glowPeakAt`.
- Toujours : aucun son (le micro l'entendrait), une vibration légère, fermeture seule après 6 s,
  l'en-tête et sa pilule de mode restent visibles, confettis et anneau limités à la zone du moment
  (jamais sur « Arrêter » / « Pause »). Animations réduites : fondus seuls, ni anneau, ni halo, ni
  confettis.
- Bilan : pas de confettis sur la carte « Première fois » ; elle a déjà été fêtée en direct, le Bilan
  se rouvre depuis le journal et peut enchaîner avec « Nouveau statut ».

Modes d'écoute (`lib/fork/listening_mode/`)
- Chaque mode a sa couleur (`ListeningModeColors`, `lib/fork/design/birdy_tokens.dart`), distincte
  en teinte et en clarté, à 4,5:1 au moins sur le fond sombre de l'écoute et sur les surfaces de la
  feuille, comme sur leurs équivalents du thème clair (test de contraste) : Normal reprend
  `accentText` (Martin-pêcheur), Vent un vert proche de Lichen, Boost reprend `orioleText` (Loriot),
  Ville un rose. Le mot et l'icône du mode sont toujours dans cette couleur, dans le statut, dans le
  bouton « Options d'écoute » et dans la feuille des modes ; « Personnalisé » reste en `text2`
  neutre.
- Bouton « Options d'écoute » de l'en-tête (`lib/fork/live/listening_options.dart`) : icône et
  couleur du mode actif (vent, boost, ville, réglage pour Personnalisé), icône neutre « tune » en
  Normal (mais dans la couleur de Normal). Lecteur d'écran : « Options d'écoute, mode Vent ». Il
  ouvre une seule feuille : d'abord la section « Conditions d'écoute » (4 options d'une phrase, 3
  sans Ville, chacune avec son icône et son nom dans sa couleur ; l'option choisie garde son
  contour accentText et sa coche, sans se recolorer), puis un trait et trois lignes de 48 dp :
  « À quel point l'app est sûre » (chevron, ouvre la feuille des niveaux par-dessus, retour à la
  feuille des options), « Aide du mode En direct » et « Paramètres » (ferment la feuille puis
  ouvrent l'aide ou les réglages). Un appui sur un mode l'applique sans couper l'écoute, ferme la
  feuille, et une snackbar confirme « Mode Vent activé » avec l'icône du mode dans sa couleur. Le
  dernier mode est gardé.
- Normal : réglages par défaut. Vent : passe-haut 250 Hz (−2 dB au plus à 400 Hz, chouettes et
  pigeons passent). Boost : gain ×2 et passe-haut 120 Hz. Ville : réduction des bruits continus
  (trames de 16 ms, bruit de fond appris en 1,5 s, −15 dB au plus, retard 16 ms, environ 0,3 % du
  temps réel sur PC), derrière `kCityModeEnabled = !kReleaseMode`.
- Le mode écrit les réglages gain et passe-haut existants, donc le spectre, l'inférence et les
  clips voient le même signal. Un curseur des Réglages bougé à la main affiche « Personnalisé ».
  Le modèle et les seuils ne changent pas.

## Ligne J6h (homogénéité, référence Profil / Quiz)

Source : `fork/handoff/README.md` (captures et maquettes dans `fork/handoff/`). Ces règles priment
sur les sections précédentes en cas de conflit.

1. **Deux en-têtes seulement.** Onglet : `BirdyTabHeader`, titre 34, légende 13, boutons ronds blancs
   de 48. Écran poussé : `BirdyOverlayHeader`, retour 48, titre 20. Les actions (tri, filtre,
   calques) montent dans les boutons ronds de l'en-tête ; plus de ligne d'options flottante.
2. **Un bloc héros par écran.** Rayon `BirdyRadii.hero` (28), marge `BirdySpace.xl` (20), fond teinté.
   Il porte le seul grand chiffre de l'écran (anneau ou nombre 34), sa phrase et sa barre.
3. **Le bloc porte son titre.** Marge de page `BirdySpace.page` (16), `BirdySpace.block` (10) entre
   blocs. Une liste vit dans un seul bloc blanc (rayon 20) titré `BirdyText.heading` (20), lignes
   séparées par un filet `c.line` de 1 px. Plus de piles de cartes séparées.
4. **Une teinte veut dire une seule chose.** `tonal` : écouter, apprendre, progresser. `sure` : acquis,
   confirmé, niveau. `oriole` : récompense, série, rare. `toCheck` (pointillé) : à vérifier. Jamais
   d'alternance décorative.
5. **Une seule ligne de liste.** Disque teinté de 44 avec icône, ou avatar de 48 ; libellé 17 gras,
   légende 13, chevron ; hauteur minimale `BirdySizes.row` (72). Réglages, Plus, Sonothèque,
   Objectif, Bilan et les tiroirs la partagent.
6. **Une seule action forte, en bas.** Depuis J6j, le disque « Écouter » de la barre du bas (68,
   `accent`, `listenGlow`) ; ailleurs, pilule de 72 (`ctaGlow`). Tout le reste : bouton tonal 48, secondaire 56, ou puce.
7. **Puces blanches, choix en encre.** La puce choisie passe en `BirdyChipColors.ink` partout.
   Exception : sur fond Brume, les filtres du Carnet gardent leur teinte de sens.
8. **Même comportement partout.** Entrée décalée (`BirdyEntrance.staggered`, 40 ms,
   `staggerMaxItems`), squelettes à la forme finale puis `BirdyCrossFade`, pression à 0,97
   (`Pressable`), cibles d'au moins 48, jamais de bordure grise sur un bloc.

Règles transverses :
- **Croix ou flèche.** Flèche ← pour revenir sans rien perdre ; croix ✕ pour sortir d'un parcours
  (Bilan, Revue rapide, Quiz en partie ou au score). Quitter une partie en cours demande confirmation.
- **Échelle de texte.** 34 / 26 / 20 / 17 / 15 / 13. Rien sous 12, graphiques et spectrogramme compris.
- **Pastilles.** Hauteur minimale 26, `BirdyText.badge` (13 gras), marge 4/10/4/7. Même format pour
  Nouveau, Nouveau cette année, rareté et fiabilité.
- **Alignement.** Grand chiffre + libellé, ou titre + légende côte à côte : baseline alphabétique,
  jamais `end`.
- **Oiseau générique : une variante par sens** (`BirdyGoSilhouetteIcon`, `SilhouetteRole`), jamais
  `AppIcons.bird`. Un sens = un visuel, partout :
  - `.mystery` (oiseau à découvrir : carte mystère du Carnet, oiseau du quiz, « à trouver » de l'Objectif
    du jour, mini-silhouette du Carnet) : corps gris, pas d'aile, « ? » Loriot sur le centre de l'aile
    (`BirdyMysteryMark`, partagé avec le quiz), masqué sous `BirdySizes.silhouetteMarkMin` (20).
  - `.species` (espèce connue sans photo : repli de `SpeciesAvatar`) : teinte `deep` de l'espèce sur son
    halo, avec l'aile aux couleurs du logo dès `BirdySizes.silhouetteWingMin` (32), sans en dessous.
  - `.glyph` (icône : pastilles du bandeau du jour, feuille du jour, carte défi, « Toutes les espèces »
    de la carte) : forme pleine, ni aile ni « ? », couleur du texte ou de l'icône.
- **Une icône = un sens.** Tri : `sort`. Autres actions : `moreHoriz`. À vérifier (Accueil) : `search`.
  Le « ? » est réservé à « Je ne sais pas ».
- **Fiche, carte de contenu de « Fais sa connaissance ».** Le filigrane de l'icône de la rubrique est en haut à droite de la carte (pas en bas).
- **Fiche, « Fais sa connaissance » (6 rubriques).** Grille 3 × 2 de pastilles de 52 (`BirdySizes.knowledgeDisc`), libellés 13 sur une ligne qui se réduisent dans leur colonne (jamais de débordement, même à 320 dp et 130 %). Ordre : À l'oreille (`tonal`), Taille (`sure`), Habitudes (`tonal`), Migration (`sure`), Ennemis (patte, `probable.background` / `probable.foreground`, accroche « Qui le chasse »), Anecdote (`oriole`). Une rubrique sans texte est masquée ; compteur « {n}/{total} découverts » avec total = rubriques présentes. « Comportement » devient « Habitudes » partout (fiche et bloc).
- **L'aile.** Les 4 barres de `BirdyGoLogoPainter.bars` (Brume, Loriot, Brume, `BirdyBrand.wingSky`
  #8CD3D9), épaisseur 30/512, bouts ronds, ombre douce (0,1 px, flou 2, #0B3C46 à 45 %). Icône des
  boutons « Écouter » et « Commencer à écouter » (écart icône/texte : +`BirdySpace.wingLabelGap`). Sur ces
  deux boutons et sur le disque de la barre (`animated`), toutes les 7 s pile (J6j : plus de variation),
  les barres font une vague douce de 0,9 s, décalées, puis reviennent au repos
  (`BirdyMotion.wingWave*`) ; rien ne tourne entre deux vagues, arrêt avec animations réduites.
  Pendant l'écoute (`listening`), le disque passe au vumètre. La feuille « Arrêter la partie ? » reprend `QuizLogo`, l'emblème du quiz.

## Onboarding (J6i : prénom et oiseau)

Parcours : Bienvenue, Comment, Niveaux (histoire, inchangées) → Étape 1 Prénom → Étape 2 Choisis ton
oiseau → Autorisations → Accueil. Premier lancement en Loriot tant que l'enfant n'a pas choisi.
Références : `fork/handoff/maquettes/DemoPrenom.dc.html`, `DemoTheme.dc.html`, `themes.js`.

- **Les deux étapes** ont leur propre en-tête (« Étape n sur 2 » à droite, flèche ← dans Réglages) et
  leur propre bouton de 72 (`BirdySizes.listen`, halo du thème). L'en-tête et le bouton restent fixes,
  le reste défile (320 dp, 130 %). L'écran cache ses points et « Passer » sur ces deux pages, et ne les
  laisse pas glisser : on en sort par leurs boutons. Les points ne comptent que les 3 pages d'histoire
  et les autorisations.
- **Étape 1.** Disque tonal de 132 (`SingingThemeLogo`, halo blanc 8 à 70 %) qui chante une phrase à
  l'arrivée et au toucher ; wordmark 44 (`BirdyGoWordmark`) ; titre « Bienvenue ! » qui devient
  « Enchanté, {prénom} ! » pendant la saisie ; « Comment tu t'appelles ? » ; champ dans un bloc blanc
  (`autofillHints: givenName`, 24 caractères, filet accent), légende cadenas « Il reste sur ton
  téléphone » ; « Continuer » grisé tant que le champ est vide ; « Plus tard » (texte, 48) ne
  sauvegarde rien.
- **Étape 2 et Réglages, « Mon oiseau ».** Même page (`BirdyBirdStep`). Disque 132 recoloré tout de
  suite et qui chante à chaque carte touchée ; grille 2 × 2 (`BirdyBirdPicker`) de cartes blanches :
  disque tonal 72 avec le logo, nom (Nunito 17), 3 pastilles de 14 (accent, bec, tonal) ; la carte
  choisie a un anneau accent de 3 et une coche. Toucher une carte met `birdyBirdProvider` à jour
  aussitôt : toute l'appli prévisualise l'oiseau, sans attendre « C'est mon oiseau ! ». Encadré
  « Ton icône sur le téléphone » : aperçu 60 (logo sur dégradé tonal → blanc, celui de la future icône
  de lanceur, toujours en clair) et le fait sur l'oiseau. Onboarding : le bouton affiche
  « Bienvenue {prénom} chez les {oiseaux} ! » 1,5 s, puis les autorisations. Réglages : le bouton et la
  flèche reviennent.
- **Réglages.** Ligne « Mon oiseau » en tête du bloc Thème : disque tonal 44 avec le logo (immobile),
  nom de l'oiseau, chevron.
- **Composants partagés.** `SingingThemeLogo` (disque + chant), `BirdyBirdPicker` / `BirdyBirdCard` /
  `BirdyIconPreview`, `BirdyBirdLabels` (nom, pluriel, fait). Aucun disque ni carte écrits à la main
  ailleurs : même emblème partout.
- **Animations réduites.** Ni chant, ni pop, ni fondu ; l'accueil de l'oiseau ne dure pas.
