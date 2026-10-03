# Liste de contrôle : test interne Play Store

Pas à pas détaillés (clé d'upload, R8, Play Console) : `fork/release/README.md`. Textes de la fiche :
`fork/store/fr/` (et `en/` pour plus tard). Politique de confidentialité : `fork/store/privacy-policy-fr.md`.
Captures : `fork/store/screenshots-plan.md`.

## 1. Avant la build

- [ ] Photos : `python tools/build_species_bundle.py --taxonomy-json tools/data/<json> --species-list
      tools/fork_sheets/region_species.csv --replace-reserved` (pack régénéré, plus aucune photo
      « © Macaulay Library » ni « nd » ; la page Licences des contenus se construit à l'exécution).
- [ ] Version : `pubspec.yaml` `version: 1.1.3+224`. versionName = 1.1.3 (visible), versionCode = 224
      (doit augmenter à chaque envoi, sinon Play refuse). Pour le premier envoi, 1.1.3+224 convient ;
      +1 à chaque nouvel envoi.
- [ ] Modèles ONNX présents (`git lfs pull`), `flutter analyze` et `flutter test` verts.
- [ ] Coordonnées du développeur et URL de la politique renseignées (voir section 4).

## 2. Signature

- Clé d'upload attendue : `android/key.properties` (non versionné, modèle : `android/key.properties.example`),
  qui pointe vers un `.jks` hors du dépôt (ex. `C:/Users/bNj/keystores/birdygo-upload.jks`).
- Sans ce fichier, `android/app/build.gradle` signe avec la clé de debug : le bundle sera refusé par Play.
- Ne jamais committer la clé ni `key.properties`. La sauvegarder (gestionnaire de mots de passe + copie hors
  SynologyDrive partagé). Accepter « Play App Signing » à la création de l'app.

## 3. Build

```
flutter pub get
flutter build appbundle --release
```

Résultat : `build/app/outputs/bundle/release/app-release.aab`. Taille constatée le 02/10 (build signée avec la clé
de debug, arm64 seul) : 128 Mo (module de base 45 Mo, asset pack des modèles 73 Mo). Les modèles partent dans l'asset pack `models_pack`.
Tester avant l'envoi : `flutter build apk --release`, installer, une écoute doit détecter des espèces
(règles R8), puis marche de 10 minutes écran éteint (HyperOS).

## 4. Play Console (test interne)

1. Compte développeur (25 $). Un compte personnel récent doit faire un test fermé (12 testeurs, 14 jours)
   avant la production ; le test interne est libre.
2. Créer l'app : « BirdyGo », français, application, gratuite.
3. Test > Test interne : créer une version, envoyer l'AAB, coller `fork/store/fr/release-notes.txt`.
4. Liste de testeurs : créer une liste (adresses Gmail, jusqu'à 100), copier le lien d'inscription, l'ouvrir
   sur le Xiaomi avec le même compte.
5. Politique de confidentialité : héberger `privacy-policy-fr.md` (page web publique), compléter [DATE],
   [NOM], [E-MAIL] et retirer l'encadré de brouillon, puis coller l'URL.
6. Fiche : titre, description courte et complète depuis `fork/store/fr/`. Icône 512 px et image 1024x500.
   Captures (≥ 2) : pas indispensables pour le test interne.

### Sécurité des données (formulaire)

Déduit du code ; à revérifier si le réseau change.

- Collecte ou partage de données : **oui** (position, voir ci-dessous) ; données chiffrées en transit : oui
  (HTTPS) ; demande de suppression : pas de compte, données sur l'appareil, suppression par
  Paramètres > Zone dangereuse ou désinstallation.
- **Position précise et approximative** : traitée sur l'appareil, finalité « Fonctionnalités de l'appli »,
  **facultative**. Partagée uniquement à l'initiative de l'utilisateur (exports, envoi Faune-France) ou via
  les options facultatives désactivées par défaut (Nominatim, Open-Meteo : latitude et longitude). Par
  prudence, déclarer « partagée » (facultative, finalité fonctionnalités de l'appli).
- **Audio** (microphone) : traité sur l'appareil, jamais envoyé : ne pas déclarer comme collecté.
- **Identifiants d'appareil, adresse IP** : les requêtes facultatives (tuiles OSM/IGN, Nominatim,
  Open-Meteo, iNaturalist) exposent l'IP au tiers ; l'IP n'est pas à déclarer comme donnée collectée par
  nous, mais la politique le dit.
- Aucun compte, aucune publicité, aucun SDK d'analyse ni de plantage (vérifié dans `pubspec.yaml`).
- Rien d'autre : pas d'informations personnelles, financières, de santé, contacts, photos de l'utilisateur.
- À vérifier : `allowBackup` n'est pas fixé dans le manifeste, la sauvegarde automatique Android est donc
  active. Décider de la couper (`android:allowBackup="false"`) ou de la laisser (mentionnée dans la
  politique).

### Contenu de l'application

- Publicité : non. Accès : tout sans compte. Applications santé, actualités, finance : non.
- **Classification (IARC)** : catégorie « Utilitaire / Référence », « Non » partout (violence, sexe, jeux
  d'argent, contenu généré par les utilisateurs, achats). Résultat attendu : PEGI 3 / Tous publics.
- **Services de premier plan** (`microphone`, `location`) : justification, l'écoute continue de chants écran
  éteint est la fonction principale, lancée par l'utilisateur, notification permanente. Vidéo de démonstration
  possible demandée par la Console.
- Localisation en arrière-plan : non déclarée (retirée du manifeste).
- **Public cible : 13 ans et plus** (recommandé). Ne cocher aucune tranche en dessous de 13 ans. Cela évite le
  programme « Designed for Families » (SDK certifiés, aucune requête vers des tiers non certifiés, revue
  des autorisations sensibles), incompatible avec les requêtes réseau facultatives, les liens externes et
  le microphone en continu. Si un jour on vise les moins de 13 ans, rouvrir ce point entièrement.
  Le style graphique (oiseaux, quiz) peut attirer des enfants : ne pas cocher « attire les enfants » que si
  on est prêt à accepter les règles Familles.

## 5. Photos : état des licences

Pack régénéré le 02/10 : 569 photos. Licences : cc-by-nc 368, cc-by 73 (+ 6 « CC BY x.y »), cc-by-sa 52
(+ 22 « CC BY-SA x.y »), cc-by-nc-sa 41, cc0 6, pd 1 ; plus aucune « © Macaulay Library », « nd » ni
droits réservés (128 photos remplacées : 126 iNaturalist taxon, 2 iNaturalist observations ; aucune espèce
sans photo libre). Sources : iNaturalist 541, Wikimedia 28. Rappels : les licences NC ne sont acceptables que tant que l'app est
gratuite et sans pub ; basculer vers du payant impose de remplacer les photos NC.
