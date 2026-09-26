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
      graphique 48 semaines existant (géomodèle, jamais l'IA). Sans fiche, ou si les noms d'espèces ne
      sont pas en français, la description existante reste. Titres et pied de fiche (« Fiche rédigée
      par IA : elle peut contenir des erreurs. ») en français et en anglais.
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

## J6 : refonte visuelle (voir fork/DESIGN.md)

Objectif : l'app la plus belle, la plus fluide et la plus utile de sa catégorie. Assez simple pour
qu'un enfant s'en serve, colorée grâce aux oiseaux, et qui donne envie d'y revenir. Maquette de
référence : le canevas « BirdyGo – Interface » sur claude.ai
(https://claude.ai/artifact/C6XUNf7AKdf1YUZzRr1K3j, privé), exporté dans `fork/maquette/` pour que
les sessions cloud puissent le lire ; à suivre et à corriger au fil des sessions.

- [x] J6a Design system : thèmes clair et sombre, polices embarquées, composants (carte espèce, puce
      de niveau, compteur, lecteur de clip, boutons), jetons d'animation. Opus pour le concevoir,
      Sonnet ensuite.
- [ ] J6b Photos : `tools/fork_region_species.py` (créé en J4b) donne la liste des espèces de la
      région. Ajouter à `tools/build_species_bundle.py` une option pour ne traiter que cette liste, à
      lancer sur le PC (birdnet.cornell.edu n'est pas joignable depuis le cloud). En ligne, photos plus
      grandes via iNaturalist (inat_id), mises en cache. Crédit et licence accessibles d'un appui.
- [ ] J6c Écrans, un par session : Accueil, Live (spectrogramme agrandi ou réduit, tableau en direct
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
- [ ] J6e Jeu : statuts selon le nombre d'espèces découvertes, badges, série de jours, défis de la
      semaine, carnet façon collection (silhouettes mystère pour les espèces attendues ici en cette
      saison, grâce au géomodèle), célébrations graduées (arrivée, première fois, oiseau rare, nouveau
      statut). Règles : seules les détections Sûr ou confirmées font progresser ; un oiseau rare se
      vérifie avant la fête ; ni notification culpabilisante ni série perdue pour un jour manqué.

Fini quand, mesuré en mode profile sur le Xiaomi :
- 60 images par seconde partout, 120 quand l'écran le permet, aucune image perdue au défilement ;
- l'écoute démarre moins d'une seconde après l'appui sur « Écouter » (le nouvel accueil garde le
  préchargement d'upstream, `_warmUpApp` dans `lib/features/home/home_screen.dart`) ;
- une espèce apparaît dans le tableau moins d'une seconde après la fin de l'analyse de son extrait ;
- thèmes clair et sombre, animations réduites respectées, texte agrandi à 130 % lisible ;
- le jeu ne récompense que les détections Sûr ou confirmées.

## J7 : publication Android

- [ ] Signature de l'app (clé d'upload), build `appbundle` en release.
- [ ] Piste de test interne sur le Play Store, fiche en français, politique de confidentialité adaptée
      de celle d'upstream.
- [ ] Avant de publier : retirer du pack les photos marquées « © Macaulay Library » (droits réservés),
      garder CC0, CC BY et CC BY-SA, et CC BY-NC seulement si l'app reste gratuite.
- [ ] Page « Licences des contenus » dans À propos : licence de chaque photo (colonne `image_license`
      de `taxonomy.csv`, à afficher aussi dans le crédit), textes Wikipédia et fiches IA sous CC BY-SA
      avec lien, icônes d'espèces tirées d'une base CC BY (J6d) avec leur auteur. La mention actuelle « Source : wikipedia » ne suffit pas pour la CC BY-SA.
- [ ] Renommer ce qui dit encore « BirdNET Live » : texte de partage d'une détection, nom des fichiers
      exportés (`BirdNET_Live_…`), champ creator des exports GPX et JSON, rapport HTML. Adapter les
      tests upstream concernés.
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
- Export au format eBird (CSV étendu), l'import eBird étant ouvert à tous.

## Phase iOS (après validation d'Android)

Même code Flutter, BirdNET Live tourne déjà sur iOS. À faire à ce moment-là :
- iOS sans Mac : Codemagic (500 minutes de build macOS gratuites par mois pour un compte personnel),
  fichier `codemagic.yaml`, compte Apple Developer (99 $ par an), TestFlight.
- Réécoute pendant l'écoute : session audio playAndRecord avec defaultToSpeaker et Bluetooth, sinon
  le son sort par l'écouteur.
- Reprendre la liste des points iOS notés pendant les jalons Android.
- Identifiants (J0) : bundle id `fr.justcodeit.birdygo` et App Group `group.fr.justcodeit.birdygo`
  posés dans le projet, jamais compilés. Créer l'App ID et l'App Group sur le portail Apple, renseigner
  l'équipe (DEVELOPMENT_TEAM). L'App Group ne sert qu'à une ancienne extension de partage upstream : on
  peut aussi le retirer de `Runner.entitlements` et d'`AppDelegate.swift`.
- Envoi à la LPO (J5b) : aucun code natif ; NaturaList s'ouvre par sa page App Store
  (`LpoConfig.naturaListAppStore`, choisie selon la plateforme), à vérifier ; partage de l'extrait par
  share_plus (ancrage iPad déjà géré par `shareOriginFrom`).
- Carte (J5) : aucun code natif ajouté ; « Me localiser » passe par le LocationService existant
  (geolocator), vérifier le texte d'autorisation de localisation dans `Info.plist`.
- Bilan de l'écoute (J6c) : aucun code natif ; partage du texte par share_plus (ancrage iPad par
  `shareOriginFrom`).
- Design system (J6a) : aucun code natif. Polices embarquées en assets Flutter, vibration légère via
  `HapticFeedback` (sur iPhone, vérifier qu'elle se sent sans être trop forte).
