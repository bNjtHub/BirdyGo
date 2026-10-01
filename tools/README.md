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
python tools/fork_world_ranges.py --workers 2          # full run, resumable
python tools/fork_world_ranges.py --species "Hirundo rustica,Apus apus"
python tools/fork_world_ranges.py --build-only         # rebuild from the cache
```

Every GBIF answer is cached in `tools/fork_world_ranges_cache/` (git-ignored),
so a stopped run resumes where it stopped. GBIF answers in 5 to 10 s per
request, 4 requests per species plus 1 match: expect more than a day for the
whole list (2 workers); use `--species-file` to do the priority species first.

Data: GBIF.org occurrence data (CC0 / CC BY 4.0 records only), attribution
"GBIF.org". Natural Earth is public domain.
