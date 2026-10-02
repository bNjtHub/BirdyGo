# Tools

Tracked helper scripts live here so a fresh clone can reproduce the bundled
species assets without relying on ignored `dev/` files.

## Species Bundle Workflow

1. Install Python dependencies:

   ```bash
   pip install -r tools/requirements-species-bundle.txt
   ```

2. Download the public taxonomy export:

   ```bash
   python tools/download_taxonomy_json.py
   ```

3. Rebuild the bundled species assets:

   ```bash
   python tools/build_species_bundle.py
   ```

Full documentation: `docs/developer/species-bundle.md`.

<!-- FORK: region photo pack (fork/PLAN.md J6b) -->
BirdyGo: `--species-list tools/fork_sheets/region_species.csv` bundles photos
for the region's species only, and `--replace-reserved` swaps photos without
an open license for iNaturalist ones (see `tools/fork_species_photos.py`).

<!-- FORK: world map ranges (fork/PLAN.md J7) -->
## World map ranges (BirdyGo)

`tools/fork_world_ranges.py` precomputes `assets/fork/world/ranges.bin.gz`: for
each bird of the model labels, the range class (resident, breeding, wintering,
passage) of every Natural Earth admin-1 region, from GBIF observation counts,
with the same rules as the app (`lib/fork/world_map/`). Standard library only.

```
python tools/fork_world_ranges.py --workers 2          # API route: full run, resumable (slow)
python tools/fork_world_ranges.py --species "Hirundo rustica,Apus apus"
python tools/fork_world_ranges.py --build-only         # rebuild from the cache
```

### SQL route (the bundled file)

The API route is too slow and rate-limited for the whole list. The bundled
`ranges.bin.gz` comes from one GBIF SQL download (GBIF account needed, run on
https://www.gbif.org/occurrence/download, "SQL" tab; DOI of the current one:
`10.15468/dl.yx7895`, also in `WorldMapConfig.gbifDownloadDoi`):

```sql
SELECT species, level1gid, "month", COUNT(*) AS n
FROM occurrence
WHERE "class" = 'Aves' AND basisofrecord = 'HUMAN_OBSERVATION'
  AND occurrencestatus = 'PRESENT' AND hasgeospatialissues = FALSE
  AND "year" >= 2010 AND license IN ('CC0_1_0', 'CC_BY_4_0')
  AND species IS NOT NULL AND level1gid IS NOT NULL
GROUP BY species, level1gid, "month"
```

```
python tools/fork_world_ranges.py --from-sql <download>.zip \
    --fallback-ranges <earlier ranges.bin.gz> --date 20261002
```

No network. The zip is streamed, never extracted (keep it out of git). The
script sums the 12 months into the 4 seasons, takes the effort of a (region,
season) as the sum over all species of the download (the API route counted all
birds, including records without a species rank: a close approximation), then
classifies exactly as above. BirdNET names are matched to the GBIF binomials
by exact name, then `taxonomy.csv`, `SYNONYMS` in the script, Latin gender
endings, and genus moves (same epithet, same order, at least 2 species on the
same genus pair). It prints the match rate and the unmatched species, and
writes `unmatched.json` / `matches.json` in the cache folder. After a rebuild,
update `WorldMapConfig.gbifDownloadDoi` and `gbifDownloadDate`.

Species of the download that are outside the map area (Europe, Africa, West
Asia) get no entry: the app falls back to the geo-model for them.

Every GBIF answer of the API route is cached in `tools/fork_world_ranges_cache/` (git-ignored),
so a stopped run resumes where it stopped. GBIF answers in 5 to 10 s per
request, 4 requests per species plus 1 match: expect more than a day for the
whole list (2 workers); use `--species-file` to do the priority species first.

Data: GBIF.org occurrence data (CC0 / CC BY 4.0 records only), attribution
"GBIF.org". Natural Earth is public domain.

<!-- FORK: species sheets (fork/PLAN.md, Version anglaise) -->
## Species sheets (BirdyGo)

`tools/fork_species_sheets.py` builds the bundled AI sheets. `bundle` and `status`
take `--lang fr|en` (default `fr`): `fr` reads `tools/fork_sheets/fr.jsonl` and writes
`assets/fork/species_sheets_fr.json.gz`; `en` reads `tools/fork_sheets/en.jsonl`
(a translation of the French sheets, same facts and flags) and writes
`assets/fork/species_sheets_en.json.gz` (`"language": "en"`). Same shippable rules.
