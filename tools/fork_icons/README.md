# Atelier SVG BirdyGo

Un outil local pour préparer les icônes d'espèces : choisir un oiseau, ajuster sa
silhouette et ses couleurs, vérifier les petits formats et exporter les SVG.
Python 3.10 ou plus suffit ; aucune clé d'API ni installation de paquet n'est
nécessaire. Les modèles BirdNET ne sont jamais chargés.

## Ouvrir l'atelier

Depuis la racine du dépôt :

```powershell
python tools/fork_icons/app.py
```

Ouvrir <http://127.0.0.1:8765>. Arrêter le serveur avec `Ctrl+C`.
`--port 8766` permet de changer le port. L'interface propose le français et
l'anglais et fonctionne sans connexion ; les liens des planches s'ouvrent
uniquement lorsqu'on les consulte.

1. Chercher une espèce par son nom français, anglais ou scientifique.
2. Comparer son dessin sur fond clair et sombre, puis à 34, 48 et 64 px.
3. Choisir un gabarit si nécessaire, déplacer les curseurs et modifier les zones
   de couleur. L'aperçu « Entendu » applique le gris et l'opacité 0,45.
   Décocher « Afficher les barres sonores » pour retirer les barres de l'oiseau
   sélectionné. Ce réglage est conservé dans le projet, le CSV et les SVG exportés.
   Il préserve la silhouette originale, y compris pour les dessins de référence.
   « Rendu du plumage → Plumage doux » adoucit les raccords des zones colorées.
   Le centre des zones garde sa couleur ; les marques distinctives, les yeux et
   le contour restent nets. Le réglage se combine librement avec les barres sonores.
4. Consulter la planche citée et vérifier le sexe, l'âge et le plumage représentés.
5. Exporter le SVG ou le lot complet. Enregistrer aussi le projet pour conserver
   les réglages morphologiques et les ouvrir dans un autre navigateur.

Les 14 oiseaux et le mystère de la maquette restent identiques à l'ouverture.
Une modification de leur forme ou de leur palette passe au gabarit paramétrable,
ce qui peut changer leurs motifs. « Réinitialiser » retrouve le dessin original.

Les brouillons sont conservés dans le stockage du navigateur, par adresse/port.
« Ouvrir un projet » remplace le projet courant après validation ; enregistrer
celui-ci avant d'en ouvrir un autre. Le serveur ne modifie jamais les données
ni les assets du dépôt. L'archive exportée contient :

- `assets/fork/species_icons/` : les SVG et `index.json` pour Flutter ;
- `species_colors.csv` : la table de couleurs modifiée et ses sources ;
- `project.json` : les réglages de silhouette et les modifications ;
- `sheet.html` : une planche autonome correspondant aux dessins exportés.

Le CSV seul ne contient pas les réglages morphologiques. Conserver le projet
avec l'archive pour pouvoir reproduire les silhouettes modifiées.

## Génération reproductible du catalogue

```powershell
python tools/fork_species_icons.py
python tools/fork_species_icons.py --check
python tools/fork_species_icons.py --species "Erithacus rubecula"
python -m unittest tools.test_fork_species_icons tools.test_fork_icons_app
```

La première commande produit les assets et `tools/fork_icons/sheet.html`.
La deuxième échoue si une sortie ne correspond plus aux données. Les chemins
peuvent être remplacés avec `--data`, `--taxonomy`, `--output` et `--sheet`.
La génération ne supprime aucun fichier existant : lorsqu'une espèce est retirée
de la table, retirer son ancien SVG du dépôt après vérification.

`species.csv` retient les 100 premiers oiseaux (`is_bird=1`) classés par
`mean_share` décroissant dans `tools/fork_sheets/region_species.csv`, puis le
loriot pour conserver toutes les références. Ce classement exprime la présence
prévue par le géomodèle dans la région, pas l'abondance observée sur le terrain.

Les palettes sont des interprétations graphiques de planches historiques du
domaine public. Les colonnes `source_*`, `plumage` et `review_status` conservent
leur provenance et leur état de relecture. `draft` signifie que les couleurs
doivent encore être relues, même lorsque la planche a été vérifiée. Ne passer à
`reviewed` qu'après cette relecture ; ce statut exige une attribution complète.
Les noms anciens des ouvrages sont explicités dans la référence de la planche.
Les dessins de référence gardent leur palette de la maquette.
La colonne optionnelle `render_style` vaut `reference` pour les 14 oiseaux
historiques, `template` pour les autres. Pour remplacer la palette d'un dessin
historique depuis le CSV, choisir `template` ; l'atelier le fait lors d'une modification.

## Étendre la famille

- `templates.py` décrit les gabarits et réutilise les formes de
  `fork/maquette/icons_gen.py` : cercles raccordés, queue en capsule, bec bicolore,
  œil avec reflet et aile en barres de spectrogramme.
- Chaque gabarit expose les 12 zones `crown`, `cheek`, `throat`, `breast`,
  `belly`, `back`, `wing`, `wing_bar`, `tail`, `beak`, `legs`, `eye`.
- Les six réglages sont bornés à 0,75–1,30. Le dessin est ajusté à la vue
  64 × 64 pour garder les extrémités visibles.
- `taxonomy.json` conserve explicitement les correspondances de genre, famille
  et synonymes. Une espèce sans palette utilise le gabarit gris du genre, puis
  celui de la famille, puis le mystère. Les sources taxonomiques y sont notées.
- Les noms de fichiers viennent du nom scientifique en minuscules et tirets.
  Les identifiants de dégradés et de découpes portent le même préfixe.

Aucun dessin PhyloPic, OpenMoji ou Mulberry n'est utilisé. Les SVG sont dessinés
dans le dépôt ; les planches servent de références de couleurs, sans être
embarquées dans l'application.

## Relecture sur téléphone

Vérifier sur le Xiaomi la reconnaissance à 34 dp, notamment pour les plumages
clairs et les espèces proches. La planche d'ordinateur ne remplace pas un essai
de défilement et de carte avec plusieurs centaines de marqueurs en mode profile.
