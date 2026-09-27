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

- Logo : `birdygo_logo.dart` redessine `birdygo-logo-static.svg` en `CustomPainter` (pas de
  `flutter_svg` avant J6d). À l'arrivée, les quatre barres de l'aile se dessinent de bas en haut,
  l'une après l'autre, en 480 ms ; l'oiseau ne bouge pas. Animations réduites : dessiné d'un coup.
- Salutation selon l'heure (mêmes bornes que le Bilan, `dayPartOf`), date et lieu du téléphone
  (cache de géocodage, ou réseau si autorisé ; jamais de demande de localisation depuis l'accueil).
- Ordre (maquette `Main.dc.html`) : salutation, objectif du jour, carte de statut, tuiles du jour,
  dernier oiseau, défi de la semaine, détections à vérifier. Le haut (logo, pastille de série, menu)
  ne s'anime pas.
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
  statut). « Écouter » (pilule Martin-pêcheur de 72 dp, seul `FilledButton` de l'écran) est fixé
  au-dessus de la barre du bas, hors de la zone qui défile.
- Mouvement : les 5 premiers blocs montent une fois (220 ms, 40 ms d'écart), les suivants arrivent
  sans animation ; rien en boucle ; animations réduites : aucune entrée, pas même un fondu.
- Tuiles du jour depuis l'index : espèces, contacts, nouvelles (Sûres ou confirmées aujourd'hui,
  jamais vérifiées avant : même règle que « Première fois » du Bilan, via `verifiedSpecies(before:)`).
  Sans écoute du jour : phrase d'invitation à la place des tuiles.
- « Dernier oiseau entendu » sur la teinte de l'espèce (niveau, heure au format de la langue, total),
  vers la fiche. « N détections à vérifier » (cachée à 0), vers la revue rapide. « Écouter » fixé en
  bas, au pouce.
- Les chiffres se chargent après la première image et se remettent à jour quand l'index change.
- Menu (en haut à droite) en attendant la barre de navigation de J6e : Sessions, Palmarès, Carte,
  Revue rapide, Sonothèque, Oiseaux des jardins, Explorer ; Point d'écoute, Transect, ARU, Analyse de
  fichier ; Réglages, Aide, À propos. Rien d'upstream ne disparaît.
- Paysage large : salutation et objectif du jour à gauche ; statut, tuiles, cartes et « Écouter » à
  droite. Colonne de 600 dp au plus sur tablette.
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
- Blocs : phrase « Entendu… » (ou « Tu ne l'as pas encore entendu. »), badge Sûr (confirmée ou score
  Sûr, même règle que le Bilan) et « N bonnes sur M vérifiées » ; « Ici en ce moment » avec les 12 mois
  du géomodèle (un mois = sa meilleure semaine, seuil de la liste Explorer) ; « Mes sons » ; fiche IA
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

## Mise en œuvre (J6e-a, navigation et Carnet)

- Barre du bas (`lib/fork/shell/fork_shell.dart`) : `NavigationBar` du thème (80 dp, pastille
  Martin-pêcheur sur l'onglet actif), sans animation de l'indicateur (vue cent fois par jour).
  Accueil, Carnet, Carte, Profil ; le reste s'ouvre en plein écran par-dessus. Le menu de l'Accueil
  garde toutes ses entrées.
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
- Médailles des badges (`BadgeMedal`) : bronze, argent, or pour 1, 2, 3 plumes, avec un dégradé
  métallique (reflet en haut à gauche, ombre en bas à droite), un liseré et un anneau gravé. Le métal
  est le même dans les deux thèmes ; la médaille verrouillée est un disque neutre du thème
  (`lineOpaque`, bordure `border`, icône `text2`). Couleurs dans `GameConfig.badgeMedals`, qui
  remplace les pastilles de SPEC.md 2.7 ; l'icône garde un contraste de 3:1 sur le métal (test).
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
- Un chargement n'est pas un vide : indicateur de progression tant que les données ne sont pas là,
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

The bird sings phrases of three syllables: on each one the beak opens, the body swells,
the tail and the wing bars move, and a note leaves the beak (Kingfisher, gold, deep
teal). The eye blinks after the phrase. The wing bars draw first; the wordmark enters at
1.0 s, « Le monde chante. » at 1.25 s, the loading status at 1.35 s and « Écoute. » at
2.15 s, each in 320 ms with 8 dp of travel. A phrase lasts 3.6 s and repeats for as long
as initialization runs. This startup-only motion is an explicit exception to the general
500 ms/no-rotation rules; it does not change Home's logo or other app animations.
The splash is a real loading screen. After initialization (preferences, notifications,
launch intents), it loads in App's provider container the audio model, the geo-model,
the taxonomy, audio labels and species sheets, and opens (or fills) the observation
index (`lib/fork/splash/birdygo_warm_up.dart`). The steps run side by side. The bottom
bar fills with the weighted share of the steps done (never a made-up percentage) and the
caption names the first step still loading, then « C'est prêt. ». A failed step counts
as done: the screen that needs the resource reports the error. App opens when loading
is done and the minimum display of 4.4 s (`BirdyGoSplash.minimumDisplay`: one whole
phrase, up to the blink and the last note fading out) has passed; past 25 s of loading
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
