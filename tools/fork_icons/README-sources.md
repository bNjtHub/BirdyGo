# Species icon palette sources

`species.csv` contains the first 100 birds (`is_bird == 1`) in `tools/fork_sheets/region_species.csv`, sorted by descending numeric `mean_share` with stable input order for ties, plus `Oriolus oriolus`: 101 rows. French and English names come from that input. Twelve anatomical color fields use uppercase six-digit sRGB hex values.

All 101 rows have a historical color plate that was downloaded and visually inspected on September 27, 2026. `sources.json` records the exact page, image URL, SHA-256 of the viewed scan, selected figure, plumage, and attribution. Downloaded scans and contact sheets remain outside the repository; no raster references are shipped with the app.

## References

- 50 species: J. Lewis Bonhote, *Birds of Britain* (1907), [Project Gutenberg edition 56397](https://www.gutenberg.org/ebooks/56397). The 100 plates were selected by H. E. Dresser from *Birds of Europe*. Dresser is credited for selection, not assumed to be every plate's painter.
- 47 species: *Naturgeschichte der Voegel Mitteleuropas* (1897-1905), edited by Carl R. Hennicke, [University of Hamburg b-online PUBLIC DOMAIN archive](https://www-archiv.fdm.uni-hamburg.de/b-online/birds/naumann.htm). Digitization: Peter v. Sengbusch. Each row identifies volume and plate.
- 2 species: H. E. Dresser, *A History of the Birds of Europe*, [BHL bibliography and public-domain status](https://www.biodiversitylibrary.org/bibliography/53765). `Ardea ibis` uses volume VI, plate 400, figure 1; `Larus michahellis` uses volume VIII, plate 602, the yellow-legged bird in front. Both scans are from Smithsonian copies on Internet Archive.
- `Gallus gallus`: William Jardine, *Gallinaceous Birds*, [Internet Archive copy](https://archive.org/details/gallinaceousbird00jardrich/page/n8/mode/1up), Bankiva Cock vignette engraved by William Home Lizars. The page names Henry G. Bohn; the catalog dates the reprint circa 1845 and marks it `NOT_IN_COPYRIGHT`. Its exact reprint date is uncertain.
- `Streptopelia decaocto`: R. Bowdler Sharpe, *Scientific Results of the Second Yarkand Mission: Aves* (1891), [plate XIV by J. G. Keulemans](https://archive.org/details/Aves00Shar/page/n206/mode/1up), historical `Turtur stoliczkae`. [BHL status](https://www.biodiversitylibrary.org/item/109484): No Known Copyright Issues. The historical taxon is a junior synonym of `Streptopelia decaocto`, also documented in [BirdNET+ taxonomy](https://birdnet.cornell.edu/taxonomy/species/Streptopelia%20decaocto). An additional 1838 monochrome plate was inspected for pattern only and is separately recorded.

## Interpretation and review

Palettes are manually chosen stylizations after viewing the plates, not measurements or automatic color extraction. Historical hand-coloring, scan aging, paper tint, individual plumage, and regional variation limit accuracy. The 12 zones cannot describe every streak, facial mask, wing patch, or seasonal variant. A single representative plumage is named in each row, usually an adult male where the sexes differ. This is an icon design dataset, not an identification key.

Every row remains `draft` pending Benjamin's visual and ornithological review. `reviewed` is reserved for an explicit review; a viewed source alone does not earn that status. `needs_source_review` remains available for later incomplete rows, but no initial row is missing its color reference.

The 14 existing species references in `fork/maquette/icons.json` keep their original brand colors and default SVG appearance. Their historical references are cross-checks; they are not a claim that the legacy colors were extracted from those scans. CSV zones support editable template variants; the exact multicolor gradients and overlapping legacy shapes cannot be losslessly encoded in 12 flat colors.

Historical labels are preserved in the evidence file. For example, `Larus leucophaeus` on Dresser's plate is the selected yellow-legged gull; `Ardea bubulcus` is the selected western cattle egret, and `Turtur stoliczkae` is the selected Eurasian collared dove. Do not substitute a different bird from a shared plate.

Two Naumann archive transcription issues are recorded without silently inventing corrections: the sparrowhawk page prints 1999 for historical volume V, and the goshawk and marsh harrier pages both report plate 54. Exact URLs and image hashes identify the viewed images; these printed plate-number labels deserve independent bibliographic review.

## Offline taxonomy

`taxonomy.json` covers all 240 genera represented by the 443 regional bird rows. `genusFamilies` preserves actual family assignments; `genera` and `families` select visual templates. A similar neutral template is not a taxonomic reassignment. The 28 approximate family mappings are enumerated in `sources.json`; for example, Turdidae uses the muscicapidae silhouette, Pandionidae the accipitridae silhouette, and Tytonidae the strigidae silhouette. Tern genera use the sternidae template while retaining their GBIF family Laridae.

Taxonomic source: GBIF Secretariat (2023), [GBIF Backbone Taxonomy](https://doi.org/10.15468/39omei), [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), queried September 27, 2026. There were 239 exact Aves/genus matches. GBIF returned only the class for `Clanga`; its Accipitridae family was checked against the [ITIS genus record](https://itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&search_value=1253594). Per-genus GBIF usage keys and this explicit override are recorded in `sources.json`. This is a frozen GBIF-based lookup, not a claim of alignment with every current checklist.

The `aliases` map is empty because every nonempty `scientific_name` equals its `canonical_scientific_name` in the supplied `assets/models/taxonomy.csv`. Historical source labels are evidence, not automatically installed runtime aliases: historical names can encompass several modern taxa.

## Data checks

The preparation checks verify 101 unique rows in the required order, 1212 valid hex values, 101 complete and viewed source records with image hashes, all 14 legacy species, 240 regional genera, and template references within the 49-template catalog. These structural checks do not replace visual review.
