# Carte du monde : observations GBIF (tools/fork_gbif_ranges.py)

Prépare `assets/fork/world/ranges_gbif.bin` + `ranges_gbif.json` : l'aire de répartition de chaque
oiseau par saison, sur une grille de 1°, à partir d'observations réelles de GBIF (dont eBird).
Lancé par Benjamin sur son PC, jamais dans le cloud. Python 3.10+, bibliothèque standard seulement.

## Mode d'emploi

1. Créer un compte sur <https://www.gbif.org> (gratuit, e-mail confirmé).
2. Dans le terminal (PowerShell) :

   ```powershell
   $env:GBIF_USER = "mon_identifiant"
   $env:GBIF_PWD = "mon_mot_de_passe"
   $env:GBIF_EMAIL = "mon.bnj@gmail.com"
   python tools/fork_gbif_ranges.py request
   ```

   Le script envoie UNE requête SQL à GBIF et affiche une clé de téléchargement. GBIF calcule
   (quelques minutes à une heure) et envoie un e-mail. Identifiants : variables d'environnement
   seulement, jamais dans un fichier du dépôt.
3. `python tools/fork_gbif_ranges.py build --download-key <clé>` : attend la fin, télécharge le ZIP
   (dans `tools/fork_gbif/cache/`, ignoré par git), agrège, écrit les deux fichiers de
   `assets/fork/world/`. Les clés GBIF viennent de `taxonomy.csv` (`gbif_id`) ; les espèces sans clé
   passent par l'API `species/match`, mise en cache dans `tools/fork_gbif/cache/taxon_keys.json`.
4. Commiter `ranges_gbif.bin` et `ranges_gbif.json` (le DOI du téléchargement y est inscrit : la
   citation est obligatoire, l'app l'affiche dans « Licences des contenus »).
5. `python tools/fork_gbif_ranges.py demo` remet l'asset fictif de démonstration (3 espèces,
   `"demo": true` : l'app de production l'ignore).

`python tools/fork_gbif_ranges.py sql` affiche la requête. Tests : `python -m unittest tools/test_fork_gbif_ranges.py`.

## Méthode choisie et pourquoi

**Téléchargement SQL de GBIF** (`format SQL_TSV_ZIP`) : GBIF fait l'agrégation (GROUP BY espèce,
cellule 1°, saison, COUNT) de centaines de millions d'enregistrements et ne renvoie que quelques millions
de lignes (quelques dizaines de Mo). Une seule requête, un seul DOI à citer. Filtres : classe Aves,
zone de la carte, 2010 et après, `HUMAN_OBSERVATION`/`OCCURRENCE`, `PRESENT`, sans problème géospatial,
incertitude inférieure à une cellule, licences CC0 ou CC BY seulement (CC BY-NC exclu).

**Alternative si l'API SQL n'est pas accessible** : `build --from-file FICHIER`. Le fichier peut être le
résultat SQL soumis à la main (page « SQL download » de gbif.org, avec la requête de `sql`), ou un
téléchargement brut (CSV/TSV avec `specieskey`, `decimalLatitude`, `decimalLongitude`, `month`),
agrégé localement en flux, sans tout charger en mémoire (deux passes). Un téléchargement « simple CSV »
de toute la classe Aves sur la zone fait des centaines de millions de lignes : à réserver à des
morceaux (par pays ou par année). C'est pourquoi le SQL est le choix le plus robuste : c'est le seul
où GBIF absorbe le volume.

## Correction du biais d'observation

Taux de signalement = enregistrements de l'espèce dans la cellule et la saison / enregistrements de tous
les oiseaux dans la même cellule et saison. Cellule « présente » si, à la fois : au moins
`MIN_CELL_TOTAL` enregistrements d'oiseaux (50), au moins `MIN_SPECIES_RECORDS` de l'espèce (2), et
taux >= `RATE_LEVELS[0]` (0,2 %). Niveaux 1, 2, 3 à 0,2 %, 1 %, 5 %. Une espèce vue dans moins de
`MIN_SPECIES_CELLS` cellules est omise (l'app retombe sur le géomodèle). Tous ces réglages sont des
constantes en tête du script.

## Format du fichier

Voir l'en-tête de `tools/fork_gbif_ranges.py` (en-tête de 20 octets, index trié des noms scientifiques,
puis par espèce 4 saisons en RLE varint : `longueur << 2 | niveau`, cellules ligne par ligne, du nord
au sud). Décodé dans `lib/fork/world_map/gbif_ranges.dart`.

Taille estimée du vrai fichier : environ 1 à 3 Ko par espèce (RLE, 4 saisons), donc 2 à 6 Mo pour
1 500 à 2 000 espèces avec des données dans la zone. Le passage à 0,5° multiplierait la taille par ~3 :
à voir après une première extraction (`GRID_STEP`, la carte lit le pas dans le fichier).

## Attribution

« Observations GBIF (dont eBird), CC BY 4.0 ». Citation : « GBIF.org (date) GBIF Occurrence Download
https://doi.org/<DOI> ». Le jeu eBird Observation Dataset (EOD) sur GBIF est sous CC BY 4.0.
