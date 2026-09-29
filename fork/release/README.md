# J7 : publier BirdyGo sur le Play Store (piste de test interne)

Tout ce qui suit se fait sur le PC de Benjamin. Ne jamais committer la clé (`.jks`) ni `key.properties`
(déjà dans `.gitignore`). Sauvegarder la clé d'upload et ses mots de passe ailleurs (gestionnaire de
mots de passe + copie hors du dépôt) : sans elle, on ne peut plus envoyer de mises à jour sans passer par
le support Google.

## 1. Créer la clé d'upload (une seule fois)

`keytool` est fourni avec le JDK d'Android Studio (`<Android Studio>\jbr\bin\keytool.exe`) :

```
keytool -genkeypair -v -storetype JKS -keystore C:\Users\bNj\keystores\birdygo-upload.jks ^
  -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Noter les deux mots de passe (magasin et clé). Le dossier `keystores` doit être hors du dépôt
(pas dans SynologyDrive s'il est partagé).

## 2. Renseigner `android/key.properties`

Copier `android/key.properties.example` en `android/key.properties`, puis remplir :

```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=C:/Users/bNj/keystores/birdygo-upload.jks
```

`android/app/build.gradle` lit ce fichier. Sans lui (ou si `storeFile` n'existe pas), la build release
retombe sur la clé de debug et Gradle affiche `*** WARNING: android/key.properties missing ...` : un
bundle signé ainsi est refusé par le Play Store. Ne pas s'en servir pour publier.

Play App Signing : à la création de l'app dans la Console, accepter « Play App Signing ». Google garde la
clé de signature définitive, la clé créée ici n'est que la clé d'upload (remplaçable en cas de perte).

## 3. Construire le bundle

Vérifier `version:` dans `pubspec.yaml` : le numéro après `+` (versionCode) doit augmenter à chaque
envoi. Puis :

```
flutter pub get
git lfs pull                       # les modèles ONNX doivent être présents
flutter build appbundle --release
```

Résultat : `build/app/outputs/bundle/release/app-release.aab`.

Notes sur la build :
- `minifyEnabled` et `shrinkResources` sont actifs (comportement upstream, inchangé). Les règles R8 de
  `android/app/proguard-rules.pro` gardent ONNX Runtime (`ai.onnxruntime.**`) et les plugins Flutter.
  Tester quand même la version release installée (`flutter build apk --release`, puis installer) : une
  écoute doit détecter des espèces, sinon R8 a retiré une classe.
- Les deux modèles ONNX partent dans l'asset pack `models_pack` (install-time), sinon le module de base
  dépasserait 200 Mo. Aucune action.
- ABI : arm64 seulement. Les téléphones 32 bits ne verront pas l'app.

## 4. Play Console

1. Créer un compte développeur (25 $ une fois). Les comptes personnels récents doivent faire un test
   fermé (12 testeurs, 14 jours) avant la production ; la piste de test interne, elle, est libre.
2. Créer l'application : nom « BirdyGo », langue par défaut français, application (pas jeu), gratuite.
3. Tableau de bord, « Configurer votre application » : remplir les rubriques ci-dessous.
4. Test > Test interne > Créer une version : envoyer `app-release.aab`, notes de version en français.
   Ajouter une liste de testeurs (adresses Gmail), copier le lien d'inscription, l'ouvrir sur le Xiaomi.
5. La fiche (textes et captures) est dans `store_listing_fr.md`, la politique de confidentialité dans
   `privacy_policy_fr.md`.

### Contenu de l'application

- **Politique de confidentialité** : URL publique obligatoire (page web, pas un fichier du dépôt privé).
  Héberger `privacy_policy_fr.md` (GitHub Pages, Netlify, page du site, etc.) après avoir rempli le contact.
- **Accès à l'application** : tout est accessible sans compte ni identifiant. Choisir « Toutes les
  fonctionnalités sont disponibles sans restriction ». Indiquer aux relecteurs que le microphone et la
  localisation sont demandés à l'usage.
- **Annonces** : aucune publicité.
- **Classification du contenu** (questionnaire IARC) : catégorie « Utilitaire / Référence ». « Non »
  partout (pas de violence, de contenu sexuel, de jeu d'argent, d'échange entre utilisateurs, d'achat).
  Le quiz est un jeu de connaissances sans argent.
- **Applications de santé, actualités, finance** : non.
- **Services de premier plan** (`FOREGROUND_SERVICE_MICROPHONE`, `FOREGROUND_SERVICE_LOCATION`) : la
  Console demande une déclaration, parfois une vidéo. Justification : l'écoute continue de chants
  d'oiseaux écran éteint est la fonction principale, l'utilisateur la lance, une notification permanente
  est affichée.
- **Localisation en arrière-plan** : non utilisée (décision : `ACCESS_BACKGROUND_LOCATION` retirée du
  manifeste pour la première version), rien à déclarer. Voir la section dédiée plus bas.

### Sécurité des données (Data safety)

Réponses déduites du code (à revérifier si des fonctions réseau sont ajoutées) :

- Aucun serveur du développeur, aucun compte, aucune publicité, aucun outil d'analyse ni de plantage
  (pas de Firebase, Sentry, Crashlytics, etc. dans `pubspec.yaml`).
- **Audio du microphone** : traité sur l'appareil, jamais envoyé. Pas de déclaration.
- **Position** : lue et traitée sur l'appareil (géomodèle, marquage des détections, carte). Elle n'est
  partagée que si l'utilisateur exporte ou envoie lui-même une observation, ou active une option
  facultative (voir ci-dessous). Les fonds de carte (OpenStreetMap et IGN, sur la carte des contacts et
  la mini-carte de la fiche espèce) ne sont chargés qu'avec le même interrupteur « cartes en ligne »
  (Paramètres > Confidentialité, désactivé par défaut) ; ils n'envoient que des coordonnées de tuile
  et l'adresse IP, pas la position de l'utilisateur au sens strict.
- **Requêtes réseau facultatives**, toutes désactivées par défaut (interrupteurs dans Paramètres >
  Confidentialité) : tuiles OpenStreetMap et Géoplateforme IGN (coordonnées de tuile et adresse IP),
  nom de lieu (Nominatim : latitude et longitude de la session), météo (Open-Meteo : latitude, longitude,
  heure), photos en grand format (iNaturalist : espèce et adresse IP).
- **Envoi à Faune-France / NaturaList et exports** : décision de l'utilisateur, via la feuille de
  partage du système ; l'app n'envoie rien à un serveur elle-même.

Réponse au formulaire : « Position approximative » et « Position précise » **collectées** (traitées sur
l'appareil), finalité « Fonctionnalités de l'appli », **facultatives** (la localisation se refuse ou se
révoque). **Partagées** : seulement lorsque l'utilisateur exporte ou envoie lui-même une observation
(partage à son initiative) ; les requêtes facultatives (Nominatim, Open-Meteo) envoient une latitude et
une longitude uniquement après activation explicite : les déclarer comme partagées avec ces services,
facultatives. La déclaration reste ainsi vraie si un utilisateur active les options. Rien d'autre à déclarer. Chiffrement en transit : oui (HTTPS). Demande de suppression :
pas de compte ; les données restent sur l'appareil (Paramètres > Zone dangereuse > Effacer toutes les
données, ou désinstaller).

Autorisations déclarées dans le manifeste : internet, microphone (via service), localisation précise,
approximative (pas de localisation en arrière-plan), notifications, vibration, services de premier plan.

### Localisation en arrière-plan : retirée pour la première version

Décision de Benjamin : `ACCESS_BACKGROUND_LOCATION` n'est plus déclarée (elle imposait un formulaire de
justification, une vidéo et une revue). Ce qui change :
- **Écoute (Live)** : rien ne change. La position est suivie pendant l'écoute, écran éteint compris, par
  le service de premier plan de type `microphone|location` (`FOREGROUND_SERVICE_LOCATION` déclarée),
  démarré depuis l'app au premier plan avec la permission « Pendant l'utilisation de l'app ». Android
  autorise ce cas sans « Toujours autoriser ».
- **Mode Relevé (Survey)** : plus aucune demande de « Toujours autoriser ». L'écran de préparation
  demande seulement « Pendant l'utilisation de l'app » ; le suivi GPS continu tourne grâce au service de
  premier plan, comme en Live. Le bandeau d'avertissement n'apparaît que si la permission de
  localisation manque.
- Risque à vérifier par Benjamin : sur HyperOS, un service de premier plan peut être bridé ; test de
  10 minutes de marche écran éteint (voir `fork/PLAN.md`, J7).
- iOS (plus tard) : voir `fork/PLAN.md`, section « Phase iOS » (`UIBackgroundModes: location`).

### Public cible : 13 ans et plus

Choix retenu : **public cible 13 ans et plus** dans la Play Console (« Public cible et contenu » : ne
cocher aucune tranche d'âge en dessous de 13 ans). Pas de programme « Designed for Families », donc pas de
revue famille ni de SDK certifiés. L'identité graphique (oiseaux-thèmes, quiz) reste possible : l'app
n'est simplement pas destinée aux moins de 13 ans. La politique de confidentialité le dit (section
« Enfants »). Si un jour les moins de 13 ans sont visés, il faudra rouvrir ce point : programme Familles,
autorisations sensibles examinées de près, liens externes (eBird, Wikipédia, iNaturalist, Faune-France)
et requêtes facultatives envoyant l'adresse IP à des tiers à justifier.

## 5. Autres tâches de J7 (hors Console)

Restent dans `fork/PLAN.md` : retrait des photos « © Macaulay Library », page « Licences des contenus »,
renommage des textes qui disent encore « BirdNET Live », quelques semaines d'usage réel.
