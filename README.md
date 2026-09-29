<h1 align="center">
  <img src="fork/brand/birdygo-logo.svg" alt="Logo BirdyGo" width="180"><br>
  BirdyGo
</h1>

<p align="center">
  <b>Reconnais les oiseaux à leur chant, hors ligne, et apprends en jouant.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/statut-en%20d%C3%A9veloppement-F4C542.svg" alt="Statut : en développement">
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-MIT-19A7B3.svg" alt="Licence MIT"></a>
  <img src="https://img.shields.io/badge/Flutter-stable-19A7B3.svg" alt="Flutter stable">
  <img src="https://img.shields.io/badge/plateforme-Android-9DB46A.svg" alt="Plateforme : Android">
  <a href="https://github.com/birdnet-team/birdnet-live-app"><img src="https://img.shields.io/badge/propuls%C3%A9%20par-BirdNET-13233A.svg" alt="Propulsé par BirdNET"></a>
</p>

BirdyGo est une app Android qui reconnaît les oiseaux à leur chant, en direct et sans connexion. Tu sors,
tu lances l'écoute, et les oiseaux apparaissent avec leur photo. L'app te dit aussi **à quel point elle est
sûre d'elle** (Sûr, Probable, À vérifier), garde tout dans un **carnet** qui se remplit au fil des sorties, et
en fait un petit jeu : niveaux, badges, série de jours, défi de la semaine et quiz « Qui chante ? ». Elle est
pensée pour être assez simple pour un enfant, et assez sérieuse pour un ornithologue amateur.

C'est un fork de [BirdNET Live](https://github.com/birdnet-team/birdnet-live-app), l'app officielle de
l'équipe BirdNET (Cornell Lab of Ornithology et TU Chemnitz). BirdyGo garde tout ce que BirdNET Live sait déjà
faire et ajoute la vérification, la collection et l'apprentissage, dans une interface pensée comme un
carnet de terrain.

> **Projet en développement.** BirdyGo n'est pas encore publié : il s'installe pour l'instant depuis les
> sources (voir [Démarrer](#démarrer)). Pour une app prête à l'emploi, installe
> [BirdNET Live](https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live).

---

## Sommaire

- [Ce que fait BirdyGo](#ce-que-fait-birdygo)
- [Feuille de route](#feuille-de-route)
- [Démarrer](#démarrer)
- [Organisation du fork](#organisation-du-fork)
- [Rester à jour avec BirdNET Live](#rester-à-jour-avec-birdnet-live)
- [Licences et crédits](#licences-et-crédits)

## Ce que fait BirdyGo

Tout est hors ligne : le modèle BirdNET+ (plus de 9 000 espèces) tourne sur le téléphone. Les éléments
marqués *(en cours)* ne sont pas encore terminés.

### Écouter

- **Premier lancement** en 3 pages qui expliquent l'app et demandent les autorisations (micro, position).
- Après chaque écoute, l'app ouvre toujours le **Bilan** de la session.
- Identification en direct avec spectrogramme défilant, et un tableau où l'oiseau entendu remonte en tête.
- Écoute **écran éteint**, avec la position GPS suivie pendant la sortie.
- **Modes d'écoute** : Normal, Vent et Boost (Ville est encore à l'essai).
- **Écouter un enregistrement** déjà fait, sans qu'il compte dans tes statistiques.
- Hérité de BirdNET Live : Point d'écoute, Transect avec GPS, analyse de fichiers, station fixe, filtre
  géographique selon le lieu et la saison.

### Vérifier

- **Trois niveaux de fiabilité** partout dans l'app : Sûr, Probable, À vérifier.
- Pastille **« Rare ici · à confirmer »** quand le géomodèle juge l'espèce peu probable à cet endroit et cette semaine.
- **Revue rapide** : une pile de cartes à balayer pour confirmer ou écarter les détections.
- **Précision mesurée** sur tes propres vérifications.
- **Réécoute** d'un chant pendant l'écoute, sans que l'app détecte son propre haut-parleur. Elle sert à vérifier,
  jamais à attirer les oiseaux.

### Collectionner et apprendre

- **Accueil** avec le dernier oiseau entendu, ton niveau et l'objectif du jour ; toucher « Aujourd'hui » rouvre le
  Bilan du jour.
- **Carnet** façon collection : les espèces découvertes en couleur, à confirmer en pointillés, les autres en silhouette.
- **Jeu** : niveaux (« niveau »), badges, **série** de jours sans pénalité pour un jour manqué, **défi de la
  semaine**, petites célébrations pour la première rencontre d'un oiseau. Seules les détections Sûr ou
  confirmées comptent.
- **Quiz « Qui chante ? »** : écoute un chant, devine l'oiseau, gagne le badge Oreille fine.
- **Fiches espèces** : photo, taille, comportement, migration, comment le reconnaître à l'oreille, anecdote.
  Les textes sont rédigés à l'avance, hors ligne ; les 100 oiseaux les plus courants de France sont prêts, leur
  relecture est *(en cours)*. Le mois en cours est visible dans la fiche, qui s'ouvre en feuille refermable
  pendant l'écoute.
- **Palmarès** : classement par contacts, jours ou dernière écoute, activité par heure et par mois
  avec un podium à médailles pour les trois premiers.
- **Sonothèque** : tous tes meilleurs clips, par espèce, avec favoris.

### Réglages et interface

- Menu **« Plus »** en grandes tuiles, les outils avancés repliés.
- **Réglages simples** (langues, thème, sons, photos en ligne, floutage), les réglages d'expert restent à part.
- Même style partout : Objectif du jour, Oiseaux des jardins, Fiabilité, envoi LPO et Sonothèque.
- **Squelettes de chargement** animés d'un balayage de lumière, figés si les animations sont réduites.

### Partager

- **Carte** de tous tes contacts, avec les fonds OSM, Plan IGN et photos aériennes IGN.
- **Envoi guidé à la LPO** (Faune-France) : fiche prête à reporter pour chaque observation confirmée, avec des
  alertes pour les espèces sensibles ou rares. Depuis une fiche espèce, « Envoyer à Faune-France » prépare l'envoi. BirdyGo n'imite pas NaturaList et ne demande jamais ton mot de passe.
- Mode **Oiseaux des jardins** (LPO et MNHN) avec minuteur.
- Exports CSV, GPX, Raven et JSON (option pour flouter la position des espèces sensibles).

## Feuille de route

Android d'abord, jusqu'à une version validée sur le Play Store, puis iOS avec le même code. Le détail de chaque
jalon et ses critères de fin sont dans [fork/PLAN.md](fork/PLAN.md). Certains jalons « faits » attendent
encore un essai sur le téléphone.

| Jalon | Contenu | État |
|---|---|---|
| J0 | Renommage en BirdyGo, identifiant `fr.justcodeit.birdygo`, écran À propos | fait |
| J1 | Index des observations (SQLite dérivé des sessions) | fait |
| J2, J2b | Réécoute pendant l'écoute, sonothèque, écoute écran éteint | fait, essais terrain restants |
| J3, J3b | Niveaux de fiabilité, revue rapide, « Rare ici » | fait |
| J4 | Palmarès | fait |
| J4b | Fiches espèces rédigées à l'avance | en cours (100 fiches livrées, relecture à faire) |
| J5 | Carte de tous les contacts | fait |
| J5b | Envoi guidé à la LPO, Oiseaux des jardins | fait |
| J5c | Écouter un enregistrement | fait |
| J6a, J6b, J6c | Design system, photos d'espèces, écrans refaits, écoute améliorée | fait |
| J6d | Icônes d'espèces en SVG | à faire |
| J6e | Jeu : carnet, profil, niveaux, badges, défis, quiz | fait |
| J6f | Interface finale (accueil, écoute, modes, profil, quiz) | fait, essais terrain restants (modes d'écoute) |
| J6g | Critique générale : onboarding, accueil, carnet, menu, réglages, carte, écrans restants, squelettes | fait |
| J7 | Publication Android (Play Store, licences des contenus, dernier renommage) | à faire |
| iOS | Même code Flutter, après validation d'Android | à faire |

## Démarrer

### Prérequis

- [Flutter](https://docs.flutter.dev/get-started/install), canal stable
- [Android Studio](https://developer.android.com/studio), pour le SDK Android
- [Git LFS](https://git-lfs.com/), pour les modèles ONNX

### Installation

```bash
git clone https://github.com/bNjtHub/BirdyGo.git
cd BirdyGo
git lfs install
git lfs pull
flutter pub get
flutter gen-l10n
flutter run
```

Les deux fichiers `.onnx` de `assets/models/` sont stockés avec Git LFS. Sans eux, l'app se compile mais ne
peut pas charger le modèle. Si `git lfs pull` échoue sur ce dépôt, récupère-les depuis le dépôt d'origine :

```bash
git config lfs.url https://github.com/birdnet-team/birdnet-live-app.git/info/lfs
git lfs pull
```

### Vérifier

Le dossier `assets/species_data/` est déclaré dans `pubspec.yaml` mais ignoré par Git (il est généré sur le PC
avec les photos et textes des espèces) : sans lui, `flutter analyze` et `flutter test` se plaignent d'un asset manquant.

```bash
mkdir -p assets/species_data   # dossier généré, attendu par pubspec.yaml
flutter analyze
flutter test
```

## Organisation du fork

Le fork reste proche d'upstream pour que les mises à jour de BirdNET Live se fusionnent sans douleur :

| Emplacement | Contenu |
|---|---|
| `lib/fork/<domaine>/` | code propre à BirdyGo |
| `test/fork/` | tests de ce code |
| `fork/` | [plan de développement](fork/PLAN.md), [direction visuelle](fork/DESIGN.md), logo et scripts d'environnement |
| `// FORK: <raison>` | marque chaque modification, minimale, d'un fichier upstream |
| `docs/developer/` | documentation technique d'upstream (architecture, pipeline audio, inférence…) |

Les règles de travail du fork sont dans [CLAUDE.md](CLAUDE.md). Elles complètent celles de l'équipe BirdNET
([AGENTS.md](AGENTS.md)).

## Rester à jour avec BirdNET Live

Une fois par mois, on fusionne la branche `main` d'upstream :

```bash
git remote add upstream https://github.com/birdnet-team/birdnet-live-app.git   # la première fois
git fetch upstream
git checkout -b sync-AAAA-MM
git merge upstream/main
```

En cas de conflit, on garde les ajouts marqués `FORK` et le code de `lib/fork/`, et la version upstream pour
le reste. Ce README est propre au fork : en cas de conflit, garder cette version.

## Licences et crédits

BirdyGo est une **version modifiée** de BirdNET Live. Ce n'est pas une app officielle BirdNET, et elle n'est ni
affiliée à l'équipe BirdNET, au Cornell Lab ou à la TU Chemnitz, ni approuvée par eux.

- **Code** : licence [MIT](LICENSE), © 2026 BirdNET-Team pour le code d'origine.
- **Modèles** : les poids BirdNET+ de `assets/models/` sont sous licence [Apache 2.0](MODEL_LICENSE).
- **Usage responsable** : voir la [charte d'usage de BirdNET](ACCEPTABLE_USE.md), notamment sur la publication
  de la position d'espèces sensibles.
- **Logo** : création originale du projet BirdyGo ([fork/brand/](fork/brand/)).
- **Photos et textes des espèces** : les photos viennent de la taxonomie BirdNET (crédit et licence d'un appui sur
  la photo) ou d'iNaturalist sous licence ouverte ; les fiches sont rédigées pour BirdyGo, avec Wikipédia et Wikidata
  comme simples contrôles. Avant la publication (J7), les photos à droits réservés seront retirées et une page
  « Licences des contenus » sera ajoutée dans À propos.

Tout le mérite de la reconnaissance revient à l'équipe BirdNET, à ses financeurs et à ses partenaires, listés
dans le [README d'origine](https://github.com/birdnet-team/birdnet-live-app#funding). Pour un usage
scientifique, cite BirdNET Live :

```bibtex
@software{BirdNET_Live_2026,
  author = {Kahl, Stefan and Börner, Andy and Mauermann, Max and Seifert, Raja Charlotte and Lasseck, Mario and Wilhelm-Stein, Thomas and Wood, Connor M. and Eibl, Maximilian and Klinck, Holger},
  title = {{BirdNET Live app - Professional bioacoustics in your pocket}},
  url = {https://github.com/birdnet-team/birdnet-live-app},
  year = {2026}
}
```
