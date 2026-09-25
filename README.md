<h1 align="center">
  <img src="fork/brand/birdygo-logo.svg" alt="Logo BirdyGo" width="180"><br>
  BirdyGo
</h1>

<p align="center">
  <b>Reconnais les oiseaux à leur chant, hors ligne, sur le terrain.</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/statut-en%20d%C3%A9veloppement-F4C542.svg" alt="Statut : en développement">
  <a href="LICENSE"><img src="https://img.shields.io/badge/licence-MIT-19A7B3.svg" alt="Licence MIT"></a>
  <img src="https://img.shields.io/badge/Flutter-stable-19A7B3.svg" alt="Flutter stable">
  <img src="https://img.shields.io/badge/plateforme-Android-9DB46A.svg" alt="Plateforme : Android">
  <a href="https://github.com/birdnet-team/birdnet-live-app"><img src="https://img.shields.io/badge/propuls%C3%A9%20par-BirdNET-13233A.svg" alt="Propulsé par BirdNET"></a>
</p>

BirdyGo est une app Flutter qui identifie les oiseaux au chant, en direct et sans connexion. C'est un fork de
[BirdNET Live](https://github.com/birdnet-team/birdnet-live-app), l'app officielle de l'équipe BirdNET
(Cornell Lab of Ornithology et TU Chemnitz). BirdyGo garde tout ce que BirdNET Live fait déjà et ajoute ce qui
sert au quotidien : savoir quand l'app se trompe, réécouter ses meilleurs enregistrements, suivre ses espèces
dans le temps et sur une carte, dans une interface pensée comme un carnet de terrain.

> **Projet en cours.** BirdyGo n'est pas encore publié. Pour une app prête à l'emploi, installe
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

**Hérité de BirdNET Live**, et déjà fonctionnel :

- identification en direct avec spectrogramme défilant, modèle BirdNET+ embarqué (plus de 9 000 espèces), sans internet ;
- modes Live, Point d'écoute, Transect avec suivi GPS, analyse de fichiers audio et station fixe (ARU) ;
- filtre géographique selon le lieu et la saison ;
- bibliothèque de sessions, lecteur de clips, exports CSV, GPX, Raven et JSON.

**Ajouté par BirdyGo** (en préparation, voir la [feuille de route](#feuille-de-route)) :

- **Fiabilité** : trois niveaux (Sûr, Probable, À vérifier), badge « Inattendu ici », revue rapide par balayage
  et précision mesurée sur tes propres vérifications.
- **Réécoute** : rejouer un chant pendant l'écoute sans que le modèle ne se détecte lui-même, et une sonothèque
  par espèce avec favoris.
- **Palmarès** : espèces classées par contacts, jours ou dernière écoute, activité par heure et par mois.
- **Carte** : tous tes contacts sur une seule carte, en hexagones, avec les fonds IGN.
- **Nouvelle interface** : photos d'oiseaux, thèmes clair et sombre, animations sobres (voir [fork/DESIGN.md](fork/DESIGN.md)).

## Feuille de route

Android d'abord, jusqu'à une version validée sur le Play Store, puis iOS avec le même code. Le détail de chaque
jalon et ses critères de fin sont dans [fork/PLAN.md](fork/PLAN.md).

| Jalon | Contenu | État |
|---|---|---|
| J0 | Renommage en BirdyGo, identifiant `fr.justcodeit.birdygo`, écran À propos | à faire |
| J1 | Index des observations (SQLite dérivé des sessions) | à faire |
| J2 | Réécoute pendant l'écoute et sonothèque | à faire |
| J3 | Niveaux de fiabilité et revue rapide | à faire |
| J4 | Palmarès | à faire |
| J5 | Carte de tous les contacts | à faire |
| J6 | Refonte visuelle | à faire |
| J7 | Publication Android | à faire |

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
