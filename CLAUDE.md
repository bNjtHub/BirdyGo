# Ramage, fork de BirdNET Live

App Flutter (Android et iOS) qui identifie les oiseaux au chant, hors ligne. C'est un fork de
birdnet-team/birdnet-live-app : code sous MIT, poids du modèle sous Apache 2.0 (MODEL_LICENSE),
charte d'usage dans ACCEPTABLE_USE.md. Développeur solo francophone (Benjamin), poste Windows,
tests sur un Xiaomi 17 Ultra (HyperOS).

Nom de travail : Ramage. Identifiant Android et iOS : `fr.justcodeit.ramage`.

Cible actuelle : Android seulement. La version iOS viendra une fois Android validé, avec le même code
Flutter. Donc : ne pas supprimer ni casser le dossier `ios/`, et pour toute fonction qui passe par du
code natif Android, prévoir une interface commune et noter dans `fork/PLAN.md` (section iOS) ce qu'il
faudra faire côté iOS. Pas de build ni de test iOS pour l'instant.

## Documents à lire au bon moment

- `fork/PLAN.md` : jalons, tâches, critères de fin. Lire la section du jalon en cours au début de chaque session.
- `fork/DESIGN.md` : couleurs, typographie, mise en page, animations. Lire avant toute tâche d'interface.
- `docs/developer/*.md` (upstream) : architecture, audio-pipeline, inference-engine, database,
  session-review, spectrogram, state-management, testing. Les lire avant d'explorer le code.

## Règles du fork (elles priment sur AGENTS.md)

- AGENTS.md contient les règles de l'équipe BirdNET. On les suit, sauf :
  - nouvelles chaînes d'interface en français et en anglais seulement, les autres langues retombent sur l'anglais ;
  - pas de captures store, de mockups multilingues ni de notes de version en 12 langues ;
  - pas de mise à jour de la doc utilisateur MkDocs ni du CHANGELOG upstream.
- Code nouveau dans `lib/fork/<domaine>/`, tests dans `test/fork/`.
- Fichiers upstream : modifications minimales, chacune marquée `// FORK: <raison>`.
  Pas de refactor ni de reformatage non demandé, ça casserait les fusions avec upstream.
- Les sessions JSON restent la source de vérité. L'index SQLite du fork est dérivé et reconstructible.
- Pipeline audio et inférence (`lib/features/audio`, `lib/features/inference`) : ne pas y toucher
  sans que le jalon le demande, et lire audio-pipeline.md et inference-engine.md avant.
- Aucun seuil ni valeur de modèle en dur : `assets/models/model_config.json`, les constantes
  existantes, ou `lib/fork/reliability/reliability_config.dart` pour les seuils propres au fork.
- Icônes via `AppIcons` (`lib/shared/utils/app_icons.dart`), jamais `Icons.*` en direct.
- Cartes : réutiliser les réglages de tuiles partagés, pas de préchargement massif de tuiles OSM.
- Nouvelle dépendance : seulement si le plan du jalon la prévoit, sinon demander.

## Commandes

- `flutter pub get`, `flutter gen-l10n`, `flutter analyze`.
- Tests ciblés pendant le travail : `flutter test test/fork/`. Suite complète avant d'ouvrir une PR.
- Dans le cloud, Flutter est installé par le setup script de l'environnement. Les modèles ONNX
  (Git LFS) ne sont pas présents : ne pas lancer l'app, ne pas tenter `git lfs pull`, ne pas écrire
  de test qui charge un vrai modèle (utiliser des faux).
- Les essais sur téléphone, c'est Benjamin qui les fait sur son PC avec `flutter run`.

## Façon de travailler (le crédit est limité)

- Début de jalon en mode plan : fichiers créés et modifiés, tests prévus, risques.
  Attendre la validation avant d'écrire du code.
- Lire seulement ce qui sert. Pour une recherche large dans le code upstream, passer par un
  sous-agent et ne rapporter que les fichiers, classes et fonctions utiles.
- Un jalon = une branche = une PR. Petits commits. Cocher les cases du jalon dans `fork/PLAN.md`.
- Après deux tentatives ratées sur le même problème : s'arrêter, résumer ce qui a été essayé,
  proposer des pistes. Ne pas tourner en rond.
- Réponses courtes, en français. Code, identifiants et commentaires de code en anglais.

## Repères techniques

- Modèle audio BirdNET+ V3.0 preview (ONNX, 32 kHz) et géomodèle BirdNET+ V3.0.4, réglages dans
  `assets/models/model_config.json`. Le lissage temporel (temporalPooling) existe déjà.
- Une détection = un épisode de chant fusionné, avec score, statut de revue, clip audio et
  position GPS au moment de la détection.
- Sessions : `<documents>/sessions/<id>.json`. Clips : `<documents>/recordings/<id>/`.
- Rejouer un clip pendant une écoute : suspendre l'inférence pendant la lecture, plus 0,5 s,
  sinon le modèle détecte le haut-parleur.
- HyperOS coupe volontiers les services en arrière-plan : prévoir un test d'écoute écran éteint.
