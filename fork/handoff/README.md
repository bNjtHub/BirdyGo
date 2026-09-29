# Handoff BirdyGo : passe d'homogénéité (ligne Profil / Quiz) et nouveautés

> Pour Claude Code, dans le dépôt `bNjtHub/BirdyGo` (branche `main`, code dans `lib/fork/`).
> À lire avec `CLAUDE.md`, `fork/DESIGN.md` et `lib/fork/design/birdy_tokens.dart`.

## Vue d'ensemble
Benjamin trouvait les écrans Profil et « Qui chante ? » réussis et voulait que tous les autres suivent la même ligne : mêmes blocs, mêmes teintes, mêmes comportements. Ce dossier décrit :
1. la **ligne de design** (8 règles) qui devient la référence ;
2. les **changements écran par écran** par rapport au code actuel ;
3. les **nouveautés** validées pendant la maquette : bande « Ta journée », prénom, fiche ludique, écoute claire, étiquettes de rareté, etc.

## À propos des fichiers de maquette
Les fichiers `maquettes/*.dc.html` sont des **références de design faites en HTML**. Ce sont des prototypes qui montrent l'aspect et le comportement voulus, pas du code à copier. Le travail consiste à **les recréer en Flutter** dans le code existant, avec ses propres briques : `BirdyBlock`, `BirdyTabHeader`, `BirdyOverlayHeader`, `BirdyFilterChip`, `BirdyPill`, `ReliabilityBadge`, `StatusRing`, `SegmentedBar`, `showBirdySheet`, `BirdyMotion`, `AppIcons`.
- `BirdyGo Demo.dc.html` : démo cliquable de tous les écrans. L'état est dans la classe logique en bas du fichier ; chaque écran est dans `Demo*.dc.html`.
- `BirdyGo Ligne de design.dc.html` : planche des 8 règles, avec avant et après.
- Ces fichiers ne s'ouvrent qu'avec le moteur de canevas, comme ceux de `fork/maquette/`. Pour des captures, demander à Benjamin.

## Fidélité
**Haute fidélité.** Couleurs, tailles, rayons, espacements et textes sont définitifs. Toutes les valeurs viennent déjà des jetons du code (`BirdyColors`, `BirdyText`, `BirdySpace`, `BirdyRadii`, `BirdySizes`) : **aucune nouvelle couleur hors palette**. Si une valeur ci-dessous ne correspond à aucun jeton, créer le jeton dans `birdy_tokens.dart`, jamais de valeur en dur.

---

## 1. La ligne de design (à ajouter dans `fork/DESIGN.md`, section « Ligne J6h »)

1. **Deux en-têtes seulement.**
   - Onglet : `BirdyTabHeader`, titre 34, légende 13 et boutons ronds blancs de 48.
   - Écran poussé : `BirdyOverlayHeader`, retour 48 et titre 20.
   - Les actions (tri, filtre, calques) montent dans les boutons ronds de l'en-tête. Plus de ligne d'options flottante.
2. **Un bloc héros par écran.** Rayon `BirdyRadii.hero` (28), marge `BirdySpace.xl` (20), fond teinté. Il porte le seul grand chiffre de l'écran (anneau ou nombre 34), sa phrase et sa barre.
3. **Le bloc porte son titre.**
   - Marge de page `BirdySpace.page` (16), `BirdySpace.block` (10) entre blocs.
   - Une liste vit dans **un seul bloc blanc** (rayon 20), avec un titre `BirdyText.heading` (20). Les lignes sont séparées par un filet `c.line` de 1 px, comme « Badges » dans « À gagner ».
   - Plus de piles de cartes séparées.
4. **Une teinte veut dire une seule chose.**
   - `tonal` (Martin-pêcheur) : écouter, apprendre, progresser.
   - `sure` (Lichen) : acquis, confirmé, niveau.
   - `oriole` (Loriot) : récompense, série, rare.
   - `toCheck` (pointillé) : à vérifier.
   - Jamais d'alternance décorative de teintes.
5. **Une seule ligne de liste.**
   - Disque de 44 teinté avec une icône, ou avatar de 48.
   - Libellé 17 gras, légende 13, chevron. Hauteur minimale `BirdySizes.row` (72).
   - Réglages, Plus, Sonothèque, Objectif, Bilan et les tiroirs la partagent.
6. **Une seule action forte, en bas.** Pilule de 72, Martin-pêcheur, avec `listenGlow` ou `ctaGlow`, épinglée en bas (« Écouter », « C'est parti ! », « Commencer à écouter »). Tout le reste : bouton tonal de 48, bouton secondaire de 56, ou puce.
7. **Puces blanches, choix en encre.** La puce choisie passe en `BirdyChipColors.ink` partout : Carnet, Palmarès, Carte, Sonothèque, Réglages. Exception : sur fond Brume, les filtres du Carnet gardent leur teinte de sens.
8. **Même comportement partout.**
   - Les blocs montent en décalé (`BirdyEntrance.staggered`, 40 ms, `staggerMaxItems`).
   - Les squelettes ont la forme finale, puis `BirdyCrossFade` sur place.
   - Pression à 0,97 (`Pressable`).
   - Zones à toucher d'au moins 48. **Jamais de bordure grise** sur un bloc.

**Règles transverses**
- **Croix ou flèche.** Flèche ← pour revenir sans rien perdre. Croix ✕ pour sortir d'un parcours : Bilan, Revue rapide, Quiz en cours de partie ou sur l'écran de score. Quitter une partie en cours demande une confirmation.
- **Échelle de texte.** 34 / 26 / 20 / 17 / 15 / 13. Rien sous 12, y compris les libellés de graphiques et le spectrogramme (13).
- **Pastilles.** Hauteur minimale 26, texte `BirdyText.badge` 13 gras, marge 4/10/4/7. Même format pour Nouveau, Nouveau cette année, rareté et fiabilité.
- **Alignement.** Grand chiffre + libellé, ou titre + légende côte à côte : `CrossAxisAlignment.baseline` (`TextBaseline.alphabetic`), jamais `end`.
- **Oiseau générique.** Le repli visuel d'une espèce sans photo devient **la silhouette BirdyGo** (`BirdyGoSilhouetteIcon`, `birdygo_silhouette.dart`) dans la teinte `deep` de l'espèce sur son halo, à la place de `AppIcons.bird` (raven). Le mettre dans `SpeciesAvatar._silhouette`.
- **Une icône = un sens.** Tri du Palmarès : `sort`, pas `tune`. « Autres actions » : `more_horiz`. « À vérifier » sur l'Accueil : `search` (loupe). Le « ? » est réservé à « Je ne sais pas ».

---

## 2. Écrans : ce qui change par rapport au code

### Accueil (`fork_home.dart`, `home_widgets.dart`)
- **Nouveau : bande « Ta journée ».** Sous l'en-tête, centrée sur toute la largeur, une ligne de 5 pastilles (hauteur 26, écart 4, marge 4/7/4/5, 13 gras, chiffres tabulaires). Elle ne passe jamais à la ligne.

  | Moment | Heure | Icône | Fond / texte |
  |---|---|---|---|
  | Oiseaux du matin | 06:50 | silhouette BirdyGo 15 | `tonal` / `accentText` |
  | Lever | 07:36 | `wb_sunny`, couleur `orioleText` | `surface1` / `text1` |
  | Heure dorée | 18:55 | `auto_awesome` plein | `orioleContainer` / `orioleText` |
  | Oiseaux du soir | 19:10 | silhouette BirdyGo 15 | `tonal` / `accentText` |
  | Coucher | 19:41 | `wb_twilight`, couleur `probable.foreground` | `surface1` / `text1` |

  - Toucher une pastille ouvre le tiroir « Ta journée d'écoute », voir plus bas.
  - Calcul : lever et coucher existent déjà (`home_loader.sunrise()`), ajouter le coucher. Heure dorée : environ coucher − 45 min. Oiseaux du matin : lever − 45 min → lever + 55 min. Oiseaux du soir : coucher − 30 min → coucher + 30 min. Mettre ces paramètres dans une config, pas en dur.
- La ligne de date devient « Mardi 29 septembre · Lieu ». Le lever du soleil passe dans les pastilles.
- **Salutation avec prénom** : « Bonjour Benjamin » si un prénom est enregistré, sinon « Bonjour ».
- **Bouton « Écouter »** : `graphic_eq` est remplacé par **l'aile du logo**, 28 px. Ce sont les 4 barres de `BirdyGoLogoPainter.bars`, dans leurs couleurs d'origine (Brume, Loriot, Brume, #8CD3D9) et épaisseur 30/512 à bouts ronds. Elles portent une ombre douce : drop shadow 0,1 px, flou 2, `#0B3C46` à 45 %. Pas de contour. Même icône sur « Commencer à écouter » (Objectif du jour).
- Bloc « à vérifier » : l'icône `question` devient `search`.
- Lettres des jours de la série : 12 au lieu de 11.
- « Aujourd'hui » : titre et chiffres alignés sur la ligne de base.

### Tiroir « Ta journée d'écoute » (nouveau, `showBirdySheet`)
- Titre 26 « Ta journée d'écoute », légende « Mardi 29 septembre · Lieu ».
- **Bloc « Quand les oiseaux chantent »** : fond `tonal`, rayon 20, marge 12/8/8, en-tête 13 gras `accentText` avec l'icône `music_note`. Deux lignes :
  - « Le matin », 06:50 → 08:30 : « Le chœur de l'aube : c'est le moment où le plus d'oiseaux chantent. Le meilleur moment pour écouter. »
  - « Le soir », 19:10 → 20:10 : « Le chœur du soir, plus court : merles et rougegorges surtout. Puis les chouettes prennent le relais. »
- **Bloc « Le soleil »** : fond `orioleContainer`, en-tête `orioleText` avec l'icône `wb_sunny`. Trois lignes :
  - « Lever du soleil », 07:36 : « Les merles et les rougegorges ont déjà commencé, les pinsons et les mésanges suivent. »
  - « Heure dorée », 18:55 → 19:41 : « La lumière est douce et chaude : idéal pour les photos, et les oiseaux se remettent à chanter. »
  - « Coucher du soleil », 19:41 : « Écoute encore un peu après : la chouette hulotte chante souvent à la tombée de la nuit. »
- **Une ligne** : disque blanc de 44 (silhouette 24 ou icône 22), nom 17 gras, heure 15 extra-gras tabulaire à droite (alignée sur la ligne de base), texte 13. Le moment touché est entouré d'une bordure 2 px `accent`, rayon 16.
- **Pied** : tonal « Me le rappeler » (icône `notifications`, rappel 10 min avant l'heure des oiseaux du lendemain) et principal « Écouter » (lance l'écoute).

### Écoute (`live_*.dart`)
- **Nouveau : option claire.** Réglage `liveTheme` (`dark` par défaut, ou `light`), dans deux endroits :
  - Réglages, bloc Thème : « Écran d'écoute », légende « Sombre par défaut : il éblouit moins à l'aube et économise la batterie », puces Sombre / Clair.
  - Tiroir des options d'écoute : interrupteur « Écran clair ».

  En clair, l'écran d'écoute suit `BirdyColors.light` : fond Brume, lignes blanches, texte encre.
  - Couleurs de mode claires : `ListeningModeColors.*Light`.
  - « Arrêter » devient encre pleine avec texte Brume : le bouton Brume disparaîtrait sur Brume.
  - Le **spectrogramme reste sombre** dans les deux thèmes.
- **Étiquettes de rareté dans les lignes**, à côté du badge de fiabilité : pastille « 👁 Peu commun ici » (`visibility` plein, fond `line`, texte `text2`) ou « ◆ Rare ici » (fond `orioleContainer`, texte `orioleText`).
  - Si la pastille « ◆ Rare ici · à confirmer » s'affiche déjà (inattendu + à vérifier), pas d'étiquette en plus. Pas d'icône seule à côté du nom.
- Spectrogramme : noms d'espèces en 13 gras, jamais superposés. On saute un nom qui toucherait le précédent (écart de 8 px), et on ne l'écrit pas s'il sort à gauche.

### Bilan (`listening_summary_view.dart`)
- Marge 16, écart 10 entre blocs (au lieu de 20 et 12).
- **Héros** : bloc `tonal` rayon 28 avec le titre 34 (« Belle matinée ! »), une légende 13 gras `accentText` et **les 3 chiffres dedans**, sur 3 tuiles blanches. Durée : « 36 » en 26, puis « min » en 15, pour ne pas déborder.
- Nouveautés et « Les N espèces entendues » passent dans des blocs blancs titrés 20.
- **Actions** : un seul bouton principal 56 « Vérifier N détections ». En dessous, un secondaire 56 « ⋯ Autres actions » qui ouvre un **tiroir** avec 4 lignes du modèle unique :
  - Envoyer à Faune-France : « Fiche prête pour chaque observation confirmée ».
  - Ajouter un oiseau observé : « Vu mais pas entendu ».
  - Détail de l'écoute : « Chaque détection, minute par minute ».
  - C'était un enregistrement : « Ne compte pas dans tes statistiques ».
- Fermeture par la croix. « Revoir sur la carte » pousse la Carte avec une flèche retour qui ramène au Bilan.

### Revue rapide (`quick_review_*.dart`)
- La pile de cartes est **centrée verticalement** entre la barre de progression et les boutons de verdict.
- Le reste est inchangé.

### Fiche espèce (`species_page_view.dart`)
- Marge 16. « Entendu N fois… » devient un **héros `sure`** avec 2 tuiles blanches (contacts, jours), la phrase, le badge Sûr et la précision.
- « Ici en ce moment », « Mes sons » et « Activité / mini-carte » deviennent des blocs blancs titrés 20. Libellés des mois et des heures en 12.
- **Nouveau bloc « Fais sa connaissance »**, qui remplace les puces de `SheetChipsBlock` :
  - En-tête 20 et compteur « N/5 découverts » 13 gras `accentText`, puis le résumé en 15 `text2`.
  - **5 pastilles rondes de 52** en grille 5 colonnes, avec un libellé 13 dessous :

    | Section | Icône | Teinte |
    |---|---|---|
    | À l'oreille | `hearing` | tonal |
    | Taille | `straighten` | sure |
    | Comportement | `visibility` | tonal |
    | Migration | `flight` | sure |
    | Anecdote | `lightbulb` | oriole |

  - Pastille choisie : fond de sa teinte, icône pleine, anneau 2 blanc + 2 couleur. Section déjà lue : petite coche Lichen de 18 en coin.
  - **Carte de contenu** : fond de la teinte, rayon 20, grande icône en filigrane (88, 12 %), accroche 13 gras (« Comment le reconnaître », « Sa taille », « Ce qu'il fait », « Où il passe l'année », « Le savais-tu ? »), texte 17.
  - Sous la carte : barre de 5 segments de 6 px, puis un bouton blanc « Suivant → ». Il devient « Revoir » à la fin.
  - En dessous, **le même lien quiz que dans le Profil** : `QuizLogo` 56, « Qui chante ? », et « Teste ton oreille sur ses chants et ceux de tes sorties. Gagne le badge Oreille fine. » avec un chevron.
- « Voir sur la carte » pousse la Carte avec une flèche retour.

### Carnet (`notebook_screen.dart`)
- Légende d'en-tête : « 24 oiseaux dans ton carnet ».
- **Héros**, mêmes données mais textes plus simples :
  - Titre 20 « Les oiseaux du coin ».
  - « 20 oiseaux vivent près de chez toi en ce moment. Tu en as trouvé 14, il en reste 6 ! »
  - Sous la barre, avec une mini-silhouette grise : « Les oiseaux gris, ce sont ceux qu'il te reste à trouver. »
- Bloc compteur « à trouver » : il compte les **mystères + les à-confirmer**, et le filtre « À trouver » garde les deux.
- Filtres et grille rentrent dans un bloc blanc « Ma collection » (titre 20 et « N cartes » sur la même ligne de base). Les puces non choisies sont Brume. Un fondu blanc de 40 px à droite montre que la ligne défile.
- **Grille à 2 colonnes**, au lieu de 3. Visuel 88, nom `BirdyText.species` (17).
- Carte mystère : « Oiseau mystère » avec l'indice dessous.
- **Rareté en mots, avec icône**, en bas de la carte à côté de « Nouveau » (plus en coin, ça cachait l'oiseau) :

  | Étiquette | Icône | Fond / texte |
  |---|---|---|
  | Peu commun | `visibility` | blanc / `text2` |
  | Rare | `diamond` | `orioleContainer` / `orioleText` |
  | Exceptionnel | `star` | `orioleContainer` / `orioleText` |

  Pas de légende séparée.

### Carte (`contact_map_screen.dart`)
- Puces flottantes : la période choisie et « Confirmées » activée passent **en encre** (au lieu de tonal).
- Libellé « espèces » de la bulle de groupe : 11 au lieu de 10.
- Ouverte par-dessus un autre écran (Bilan, Fiche) : bouton retour dans l'en-tête.

### Profil (`profile_screen.dart`)
- **Ligne de l'échelle des niveaux** : 3 traits séparés **entre** les emblèmes, de largeur `cellule − 48`, arrondis, centrés verticalement sur l'emblème (haut = 8 + 24 − épaisseur / 2). Elle ne doit plus passer dans l'anneau de l'emblème actuel.
- « Bravo Benjamin, te voilà » si un prénom est enregistré.
- Progression des badges : 13 au lieu de 12.
- Défi de la semaine : l'icône raven devient la silhouette BirdyGo.

### Qui chante ? (`quiz_intro.dart`, `fine_ear_quiz_screen.dart`)
- **L'intro tient sans défiler** sur un téléphone de 844 pt : zone illustrée de 210, écarts de 12.
- Les 3 cartes d'étapes gardent leur inclinaison pendant leur animation d'apparition : c'est une rotation séparée, pas écrasée par l'animation.
- **Oiseau mystère** : un « ? » Fraunces 30 gras Loriot, penché de −8°, posé sur l'aile (`birdyGoWingCenter`).
- **Fermeture** : flèche sur l'intro, croix pendant la partie et sur le score.
  - La croix en pleine partie ouvre un tiroir : disque Loriot `headphones`, « Arrêter la partie ? », « Tes N bonnes réponses sont gardées pour le badge Oreille fine. », avec les boutons [Arrêter] (secondaire) et [Continuer] (principal).
- Retour après une réponse : « Bravo, c'est bien lui : {Nom} » ou « C'était : {Nom} ». Pas d'article accordé à la main.

### Palmarès (`ranking_screen.dart`, `ranking_widgets.dart`)
- Marge 16 au lieu de 20, blocs à 10.
- **Héros tonal** : chiffre 34 et libellé alignés sur la ligne de base, légende « 9 nouvelles en 2026 · du … au … ». Les **puces de période** (hauteur 48) sont dans le héros, la choisie en encre.
- Bloc blanc « Podium » (titre 20 et interrupteur « Confirmées » dans l'en-tête), puis bloc blanc « Classement » (titre 20 et « par contacts ▾ »), avec des lignes séparées par un filet.
- Bouton rond `sort` en haut à droite, pour trier et filtrer, à la place de la ligne d'options flottante.

### Sonothèque (`sound_library_screen.dart`)
- Héros tonal : disque blanc de 76 avec `graphic_eq`, « 126 enregistrements » aligné sur la ligne de base, « 18 espèces · 9 ★ favoris ».
- Puces « Toutes / ★ Favoris seulement » : le filtre favoris est **aussi sur la liste des espèces**. La choisie est en encre.
- Les espèces passent dans **un seul bloc blanc** à lignes séparées (au lieu de cartes espacées de 8).

### Réglages (`simple_settings_screen.dart`)
- Chaque bloc a un titre 20 (Toi, Langues, Thème, Options). Chaque ligne a son disque de 44 teinté.
- **Nouveau bloc « Toi »** : disque Loriot `person`, champ « Ton prénom » (24 caractères au plus, espace réservé « Pour te saluer »), note : « Il reste sur le téléphone. Demandé au premier lancement, jamais obligatoire. »
- Thème : Clair / Sombre / **Auto** (icône `smartphone`, plus `contrast`), sur **une ligne** en grille de 3.
- Écran d'écoute : Sombre / Clair, voir Écoute.
- « Réglages avancés » redevient un bloc **blanc** : le Loriot reste sur son disque de 44.

### Menu Plus (`more_sheet.dart`)
- Toutes les tuiles sont en Brume (`background`) sur le tiroir blanc. **Seul le disque de 40 porte la teinte de sens** : Palmarès oriole, Carte tonal, Revue rapide avec contour pointillé `toCheck`, Sonothèque tonal, Oiseaux des jardins sure, Explorer tonal, Mes sessions tonal, Aide blanc.
- Réglages et À propos : dans un seul bloc Brume à lignes séparées, disques blancs de 44.

### Objectif du jour (`daily_goal_screen.dart`)
- Héros tonal avec anneau 120, « N/5 espèces entendues » et l'intro.
- Liste dans un bloc blanc, ligne du modèle unique. Oiseau trouvé : teinte et « Entendu · Sûr » en Lichen. À trouver : silhouette grise et `hearing`.
- Bouton épinglé « Commencer à écouter », avec l'aile.

### Premier lancement (`fork_onboarding_screen.dart`)
- Ajouter une étape facultative « Comment tu t'appelles ? » (champ prénom, bouton « Passer »). Elle enregistre la même préférence que le bloc « Toi ».

---

## 3. État et préférences à ajouter
- `firstName` (String?, SharedPreferences) : salutation de l'Accueil, félicitations du Profil, étape du premier lancement, bloc Réglages « Toi ».
- `liveTheme` (`dark` | `light`, défaut `dark`) : thème de l'écran d'écoute.
- Tiroir « Ta journée » : moment mis en avant (éphémère). « Me le rappeler » crée une notification locale : vérifier si la dépendance est prévue dans `fork/PLAN.md`, sinon demander.
- Fiche : section choisie et sections vues (éphémère, remis à zéro à chaque ouverture).
- Quiz : confirmation de sortie quand `stage == question`.

## 4. Jetons utilisés (tous existants)
- **Couleurs** : celles de `BirdyColors.light` et `.dark`, plus `BirdyBrand.*`, `BirdyQuizColors.*` et `ListeningModeColors.*`. Seul ajout : **#8CD3D9**, la barre bleu clair du logo, déjà dans `fork/brand/birdygo-logo.svg`. L'exposer en jeton pour l'aile.
- **Espacements** : `BirdySpace` (4, 8, 12, 16, 20, 24, 32 ; page 16, bloc 10).
- **Rayons** : hero 28, card 20, inset 16, thumb 12, pill 999.
- **Tailles** : target 48, mainAction 56, listen 72, row 72, disque de ligne 44, pastille 26.
- **Ombres** : `floatShadow`, `listenGlow`, `ctaGlow`. Nouvelle ombre douce de l'aile : 0,1 px, flou 2, `#0B3C46` à 45 %.
- **Texte** : `BirdyText` (Fraunces pour les titres et les noms, Atkinson pour le reste).

## 5. Ressources
- Polices : `assets/fonts/` (déjà dans le dépôt).
- Logo et aile : `fork/brand/birdygo-logo*.svg`, `BirdyGoLogoPainter`.
- Silhouette : `birdygo_silhouette.dart`.
- Icônes : Material Symbols via `AppIcons`. Nouvelles entrées à ajouter : `sort`, `moreHoriz`, `visibility`, `wbSunny`, `wbTwilight`, `smartphone`, `straighten`, `lightbulb`, `flight`, `notifications`, `musicNote`.

## 6. Fichiers du dossier
- `captures/` : une capture par écran (812 × 1720, téléphone 390 × 844 à 2x). 01 Accueil, 02 tiroir Ta journée, 03 Écoute, 04 Bilan, 05 Revue, 06 et 07 Fiche (haut, puis « Fais sa connaissance »), 08 Carnet, 09 Carte, 10 Profil, 11 Quiz, 12 Palmarès, 13 Sonothèque, 14 Réglages, 15 Objectif, 16 Menu Plus. **La source de vérité reste le README** ; les captures servent de repère visuel. Les photos d'oiseaux sont remplacées par la silhouette BirdyGo.
- `maquettes/BirdyGo Demo.dc.html` : démo complète et toute la logique d'état.
- `maquettes/Demo*.dc.html` : un fichier par écran.
- `maquettes/BirdyGo Ligne de design.dc.html` : planche des règles.
- `PROMPT_CLAUDE_CODE.md` : le message à donner à Claude Code.
