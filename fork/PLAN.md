# Plan de développement de Ramage

Base : BirdNET Live (github.com/birdnet-team/birdnet-live-app), l'app officielle de l'équipe BirdNET
(Cornell Lab et TU Chemnitz). On ne refait pas ce qui existe : on ajoute ce qui manque et on refait
l'habillage.

Ordre : Android d'abord, jusqu'à une version validée sur le Play Store. iOS ensuite, avec le même code
Flutter (section « Phase iOS » en bas de ce fichier).

## Ce qui existe déjà, ce qu'on ajoute

| Besoin | Déjà dans BirdNET Live | Ajouté par Ramage |
|---|---|---|
| Savoir si l'app se trompe | score, seuil réglable, filtre géographique (3 modes), lissage temporel, confirmation manuelle | niveaux Sûr, Probable, À vérifier, alerte « inattendu ici », revue rapide par balayage, précision mesurée sur tes revues (J3) |
| Retrouver et réécouter les sons | bibliothèque de sessions, lecteur de clips, spectrogramme | réécoute pendant l'écoute, sonothèque par espèce avec favoris (J2) |
| Classement | liste des espèces déjà entendues, sans compteur | palmarès : contacts, jours, première et dernière écoute, activité par heure et par mois (J4) |
| Positions GPS | position de chaque détection, trace GPS en mode Survey, carte d'une session | index global des positions (J1) |
| Carte | carte d'une session | carte de toutes les sessions, hexagones selon le nombre de contacts, filtres (J5) |
| Belle interface | Material 3, photos 480×320 | refonte complète avec photos et animations (J6, voir DESIGN.md) |
| Station fixe, alertes, exports | mode ARU, alerte première espèce, exports CSV, GPX, Raven, JSON, annonces vocales, widget | rien à faire |

## Étape 0 : préparation (sans crédit, une soirée)

- [ ] Installer BirdNET Live depuis le Play Store, faire une ou deux sorties, noter ce qui gêne vraiment.
- [ ] Sur GitHub, forker birdnet-team/birdnet-live-app vers Bnjthub (tu peux renommer le dépôt en
      `ramage`). Un fork est public. Pour un dépôt privé, il faut le dupliquer au lieu de le forker.
- [ ] Sur le PC : installer Flutter (canal stable), Android Studio (pour le SDK Android) et Git LFS, puis :
  ```
  git clone https://github.com/Bnjthub/ramage.git
  cd ramage
  git lfs install
  git lfs pull
  flutter pub get
  flutter gen-l10n
  flutter run
  ```
  Si `git lfs pull` échoue sur le fork, prendre les modèles dans le dépôt officiel :
  `git config lfs.url https://github.com/birdnet-team/birdnet-live-app.git/info/lfs` puis `git lfs pull`.
  L'app d'origine doit tourner sur le téléphone avant de commencer quoi que ce soit.
- [ ] Dézipper le kit à la racine du dépôt (`CLAUDE.md`, `fork/`, `.claude/`), commit, push.
- [ ] Sur claude.ai/code : connecter GitHub, créer un environnement cloud « Flutter » avec l'accès
      réseau Trusted, coller le contenu de `fork/cloud-setup.sh` dans le champ Setup script, et
      ajouter la variable d'environnement `GIT_LFS_SKIP_SMUDGE=1`.
- [ ] Première session : vérifier que `flutter --version`, `flutter analyze` et `flutter test` passent.
      Si Flutter manque, corriger le setup script avant d'aller plus loin.

## Budget indicatif (250 $)

| Jalon | Modèle | Ordre de grandeur |
|---|---|---|
| J0 Renommage | Sonnet | 10 $ |
| J1 Index des observations | Sonnet | 25 $ |
| J2 Réécoute et sonothèque | Sonnet | 30 $ |
| J3 Fiabilité | Opus pour le plan, Sonnet pour le code | 30 $ |
| J4 Palmarès | Sonnet | 20 $ |
| J5 Carte | Sonnet | 25 $ |
| J6 Refonte visuelle | Opus pour le design system, Sonnet ensuite | 60 $ |
| J7 Publication Android | Sonnet | 10 $ |
| Réserve pour les bugs | | 40 $ |

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

- [ ] Nom affiché « Ramage », applicationId Android `fr.justcodeit.ramage`, pour que l'app s'installe
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

Fini quand : rejouer un rougegorge pendant une écoute ne crée aucune nouvelle détection.

## J3 : savoir quand l'app se trompe

- [ ] Trois niveaux affichés partout (Live, revue de session, sonothèque, palmarès) : Sûr, Probable,
      À vérifier. Calculés à partir du score et du niveau d'abondance du géomodèle pour le lieu et la
      semaine. Seuils de départ dans `lib/fork/reliability/reliability_config.dart` : Sûr à partir de
      0,80 si l'espèce est plausible ici, Probable de 0,55 à 0,80, À vérifier en dessous ou si
      l'espèce est rare ici à cette saison.
- [ ] Badge « Inattendu ici » quand le géomodèle juge l'espèce rare ou absente pour ce lieu et cette semaine.
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

## J5 : carte de tous les contacts

- [ ] Carte plein écran avec flutter_map, déjà utilisé. Aux petits zooms, grille d'hexagones dont la
      couleur suit le nombre de contacts. Aux grands zooms, points regroupés avec
      flutter_map_marker_cluster, déjà présent.
- [ ] Filtres : espèce (recherche), période, confirmées seulement. Appui sur un hexagone : feuille avec
      les espèces de la zone, leurs compteurs et leurs clips.
- [ ] Fonds de carte : OSM avec les réglages partagés, plus Plan IGN et photos aériennes IGN
      (Géoplateforme). Vérifier les URL WMTS actuelles et la mention de source obligatoire.
- [ ] Dans les exports, option pour flouter la position des espèces sensibles, dans l'esprit
      d'ACCEPTABLE_USE.md.

Fini quand : 10 000 points se déplacent et zooment sans saccade sur le téléphone.

## J6 : refonte visuelle (voir fork/DESIGN.md)

- [ ] J6a Design system : thèmes clair et sombre, polices embarquées, composants (carte espèce, puce
      de niveau, lecteur de clip, boutons), jetons d'animation. Opus pour le concevoir, Sonnet ensuite.
- [ ] J6b Photos : script `tools/fork_region_species.py`, à lancer sur le PC avec uv, qui liste les
      espèces plausibles en France et en Europe de l'Ouest grâce au géomodèle. Ajouter à
      `tools/build_species_bundle.py` une option pour ne traiter que cette liste. En ligne, photos plus
      grandes via iNaturalist (inat_id), mises en cache. Crédit et licence accessibles d'un appui.
- [ ] J6c Écrans, un par session : Accueil, Live, Fiche espèce, Palmarès, Carte, Sonothèque, Revue rapide.

Fini quand : 60 images par seconde en mode profile sur le Xiaomi, thèmes clair et sombre, animations
réduites respectées.

## J7 : publication Android

- [ ] Signature de l'app (clé d'upload), build `appbundle` en release.
- [ ] Piste de test interne sur le Play Store, fiche en français, politique de confidentialité adaptée
      de celle d'upstream.
- [ ] Avant de publier : retirer du pack les photos marquées « © Macaulay Library » (droits réservés),
      garder CC0, CC BY et CC BY-SA, et CC BY-NC seulement si l'app reste gratuite.
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
- Export compatible Faune-France, format à vérifier.
- Widget « dernier oiseau entendu ».

## Phase iOS (après validation d'Android)

Même code Flutter, BirdNET Live tourne déjà sur iOS. À faire à ce moment-là :
- iOS sans Mac : Codemagic (500 minutes de build macOS gratuites par mois pour un compte personnel),
  fichier `codemagic.yaml`, compte Apple Developer (99 $ par an), TestFlight.
- Réécoute pendant l'écoute : session audio playAndRecord avec defaultToSpeaker et Bluetooth, sinon
  le son sort par l'écouteur.
- Reprendre la liste des points iOS notés pendant les jalons Android.
