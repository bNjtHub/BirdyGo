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