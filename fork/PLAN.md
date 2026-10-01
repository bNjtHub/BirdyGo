# Plan de développement de BirdyGo

Base : BirdNET Live (github.com/birdnet-team/birdnet-live-app), l'app officielle de l'équipe BirdNET
(Cornell Lab et TU Chemnitz). On ne refait pas ce qui existe : on ajoute ce qui manque et on refait
l'habillage.

Ordre : Android d'abord, jusqu'à une version validée sur le Play Store. iOS ensuite, avec le même code
Flutter (section « Phase iOS » en bas de ce fichier).

## Ce qui existe déjà, ce qu'on ajoute

| Besoin | Déjà dans BirdNET Live | Ajouté par BirdyGo |
|---|---|---|
| Savoir si l'app se trompe | score, seuil réglable, filtre géographique (3 modes), lissage temporel, confirmation manuelle | niveaux Sûr, Probable, À vérifier, alerte « inattendu ici », revue rapide par balayage, précision mesurée sur tes revues (J3) |
| Retrouver et réécouter les sons | bibliothèque de sessions, lecteur de clips, spectrogramme | réécoute pendant l'écoute, sonothèque par espèce avec favoris (J2) |
| Classement | liste des espèces déjà entendues, sans compteur | palmarès : contacts, jours, première et dernière écoute, activité par heure et par mois (J4) |
| Positions GPS | position de chaque détection, trace GPS en mode Survey, carte d'une session | index global des positions (J1) |
| Carte | carte d'une session, marqueurs ronds avec photo en mode Survey | carte de toutes les sessions avec les icônes des oiseaux, hexagones aux petits zooms, filtres (J5) |
| Connaître l'oiseau | description Wikipédia, courbe de présence sur 48 semaines, liens eBird, iNaturalist, Wikipédia | fiche rédigée par IA à l'avance, vérifiée contre ses sources, relue pour les plus courantes, hors ligne (J4b) |
| Recensement LPO | exports CSV, GPX, Raven, JSON | envoi guidé des observations confirmées vers Faune-France, mode Oiseaux des jardins (J5b) |
| Belle interface | Material 3, photos 480×320 | refonte complète avec photos, icônes d'espèces et animations (J6, voir DESIGN.md) |
| Jeu | alerte première espèce | statuts, badges, défis, carnet façon collection, célébrations (J6e) |
| Station fixe, alertes, exports | mode ARU, alerte première espèce, exports CSV, GPX, Raven, JSON, annonces vocales, widget | rien à faire |

## Étape 0 : préparation (sans crédit, une soirée)

- [ ] Installer BirdNET Live depuis le Play Store, faire une ou deux sorties, noter ce qui gêne vraiment.
- [x] Sur GitHub, forker birdnet-team/birdnet-live-app vers Bnjthub (tu peux renommer le dépôt en
      `BirdyGo`). Un fork est public. Pour un dépôt privé, il faut le dupliquer au lieu de le forker.
- [x] Sur le PC : installer Flutter (canal stable), Android Studio (pour le SDK Android) et Git LFS, puis
  (PowerShell, dans le dossier du projet) :
  ```
  $env:GIT_LFS_SKIP_SMUDGE = "1"
  git clone https://github.com/bNjtHub/BirdyGo.git .
  Remove-Item Env:GIT_LFS_SKIP_SMUDGE
  git config lfs.url https://github.com/birdnet-team/birdnet-live-app.git/info/lfs
  git lfs pull
  New-Item -ItemType Directory -Force assets\species_data | Out-Null
  flutter pub get
  flutter gen-l10n
  flutter run
  ```
  Les modèles ONNX ne sont pas stockés sur le fork : on les prend dans le dépôt officiel (`lfs.url`).
  `assets/species_data` est un dossier généré, attendu par `pubspec.yaml`. Sur le Xiaomi (HyperOS),
  activer « Débogage USB » et « Installer via USB » dans les options pour les développeurs, et
  appuyer sur « Installer » quand le téléphone le demande, sinon `INSTALL_FAILED_USER_RESTRICTED`.
- [x] Dézipper le kit à la racine du dépôt (`CLAUDE.md`, `fork/`, `.claude/`), commit, push.
- [x] Sur claude.ai/code : connecter GitHub, créer un environnement cloud « Flutter » avec l'accès
      réseau Trusted, coller le contenu de `fork/cloud-setup.sh` dans le champ Setup script, et
      ajouter la variable d'environnement `GIT_LFS_SKIP_SMUDGE=1`.
- [x] Première session : vérifier que `flutter --version`, `flutter analyze` et `flutter test` passent.
      Si Flutter manque, corriger le setup script avant d'aller plus loin.

## Budget indicatif (330 $, plus 40 à 70 $ d'API pour les fiches)

| Jalon | Modèle | Ordre de grandeur |
|---|---|---|
| J0 Renommage | Sonnet | 10 $ |
| J1 Index des observations | Sonnet | 25 $ |
| J2 Réécoute et sonothèque | Sonnet | 30 $ |
| J3 Fiabilité | Opus pour le plan, Sonnet pour le code | 30 $ |
| J4 Palmarès | Sonnet | 20 $ |
| J4b Fiches espèces | Sonnet | 20 $, plus 40 à 70 $ d'API Anthropic (à part) |
| J5 Carte | Sonnet | 25 $ |
| J5b Envoi à la LPO | Sonnet | 15 $ |
| J6 Refonte visuelle (J6a à J6c) | Opus pour le design system, Sonnet ensuite | 60 $ |
| J6d Icônes d'espèces | Opus pour le style, Sonnet ensuite | 20 $ |
| J6e Jeu | Sonnet | 25 $ |
| J7 Publication Android | Sonnet | 10 $ |
| Réserve pour les bugs | | 40 $ |

L'API des fiches (J4b) se paie sur un compte de la console Anthropic, séparé du crédit Claude Code.

Si un jalon dépasse nettement son enveloppe, s'arrêter et le redécouper.
Changer de modèle dans une session cloud : `/model sonnet` ou `/model opus`.

## Déroulé d'un jalon

1. Nouvelle session cloud (claude.ai/code ou onglet Code de l'app Claude), environnement Flutter.
2. Coller le prompt du jalon. Claude lit le plan et propose sa démarche. Valider ou corriger.
3. Claude code, lance analyze et les tests, ouvre une PR.
4. Sur le PC : `git fetch`, `git checkout <branche>`, `flutter run` sur le téléphone.
5. Retours dans la même session tant qu'elle reste courte. `/compact` si elle s'allonge.
   `/clear` n'existe pas dans le cloud : pour repartir de zéro, ouvrir une nouvelle session.
6. Fusionner la PR quand tout va bien sur le téléphone.

Prompt pour lancer un jalon :
```
Lis CLAUDE.md et la section J<n> de fork/PLAN.md, plus fork/DESIGN.md si le jalon touche l'interface. Mode plan : liste les fichiers créés ou modifiés, les tests prévus et les risques. Attends ma validation avant de coder.
```

Prompt pour un bug :
```
Bug sur le téléphone, branche <nom>. J'ai fait : <étapes>. Résultat : <ce qui se passe>. Attendu : <ce qui devrait se passer>. Logs : <coller la sortie de flutter run>. Trouve la cause avant de corriger, explique-la en deux phrases, puis corrige et ajoute un test si c'est possible.
```

## J0 : faire du fork une app à part

- [x] Nom affiché « BirdyGo », applicationId Android `fr.justcodeit.birdygo`, pour que l'app s'installe
      à côté de BirdNET Live. Mettre aussi le bundle id iOS au même nom, sans rien tester côté iOS.
- [x] Icône provisoire simple, refaite en J6.
- [x] Écran À propos : « Propulsé par BirdNET » avec le lien vers le dépôt d'origine. Garder LICENSE,
      MODEL_LICENSE et ACCEPTABLE_USE.md, ajouter un fichier NOTICE qui dit que c'est une version modifiée.
- [x] Ne pas mettre le nom BirdNET dans le nom de l'app.
- [x] Désactiver `release.yml` et `docs.yml` dans `.github/workflows`, garder `ci.yml`.

Fini quand : analyze et tests passent, l'app s'installe sur le Xiaomi à côté de BirdNET Live.

Prompt J0 :
```
Lis CLAUDE.md et la section J0 de fork/PLAN.md. Mode plan : liste les fichiers à modifier pour le renommage, l'écran À propos et les workflows. Attends ma validation, puis applique, lance flutter analyze et flutter test, et ouvre une PR.
```

## J1 : index des observations

But : compter, classer et cartographier toutes les détections de toutes les sessions sans relire
tous les JSON à chaque écran. C'est la fondation de J2 à J5.

- [x] `lib/fork/data/observation_index.dart` : base SQLite (sqflite, et sqflite_common_ffi pour les
      tests) avec une table des sessions et une table des détections : id, session, espèce, début, fin,
      score, statut de revue, latitude, longitude, chemin du clip, favori.
- [x] Mise à jour de l'index à chaque sauvegarde, modification ou suppression de session, avec des
      points d'accroche minimaux dans SessionRepository, marqués FORK.
- [x] Remplissage initial en arrière-plan au premier lancement, sur le modèle de GlobalSpeciesHistory.
      Bouton « Reconstruire l'index » dans les réglages.
- [x] Requêtes prêtes pour la suite : palmarès par période, points pour la carte, clips d'une espèce,
      activité par heure et par mois, file des détections à revoir.
- [x] Tests avec des sessions JSON d'exemple dans `test/fork/fixtures/`.

Fini quand : les tests passent, et sur le téléphone l'index se remplit sans figer l'interface.

## J2 : réécouter pendant l'écoute, et la sonothèque

- [x] En mode Live, un bouton lecture sur chaque détection joue son clip sans arrêter l'écoute.
      Un deuxième appui arrête. Toucher le reste de la ligne ouvre toujours la fiche espèce.
- [x] Pendant la lecture, plus 0,5 s, l'inférence est suspendue pour que le modèle ne détecte pas le
      haut-parleur. L'enregistrement continue. Le changement se fait dans le planificateur d'inférence
      commun aux modes Live, Point Count et Survey, avec le moins de lignes possible.
- [x] Si le clip est encore en cours d'écriture, le bouton l'indique et s'active dès qu'il est prêt.
- [ ] (Benjamin) Android : vérifier la lecture pendant l'enregistrement, haut-parleur et casque Bluetooth.
- [x] Écran Sonothèque : liste des espèces, puis tous leurs clips triés par score ou par date, avec
      lecture, mini spectrogramme, date et lieu. Étoile pour garder ses meilleurs enregistrements,
      filtre « favoris seulement ».
- [x] Rien n'est supprimé automatiquement.
- [x] Tableau Live : la liste ne s'efface pas pendant l'écoute et l'oiseau entendu remonte en tête.
      Upstream le fait déjà avec deux réglages : les activer par défaut dans BirdyGo
      (`showAllDetectedSpeciesProvider` à vrai, `detectedSpeciesSortModeProvider` sur « newest »,
      dans `lib/shared/providers/settings_providers.dart`, modification minimale marquée FORK).
      Ajouter à chaque ligne le total toutes sorties confondues, lu dans l'index de J1 (« ×3 · 142 »).
- [x] La réécoute sert à vérifier, jamais à attirer les oiseaux (la LPO déconseille la repasse) :
      volume modéré par défaut, et l'app le dit une fois, simplement.
- Notes de réalisation : en mode d'enregistrement « complet », BirdyGo garde aussi un extrait par
  détection (upstream ne le faisait qu'en mode « extraits »). La réécoute utilise un lecteur qui ne
  prend pas le focus audio, sinon Android met le micro en pause. Le crochet du pilote d'inférence
  sert aussi au mode Survey, mais sa liste n'a pas encore le bouton de réécoute. Le mini
  spectrogramme de la sonothèque est celui du lecteur d'extrait.

Fini quand : rejouer un rougegorge pendant une écoute ne crée aucune nouvelle détection.

## J2b : écouter écran éteint

Problème : l'écoute Live se coupait dès que l'app passait en arrière-plan. Le Live se mettait en pause
lui-même (`_pauseSessionForBackground` dans `live_screen.dart`) et n'avait pas de service au premier
plan, contrairement au mode Survey et à l'ARU ; HyperOS tuait ensuite le processus.

- [x] Service Android au premier plan pour le Live (`lib/fork/background/live_background.dart`,
      type micro, identifiant 768, canal « Écoute en direct », notification discrète « BirdyGo écoute »
      avec « Ouvrir »). Démarre avec l'écoute, s'arrête à la fin de l'écoute ou en quittant l'écran.
      `ForegroundServiceOwner.live` (ligne FORK) : jamais en même temps que Survey ou ARU.
- [x] Tant que le service tourne, passer en arrière-plan ne met plus l'écoute en pause (une ligne FORK
      dans `_pauseSessionForBackground`). Sans service (refus, autre mode), l'ancien comportement reste.
- [x] Conseil unique à la première écoute (`background_tip.dart`) : l'écoute continue écran éteint ;
      sur Xiaomi, autoriser BirdyGo sans restriction de batterie, avec un bouton vers les réglages de
      l'app. Pas de demande automatique d'exemption d'optimisation de batterie (surveillée par le
      Play Store).
- [ ] (Benjamin) Sur le Xiaomi : 30 minutes d'écoute écran éteint, avec et sans « Pas de
      restriction » ; vérifier la notification, le bouton « Ouvrir », la reprise à l'écran, et qu'un
      Survey lancé ensuite démarre bien son propre service.

## J3 : savoir quand l'app se trompe

- [x] Trois niveaux affichés partout (Live, revue de session, sonothèque, palmarès) : Sûr, Probable,
      À vérifier. Calculés à partir du score et du niveau d'abondance du géomodèle pour le lieu et la
      semaine. Seuils de départ dans `lib/fork/reliability/reliability_config.dart` : Sûr à partir de
      0,80 si l'espèce est plausible ici, Probable de 0,55 à 0,80, À vérifier en dessous ou si
      l'espèce est rare ici à cette saison.
- [x] Badge « Inattendu ici » quand le géomodèle juge l'espèce rare ou absente pour ce lieu et cette semaine.
- [x] Réutiliser ce qui existe au lieu de recalculer : `GeoModel.predict` (lib/features/inference/geo_model.dart),
      `geoCommonnessProvider` et son indicateur hors saison, `ExploreTierScale`
      (`lib/features/inference/geo_abundance.dart`), `AlertReason.rare` des alertes Survey.
- [x] Ces niveaux alimentent le jeu (J6e) et l'envoi à la LPO (J5b) : seules les détections Sûr ou
      confirmées font progresser, et seules les confirmées peuvent partir.
- [x] Revue rapide : une pile de cartes des détections à vérifier, avec photo, clip joué
      automatiquement et spectrogramme. À droite « C'est bien lui », à gauche « Ce n'est pas lui »,
      vers le haut « Je ne sais pas ». Utilise les champs de revue existants et met l'index à jour.
- [x] Précision mesurée : pour chaque niveau, et pour chaque espèce revue au moins 5 fois, la part de
      détections confirmées. Visible dans la fiche espèce (« 11 bonnes sur 12 vérifiées ») et dans un
      écran Fiabilité.
- [ ] (Benjamin, plus tard) Après quelques semaines de revues, ajuster les seuils avec ces chiffres.
- Notes de réalisation : les niveaux s'affichent dans Live, le comptage ponctuel, la sonothèque et la
  revue rapide ; la revue de session d'upstream et le palmarès (J4) les recevront avec leurs écrans.
  En Live, la présence vient de `geoCommonnessProvider` (lieu actuel, hors saison compris) ; ailleurs,
  du géomodèle au lieu et à la semaine de la détection (`GeoPresenceService`). Sans position, un
  score élevé reste « Probable ». La précision par niveau est mesurée par tranche de score, car ce
  sont ces seuils qu'on ajuste. « Je ne sais pas » laisse la détection non revue mais la retire de la file.

Fini quand : les niveaux sont cohérents d'un écran à l'autre et chaque balayage est bien enregistré.

## J3b : « Rare ici » expliqué

Problème : un chant bien reconnu mais inattendu ici (lieu ou saison) s'affichait « À vérifier » +
« Inattendu ici », comme si l'identification était douteuse. La règle ne change pas : un oiseau
inattendu reste « À vérifier » et doit être confirmé avant de compter. Seul l'affichage change.

- [x] Comprendre : en Live, `livePresence` comptait aussi le « hors saison » (score de la semaine
      sous 40 % du pic annuel), alors que `presenceAt` (Bilan, revue, sonothèque, Accueil) n'utilise
      que le palier rare et le seuil d'inclusion. Un `debugPrint` `[GeoPresence]` (une fois par
      espèce, attendue ou non, en debug et en profile) dit quel critère a joué et si le hors-saison
      aurait joué ; une ligne « no commonness map » si le Live n'a ni position ni géomodèle.
- [x] Aligner le Live sur `presenceAt` : palier rare, sous le seuil d'inclusion ou absent de la carte.
      Le hors-saison seul ne rend plus une espèce inattendue ; il reste dans les annonces vocales et
      dans `LpoGeoStatus.outOfSeason`.
- [x] Une seule pastille Loriot, bord pointillé, « Rare ici · à confirmer » à la place de « À
      vérifier » + « Inattendu ici » quand le lieu seul déclenche (`placeOnlyToCheck` : score au
      moins Probable, non confirmé). Un appui ouvre l'explication (`rare_here_sheet.dart`). En
      compact (lignes du Live), pas d'appui : libellé pour l'infobulle et le lecteur d'écran.
- [x] Fiche espèce : la même phrase sous « Ici en ce moment » quand l'espèce est inattendue au lieu
      du téléphone cette semaine (même règle, à partir des scores déjà chargés).
- [x] Cohérence vérifiée : Bilan (« Vérifier N », point sur les espèces), Accueil (compteur à
      vérifier), revue rapide (toutes les détections non revues) et LPO (confirmées seulement)
      restent calculés sur le niveau ou le statut de revue, pas sur le libellé.
- [x] (Benjamin) Sur le Xiaomi : passer un chant de Rougegorge depuis le web pendant une écoute,
      relever la ligne `[GeoPresence]`, vérifier Live et Bilan. Résultat : Rougegorge « abundant »,
      ni rare ni hors saison, « Sûr » en Live et au Bilan. Le « À vérifier » d'origine venait donc
      d'un score bas (son de haut-parleur), pas du lieu.
- Limite connue, inchangée : l'index ne garde pas l'avis du géomodèle, donc une ancienne détection
  non revue à score élevé compte comme « déjà vérifiée » même si l'espèce était inattendue
  (`ObservationIndex.verifiedSpecies`, « Première fois » et « nouvelles »). À traiter avec le jeu (J6e).

## J4 : palmarès

- [x] Classement des espèces par nombre de contacts, par nombre de jours ou par dernière écoute.
      Périodes : 30 jours, saison, année, tout. Option « confirmées seulement ».
- [x] En tête : nombre d'espèces sur la période et nouvelles de l'année.
- [x] Fiche espèce : une phrase plutôt qu'un tableau (« Entendu 23 fois sur 9 jours, la dernière fois
      hier à 7 h 42 »), activité par heure (24 barres) et par mois (12 barres) dessinées avec
      CustomPainter, sans nouvelle dépendance.
- [x] Filtre « oiseaux seulement » : le modèle reconnaît aussi des amphibiens, des insectes et des mammifères.
- Notes de réalisation : écran Palmarès (accueil), périodes météorologiques pour « saison »,
  « nouvelles de l'année » = première détection de l'espèce dans l'année. La phrase et les deux
  graphiques sont ajoutés à la fiche espèce d'upstream (`SpeciesInfoOverlay`, une ligne FORK).
  « Oiseaux seulement » utilise le groupe de `taxonomy.csv` (Aves). Reste à vérifier sur le
  téléphone : les compteurs d'une espèce contre un export CSV.

Fini quand : les compteurs d'une espèce correspondent à un export CSV sur un échantillon.

## J4b : fiches espèces rédigées par IA

But : pour chaque oiseau de France, une fiche claire en français : taille, ce qu'il fait, pourquoi il
est là, migration, comment le reconnaître à l'oreille, confusions possibles, une anecdote, et un indice
court pour le carnet du jeu (J6e). Les fiches sont écrites une fois, vérifiées, relues et embarquées :
hors ligne, sans coût à l'usage, sans clé d'API dans l'app.

Changement de méthode (septembre 2026) : les fiches sont écrites par Claude à partir de ses propres
connaissances, avec la consigne « laisser vide plutôt que deviner ». Wikipédia et Wikidata ne servent
plus de source mais de contrôle. Plus simple (pas de collecte ni de clé d'API pour écrire), et pas de
licence CC BY-SA imposée puisque le texte ne dérive pas d'un article.

- [x] Liste des espèces de la région : `tools/fork_region_species.py`, géomodèle sur une grille France
      et Europe de l'Ouest × 48 semaines, seuil de `model_config.json`, colonne « oiseau » et statut
      saisonnier (sédentaire, estivant, hivernant, de passage). À lancer sur le PC (modèles LFS).
- [x] `tools/fork_species_sheets.py` (dépendances dans `tools/requirements-fork-sheets.txt`, tests
      dans `tools/test_fork_species_sheets.py`) : `verify`, `review`, `apply-review`, `bundle`,
      `status`, et en option `write` et `check` par la Message Batches API (modèle à choisir avec
      `--model`, tarifs du jour).
- [x] 100 premières fiches (les oiseaux les plus courants de France) écrites dans une session Claude
      Code, dans `tools/fork_sheets/fr.jsonl`, livrées dans `assets/fork/species_sheets_fr.json.gz`.
- [ ] Vérification gratuite sur le PC : `python tools/fork_species_sheets.py verify` (tailles contre
      Wikidata, migration contre le géomodèle, noms contre `taxonomy.csv`). Une fiche signalée n'est
      plus livrée tant qu'elle n'est pas relue.
- [ ] Relecture par Benjamin : `review` ouvre une page HTML locale (les 100 plus courantes, toutes les
      fiches signalées, 10 % des autres), puis `apply-review review_decisions.json` et `bundle`.
- [ ] Optionnel, avec une clé d'API : `check --model <modèle moins cher>` compare chaque fiche à
      l'article Wikipédia et signale les contradictions ; `write --model <modèle>` pour les autres
      espèces de la région (environ 10 à 20 $ pour 300 espèces).
- [x] Écran : la fiche prend la place du bloc description de `SpeciesInfoOverlay` par un point
      d'accroche marqué FORK ; code dans `lib/fork/species_sheet/`. « Ici en ce moment » reste le
      graphique de présence existant (géomodèle, jamais l'IA). Sans fiche, ou si les noms d'espèces ne
      sont pas en français, la description existante reste. Titres et pied de fiche (« Fiche rédigée
      par IA : elle peut contenir des erreurs. ») en français et en anglais.
- [x] Fiche espèce, sons et saisons (PR « J7 Fiche espèce ») : « Mes sons » juste après « Entendu… »
      (le meilleur son devient un lecteur mis en avant, grand bouton), « Ici en ce moment » garde sa
      courbe compacte de 12 mois, avec la phrase calculée sur 48 semaines (« Arrive début mars ·
      repart fin septembre » ou « Présent toute l'année »). Pas de bande de nidification sur la fiche :
      la nidification (champ `nesting`, `NestingPeriod`) est affichée par la carte du monde (« Niche d'avril à juillet »).
- [x] Générateur : champ `nesting` (« M-N », mois 1 à 12) ajouté au schéma, au prompt et au bundle
      (`tools/fork_species_sheets.py`, valeur invalide non livrée). Génération non lancée.
- [ ] (Benjamin) Régénérer le bundle avec la nidification : `write` (ou compléter les fiches
      existantes) puis `verify`, `review`, `bundle` sur le PC, et commiter
      `assets/fork/species_sheets_fr.json.gz`. Nécessaire pour que la carte du monde affiche « Niche d'avril à juillet ».
- Ne jamais donner au modèle des textes de la LPO, d'oiseaux.net ou d'eBird (droits réservés).

Notes de réalisation : les fiches se chargent au démarrage (préchargement de l'accueil), 1 fichier gzip.
Le champ `hint` est embarqué mais pas affiché : il servira au carnet du jeu (J6e).

Fini quand : les 100 espèces les plus entendues ont une fiche relue et l'app les affiche hors ligne.

## J5 : carte de tous les contacts

- [x] Carte plein écran avec flutter_map, déjà utilisé. Aux petits zooms, grille d'hexagones dont la
      couleur suit le nombre de contacts. Aux grands zooms, les icônes rondes des oiseaux, regroupées
      avec flutter_map_marker_cluster, déjà présent. Réutiliser `_SpeciesMarker` et
      `SurveyMapClusterBubble` de `lib/features/survey/widgets/survey_map_widget.dart`, qui dessinent
      déjà des marqueurs ronds avec la photo de l'espèce en mode Survey. `SurveyMapClusterBubble` est déjà
      public ; rendre `_SpeciesMarker` public par une modification minimale marquée FORK, ou le recopier
      dans `lib/fork/map/` si l'extraction touche trop de lignes. Plus tard, les icônes SVG de J6d.
- [x] Filtres : espèce (recherche), période, confirmées seulement. Appui sur un hexagone : feuille avec
      les espèces de la zone, leurs compteurs et leurs clips.
- [x] Fonds de carte : OSM avec les réglages partagés, plus Plan IGN et photos aériennes IGN
      (Géoplateforme). Vérifier les URL WMTS actuelles et la mention de source obligatoire.
- [x] Dans les exports, option pour flouter la position des espèces sensibles, dans l'esprit
      d'ACCEPTABLE_USE.md.

Fini quand : 10 000 points se déplacent et zooment sans saccade sur le téléphone.

Fait (code dans `lib/fork/map/`) : bouton « Carte » sur l'accueil. Hexagones sous le zoom 13
(`map_config.dart`), marqueurs `SpeciesMarker` (typedef public de `_SpeciesMarker`, une ligne FORK)
avec le nombre de contacts, un marqueur par espèce et par lieu (environ 25 m), regroupés par
`SurveyMapClusterBubble`. URL IGN vérifiées en septembre 2026 (data.geopf.fr, WMTS, matrice PM),
mention « © IGN – Géoplateforme » ; data.geopf.fr n'est pas joignable depuis le cloud, donc
l'affichage des tuiles IGN est à vérifier sur le téléphone. Exports : case « Flouter les espèces
sensibles » (réglages, section export, cochée par défaut), liste de départ dans
`sensitive_species.dart` à revoir avec les règles LPO en J5b.
À tester sur le Xiaomi : fluidité avec beaucoup de points (le test unitaire bine 10 000 points),
tuiles IGN, bouton « Me localiser ».

## J5b : envoyer ses observations à la LPO

Constat (recherche de septembre 2026) : Faune-France n'offre pas d'accès ouvert aux applis tierces.
L'API VisioNature demande une clé délivrée par Biolovision et des droits fixés par les portails.
NaturaList (Biolovision) est l'appli de saisie officielle, et nous n'avons trouvé aucune appli tierce
grand public qui y écrive. La LPO Île-de-France (2026) demande de confirmer à l'oreille et aux
jumelles, de comparer les enregistrements douteux avec xeno-canto, et de ne pas saisir sur Faune de
listes d'espèces identifiées par une appli ; la Station ornithologique suisse demande de ne saisir que
des observations confirmées. L'envoi est donc guidé, jamais automatique.

- [x] Écran « Envoyer à la LPO » réservé aux détections confirmées (« C'est bien lui »). Avant l'envoi,
      l'app demande en plus « Tu l'as vu ? » et « Tu connais ce chant ? », avec un lien vers xeno-canto
      pour comparer.
- [x] Pour chaque observation, une fiche prête à reporter : nom français et latin, date, heure,
      position GPS et précision, nombre, entendu ou vu, remarque « Contact auditif ; identification
      assistée par IA puis confirmée par l'observateur ». Code atlas proposé seulement pendant la
      période de nidification de l'espèce. Boutons copier, partager le clip, ouvrir NaturaList ou
      faune-france.org (nous n'avons trouvé aucun pré-remplissage documenté).
- [x] Alertes avant l'envoi : espèce sensible (proposer de masquer la donnée), espèce rare ou hors saison.
- [x] Mode « Oiseaux des jardins » (LPO et MNHN) : minuteur (1 h les deux week-ends nationaux, les
      derniers week-ends complets de janvier et de mai ; durée libre le reste de l'année), compteur du
      nombre maximum vu en même temps pour chaque espèce, saisi à la main. Les détections sonores
      servent seulement d'invitation à regarder : le protocole compte les oiseaux vus posés dans le
      jardin, plus les hirondelles, martinets et rapaces qui chassent au-dessus. À la fin,
      un résumé à reporter sur oiseauxdesjardins.fr.
- [x] Ne jamais aspirer ni imiter NaturaList, ne jamais demander le mot de passe Faune-France.

Fait (code dans `lib/fork/lpo/` et `lib/fork/garden/`) : bouton « Envoyer à Faune-France (LPO) » et sa
légende en bas de la liste des espèces du bilan de session (`session_review_screen.dart`, lignes FORK),
comme dans la maquette Resume. Une seule porte, `lpoEligible` : statut « confirmé » ; ni « Sûr », ni les
détections non revues ou rejetées. Une observation = une espèce en un lieu (détections confirmées à moins
de 250 m regroupées), heure du premier contact, précision tirée du point GPS de la trace le plus proche
(60 s). La fiche n'apparaît qu'après « Tu l'as vu ? » et « Tu connais ce chant ? » ; « Pas sûr » demande
de comparer sur xeno-canto d'abord. Code atlas proposé (3, sinon 2 ou aucun) seulement pendant la période
de nidification, table approximative des 100 espèces des fiches dans `atlas_codes.dart` (à vérifier avec
le coordinateur local). Alertes : espèce sensible (interrupteur « Masquer la donnée », coché), rare et
hors saison par `geoCommonnessProvider` quand l'observation est ici et cette semaine (moins de 10 km),
sinon rareté seule par `GeoPresenceService` au lieu et à la semaine de l'observation. Liste des espèces
sensibles revue (liste SINP : Aigle botté, Faucon d'Éléonore, Hibou des marais, Pies-grièches grise et
méridionale ajoutés). NaturaList s'ouvre par sa page Play Store (bouton « Ouvrir » si installée).
Aucun appel réseau, aucun compte. Oiseaux des jardins : bouton sur l'accueil, minuteur (1 h les derniers
week-ends complets de janvier et de mai, libre sinon, sans compte à rebours), compteurs à la main,
espèces entendues pendant le comptage (écoute en cours) proposées comme invitation à regarder, résumé à
copier, comptage gardé dans les préférences.
À tester sur le Xiaomi : une observation confirmée reportée dans NaturaList en moins d'une minute,
ouverture de NaturaList, partage d'un extrait, comptage des jardins interrompu puis repris.

Plus tard, hors de ce jalon : un export CSV (lisible par Excel) des observations confirmées, car
l'import sur Faune-France demande un droit donné par le portail (vérifier le modèle de colonnes avec
le coordinateur local) ; et, une fois l'app utilisée, écrire à l'équipe Faune-France et à Biolovision
pour proposer un partenariat.

Fini quand : une observation confirmée se reporte dans NaturaList en moins d'une minute, et aucune
détection non confirmée ne peut partir.

## J5c : écouter un enregistrement

But : tester l'app avec des sons du web ou d'un CD sans fausser les données. Un son enregistré n'est
pas une observation. Règle unique, dans `lib/fork/practice/` : **les sons enregistrés ne comptent
pas**. Une sortie compte seulement si elle n'est pas marquée `practice` et n'est pas une analyse de
fichier (`SessionType.fileUpload`, qui comptait partout jusqu'ici).

- [x] Entrée « Écouter un enregistrement » dans le menu de l'accueil (`lib/fork/home/`), pas
      d'interrupteur sur l'écran d'écoute. Le mode n'est pas enregistré dans les préférences : il est
      remis à zéro à chaque démarrage.
- [x] Pendant cette écoute : filtre d'espèces sur « off », pas de géomodèle (ni « Inattendu ici » ni
      « Rare ici »), bandeau discret « Enregistrement » sur l'écran d'écoute.
- [x] Champ `practice` (FORK) dans `LiveSession`, écrit dans le JSON seulement quand il vaut vrai ;
      les anciennes sessions se lisent sans lui (faux).
- [x] Index : une sortie qui ne compte pas n'y entre pas (ni détections, ni précision, ni
      `verifiedSpecies`), et en sort si on la marque après coup. Schéma de l'index 2 → 3 pour
      forcer une reconstruction qui retire les analyses de fichier déjà indexées (favoris gardés).
- [x] Rien au palmarès, sur la carte, sur l'accueil, dans la sonothèque ni la revue rapide (tous lus
      dans l'index) ; la LPO renvoie une liste vide et son bouton disparaît. Jeu (J6e) : il lira
      l'index, donc la règle s'applique d'office.
- [x] Bilan (`lib/fork/summary/`) : lien « C'était un enregistrement ? » pour marquer la sortie après
      coup (et l'annuler) ; une sortie marquée n'a ni « Première fois », ni avis du géomodèle, ni
      « Vérifier », ni bouton LPO.
- [x] Chaînes en français et en anglais.
- [x] Tests : sérialisation, exclusion de l'index, palmarès, carte et LPO vides, lien du Bilan,
      reconstruction de l'index.

Fait (règle dans `lib/fork/practice/practice.dart`, `countsAsObservation`) : l'entrée du menu ouvre
`LiveScreen(forkPractice: true)`, qui lance l'écoute avec le filtre sur « off », sans `geoScores` ni
avis du géomodèle, et marque la session `practice` au démarrage ; le mode vit avec cet écran, rien
n'est gardé ailleurs. Rouvrir l'écoute en cours (notification) garde le bandeau, lu sur la session.
L'index retire toute session qui ne compte pas dans `_upsert` et `rebuild` : palmarès, carte,
accueil, sonothèque, revue rapide, précision et totaux en sont exclus d'office. Conséquences
voulues : les anciennes analyses de fichier disparaissent après la reconstruction, et les détections
d'une sortie qui ne compte pas ne passent plus par la revue rapide (le détail de la session reste).
Limites : l'option « ignorer les espèces communes » (qui dépend du géomodèle) ne s'applique pas
pendant un enregistrement ; les annonces vocales (option upstream) lisent encore la rareté du
géomodèle ; l'export JSON upstream ne transporte pas `practice`.
À tester sur le Xiaomi : un chant joué depuis un autre téléphone, bandeau visible, puis rien au
palmarès, sur la carte ni sur l'accueil ; « C'était un enregistrement ? » sur une vraie sortie, puis
annulé ; reconstruction de l'index au premier lancement après la mise à jour.

Fini quand : une écoute d'un son du web ne laisse aucune trace au palmarès, sur la carte, sur
l'accueil ni à la LPO, et une sortie marquée après coup disparaît partout.

## J6 : refonte visuelle (voir fork/DESIGN.md)

Objectif : l'app la plus belle, la plus fluide et la plus utile de sa catégorie. Assez simple pour
qu'un enfant s'en serve, colorée grâce aux oiseaux, et qui donne envie d'y revenir. Maquette de
référence : le canevas « BirdyGo – Interface » sur claude.ai
(https://claude.ai/artifact/C6XUNf7AKdf1YUZzRr1K3j, privé), exporté dans `fork/maquette/` pour que
les sessions cloud puissent le lire ; à suivre et à corriger au fil des sessions.

- [x] J6a Design system : thèmes clair et sombre, polices embarquées, composants (carte espèce, puce
      de niveau, compteur, lecteur de clip, boutons), jetons d'animation. Opus pour le concevoir,
      Sonnet ensuite.
- [x] J6b Photos : `tools/fork_region_species.py` (créé en J4b) donne la liste des espèces de la
      région. Ajouter à `tools/build_species_bundle.py` une option pour ne traiter que cette liste, à
      lancer sur le PC (birdnet.cornell.edu n'est pas joignable depuis le cloud). En ligne, photos plus
      grandes via iNaturalist (inat_id), mises en cache. Crédit et licence accessibles d'un appui.
      Notes de réalisation :
      - Script : `--species-list` limite les photos à la liste (noms et descriptions restent complets),
        `--replace-reserved` remplace les photos sans licence ouverte (« © Macaulay Library ») par une
        photo iNaturalist libre et réécrit leur crédit dans `taxonomy.csv` (source « iNaturalist
        <id> »). Code dans `tools/fork_species_photos.py`, tests dans `tools/test_fork_species_photos.py`.
        Les photos sont recadrées en 3:2 au lieu d'être étirées ; le cache de téléchargement est
        indexé par URL. Avec `--species-list`, `taxonomy.csv` n'est pas reconstruit : seules les
        colonnes de crédit photo des espèces de la liste changent. Une reconstruction complète
        supprimait la colonne `wikipedia_url_zh` ajoutée par upstream et réécrivait les 9 790 lignes.
      - App : `lib/fork/species_photo/`. `SpeciesPhoto` remplace la photo de `SpeciesInfoOverlay`
        (point FORK) ; la ligne de crédit sous la photo devient une feuille ouverte d'un appui.
        Réglage « Photos en grand (en ligne) », désactivé par défaut (Confidentialité, et dans la
        feuille de crédit). Photo `large` d'iNaturalist, licence ouverte sans « nd », format paysage,
        même règle que le script ; cache disque de 50 Mo ; valeurs dans `species_photo_config.dart`.
      - Vérifié sur le Xiaomi : photos hors ligne, crédit, grande photo en fondu, mode avion.
- [x] J6c Écrans, un par session : Accueil, Live (spectrogramme agrandi ou réduit, tableau en direct
      avec compteurs de session et totaux), Fin de sortie (résumé de l'écoute), Fiche espèce, Palmarès,
      Carte, Sonothèque, Revue rapide, Envoi à la LPO. Carnet et Profil (statut, badges, série)
      viennent avec le jeu, en J6e. Le logo de l'accueil s'anime en Flutter à partir du logo statique
      (flutter_svg ne lit pas les animations CSS).
      - [x] Live : thème sombre (dialogues compris), spectre agrandi ou réduit d'un appui avec un
            trait de la couleur de l'espèce sous chaque passage, tableau en direct (entrée en haut,
            remontée en tête en 250 ms, ×N qui rebondit, total toutes sorties), barre Arrêter / Pause.
            En paysage : spectre à gauche, tableau et barre à droite. À mesurer en mode profile
            sur le Xiaomi : 60 images par seconde pendant l'agrandissement du spectre.
            Les traits sous le spectre ne comptent pas le temps de pause (le spectre s'arrête aussi) :
            ils restent sous leur passage après Pause puis Reprendre.
      - [x] Fin de sortie (« Bilan de l'écoute », `lib/fork/summary/`) : s'ouvre après « Arrêter »
            quand la session est enregistrée automatiquement (sinon la revue upstream, qui propose
            d'enregistrer). Titre selon l'heure, chiffres, « Première fois » (Sûr ou confirmée, jamais
            vérifiée avant, avec son rang), « Peut-être une première » (Probable, À vérifier ou
            inattendue ici), bandeau des espèces avec un point sur celles à vérifier, « Vérifier N
            détections » qui ouvre la revue rapide sur ces seules détections, détail de la session,
            envoi à la LPO. La croix et le retour ramènent à l'Accueil. Partage en texte, sans lieu.
            Reportés en J6e : carte de statut, puce de badge, célébration de nouveau statut.
      - [x] Accueil (`lib/fork/home/`) : logo BirdyGo dessiné en Flutter (l'aile se dessine une fois),
            salutation, date et lieu, tuiles du jour (espèces, contacts, nouvelles), dernier oiseau
            entendu, détections à vérifier, « Écouter » en bas ; menu avec toutes les entrées upstream.
            Reportés en J6e : pastille de série, carte de statut, défi de la semaine, barre de
            navigation Accueil, Carnet, Carte, Profil (le menu garde alors les autres entrées). À
            mesurer sur le Xiaomi : l'écoute démarre moins d'une seconde après l'appui.
      - [x] Accueil visuel (maquette `Main.dc.html` de la PR #47) : l'objectif du jour devient la carte
            principale sous la salutation, ses oiseaux en grands ronds (2 rangées de 4 ; entendu sur sa
            teinte avec une coche, à trouver gris en pointillé, chaque rond annoncé au lecteur d'écran) ;
            ordre de la maquette ; « Écouter » seule action forte, fixée au-dessus de la barre ; entrée
            de 220 ms sur 5 blocs au plus, rien avec les animations réduites. Logo : l'oiseau qui
            chante du démarrage, une phrase à l'arrivée puis une toutes les 2 minutes tant que
            l'accueil est visible (immobile avec les animations réduites).
            À vérifier sur le Xiaomi : ronds avec les vraies photos, thème sombre, texte à 130 %,
            chant du logo (à l'arrivée, après 2 minutes, arrêté sur un autre onglet).
      - [x] Startup screen (`lib/fork/splash/`): supplied Claude Design composition,
            Mist background, singing bird (beak, body, tail, wing bars, one note per
            syllable), « Birdy » · « Go » wordmark with the Oriole dot, tagline in two beats,
            real loading (audio model, geo-model, species, observation index) with a
            weighted bar and a caption per step, 4.4-second minimum display, 25-second
            loading limit, immediate reduced-motion state,
            real bootstrap loading and retry. Launch share and Quick Listen are retained
            across retry; normal launch waits for initialization and introduction. Android launch
            and normal window backgrounds match Flutter, with the current BirdyGo mark.
            Cold Share/Quick Listen keep the splash over App until their route checks finish,
            then bypass any remaining introduction to expose the destination controls.
      - [ ] Device check: cold launch on Xiaomi (Android 12+), light/dark system theme,
            launch from an audio share and Quick Listen, and Android pre-12 if available.
      Écrans restants : une session et une PR par écran (titre « J6c <écran> : … »). Avant de
      commencer, vérifier dans les PR ouvertes que l'écran n'est pas déjà pris. Deux sessions à la
      fois, dans cet ordre : Fiche espèce et Revue rapide, puis Palmarès et Carte, puis Sonothèque
      et Envoi à la LPO.
      - [x] Fiche espèce (`lib/fork/species_page/`) : page plein écran qui remplace la feuille upstream
            (un point FORK dans `SpeciesInfoOverlay.show`, donc tous les appelants), feuille sombre
            pendant une écoute. Photo de J6b en tête sur la teinte de l'espèce, « Entendu N fois… »,
            badge Sûr et nombre de bonnes, « Ici en ce moment » (géomodèle au lieu du téléphone, 12
            barres, jamais de demande de localisation), « Mes sons » (3 meilleurs, favoris d'abord,
            réécoute par le lecteur du Live donc sans fausse détection pendant une écoute, lien vers la
            sonothèque), chant de référence vers eBird, fiche IA en puces (le résumé en tête), sinon
            la description upstream, activité par heure et mini-carte vers la carte filtrée, liens.
            Écarts : photo au lieu de l'icône (J6d), pas d'étoile « favori » pour l'espèce, pas de
            « il chante aussi en automne » (le géomodèle ne le dit pas), pas de Hero (aucun appelant
            ne donne de photo de départ). À vérifier sur le Xiaomi : réécoute depuis la feuille
            pendant une écoute, défilement fluide avec la mini-carte.
      - [x] Palmarès (`lib/fork/ranking/`) : barre retour + « Palmarès », en-tête « 17 espèces en
            30 jours » et « N nouvelles en 2026 · du 27 août au 26 septembre », puces de période,
            interrupteur « Confirmées seulement », menu « Classées par … » (contacts, jours, dernière
            écoute, « Oiseaux seulement »), podium des trois premiers sur la teinte de chaque espèce
            (disques or, argent, bronze, photo), puis rangs 4 et suivants avec photo, barre de la
            couleur `deep` de l'espèce et pastille « Nouveau cette année ». Un appui ouvre la fiche.
            Écarts : « Confirmées seulement » reste désactivé par défaut (peu de détections sont
            confirmées au début) ; tri et filtre oiseaux dans un menu plutôt qu'en puces.
      - [x] Carte (`lib/fork/map/`) : couleurs et textes du design system partout. Puces de filtre
            SPEC.md 5.10 (sélectionnée = fond de la couleur du texte, coche sur « Confirmées »),
            boutons ronds blancs avec ombre, marqueurs en disque blanc cerclé de Martin-pêcheur
            (Loriot pour le lieu choisi) avec la photo et le nombre de contacts, groupes en disque
            Martin-pêcheur avec le nombre d'espèces, position de l'utilisateur avec un halo fixe.
            Feuille d'une zone : « N espèces · M contacts », lignes avec photo sur la teinte de
            l'espèce, nombre de contacts et bouton de réécoute, ligne « Tes positions précises… ».
            Écarts : pas de halo animé autour de la position (pas d'animation sans fin sur la
            carte), pas de barre de navigation (elle vient avec J6e), marqueurs avec photo tant que
            les icônes de J6d manquent.
      - [x] Sonothèque (`lib/fork/sound_library/`) : pas de maquette ; même langage que les autres
            écrans J6c. Barre retour + titre, liste des espèces avec photo sur la teinte de l'espèce et
            « N enregistrements · N ★ », puis les extraits d'une espèce : puces « Meilleur score » /
            « Plus récents » et « Favoris seulement », bouton de réécoute du design system, date,
            score, lieu, badge de fiabilité, étoile Loriot. Corrigé : trier ou marquer un favori
            levait une assertion en mode debug (`setState` qui renvoyait un Future).
      - [x] Revue rapide (`lib/fork/reliability/quick_review_*.dart`) : barre « Revue rapide · N sur M »
            (fermer, écran Fiabilité), barre de progression et « Tu as trié N détections », pile de
            cartes (deux cartes derrière), carte avec badge de niveau (« Rare ici · à confirmer »
            compris), photo, nom, heure, score, spectrogramme de l'extrait, réécoute et chant de
            référence eBird, « Au casque ou à faible volume ». La carte suit le doigt, part avec la
            vitesse du geste ou revient en ressort ; les trois boutons de verdict (104 dp) la font
            partir aussi. Animations réduites : fondu seul. Écarts : pas de mention du badge
            Réviseur (J6e), pas de lieu (géocodage en ligne), pas de rotation de la carte (DESIGN.md).
            À vérifier sur le Xiaomi : balayage fluide à 60 images par seconde, extrait joué à
            l'arrivée de chaque carte.
      - [x] Envoi à la LPO (`lib/fork/lpo/lpo_send_screen.dart`) : pas de maquette dédiée (le Bilan
            n'en montre que le bouton) ; même langage que les autres écrans J6c. Barre retour + titre,
            introduction et notes discrètes, carte par observation avec photo sur la teinte de
            l'espèce, nom, nom latin et heure ; alertes « rare » et « hors saison » en Loriot,
            « espèce sensible » en bleu Probable ; questions et fiche à copier inchangées ; boutons
            du design system (Copier en principal, les autres en secondaire). Aucun changement de
            règle : seules les détections confirmées sont proposées.
      - [x] Écrans vides (`lib/fork/design/widgets/empty_state.dart`, DESIGN.md « Écrans vides ») :
            un composant, trois situations (rien encore, rien avec ces filtres, tout est fait), icône,
            titre, phrase, bouton qui élargit le filtre quand c'est possible. Posé sur l'Accueil, le
            Palmarès, la Carte, la Sonothèque, la Revue rapide, l'Envoi à la LPO et le comptage au
            jardin. À vérifier sur le Xiaomi : l'Accueil un jour sans écoute, la Sonothèque avec
            « Favoris seulement » et aucun favori.
- [x] J6c-bis-a Live : corrections (`lib/fork/live/`, PR « J6c-bis-a Live : corrections », fusionnée #23).
      - [x] Traits sous le spectre : départ au début de la fenêtre analysée (`DetectionRecord.timestamp`),
            plus 3 s trop tôt ; la fin ne recule ni ne saute quand le contact se ferme (fin de chant,
            pause, réécoute).
      - [x] Tableau : « dernier entendu » calculé sur les détections de la session seulement, le tri
            ne bouge plus à chaque cycle.
      - [x] Symbole « chante » : place réservée, fondu à l'allumage et à l'extinction, animation
            arrêtée quand il est masqué ; la ligne ne bouge plus.
      - [x] En-tête : statut sur une ligne, changement de texte en fondu, hauteur constante.
      - [x] En pause et pendant une réécoute : symbole « chante » et trait en cours éteints.
      - [x] Mesure (journal hors version publiée) : p50 et p95 du temps d'analyse et du retard
            entre la fin de la fenêtre et l'affichage.
      - [x] Réglages d'inférence avancés visibles hors version publiée, pour essayer « Very-high
            immediate threshold » à 0,90 puis 0,80 en `flutter run --profile` sur le Xiaomi.
      À faire sur le Xiaomi : relever les lignes `[InferenceTiming]` (toutes les 30 analyses) en
      `--profile`, et vérifier que symbole et trait s'éteignent en pause et pendant une réécoute.
- [x] J6c-bis-b Live : « Analyse… » et fin rapide (`lib/fork/live/`, PR « J6c-bis-b Live : … », fusionnée #26).
      Lecture seule dans `lib/features/inference` (quelques lignes `// FORK`, `infer()` et le lissage
      inchangés).
      - [x] Upstream : `lastWindowScores` (scores de la dernière fenêtre × multiplicateurs) et
            `supportThresholdFor` dans `InferenceService`, un getter dans `InferenceIsolate`, un
            `ValueNotifier` du cycle dans `LiveController`, publié avec les détections, vidé en pause et
            en réécoute ; `ReplayGuard.heard` sans effet de bord.
      - [x] « Analyse… » : l'en-tête passe en fondu de « En écoute » à « Analyse… » quand la dernière
            fenêtre contient un candidat (Aves, dans le filtre d'espèces et l'intersection géo, score de
            fenêtre au moins égal au seuil de support, pas déjà confirmé). Rien en lissage off, avg ou
            max. Reste un cycle de plus après la confirmation. Ni nom, ni ligne, ni vibration.
      - [x] Fin rapide : le symbole « chante » s'allume à l'ouverture du contact et s'éteint après
            2 fenêtres de suite sous le seuil de support (`LiveTableEntry.singingVisual`) ; `singing`
            garde son sens. Fin du trait : `heardUntil` (fin de la dernière fenêtre au-dessus du seuil de
            support), jamais en recul.
      - [x] Seuils `liveSingingHoldWindows` et `analysingHoldWindows` dans `reliability_config.dart`.
      À faire sur le Xiaomi : à l'aube, noter si « Analyse… » reste allumé presque tout le temps ;
      vérifier le coût du cycle dans `[InferenceTiming]` ; réécoute par le haut-parleur sans
      « Analyse… » ni symbole.
- [x] J6c-bis-c Live : spectre, noms et couleurs (`lib/fork/live/`, PR « J6c-bis-c Live : … », fusionnée #34).
      - [x] Rotation portrait ↔ paysage sans effacer le spectre ni ses traits (clés globales : le
            spectre, les traits et le tableau changent de place dans l'arbre sans être recréés).
      - [x] Échelle en kHz retirée, en petit comme en grand : le modèle dit quand un oiseau chante,
            pas à quelle fréquence. `live_screen.dart` repasse `showFrequencyAxis: false` comme upstream.
      - [x] Noms sous les traits aussi en petit, dans la couleur de l'espèce ; bande de 40 dp.
      - [x] Lien de couleur avec le tableau : pastille de la couleur de l'espèce sur la photo de
            chaque ligne, symbole « chante » de la même couleur.
      - [x] Bouton « i » en haut à la place du chevron : feuille qui explique Sûr, Probable,
            À vérifier et « Rare ici · à confirmer » (`lib/fork/reliability/levels_sheet.dart`).
      - [x] Chevron agrandir / réduire dans le coin du spectre ; un appui sur le spectre bascule.
      À vérifier sur le Xiaomi : rotation pendant une écoute, lisibilité des noms en petit.
- [ ] J6c Écoute : position GPS suivie pendant l'écoute (`lib/fork/live/live_position.dart`,
      PR « J6c Écoute : position GPS suivie pendant l'écoute »).
      - [x] `LivePositionTracker` sur `SurveyGpsTracker` (interface `LivePositionSource` pour iOS) :
            démarre après le lancement de l'écoute, sans la retarder ; seulement si « Utiliser le GPS »
            est actif, la localisation allumée et l'autorisation déjà donnée (jamais de demande).
            Rien en écoute d'un enregistrement (J5c) ni en position manuelle.
      - [x] Chaque nouvelle détection reçoit le dernier point mesuré (detLat, detLon) ; avant le
            premier point, la position de la session si elle est fiable, sinon rien (les lecteurs
            retombent sur la position de la session, corrigée au premier point).
      - [x] Position de départ absente ou venue du cache de l'OS : remplacée par le premier point précis.
      - [x] Trace mesurée gardée dans `gpsTrack` de la session (précision pour la LPO, carte du
            rapport HTML). Arrêt à la pause, à la fin, en quittant ; reprise avec l'écoute.
      - [x] Écran éteint : le service Live (J2b) démarre au premier plan et son type manifeste est
            déjà `microphone|location`, rien à ajouter.
      - [x] Seuils `liveGpsIntervalSeconds` (10 s), `liveGpsDistanceFilterMeters` (5 m),
            `liveGpsMaxAccuracyMeters` (30 m) dans `reliability_config.dart`. Localisation
            « approximative » d'Android seulement journalisée (les points de 2 km sont écartés).
      - [ ] (Benjamin) Sur le Xiaomi : marche de 10 minutes écran éteint, puis vérifier sur la carte
            que les contacts sont placés le long du chemin et non tous au point de départ.
- [ ] J6d Icônes d'espèces en SVG, pour la carte, le tableau en direct et le carnet. Aucune base SVG
      d'oiseaux complète, en couleur et réutilisable n'existe (recherche de septembre 2026) : on la
      construit nous-mêmes, dans le style du logo.
      - Une famille de 30 à 50 gabarits (un par famille ou genre), avec des zones de couleur nommées
        (calotte, joue, poitrine, dos, aile, barre alaire, queue, bec, pattes), remplies depuis une table
        de couleurs par espèce. Formes de base : dessins maison ou silhouettes PhyloPic sous CC0.
        Couleurs relevées sur des planches du domaine public, jamais sur des guides protégés.
      - Silhouettes PhyloPic (environ 19 des 20 oiseaux les plus courants en France, sous CC0 ou CC BY)
        comme secours pour les espèces sans gabarit : récupérées une fois par un script, jamais en
        lien direct, en filtrant NC et SA, avec licence et auteur notés pour chaque image.
      - Écran des crédits pour les images CC BY (auteur, licence, « recolorée »). Ne jamais partir
        d'OpenMoji ni de Mulberry (CC BY-SA) ni d'images NC.
      - Relecture sur planches. La photo reste sur la fiche.
      - Nouvelle dépendance prévue : `flutter_svg` (absente du projet).
- [x] J6e Jeu : statuts selon le nombre d'espèces découvertes, badges, série de jours, défis de la
      semaine, carnet façon collection (silhouettes mystère pour les espèces attendues ici en cette
      saison, grâce au géomodèle), célébrations graduées (arrivée, première fois, oiseau rare, nouveau
      statut). Règles : seules les détections Sûr ou confirmées font progresser ; un oiseau rare se
      vérifie avant la fête ; ni notification culpabilisante ni série perdue pour un jour manqué.
      Trois PR : J6e-a (navigation et Carnet), J6e-b (Profil), J6e-c (moments et défis). Toutes fusionnées (#36, #37, #38, plus quiz #42 à #45).
      - [x] J6e-a Navigation et Carnet (`lib/fork/shell/`, `lib/fork/notebook/`, `lib/fork/game/`) :
            barre Accueil, Carnet, Carte, Profil (un point FORK dans `HomeScreen`, qui renvoie
            `ForkShell`) ; chaque onglet est construit à sa première visite puis gardé, la carte ne
            charge donc ses tuiles qu'à l'ouverture de l'onglet ; retour depuis un onglet = Accueil ;
            la carte en onglet n'a pas de bouton retour. Profil : écran « bientôt » jusqu'à J6e-b.
            Carnet : découvertes (Sûr ou confirmées, oiseaux seulement) en couleur avec « N fois » et
            « Nouveau » jusqu'à l'ouverture de la fiche (à la première ouverture du carnet, les espèces
            déjà trouvées ne sont pas nouvelles) ; « À confirmer » (entendue, jamais vérifiée, détections
            dans la revue) ouvre la revue rapide sur ces seules détections ; silhouettes mystère des
            oiseaux attendus ici cette semaine (liste d'Explorer, jamais de demande de localisation)
            avec l'indice de la fiche IA, jamais le nom ; marques de rareté selon le palier du
            géomodèle ici cette semaine (`uncommonTiers`, `rareTiers`, absente = étoile) ; puces Toutes,
            Découvertes, À découvrir, Rares ; podium vers le Palmarès.
            Règle du jeu (`gameVerifiedSpecies`) : confirmée, ou Sûr au sens de `reliabilityFor`
            (score ≥ `sureMinScore` et espèce plausible au lieu et à la semaine de la détection). Plus
            stricte que `verifiedSpecies` de l'index : un oiseau rare attend « C'est bien lui », une
            détection sans position ne compte pas sur son seul score.
            Écarts : silhouette générique (oiseau gris) en attendant les icônes de J6d, qui se
            brancheront dans `notebook_visuals.dart` ; sans fiche en français, le mystère n'a pas
            d'indice ; pas de mystères sans position (une phrase le dit).
            À vérifier sur le Xiaomi : passage d'un onglet à l'autre sans saccade, carte ouverte
            puis quittée, Carnet avec la localisation coupée, « Écouter » au-dessus de la barre.
      - [x] J6e-b Profil (`lib/fork/profile/`, `lib/fork/game/`) : carte de statut (anneau de progression,
            nom, espèces découvertes, « Encore N espèces pour devenir … », phrase du statut), échelle des
            8 statuts (seuils 1, 5, 10, 20, 35, 50, 75, 100), série sur deux semaines (écoute, repos en
            pointillé, jour manqué, aujourd'hui cerclé) avec record, badges en grille de 4 (médaille aux
            couleurs de la plume, points de plumes ou « N sur M » tant qu'il est à gagner) ; un appui sur
            un badge ouvre sa règle et ses paliers. Accueil : pastille de série (cachée sans série en
            cours) et carte de statut, qui ouvrent l'onglet Profil.
            Règles (`game_config.dart`, SPEC.md 7) : statut selon les oiseaux Sûrs ou confirmés
            (`gameVerifiedSpecies`) ; série : un jour compte à partir de 5 minutes d'écoute, un jour de
            repos par 7 jours, au-delà la série repart sans bruit et le record reste ; badges Chœur de
            l'aube (10 espèces sûres dans une écoute commencée avant 8 h), Lève-tôt (avant le lever du
            soleil, calcul NOAA d'upstream `estimateAruSunTimes`, lieu de l'écoute), Noctambule et Les
            mésanges (par genre), Réviseur (confirmées, rejetées et « Je ne sais pas »), Migrateur (score
            hebdomadaire du géomodèle ici : présent certaines semaines, absent d'autres), 7 jours
            d'affilée (record de série).
            Emblèmes : tracés de la maquette (SPEC.md 4.3) lus par `lib/fork/design/svg_path.dart`
            (petit lecteur de chemins SVG, sans `flutter_svg`).
            Écarts : badge Oreille fine arrivé avec J6e-d ; icône
            générique pour Les mésanges en attendant J6d ; pas d'animation de gain sur l'anneau (elle
            vient avec la célébration de nouveau statut en J6e-c).
            À vérifier sur le Xiaomi : Lève-tôt sur une vraie écoute avant le lever du soleil, série
            après un jour sans écoute.
      - [x] J6e-c Moments et défis :
            - Arrivée : déjà là depuis J6c (la ligne entre en haut, vibration légère).
            - Première fois (`lib/fork/live/live_moments.dart`) : quand un oiseau jamais vérifié devient
              Sûr pendant l'écoute, carte « Première rencontre ! » par-dessus le spectre et le tableau,
              jamais sur Arrêter / Pause (`LiveListeningLayout.moment`) ; teinte de l'oiseau à 15 % au
              plus, rang dans le carnet, statut et ce qui manque pour le suivant, Réécouter (lecteur du
              Live, donc sans fausse détection), se referme seule après 6 s.
            - Oiseau rare : carte dorée immobile quand un oiseau jamais vérifié est « Rare ici · à
              confirmer » ; présence estimée ici, réécoute, « c'est bien lui ? » et les trois réponses,
              écrites sur les détections de la session (enregistrées à « Arrêter »). La fête (un anneau,
              « +1 espèce rare ») seulement après « C'est bien lui ».
            - Une carte à la fois : un moment qui arrive pendant qu'une carte est ouverte attend le Bilan.
            - Nouveau statut (`status_celebration.dart`) : dans le Bilan après « Arrêter », ou à
              l'Accueil (statut atteint par la revue), jamais pendant une écoute ; une seule fois par
              statut ; les statuts atteints avant cette version ne sont pas fêtés.
            - Défis de la semaine (`challenges.dart`) : un par semaine à tour de rôle (3 matins avant
              8 h, 5 jours d'écoute, 10 espèces sûres ou confirmées) ; rien ne compte avant « Commencer »,
              pas de pénalité ; carte sur l'Accueil et le Profil.
            Écarts : pas de défi saisonnier ni de défi débloqué par un statut, pas de notification ;
            pas de bouton Partager sur le nouveau statut ; pas de vague ni de plumes (DESIGN.md prime).
            À vérifier sur le Xiaomi : carte « Première rencontre » pendant une vraie écoute (l'écoute
            continue, Arrêter reste accessible), réponse sur un oiseau rare retrouvée dans la session.
      - [x] J6e-d Quiz « Qui chante ? » et badge Oreille fine (`lib/fork/game/fine_ear*.dart`) : un de
            ses propres enregistrements d'un oiseau vérifié, quatre noms, un seul juste ; manches de
            10 questions tirées au hasard, chaque espèce une fois ; il faut 4 oiseaux vérifiés avec un
            extrait. Le clip vient d'une détection qui compte pour le jeu (confirmée, ou Sûr non revue),
            jamais rejetée, fichier encore présent (sinon un autre extrait de l'espèce). Lecture par le
            lecteur partagé (`speciesClipPlayerProvider`), donc l'inférence ignore la réécoute si une
            écoute tourne. Seules les bonnes réponses sont gardées (un compteur). Badge Oreille fine :
            10, 50, 150 bonnes réponses. Accès : carte « Qui chante ? » sous les badges du Profil, et
            « Lancer le quiz » dans la fiche du badge. Repris de la branche `feat/j6e-notebook-game`
            (le reste de cette branche doublait J6e-a à c).
            Écarts : icône générique pour Les mésanges et silhouettes grises du carnet, J6d étant en
            pause ; « Je ne sais pas » reste dans l'index (table `review_skipped`), pas dans les
            sessions JSON.
            Quiz v2 (maquette « Quiz v2 ») : accueil avec interrupteur « Avec son / Sans son »,
            chemin de 10 étapes, oiseau mystère dessiné, confettis, rayons, pops, « +1 Oreille fine »
            qui s'envole, bilan étoiles / grille 5 × 2 / barre animée, jingle et fanfare (lecteur
            dédié `quiz_sfx.dart`, sons synthétisés par `tools/fork_quiz_sounds.py`). Oiseaux
            toujours en photo (choix de Benjamin : aucune icône d'oiseau dessinée) ; seule la
            silhouette mystère vient de `icons.json`. Dépendances
            ajoutées : `confetti`, `flutter_svg`.
- [ ] J6f Interface finale (maquettes « App finale » du canevas, design system mis à jour). Base
      commune : `BirdyBlock` (tons plain, tonal, sure, oriole, toCheck), barre et anneau de
      progression, `BirdyTabHeader`, `BirdyOverlayHeader`, `BirdyFilterChip`, jetons 16 / 10 dp.
      - [x] J6f-a Accueil en blocs et Écoute (PR « J6f-a Accueil et Écoute : … ») : héros « Dernier
            oiseau entendu », grille objectif / série / à vérifier, statut, « Aujourd'hui », défi ;
            « Écouter » lance l'écoute (`forceAutoStart`). Live : état vide « Attendus ici ce
            matin », ligne de lieu, pilule de mode à la place du menu ⋮ (Aide et Réglages passent
            dans la feuille « i »).
      - [x] J6f-b Onglets et écrans par-dessus (PR « J6f-b Carnet, Profil, Carte, Fiche, Palmarès,
            Bilan, Revue : … ») : grands titres, blocs teintés, filtres colorés, en-tête retour et
            titre 20 (croix « Fermer » pour le Bilan et la Revue). Fiche espèce : le mois en cours
            est visible dans la frise (PR #57).
      - [x] J6f-c Modes d'écoute (PR « J6f-c Écoute : modes d'écoute »), `lib/fork/listening_mode/` :
            Normal, Vent (passe-haut 250 Hz), Boost (gain ×2, passe-haut 120 Hz) écrivent les réglages
            gain et passe-haut existants ; Ville (réduction des bruits continus, une ligne FORK dans
            `audio_capture_service.dart`) derrière `kCityModeEnabled = !kReleaseMode`.
      - [ ] (Benjamin) Terrain : Vent par vent réel (chouettes et pigeons toujours reconnus),
            Boost sur oiseaux lointains, Ville près d'une route (scores, spectre, coût en profile,
            écran éteint), changement de mode en pleine écoute, mode retrouvé après redémarrage.
      - [ ] Décider de garder Ville après le terrain (lever le drapeau ou retirer le mode).
      - [x] Enregistrer le mode dans la session (champ `SessionSettings.listeningMode`, un `// FORK` dans `live_session.dart`, `live_controller.dart` et `live_screen.dart`, J6 Fin).
      - [x] J6f-e Profil et Quiz (PR « J6f-e Profil et Quiz : … », maquettes Claude Design `AppProfil`
            et `AppQuiz`). Profil en 3 blocs : « Mon niveau » (anneau, échelle 2×4 qu'on touche, encart
            du prochain niveau avec barre à cases), « Série », « À gagner » (plumes, défi, badges sur 3
            colonnes gagnés d'abord, entrée du quiz avec le nouveau `QuizLogo`). Les rangs du jeu
            s'appellent « niveau » partout (valeurs des chaînes seulement). Quiz : accueil (étincelles,
            oiseaux en orbite, bulle, cartes Écoute / Devine / Gagne, carte badge à cases), pastille de
            score, scène d'écoute (bulle, anneaux, spectre 27 barres), encouragement sur une erreur,
            récap « N trouvés », carte médaille au ton du métal, « +N cette partie ». Les photos restent ;
            l'oiseau mystère prend la silhouette BirdyGo.
      - [x] (Benjamin) Téléphone : 60 images par seconde sur l'accueil du quiz (décor animé) et le Profil.
      - [x] J6f-f Palmarès (PR « J6f-f Palmarès : … », maquette Claude Design `AppPalmares`) : podium
            2-1-3 à hauteurs 240 / 212 / 196 avec médailles or, argent, bronze (`BadgeMedal` avec le
            rang), photos dans un disque cerclé de l'accent, scintillements fixes sur le premier ;
            lignes de 60 dp avec barre proportionnelle au premier qui pousse une fois ; nombre de
            nouvelles de l'année en Loriot ; interrupteur partagé `BirdySwitch`. Pas de boucle ni de
            rebond (DESIGN.md prime sur la maquette).
      - [x] (Benjamin) Téléphone : Palmarès, podium et barres, clair et sombre.
- [ ] J6g Critique générale : style unifié et navigation (une PR par chantier, titres « J6g-x … »).
      - [x] J6g-a Premier lancement (PR « J6g-a Premier lancement : … », `lib/fork/onboarding/`) :
            onboarding BirdyGo en 3 pages (l'app, trois cartes, Sûr / Probable / À vérifier) puis
            autorisations (micro nécessaire, position facultative, carte en ligne coupée par défaut).
      - [x] J6g-b Accueil et Carnet (PR « J6g-b Accueil et Carnet : … ») : style Profil (héros avec
            halo, bloc niveau, tuiles du Carnet par état) ; « Aujourd'hui » rouvre le Bilan du jour.
      - [x] J6g-c Menu et Réglages (PR « J6g-c Menu et Réglages : … ») : feuille « Plus » en 8
            tuiles et « Outils avancés » repliés ; Réglages simples, réglages BirdNET en « avancés ».
      - [x] J6g-d Écrans BirdyGo (PR « J6g-d Écrans BirdyGo : … ») : Objectif du jour, Jardin,
            Fiabilité, envoi LPO et Sonothèque passés aux composants maison.
      - [x] J6g-e Navigation (PR « J6g-e Navigation : … ») : toujours le Bilan après l'écoute (même
            sans sauvegarde automatique), fiche en feuille refermable, « Envoyer à Faune-France »
            depuis la fiche espèce.
      - [x] J6g-f Carte (PR « J6g-f Carte : … ») : marqueurs et regroupements sur jetons
            (`BirdyMapStyle`), feuilles au style Profil, squelette de chargement.
      - [x] J6g-g Squelettes (PR « J6g-g Squelettes : … ») : `BirdyShimmer`, balayage de lumière
            partagé, figé en animations réduites ; boucle autorisée dans DESIGN.md.
      - [x] (Benjamin) Téléphone : série J6g validée.
      - [x] Retirer `HomeMenuEntry` et `HomeMenuSheet`, devenus inutilisés (J6g-c).
      - [ ] Confirmer que la phrase de consentement de l'onboarding (liens Politique d'utilisation
            acceptable et de confidentialité) remplace bien l'étape de la charte d'usage BirdNET.
      - [ ] Envoi à Faune-France depuis la fiche : une session à la fois (pas de logique serveur
            nouvelle) ; à revoir si le besoin se confirme.
      - [x] Faire passer « Aujourd'hui » par `openListeningSummary` (retour d'un seul écran, J6 Fin).

- [ ] J6h Passe d'homogénéité, ligne Profil / Quiz (handoff `fork/handoff/README.md`, règles dans
      DESIGN.md « Ligne J6h »). Un écran = une PR « J6h <Écran> : … », PR empilées dans l'ordre.
      - [x] Socle : silhouette dans `SpeciesAvatar`, pastilles, `AppIcons`, jeton #8CD3D9 et aile,
            ligne de liste unique, préférences `firstName` et `liveTheme`, config des heures du jour.
      - [x] Accueil : bande « Ta journée » et son tiroir, salutation avec prénom, aile sur « Écouter ».
      - [x] Écoute : thème clair (`liveTheme`), étiquettes de rareté, noms du spectrogramme sans chevauchement.
      - [x] Bilan : héros à 3 tuiles, blocs titrés, tiroir « Autres actions ».
      - [x] Carnet : héros simplifié, bloc « Ma collection », grille 2 colonnes, rareté en mots.
      - [x] Fiche : héros `sure`, bloc « Fais sa connaissance ».
      - [x] Fiche, rubrique Ennemis : code prêt (6e disque, `SheetSection.enemies`, script `tools/fork_species_sheets.py`).
            Régénérer les fiches avec la rubrique Ennemis (PC, API) ; fait : fiches régénérées, 100 espèces (commits 71630632, 06f838e6).
      - [x] Profil : traits de l'échelle entre emblèmes, félicitations avec prénom.
      - [x] Quiz : intro sans défilement, croix et confirmation de sortie.
      - [x] Palmarès : héros avec puces de période, blocs Podium et Classement, bouton `sort`.
      - [x] Sonothèque : héros, filtre favoris sur la liste, bloc unique.
      - [x] Réglages : blocs titrés, bloc « Toi » (prénom), thème Auto, écran d'écoute.
      - [x] Menu Plus : tuiles Brume, seul le disque teinté ; retirer `HomeMenuEntry`/`HomeMenuSheet`.
      - [x] Objectif : héros à anneau, liste en bloc, bouton épinglé avec l'aile.
      - [x] Carte : puces en encre, bulle 13, retour quand elle est poussée.
      - [x] Revue : pile centrée verticalement.
      - [x] Premier lancement : étape prénom facultative.
      - [x] J6i Icônes (Android) : 4 icônes adaptatives (fond dégradé tonal → blanc, logo du thème),
            rendues par `test/fork/tool/render_launcher_icons_test.dart`
            (`RENDER_LAUNCHER_ICONS=1 flutter test …`). 4 `activity-alias` (`.AliasLoriot` par défaut,
            `.AliasMartin`, `.AliasFlamant`, `.AliasEtourneau`), canal `fr.justcodeit.birdygo/app_icon`,
            `AppIconChannel.kt` applique le choix quand l'appli passe en arrière-plan.
      - [ ] (Benjamin) Téléphone : l'icône change après avoir quitté l'appli, widgets et partage vers
            l'appli fonctionnent toujours.
      - [x] Écoute : alerte « Volume coupé / Volume bas » (volume média sous `MediaVolumeConfig.lowBelow`,
            lu chaque seconde par `MediaVolume`) et bouton « Monter le son » (`comfortable`, avec le
            curseur système). Canal `fr.justcodeit.birdygo/media_volume`, `MediaVolumeChannel.kt`.
      - [x] Écoute : notification d'une nouvelle espèce (Sûr ou Probable, première fois de la session) quand l'app est en arrière-plan ; canal « Nouvelles espèces », interrupteur dans les options d'écoute (`lib/fork/notifications/`). Côté iOS : autorisation de notification (UNUserNotificationCenter) et mode d'arrière-plan audio nécessaires.
      - [x] Écoute : premières rencontres en série (file, « 1 sur 3 nouvelles », points, « Espèce suivante »),
            barre de décompte qui se fige en pause, retour d'arrière-plan, logo animé partagé
            (`BirdyListeningLogo`), feu d'artifice en deux salves et étincelles (`BirdySparkles`).
      - [x] Accueil et Quiz : point du wordmark posé sur la ligne de base, « Avec effets / Sans effets »,
            Réglages « Effets sonores du quiz ».
      - [x] Écoute : carte de l'oiseau rare (arrivée avec anneau pointillé, halo et losanges ; « 1 chance sur n » ;
            les 3 verdicts de la Revue rapide ; décomptes 6 s / 3 s ; « Je ne sais pas » laisse à vérifier) et
            carte de première rencontre compacte (oiseau 96, sans nom latin, `BalancedText`, sans « n au total »).
      - [ ] « Me le rappeler » (tiroir Ta journée) : reporté. Demande `timezone` en dépendance directe
            pour `zonedSchedule` ; à décider. Côté iOS : autorisation de notification à demander.
      - [ ] (Benjamin) Téléphone : série J6h, clair et sombre, écoute claire écran éteint.

- [ ] J6i Thèmes, typo, wordmark, icônes, premier lancement (suite de J6h, PR #103 à #108).
      - [x] Thèmes (#104, #105) : 4 palettes d'oiseau (loriot, martin, flamant, étourneau), choix clair / sombre.
      - [x] Typo (#103) : échelle Nunito / Atkinson / Fraunces, jetons dans `birdy_typography.dart`.
      - [x] Wordmark (#106) : point posé sur la ligne de base, logo animé du thème.
      - [x] Icônes (#107) : icône d'appli par oiseau (4 alias Android), l'icône de l'application pointe
            vers celle du loriot. Côté iOS : voir la section « Phase iOS », icône d'appli par oiseau.
      - [x] Onboarding (#108) : choix de l'oiseau, prénom, bienvenue.
      - [x] Ménage : images d'échec des goldens ignorées (`**/goldens/failures/`), jetons pour les tailles
            de l'onboarding (`labelLarge`, `inputLarge`, `headingSmall`, `ctaIcon`, `inlineIcon`).
      - [ ] (Benjamin) Téléphone : premier lancement, 4 oiseaux, icône, clair/sombre.
      - [x] Régénérer les fiches avec Ennemis (PC, API) : voir la rubrique Ennemis de J6h.
    - Accueil et Plus (L, M) :
      - [x] L : « Qui chante ? » sur l'Accueil (`QuizEntryRow` + `progress`, barre vers la prochaine
            plume), affiché seulement si le quiz est jouable (`quizPlayableProvider`).
      - [x] M : menu Plus en 3 groupes titrés, Carte retirée, bloc utilitaire avec Outils avancés
            dépliable en dernier ; golden 4 thèmes.
      - [x] Liseré du logo quiz à l'accent du thème d'oiseau choisi.
      - [ ] (Benjamin) Téléphone : bloc quiz sur l'Accueil, menu Plus dans les 4 thèmes.

- [x] J6j Barre du bas : « Écouter » devient un disque au centre de la barre (5 emplacements : Accueil,
      Carnet, Écouter, Carte, Profil).
      - [x] `ForkNavBar` (`lib/fork/shell/fork_nav_bar.dart`) : barre dessinée à la main, disque de 68 dp
            qui dépasse de 22 dp, aile en vumètre pendant l'écoute, appui à 0,95, sémantique dans l'ordre.
      - [x] `ForkShell` : pages au-dessus de la barre (`Stack`), le disque n'est pas un onglet ; il ouvre
            l'écoute, ou rouvre l'écran d'une écoute en cours.
      - [x] Accueil : plus de pilule « Écouter », marge basse de 38, fondu de 28 dp. Profil : le bouton
            Palmarès devient le menu (Palmarès reste dans le menu). Marge basse de Carnet et Profil
            alignée sur celle de l'Accueil.
      - [x] Vague de l'aile toutes les 7 s pile (plus de variation).
      - [x] Tests : goldens de la barre (4 oiseaux, clair et sombre), appuis, cibles de 48, ordre de la
            sémantique, contrastes ; goldens de l'Accueil régénérés.
      - [ ] (Benjamin) Téléphone : disque, écoute écran éteint, rouvrir l'écoute depuis la barre.

   J7 Écoute (thème clair, niveau stable), branche `feat/ecoute-theme-clair` :
      - [x] L'écran d'écoute suit le thème de l'app par défaut ; réglage « Écran d'écoute toujours
            sombre » (Réglages, feuille d'options de l'écoute), faux par défaut.
      - [x] Contrastes du Live dans les 4 thèmes clair et sombre, goldens du Live (8).
      - [x] Bouton play de la carte « première fois » (et de l'oiseau rare) réservé dès la première image.
      - [x] Niveau d'une ligne = meilleur contact de la sortie (stable), barres « chante » selon le score
            courant, pastille « Confirmé » une fois, feuille des niveaux par espèce (meilleur score,
            heure, contacts). Le Bilan appliquait déjà cette règle.
      - [ ] (Benjamin) Téléphone : écoute en clair au soleil, puits sombre, Confirmé sur un vrai chant

Fini quand, mesuré en mode profile sur le Xiaomi :
- 60 images par seconde partout, 120 quand l'écran le permet, aucune image perdue au défilement ;
- l'écoute démarre moins d'une seconde après l'appui sur « Écouter » (le nouvel accueil garde le
  préchargement d'upstream, `_warmUpApp` dans `lib/features/home/home_screen.dart`) ;
- une espèce apparaît dans le tableau moins d'une seconde après la fin de l'analyse de son extrait ;
- thèmes clair et sombre, animations réduites respectées, texte agrandi à 130 % lisible ;
- le jeu ne récompense que les détections Sûr ou confirmées.

## J7 : publication Android

- [x] Quiz « Qui chante ? », réécoute et score (`feat/quiz-reecoute-score`) : le bon chant est rejoué après une
      mauvaise réponse, le bouton de lecture garde sa place entre question et correction, le chemin de
      10 points remplace « Chant n sur N » et la pastille de score, « Sons à retenir » sur l'écran de fin,
      libellé « Oiseau mystère » retiré. Tests dans `test/fork/game/fine_ear_test.dart`.

- [x] J7 Accueil (retours) : horaires du jour resserrés (moins d'espace au-dessus et en dessous), cri du logo préchargé (plus de retard au premier appui), connecteurs entre les points de la série.
- [x] Signature de l'app (clé d'upload), build `appbundle` en release. Config dans `android/app/build.gradle` (lit `android/key.properties`), pas à pas dans `fork/release/README.md`. Reste à Benjamin : créer la clé et lancer la build.
- [x] Onboarding : carte dédiée « Carte en ligne » (Oui / Non, rien coché d'office) à la place de
      l'interrupteur de la carte Position ; écrit `privacyAllowMapProvider`.
- [ ] Piste de test interne sur le Play Store, fiche en français, politique de confidentialité adaptée
      de celle d'upstream.
- [ ] Avant de publier : retirer du pack les photos marquées « © Macaulay Library » (droits réservés),
      garder CC0, CC BY et CC BY-SA, et CC BY-NC seulement si l'app reste gratuite.
      `--replace-reserved` (J6b) en remplace déjà la plupart ; le script liste celles qui restent.
- [ ] (fait : photos par licence, polices, modèle, cartes ; reste : textes Wikipédia et icônes d’espèces CC BY) Page « Licences des contenus » dans À propos : licence de chaque photo (colonne `image_license`
      de `taxonomy.csv`, à afficher aussi dans le crédit), textes Wikipédia et fiches IA sous CC BY-SA
      avec lien, icônes d'espèces tirées d'une base CC BY (J6d) avec leur auteur. La mention actuelle « Source : wikipedia » ne suffit pas pour la CC BY-SA.
- [x] Renommer ce qui dit encore « BirdNET Live » : texte de partage d'une détection, nom des fichiers
      exportés (`BirdNET_Live_…`), champ creator des exports GPX et JSON, rapport HTML. Adapter les
      tests upstream concernés.
- [x] Première version sans localisation en arrière-plan : `ACCESS_BACKGROUND_LOCATION` retirée du
      manifeste, plus aucune demande de « Toujours autoriser » (Relevé : `survey_setup_screen.dart`,
      `// FORK`). Live et Relevé gardent la position écran éteint via le service de premier plan
      `microphone|location` + « pendant l'utilisation ». Test : `test/fork/release/location_permission_test.dart`.
      Impact Relevé : plus de mode « arrière-plan » séparé, le suivi continu dépend du service de premier plan.
      - [ ] (Benjamin) sur le Xiaomi : marche de 10 minutes écran éteint en écoute, la trace GPS de la
            session doit couvrir toute la marche (sinon HyperOS bride le service : revoir).
- [x] Public cible 13 ans et plus, sans programme Familles (`fork/release/README.md`, politique de
      confidentialité).
- [x] Tuiles IGN : la carte des contacts était déjà soumise à l'interrupteur « cartes en ligne »
      (`privacyAllowMapProvider`, désactivé par défaut) ; la mini-carte de la fiche espèce chargeait ses
      tuiles sans ce contrôle, corrigé (`speciesMiniMapTilesProvider`) avec test.
- [ ] Quelques semaines d'usage réel avant de passer à iOS.

Fini quand : la build de test interne s'installe depuis le Play Store et tient une matinée d'écoute
écran éteint sur le Xiaomi.

## Garder le fork à jour avec BirdNET

Une fois par mois, sur le PC :
```
git remote add upstream https://github.com/birdnet-team/birdnet-live-app.git   (la première fois seulement)
git fetch upstream
git checkout -b sync-AAAA-MM
git merge upstream/main
git lfs pull
```
Sans conflit : push et PR. Avec des conflits : `git add -A`, commit « merge upstream, conflits à
résoudre », push, puis une session cloud sur cette branche :
```
Cette branche contient une fusion avec upstream dont les conflits sont encore marqués. Résous-les en gardant nos ajouts marqués FORK et le code de lib/fork, et la version upstream pour le reste. Lance analyze et les tests, puis résume ce qui a changé côté BirdNET.
```

## Idées pour plus tard

- Activité de chant selon la météo (upstream a déjà un service météo).
- Widget « dernier oiseau entendu ».
- Audit des couleurs (skills `design:accessibility-review` et `design:design-system`) : contraste
  mesuré de toutes les paires de `BirdyColors` en clair et en sombre (au-delà de
  `test/fork/design/contrast_test.dart`), couleurs en dur (`Color(0x…)`, `Colors.*`) dans
  `lib/fork/`, puis propositions de teintes avec avant/après et ratio. Rapport d'abord, aucune
  modification sans choix de Benjamin.
- Export au format eBird (CSV étendu), l'import eBird étant ouvert à tous.

## Phase iOS (après validation d'Android)

Même code Flutter, BirdNET Live tourne déjà sur iOS. À faire à ce moment-là :
- iOS sans Mac : Codemagic (500 minutes de build macOS gratuites par mois pour un compte personnel),
  fichier `codemagic.yaml`, compte Apple Developer (99 $ par an), TestFlight.
- Réécoute pendant l'écoute : session audio playAndRecord avec defaultToSpeaker et Bluetooth, sinon
  le son sort par l'écouteur.
- Reprendre la liste des points iOS notés pendant les jalons Android.
- Notification de nouvelle espèce (J6h) : `NotificationsGateway` demande déjà l'autorisation iOS (`requestPermissions`) ; sans `UIBackgroundModes: audio` (ci-dessous) l'écoute s'arrête en arrière-plan, donc pas de notification. À tester.
- Photo dans la notification (J6h) : Android utilise `largeIcon` + `BigPictureStyleInformation` (octets PNG, `lib/fork/notifications/notification_images.dart`). Côté iOS : écrire le PNG dans le dossier temporaire et le joindre via `DarwinNotificationDetails(attachments: [DarwinNotificationAttachment(path)])`.
- Localisation écran éteint (J7) : Android n'utilise plus `ACCESS_BACKGROUND_LOCATION`. Côté iOS il
  faudra `UIBackgroundModes: location` (avec `allowBackgroundLocationUpdates`, déjà prévu par
  `buildLocationSettings(background: true)`) et la permission « Toujours » si le suivi doit continuer
  hors de l'app ; les textes `NSLocation*UsageDescription` sont à revoir.
- Écoute écran éteint (J2b) : `live_background.dart` ne fait rien sur iOS. Il faudra le mode
  `UIBackgroundModes: audio` dans `Info.plist` et une session audio active pendant l'écoute.
- Identifiants (J0) : bundle id `fr.justcodeit.birdygo` et App Group `group.fr.justcodeit.birdygo`
  posés dans le projet, jamais compilés. Créer l'App ID et l'App Group sur le portail Apple, renseigner
  l'équipe (DEVELOPMENT_TEAM). L'App Group ne sert qu'à une ancienne extension de partage upstream : on
  peut aussi le retirer de `Runner.entitlements` et d'`AppDelegate.swift`.
- Envoi à la LPO (J5b) : aucun code natif ; NaturaList s'ouvre par sa page App Store
  (`LpoConfig.naturaListAppStore`, choisie selon la plateforme), à vérifier ; partage de l'extrait par
  share_plus (ancrage iPad déjà géré par `shareOriginFrom`).
- Carte (J5) : aucun code natif ajouté ; « Me localiser » passe par le LocationService existant
  (geolocator), vérifier le texte d'autorisation de localisation dans `Info.plist`.
- Accueil (J6c) : aucun code natif ; logo dessiné en Flutter.
- Écouter un enregistrement (J5c) : aucun code natif ; même écran d'écoute avec le filtre sur « off »
  et sans géomodèle.
- Fiche espèce (J6c) : aucun code natif ; partage par share_plus (ancrage iPad par
  `shareOriginFrom`), liens externes par url_launcher, réécoute par just_audio comme le Live.
- Bilan de l'écoute (J6c) : aucun code natif ; partage du texte par share_plus (ancrage iPad par
  `shareOriginFrom`).
- Photos (J6b) : aucun code natif. Grandes photos par `http`, cache dans le dossier cache de l'app
  (`getApplicationCacheDirectory`, non sauvegardé sur iCloud), en HTTPS : rien à régler dans ATS.
- Design system (J6a) : aucun code natif. Polices embarquées en assets Flutter, vibration légère via
  `HapticFeedback` (sur iPhone, vérifier qu'elle se sent sans être trop forte).
- Live, corrections (J6c-bis-a) : aucun code natif. Mesures p50/p95 à refaire sur iPhone en
  `--profile` (le temps d'analyse ONNX y sera différent).
- Live, « Analyse… » et fin rapide (J6c-bis-b) : aucun code natif. Vérifier qu'une réécoute par le
  haut-parleur de l'iPhone n'allume ni « Analyse… » ni le symbole « chante ».
- Position GPS pendant l'écoute (J6c) : `GeolocatorLivePositionSource` marche au premier plan.
  `UIBackgroundModes` contient déjà `location` et `audio` (upstream, pour le Survey). Écran éteint,
  vérifier que le flux continue avec `buildLocationSettings(background: true)` (indicateur bleu) et
  l'autorisation « Pendant l'utilisation », sans demander « Toujours ». Localisation approximative d'iOS :
  même comportement (points écartés, position de la session gardée).

- Startup screen (J6c): Flutter composition is shared. Native iOS launch assets remain
  unchanged; during the iOS phase make `LaunchScreen.storyboard` a plain Mist (#EEF1EC) view
  with no mark, as on Android, so the Flutter splash fades the bird in without a jump, and check
  cold-launch timing.
- Quiz « Qui chante ? » (J6e) : aucun code natif. Bruitages en WAV lus par just_audio avec un
  lecteur à part : sur iPhone, vérifier qu'ils ne coupent pas une musique en cours (session audio
  « ambient » ou mixage) et que le mode silencieux est respecté.
- Volume média (J6h) : `AVAudioSession.outputVolume` en lecture seule ; iOS ne permet pas de régler
  le volume (`MPVolumeView` seulement) → bouton qui ouvre le curseur système. En attendant,
  `NoopMediaVolume` ne montre aucune alerte.
- Icône d'appli par oiseau (J6i) : `AppIcon` (`lib/fork/app_icon/`) est un no-op hors Android
  (`NoopAppIcon`). Côté iOS : `UIApplication.setAlternateIconName` depuis un canal Swift (même canal
  `fr.justcodeit.birdygo/app_icon`, méthode `setIcon(bird)`), déclarer `CFBundleIcons` >
  `CFBundleAlternateIcons` dans `Info.plist` (une entrée par oiseau : `martin`, `flamant`,
  `etourneau`, Loriot = icône principale) et ajouter les images par thème (60x60 @2x/@3x, hors
  catalogue d'assets, ou ensemble « Alternate App Icons » de Xcode). iOS affiche une alerte système
  au changement : pas de report à l'arrière-plan. Le rendu des PNG existe déjà
  (`test/fork/tool/render_launcher_icons_test.dart`, à étendre aux tailles iOS).
- Modes d'écoute (J6f) : Dart pur, aucun code natif. Gain, filtre passe-haut et réducteur du mode
  Ville agissent sur les échantillons après le micro, comme sur Android. Seuls des essais sur le
  terrain restent à faire (le micro de l'iPhone et son traitement de la voix n'ont pas le même
  bruit de fond), dont le coût du mode Ville en `--profile`.
