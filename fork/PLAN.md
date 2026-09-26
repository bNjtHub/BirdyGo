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
| Connaître l'oiseau | description Wikipédia, courbe de présence sur 48 semaines, liens eBird, iNaturalist, Wikipédia | fiche rédigée par IA à l'avance, vérifiée et relue, hors ligne (J4b) |
| Recensement LPO | exports CSV, GPX, Raven, JSON | envoi guidé des observations confirmées vers Faune-France, mode Oiseaux des jardins (J5b) |
| Belle interface | Material 3, photos 480×320 | refonte complète avec photos, icônes d'espèces et animations (J6, voir DESIGN.md) |
| Jeu | alerte première espèce | statuts, badges, défis, carnet façon collection, célébrations (J6e) |
| Station fixe, alertes, exports | mode ARU, alerte première espèce, exports CSV, GPX, Raven, JSON, annonces vocales, widget | rien à faire |

## Étape 0 : préparation (sans crédit, une soirée)

- [ ] Installer BirdNET Live depuis le Play Store, faire une ou deux sorties, noter ce qui gêne vraiment.
- [x] Sur GitHub, forker birdnet-team/birdnet-live-app vers Bnjthub (tu peux renommer le dépôt en
      `BirdyGo`). Un fork est public. Pour un dépôt privé, il faut le dupliquer au lieu de le forker.
- [ ] Sur le PC : installer Flutter (canal stable), Android Studio (pour le SDK Android) et Git LFS, puis :
  ```
  git clone https://github.com/Bnjthub/BirdyGo.git
  cd BirdyGo
  git lfs install
  git lfs pull
  flutter pub get
  flutter gen-l10n
  flutter run
  ```
  Si `git lfs pull` échoue sur le fork, prendre les modèles dans le dépôt officiel :
  `git config lfs.url https://github.com/birdnet-team/birdnet-live-app.git/info/lfs` puis `git lfs pull`.
  L'app d'origine doit tourner sur le téléphone avant de commencer quoi que ce soit.
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

- [ ] Nom affiché « BirdyGo », applicationId Android `fr.justcodeit.birdygo`, pour que l'app s'installe
      à côté de BirdNET Live. Mettre aussi le bundle id iOS au même nom, sans rien tester côté iOS.
- [ ] Icône provisoire simple, refaite en J6.
- [ ] Écran À propos : « Propulsé par BirdNET » avec le lien vers le dépôt d'origine. Garder LICENSE,
      MODEL_LICENSE et ACCEPTABLE_USE.md, ajouter un fichier NOTICE qui dit que c'est une version modifiée.
- [ ] Ne pas mettre le nom BirdNET dans le nom de l'app.
- [ ] Désactiver `release.yml` et `docs.yml` dans `.github/workflows`, garder `ci.yml`.

Fini quand : analyze et tests passent, l'app s'installe sur le Xiaomi à côté de BirdNET Live.

Prompt J0 :
```
Lis CLAUDE.md et la section J0 de fork/PLAN.md. Mode plan : liste les fichiers à modifier pour le renommage, l'écran À propos et les workflows. Attends ma validation, puis applique, lance flutter analyze et flutter test, et ouvre une PR.
```

## J1 : index des observations

But : compter, classer et cartographier toutes les détections de toutes les sessions sans relire
tous les JSON à chaque écran. C'est la fondation de J2 à J5.

- [ ] `lib/fork/data/observation_index.dart` : base SQLite (sqflite, et sqflite_common_ffi pour les
      tests) avec une table des sessions et une table des détections : id, session, espèce, début, fin,
      score, statut de revue, latitude, longitude, chemin du clip, favori.
- [ ] Mise à jour de l'index à chaque sauvegarde, modification ou suppression de session, avec des
      points d'accroche minimaux dans SessionRepository, marqués FORK.
- [ ] Remplissage initial en arrière-plan au premier lancement, sur le modèle de GlobalSpeciesHistory.
      Bouton « Reconstruire l'index » dans les réglages.
- [ ] Requêtes prêtes pour la suite : palmarès par période, points pour la carte, clips d'une espèce,
      activité par heure et par mois, file des détections à revoir.
- [ ] Tests avec des sessions JSON d'exemple dans `test/fork/fixtures/`.

Fini quand : les tests passent, et sur le téléphone l'index se remplit sans figer l'interface.

## J2 : réécouter pendant l'écoute, et la sonothèque

- [ ] En mode Live, un bouton lecture sur chaque détection joue son clip sans arrêter l'écoute.
      Un deuxième appui arrête. Toucher le reste de la ligne ouvre toujours la fiche espèce.
- [ ] Pendant la lecture, plus 0,5 s, l'inférence est suspendue pour que le modèle ne détecte pas le
      haut-parleur. L'enregistrement continue. Le changement se fait dans le planificateur d'inférence
      commun aux modes Live, Point Count et Survey, avec le moins de lignes possible.
- [ ] Si le clip est encore en cours d'écriture, le bouton l'indique et s'active dès qu'il est prêt.
- [ ] Android : vérifier la lecture pendant l'enregistrement, haut-parleur et casque Bluetooth.
- [ ] Écran Sonothèque : liste des espèces, puis tous leurs clips triés par score ou par date, avec
      lecture, mini spectrogramme, date et lieu. Étoile pour garder ses meilleurs enregistrements,
      filtre « favoris seulement ».
- [ ] Rien n'est supprimé automatiquement.
- [ ] La réécoute sert à vérifier, jamais à attirer les oiseaux (la LPO déconseille la repasse) :
      volume modéré par défaut, et l'app le dit une fois, simplement.

Fini quand : rejouer un rougegorge pendant une écoute ne crée aucune nouvelle détection.

## J3 : savoir quand l'app se trompe

- [ ] Trois niveaux affichés partout (Live, revue de session, sonothèque, palmarès) : Sûr, Probable,
      À vérifier. Calculés à partir du score et du niveau d'abondance du géomodèle pour le lieu et la
      semaine. Seuils de départ dans `lib/fork/reliability/reliability_config.dart` : Sûr à partir de
      0,80 si l'espèce est plausible ici, Probable de 0,55 à 0,80, À vérifier en dessous ou si
      l'espèce est rare ici à cette saison.
- [ ] Badge « Inattendu ici » quand le géomodèle juge l'espèce rare ou absente pour ce lieu et cette semaine.
- [ ] Réutiliser ce qui existe au lieu de recalculer : `GeoModel.predict` (lib/features/inference/geo_model.dart),
      `geoCommonnessProvider` et son indicateur hors saison, `ExploreTierScale`
      (lib/features/explore/geo_abundance.dart), `AlertReason.rare` des alertes Survey.
- [ ] Ces niveaux alimentent le jeu (J6e) et l'envoi à la LPO (J5b) : seules les détections Sûr ou
      confirmées font progresser, et seules les confirmées peuvent partir.
- [ ] Revue rapide : une pile de cartes des détections à vérifier, avec photo, clip joué
      automatiquement et spectrogramme. À droite « C'est bien lui », à gauche « Ce n'est pas lui »,
      vers le haut « Je ne sais pas ». Utilise les champs de revue existants et met l'index à jour.
- [ ] Précision mesurée : pour chaque niveau, et pour chaque espèce revue au moins 5 fois, la part de
      détections confirmées. Visible dans la fiche espèce (« 11 bonnes sur 12 vérifiées ») et dans un
      écran Fiabilité.
- [ ] Après quelques semaines de revues, ajuster les seuils avec ces chiffres.

Fini quand : les niveaux sont cohérents d'un écran à l'autre et chaque balayage est bien enregistré.

## J4 : palmarès

- [ ] Classement des espèces par nombre de contacts, par nombre de jours ou par dernière écoute.
      Périodes : 30 jours, saison, année, tout. Option « confirmées seulement ».
- [ ] En tête : nombre d'espèces sur la période et nouvelles de l'année.
- [ ] Fiche espèce : une phrase plutôt qu'un tableau (« Entendu 23 fois sur 9 jours, la dernière fois
      hier à 7 h 42 »), activité par heure (24 barres) et par mois (12 barres) dessinées avec
      CustomPainter, sans nouvelle dépendance.
- [ ] Filtre « oiseaux seulement » : le modèle reconnaît aussi des amphibiens, des insectes et des mammifères.

Fini quand : les compteurs d'une espèce correspondent à un export CSV sur un échantillon.

## J4b : fiches espèces rédigées par IA

But : pour chaque oiseau de France, une fiche claire en français : taille, ce qu'il fait, pourquoi il
est là, migration, comment le reconnaître à l'oreille, confusions possibles, une anecdote. Les fiches
sont écrites une fois, vérifiées, relues et embarquées : hors ligne, sans coût à l'usage, sans clé
d'API dans l'app.

- [ ] Liste des espèces de la région : `tools/fork_region_species.py` (avancé de J6b), géomodèle sur
      une grille France et Europe de l'Ouest × 48 semaines, seuil de `model_config.json`. Oiseaux
      seulement, environ 300 à 450 espèces. À lancer sur le PC : les modèles LFS ne sont pas dans le cloud.
- [ ] `tools/fork_species_sheets.py`, avec sa propre dépendance (`anthropic`) dans
      `tools/requirements-fork-sheets.txt`. Collecte des sources par espèce : article Wikipédia FR
      (numéro de révision noté), Wikidata pour la taille, l'envergure, la masse et le statut UICN,
      description déjà embarquée, statut saisonnier calculé par le géomodèle. Génération par la
      Message Batches API avec une sortie JSON structurée et, pour chaque affirmation, la phrase exacte
      de la source. Consigne : laisser vide plutôt qu'inventer.
- [ ] Vérification automatique : chaque citation existe dans la source (sinon la section est vidée),
      tailles cohérentes avec Wikidata, statut migratoire cohérent avec le géomodèle, noms français
      identiques à `taxonomy.csv`. Puis un second passage, avec un modèle moins cher, qui liste les
      affirmations non couvertes par les sources.
- [ ] Relecture par Benjamin sur une page HTML locale : les 100 espèces les plus entendues, toutes les
      fiches signalées, et 10 % des autres au hasard. Commencer par un pilote de 20 espèces.
- [ ] Fiches relues versionnées dans `tools/fork_sheets/fr.jsonl` (une ligne par espèce), livrées dans
      `assets/fork/species_sheets_fr.json.gz` (environ 0,5 Mo) sans les citations.
- [ ] Licence : les fiches dérivent de Wikipédia, donc le fichier de données est sous CC BY-SA 4.0 ; le
      code reste MIT. Pied de fiche : « Texte rédigé par IA à partir de l'article Wikipédia « X »,
      modifié, CC BY-SA 4.0 », avec le lien vers la révision. Ne jamais donner au modèle des textes de
      la LPO, d'oiseaux.net ou d'eBird (droits réservés).
- [ ] Écran : la fiche prend la place du bloc description de `SpeciesInfoOverlay`
      (lib/features/explore/widgets/species_info_overlay.dart), code dans `lib/fork/species_sheet/`.
      « Ici en ce moment » est calculé en direct par le géomodèle (courbe sur 48 semaines,
      `geoCommonnessProvider`), jamais par l'IA. Sans fiche, on garde la description Wikipédia existante.
- Coût, à part du crédit Claude Code : environ 40 à 70 $ d'API Anthropic pour 350 à 600 espèces, sur
  un compte de la console Anthropic. Choisir le modèle au moment du pilote, avec les tarifs du jour.

Fini quand : les 100 espèces les plus entendues ont une fiche relue et l'app les affiche hors ligne.

## J5 : carte de tous les contacts

- [ ] Carte plein écran avec flutter_map, déjà utilisé. Aux petits zooms, grille d'hexagones dont la
      couleur suit le nombre de contacts. Aux grands zooms, les icônes rondes des oiseaux, regroupées
      avec flutter_map_marker_cluster, déjà présent. Réutiliser `_SpeciesMarker` et
      `SurveyMapClusterBubble` de `lib/features/survey/widgets/survey_map_widget.dart`, qui dessinent
      déjà des marqueurs ronds avec la photo de l'espèce en mode Survey : les rendre publics par une
      modification minimale marquée FORK, ou les recopier dans `lib/fork/map/` si l'extraction touche
      trop de lignes. Plus tard, les icônes SVG de J6d.
- [ ] Filtres : espèce (recherche), période, confirmées seulement. Appui sur un hexagone : feuille avec
      les espèces de la zone, leurs compteurs et leurs clips.
- [ ] Fonds de carte : OSM avec les réglages partagés, plus Plan IGN et photos aériennes IGN
      (Géoplateforme). Vérifier les URL WMTS actuelles et la mention de source obligatoire.
- [ ] Dans les exports, option pour flouter la position des espèces sensibles, dans l'esprit
      d'ACCEPTABLE_USE.md.

Fini quand : 10 000 points se déplacent et zooment sans saccade sur le téléphone.

## J5b : envoyer ses observations à la LPO

Constat (recherche de septembre 2026) : Faune-France n'offre pas d'accès ouvert aux applis tierces.
L'API VisioNature demande une clé délivrée par Biolovision et des droits fixés par les portails, et
seule NaturaList y écrit. La LPO demande de ne saisir que des observations dont l'observateur est sûr,
et pas de listes construites par une appli d'identification (LPO Île-de-France, 2026). L'envoi est
donc guidé, jamais automatique.

- [ ] Écran « Envoyer à la LPO » réservé aux détections confirmées. La confirmation demande « Tu l'as
      vu ? » et « Tu connais ce chant ? », avec un lien vers xeno-canto pour comparer.
- [ ] Pour chaque observation, une fiche prête à reporter : nom français et latin, date, heure,
      position GPS et précision, nombre, entendu ou vu, remarque « Contact auditif ; identification
      assistée par IA puis confirmée par l'observateur ». Code atlas proposé seulement pendant la
      période de nidification de l'espèce. Boutons copier, partager le clip, ouvrir NaturaList ou
      faune-france.org (aucun pré-remplissage n'est documenté).
- [ ] Alertes avant l'envoi : espèce sensible (proposer de masquer la donnée), espèce rare ou hors saison.
- [ ] Mode « Oiseaux des jardins » (LPO et MNHN) : minuteur (1 h les deux week-ends nationaux, les
      derniers week-ends complets de janvier et de mai ; durée libre le reste de l'année), compteur du
      nombre maximum vu en même temps pour chaque espèce, saisi à la main. Les détections sonores
      servent seulement d'invitation à regarder : le protocole compte les oiseaux vus posés. À la fin,
      un résumé à reporter sur oiseauxdesjardins.fr.
- [ ] Plus tard, en option : export Excel ou CSV des observations confirmées. L'import sur Faune-France
      demande un droit d'import donné par le portail : vérifier le modèle de colonnes avec le
      coordinateur local.
- [ ] Plus tard : écrire à l'équipe Faune-France et à Biolovision pour un partenariat, une fois l'app
      utilisée. Ne jamais aspirer ni imiter NaturaList, ne jamais demander le mot de passe Faune-France.

Fini quand : une observation confirmée se reporte dans NaturaList en moins d'une minute, et aucune
détection non confirmée ne peut partir.

## J6 : refonte visuelle (voir fork/DESIGN.md)

Objectif : l'app la plus belle, la plus fluide et la plus utile de sa catégorie. Simple au point
qu'un enfant s'en serve, colorée grâce aux oiseaux, et qui donne envie d'y revenir. Maquette de
référence : le canevas « BirdyGo – Interface » (claude.ai), à suivre et à corriger au fil des sessions.

- [ ] J6a Design system : thèmes clair et sombre, polices embarquées, composants (carte espèce, puce
      de niveau, compteur, lecteur de clip, boutons), jetons d'animation. Opus pour le concevoir,
      Sonnet ensuite.
- [ ] J6b Photos : `tools/fork_region_species.py` (créé en J4b) donne la liste des espèces de la
      région. Ajouter à `tools/build_species_bundle.py` une option pour ne traiter que cette liste, à
      lancer sur le PC (birdnet.cornell.edu n'est pas joignable depuis le cloud). En ligne, photos plus
      grandes via iNaturalist (inat_id), mises en cache. Crédit et licence accessibles d'un appui.
- [ ] J6c Écrans, un par session : Accueil, Live (spectre agrandi ou réduit, tableau en direct avec
      compteurs de session et totaux), Fin de sortie, Fiche espèce, Carnet, Profil, Palmarès, Carte,
      Sonothèque, Revue rapide, Envoi à la LPO.
- [ ] J6d Icônes d'espèces en SVG : une famille d'une quinzaine de silhouettes dans le style du logo,
      avec les couleurs et les marques de chaque espèce, pour la carte, le tableau en direct et le
      carnet. Générées par script pour les espèces de la région, silhouette de famille pour les
      autres, relues sur planches. Une base existante n'est réutilisée que si sa licence le permet
      (CC0 ou CC BY, jamais NC) ; sinon, on dessine la famille nous-mêmes. La photo reste sur la fiche.
- [ ] J6e Jeu : statuts selon le nombre d'espèces découvertes, badges, série de jours, défis de la
      semaine, carnet façon collection (silhouettes mystère pour les espèces attendues ici en cette
      saison, grâce au géomodèle), célébrations graduées (arrivée, première fois, oiseau rare, nouveau
      statut). Règles : seules les détections Sûr ou confirmées font progresser ; un oiseau rare se
      vérifie avant la fête ; ni notification culpabilisante ni série perdue pour un jour manqué.

Fini quand, mesuré en mode profile sur le Xiaomi :
- 60 images par seconde partout, 120 quand l'écran le permet, aucune image perdue au défilement ;
- l'écoute démarre moins d'une seconde après l'appui sur « Écouter » ;
- une espèce apparaît dans le tableau moins d'une seconde après la fin de l'analyse de son extrait ;
- thèmes clair et sombre, animations réduites respectées, texte agrandi à 130 % lisible ;
- le jeu ne récompense aucune détection non vérifiée.

## J7 : publication Android

- [ ] Signature de l'app (clé d'upload), build `appbundle` en release.
- [ ] Piste de test interne sur le Play Store, fiche en français, politique de confidentialité adaptée
      de celle d'upstream.
- [ ] Avant de publier : retirer du pack les photos marquées « © Macaulay Library » (droits réservés),
      garder CC0, CC BY et CC BY-SA, et CC BY-NC seulement si l'app reste gratuite.
- [ ] Page « Licences des contenus » dans À propos : licence de chaque photo (colonne `image_license`
      de `taxonomy.csv`, à afficher aussi dans le crédit), textes Wikipédia et fiches IA sous CC BY-SA
      avec lien. La mention actuelle « Source : wikipedia » ne suffit pas pour la CC BY-SA.
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
