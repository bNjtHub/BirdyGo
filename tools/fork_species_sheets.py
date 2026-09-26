#!/usr/bin/env python3
"""Write, check and bundle the French species sheets of BirdyGo (J4b).

The sheets are written by Claude from its own knowledge, with the rule
"leave a section empty rather than guess". The open sources (French
Wikipedia, Wikidata, the geomodel) are only used to check them: sizes
against Wikidata, migration against the geomodel, names against
taxonomy.csv, and, optionally, a second model that lists what contradicts
the Wikipedia article. Flagged sheets ship only once Benjamin has reviewed
them on a local HTML page.

The first 100 sheets were written in a Claude Code session and live in
tools/fork_sheets/fr.jsonl. The rest can be written the same way, or here
with the Message Batches API (half price, needs ANTHROPIC_API_KEY).

Steps, on the PC:
    pip install -r tools/requirements-fork-sheets.txt
    python tools/fork_region_species.py            # needs the LFS models
    python tools/fork_species_sheets.py verify     # free, no API
    python tools/fork_species_sheets.py review     # opens review.html
    python tools/fork_species_sheets.py apply-review review_decisions.json
    python tools/fork_species_sheets.py bundle
    python tools/fork_species_sheets.py status
Optional, with an API key (pick the model and check its price first):
    python tools/fork_species_sheets.py write --model MODEL --limit 50
    python tools/fork_species_sheets.py check --model MODEL

A batch that is still running is resumed, never submitted twice.
Never feed the model texts from the LPO, oiseaux.net or eBird (all rights
reserved); the sheets are written in the model's own words.
"""

import argparse
import csv
import gzip
import json
import random
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
import webbrowser
from datetime import datetime, timezone
from pathlib import Path

for _stream in (sys.stdout, sys.stderr):
    try:
        _stream.reconfigure(encoding="utf-8", errors="replace")
    except (AttributeError, ValueError):
        pass

ROOT = Path(__file__).resolve().parent.parent
SHEETS_DIR = ROOT / "tools" / "fork_sheets"
REGION_CSV = SHEETS_DIR / "region_species.csv"
SHEETS_JSONL = SHEETS_DIR / "fr.jsonl"
CACHE_DIR = SHEETS_DIR / "cache"
SOURCES_DIR = CACHE_DIR / "sources"
STATE_FILE = CACHE_DIR / "state.json"
REVIEW_HTML = SHEETS_DIR / "review.html"
TAXONOMY_CSV = ROOT / "assets" / "models" / "taxonomy.csv"
BUNDLE = ROOT / "assets" / "fork" / "species_sheets_fr.json.gz"

USER_AGENT = "BirdyGo-species-sheets/1.0 (https://github.com/bNjtHub/BirdyGo)"
PILOT_SIZE = 20
MAX_ARTICLE_CHARS = 24_000

# Sections of a sheet, in display order. `hint` feeds the game notebook (J6e).
FIELDS = [
    "summary", "size", "behaviour", "why_here", "migration",
    "by_ear", "confusions", "anecdote", "hint",
]

STATUS_FR = {
    "resident": "Présent toute l'année dans la région.",
    "summer": "Présent surtout à la belle saison : il niche dans la région "
              "et passe l'hiver ailleurs.",
    "winter": "Présent surtout en hiver dans la région.",
    "passage": "Vu surtout au passage, pendant les migrations de printemps "
               "et d'automne.",
    "mixed": "Présence variable selon la saison.",
}
MONTHS_FR = ["janvier", "février", "mars", "avril", "mai", "juin", "juillet",
             "août", "septembre", "octobre", "novembre", "décembre"]

IUCN_FR = {
    "Q211005": "préoccupation mineure (LC)",
    "Q719675": "quasi menacée (NT)",
    "Q278113": "vulnérable (VU)",
    "Q11394": "en danger (EN)",
    "Q219127": "en danger critique (CR)",
    "Q3245245": "données insuffisantes (DD)",
}
# Wikidata units -> (kind, factor to cm or g).
UNITS = {
    "Q174728": ("cm", 1.0), "Q11573": ("cm", 100.0), "Q174789": ("cm", 0.1),
    "Q41803": ("g", 1.0), "Q11570": ("g", 1000.0),
}

SYSTEM_PROMPT = """Tu rédiges les fiches espèces de BirdyGo, une application \
qui reconnaît les oiseaux à leur chant. Les lecteurs sont des familles et des \
curieux, pas des ornithologues. Tu écris à partir de tes connaissances, avec \
tes propres mots. Tu reçois parfois la présence saisonnière calculée par le \
géomodèle BirdNET pour la France et les pays voisins : reste cohérent avec \
elle.

Sections de la fiche :
- summary : qui est cet oiseau, en une ou deux phrases.
- size : taille, envergure et poids, avec les unités (ex. « 14 cm, \
envergure 20 à 22 cm, 16 à 22 g »).
- behaviour : ce qu'il fait (alimentation, comportement).
- why_here : pourquoi on le trouve là (milieux, nourriture, nid).
- migration : sédentaire ou migrateur, quand il arrive et repart en France.
- by_ear : comment le reconnaître à l'oreille (chant, cris).
- confusions : avec quelles espèces on peut le confondre et comment les \
distinguer.
- anecdote : un fait étonnant et vrai.
- hint : un indice de 12 mots au plus pour un jeu de devinettes, sans \
nommer l'espèce ni son genre.

Règles :
1. Seulement ce dont tu es sûr pour cette espèce. Sinon, laisse la section \
vide : une section vide vaut mieux qu'une erreur.
2. Pas de chiffre incertain (dates, tailles, âges, vitesses).
3. Nomme l'espèce uniquement par le nom français donné dans la demande.
4. Style : phrases courtes et vivantes, mots simples, termes techniques \
expliqués. Pas de markdown, pas de liste. Au plus 60 mots par section \
(35 pour summary, 12 pour hint)."""

CHECKER_PROMPT = """Tu compares une fiche d'oiseau avec l'article Wikipédia \
et les données fournies. Liste chaque affirmation de la fiche que ces \
sources contredisent (un chiffre, une période, un milieu, un chant ou un \
comportement différent). Une affirmation simplement absente des sources \
n'est pas une contradiction. Si rien n'est contredit, renvoie une liste \
vide."""

SHEET_SCHEMA = {
    "type": "object",
    "properties": {f: {"type": "string"} for f in FIELDS},
    "required": FIELDS,
    "additionalProperties": False,
}

CHECK_SCHEMA = {
    "type": "object",
    "properties": {
        "contradictions": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "field": {"type": "string", "enum": FIELDS},
                    "claim": {"type": "string"},
                    "source_says": {"type": "string"},
                },
                "required": ["field", "claim", "source_says"],
                "additionalProperties": False,
            },
        },
    },
    "required": ["contradictions"],
    "additionalProperties": False,
}


# ---------------------------------------------------------------------------
# Files
# ---------------------------------------------------------------------------

def custom_id(scientific_name: str) -> str:
    """Batch request id: letters, digits, '_' and '-' only, 64 max."""
    return re.sub(r"[^A-Za-z0-9_-]", "_", scientific_name)[:64]


def load_region(birds_only: bool = True) -> list[dict]:
    if not REGION_CSV.exists():
        sys.exit(f"{REGION_CSV.relative_to(ROOT)} is missing: run "
                 "tools/fork_region_species.py first.")
    with open(REGION_CSV, encoding="utf-8", newline="") as f:
        rows = list(csv.DictReader(f))
    return [r for r in rows if not birds_only or r["is_bird"] == "1"]


def load_taxonomy() -> dict[str, dict]:
    with open(TAXONOMY_CSV, encoding="utf-8", newline="") as f:
        return {row["scientific_name"]: row for row in csv.DictReader(f)}


def load_sheets() -> dict[str, dict]:
    if not SHEETS_JSONL.exists():
        return {}
    sheets = {}
    with open(SHEETS_JSONL, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                sheet = json.loads(line)
                sheets[sheet["scientific_name"]] = sheet
    return sheets


def save_sheets(sheets: dict[str, dict]) -> None:
    SHEETS_JSONL.parent.mkdir(parents=True, exist_ok=True)
    with open(SHEETS_JSONL, "w", encoding="utf-8", newline="\n") as f:
        for name in sorted(sheets):
            f.write(json.dumps(sheets[name], ensure_ascii=False) + "\n")


def load_state() -> dict:
    if STATE_FILE.exists():
        return json.loads(STATE_FILE.read_text(encoding="utf-8"))
    return {}


def save_state(state: dict) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2), encoding="utf-8")


def source_path(scientific_name: str) -> Path:
    return SOURCES_DIR / f"{custom_id(scientific_name)}.json"


def load_source(scientific_name: str) -> dict | None:
    path = source_path(scientific_name)
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def select_species(args) -> list[dict]:
    rows = load_region()
    if args.only:
        wanted = set(args.only)
        rows = [r for r in rows if r["scientific_name"] in wanted]
    elif args.pilot:
        rows = rows[:PILOT_SIZE]
    if args.limit:
        rows = rows[:args.limit]
    return rows


# ---------------------------------------------------------------------------
# Sources: French Wikipedia and Wikidata
# ---------------------------------------------------------------------------

def http_json(url: str, params: dict) -> dict:
    query = urllib.parse.urlencode(params)
    request = urllib.request.Request(f"{url}?{query}",
                                     headers={"User-Agent": USER_AGENT})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except OSError:
            if attempt == 3:
                raise
            time.sleep(2 ** (attempt + 1))
    return {}


def wikidata_entities(ids: list[str]) -> dict:
    data = http_json("https://www.wikidata.org/w/api.php", {
        "action": "wbgetentities", "ids": "|".join(ids),
        "props": "claims|sitelinks", "sitefilter": "frwiki",
        "format": "json",
    })
    return data.get("entities", {})


def taxon_names(entity: dict) -> set[str]:
    names = set()
    for claim in entity.get("claims", {}).get("P225", []):
        value = claim.get("mainsnak", {}).get("datavalue", {}).get("value")
        if isinstance(value, str):
            names.add(value)
    return names


def find_wikidata(scientific_name: str) -> dict | None:
    """Wikidata item whose taxon name (P225) is the scientific name."""
    found = http_json("https://www.wikidata.org/w/api.php", {
        "action": "wbsearchentities", "search": scientific_name,
        "language": "en", "type": "item", "limit": 7, "format": "json",
    })
    ids = [hit["id"] for hit in found.get("search", [])]
    if not ids:
        return None
    for qid, entity in wikidata_entities(ids).items():
        if scientific_name in taxon_names(entity):
            entity["id"] = qid
            return entity
    return None


def wikipedia_page(title: str) -> dict | None:
    data = http_json("https://fr.wikipedia.org/w/api.php", {
        "action": "query", "format": "json", "formatversion": 2,
        "redirects": 1, "titles": title,
        "prop": "extracts|revisions|pageprops", "explaintext": 1,
        "rvprop": "ids", "ppprop": "wikibase_item|disambiguation",
    })
    pages = data.get("query", {}).get("pages", [])
    if not pages or pages[0].get("missing"):
        return None
    page = pages[0]
    if "disambiguation" in page.get("pageprops", {}):
        return None
    return page


def quantities(entity: dict, prop: str) -> list[tuple[str, float]]:
    values = []
    for claim in entity.get("claims", {}).get(prop, []):
        value = claim.get("mainsnak", {}).get("datavalue", {}).get("value")
        if not isinstance(value, dict) or "amount" not in value:
            continue
        unit = value.get("unit", "").rsplit("/", 1)[-1]
        if unit in UNITS:
            kind, factor = UNITS[unit]
            values.append((kind, round(float(value["amount"]) * factor, 1)))
    return values


def wikidata_facts(entity: dict) -> dict:
    iucn = None
    for claim in entity.get("claims", {}).get("P141", []):
        value = claim.get("mainsnak", {}).get("datavalue", {}).get("value")
        if isinstance(value, dict):
            iucn = IUCN_FR.get(value.get("id")) or iucn
    return {
        "qid": entity.get("id"),
        "length_cm": [v for k, v in quantities(entity, "P2043") if k == "cm"],
        "wingspan_cm": [v for k, v in quantities(entity, "P2050") if k == "cm"],
        "mass_g": [v for k, v in quantities(entity, "P2067") if k == "g"],
        "iucn": iucn,
    }


def collect_one(row: dict, taxonomy: dict) -> dict:
    sci = row["scientific_name"]
    tax = taxonomy.get(sci, {})
    name_fr = tax.get("common_name_fr") or row.get("common_name_fr") or sci
    entity = find_wikidata(sci)
    page = None
    title = (entity or {}).get("sitelinks", {}).get("frwiki", {}).get("title")
    if title:
        page = wikipedia_page(title)
    if page is None:
        # No Wikidata link: try the French and scientific names, and keep
        # the page only if its Wikidata item has the right taxon name.
        for candidate in (name_fr, sci):
            page = wikipedia_page(candidate)
            qid = (page or {}).get("pageprops", {}).get("wikibase_item")
            if page and qid:
                entity = wikidata_entities([qid]).get(qid)
                if entity and sci in taxon_names(entity):
                    entity["id"] = qid
                    break
            page = None
    wikipedia = None
    if page:
        revid = page.get("revisions", [{}])[0].get("revid")
        wikipedia = {
            "title": page["title"],
            "revid": revid,
            "url": f"https://fr.wikipedia.org/w/index.php?oldid={revid}",
            "extract": clean_extract(page.get("extract", "")),
        }
    weekly = [float(v) for v in row.get("weekly", "").split()]
    return {
        "scientific_name": sci,
        "birdnet_id": tax.get("birdnet_id", row.get("birdnet_id", "")),
        "name_fr": name_fr,
        "wikipedia": wikipedia,
        "wikidata": wikidata_facts(entity) if entity else None,
        "status": row.get("status", "mixed"),
        "weekly": weekly,
        "collected": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }


def clean_extract(text: str) -> str:
    """Drops the reference sections and trims very long articles."""
    cut = re.search(r"\n(Notes et références|Références|Voir aussi|"
                    r"Annexes|Liens externes|Bibliographie)\n", text)
    if cut:
        text = text[:cut.start()]
    text = re.sub(r"\n{3,}", "\n\n", text).strip()
    return text[:MAX_ARTICLE_CHARS]


# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------

def presence_months(weekly: list[float]) -> str | None:
    """Months where the geomodel expects the species most, in French."""
    if len(weekly) != 48 or max(weekly) <= 0:
        return None
    peak = max(weekly)
    months = [MONTHS_FR[m] for m in range(12)
              if max(weekly[m * 4:m * 4 + 4]) >= 0.5 * peak]
    if len(months) == 12:
        return "toute l'année"
    return ", ".join(months)


def presence_text(status: str, weekly: list[float]) -> str:
    lines = [STATUS_FR.get(status, STATUS_FR["mixed"])]
    months = presence_months(weekly)
    if months:
        lines.append(f"Mois où il est le plus attendu : {months}.")
    return "\n".join(lines)


def wikidata_lines(facts: dict | None) -> list[str]:
    if not facts:
        return []

    def span(values, unit):
        low, high = min(values), max(values)
        fmt = lambda v: f"{v:g}".replace(".", ",")
        return f"{fmt(low)} {unit}" if low == high else \
            f"{fmt(low)} à {fmt(high)} {unit}"

    lines = []
    if facts.get("length_cm"):
        lines.append(f"Longueur : {span(facts['length_cm'], 'cm')}.")
    if facts.get("wingspan_cm"):
        lines.append(f"Envergure : {span(facts['wingspan_cm'], 'cm')}.")
    if facts.get("mass_g"):
        lines.append(f"Masse : {span(facts['mass_g'], 'g')}.")
    if facts.get("iucn"):
        lines.append(f"Statut UICN : {facts['iucn']}.")
    return lines


def sources_text(source: dict) -> str:
    """The open sources of a species, as given to the checking model."""
    parts = []
    wiki = source.get("wikipedia")
    if wiki:
        parts.append(f"Article Wikipédia « {wiki['title']} »\n"
                     f"{wiki['extract']}")
    lines = wikidata_lines(source.get("wikidata"))
    if lines:
        parts.append("Wikidata\n" + "\n".join(lines))
    parts.append("Présence calculée par le géomodèle BirdNET\n"
                 + presence_text(source.get("status", "mixed"),
                                 source.get("weekly", [])))
    return "\n\n".join(parts)


def writer_request(row: dict, name_fr: str, model: str):
    from anthropic.types.message_create_params import (
        MessageCreateParamsNonStreaming)
    from anthropic.types.messages.batch_create_params import Request

    weekly = [float(v) for v in row.get("weekly", "").split()]
    presence = presence_text(row.get("status", "mixed"), weekly)
    user = (f"Espèce : {name_fr} ({row['scientific_name']}).\n\n"
            f"Présence calculée par le géomodèle BirdNET :\n{presence}\n\n"
            "Rédige la fiche.")
    return Request(
        custom_id=custom_id(row["scientific_name"]),
        params=MessageCreateParamsNonStreaming(
            model=model,
            max_tokens=12000,
            # The shared instructions are cached across the batch.
            system=[{"type": "text", "text": SYSTEM_PROMPT,
                     "cache_control": {"type": "ephemeral"}}],
            thinking={"type": "adaptive"},
            output_config={
                "effort": "medium",
                "format": {"type": "json_schema", "schema": SHEET_SCHEMA},
            },
            messages=[{"role": "user", "content": user}],
        ),
    )


def checker_request(source: dict, sheet: dict, model: str):
    from anthropic.types.message_create_params import (
        MessageCreateParamsNonStreaming)
    from anthropic.types.messages.batch_create_params import Request

    texts = "\n".join(f"{field} : {sheet['fields'][field]}"
                      for field in FIELDS if sheet["fields"].get(field))
    user = (f"Sources :\n\n{sources_text(source)}\n\n"
            f"Fiche de {sheet['name']} :\n{texts}")
    return Request(
        custom_id=custom_id(sheet["scientific_name"]),
        params=MessageCreateParamsNonStreaming(
            model=model,
            max_tokens=8000,
            system=[{"type": "text", "text": CHECKER_PROMPT,
                     "cache_control": {"type": "ephemeral"}}],
            output_config={
                "effort": "medium",
                "format": {"type": "json_schema", "schema": CHECK_SCHEMA},
            },
            messages=[{"role": "user", "content": user}],
        ),
    )


# ---------------------------------------------------------------------------
# Free checks
# ---------------------------------------------------------------------------

def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", text).lower()
    text = (text.replace("’", "'").replace("‘", "'")
            .replace("–", "-").replace("—", "-"))
    return re.sub(r"\s+", " ", text).strip(" .…")


def numbers_with_unit(text: str, unit: str) -> list[float]:
    """Numbers followed (directly or after a range) by the unit."""
    values = []
    pattern = (r"(\d+(?:[.,]\d+)?)(?:\s*(?:à|-|–)\s*(\d+(?:[.,]\d+)?))?"
               rf"\s*{unit}\b")
    for match in re.finditer(pattern, text):
        for group in match.groups():
            if group:
                values.append(float(group.replace(",", ".")))
    return values


def size_consistent(text: str, facts: dict | None) -> bool:
    """Every cm and g figure is within a wide margin of the Wikidata ones."""
    if not facts or not text:
        return True
    lengths = facts.get("length_cm", []) + facts.get("wingspan_cm", [])
    for unit, reference in (("cm", lengths), ("g", facts.get("mass_g", []))):
        if not reference:
            continue
        low, high = 0.5 * min(reference), 1.5 * max(reference)
        if any(not low <= v <= high for v in numbers_with_unit(text, unit)):
            return False
    return True


MIGRATION_CONFLICTS = {
    "resident": ["uniquement en été", "absent en hiver", "quitte la france",
                 "n'hiverne pas en france"],
    "summer": ["sédentaire", "toute l'année"],
    "winter": ["niche en france", "sédentaire"],
}


def migration_consistent(text: str, status: str) -> bool:
    words = normalize(text)
    return not any(w in words for w in MIGRATION_CONFLICTS.get(status, []))


def free_checks(sheet: dict, source: dict | None, status: str | None,
                taxonomy_name: str | None) -> list[str]:
    """Flags from Wikidata, the geomodel and taxonomy.csv."""
    fields = sheet["fields"]
    flags = []
    if taxonomy_name and sheet["name"] != taxonomy_name:
        flags.append("name_vs_taxonomy")
    if source and not size_consistent(fields.get("size", ""),
                                      source.get("wikidata")):
        flags.append("size_vs_wikidata")
    if status and not migration_consistent(fields.get("migration", ""),
                                           status):
        flags.append("migration_vs_geomodel")
    title = re.sub(r"\s*\(.*\)$", "",
                   ((source or {}).get("wikipedia") or {}).get("title", ""))
    if title and normalize(title) != normalize(sheet["name"]):
        if normalize(title) in normalize(" ".join(fields.values())):
            flags.append("name_mismatch")
    return flags


def cmd_verify(args) -> None:
    """Fetches the open sources (cached) and runs the free checks."""
    taxonomy = load_taxonomy()
    region = {}
    if REGION_CSV.exists():
        region = {r["scientific_name"]: r for r in load_region(False)}
    sheets = load_sheets()
    todo = [s for s in sorted(sheets)
            if args.all or not sheets[s].get("verified")]
    SOURCES_DIR.mkdir(parents=True, exist_ok=True)
    for i, sci in enumerate(todo, 1):
        row = region.get(sci, {"scientific_name": sci})
        source = None if args.refresh else load_source(sci)
        if source is None:
            print(f"[{i}/{len(todo)}] {sci}")
            try:
                source = collect_one(row, taxonomy)
            except OSError as error:
                print(f"   network error, will retry next run: {error}")
                continue
            source_path(sci).write_text(
                json.dumps(source, ensure_ascii=False, indent=1),
                encoding="utf-8")
            time.sleep(0.2)  # Be gentle with the Wikimedia APIs.
        sheet = sheets[sci]
        kept = [f for f in sheet["flags"] if f.startswith("contradiction:")]
        sheet["flags"] = kept + free_checks(
            sheet, source, row.get("status"),
            taxonomy.get(sci, {}).get("common_name_fr"))
        sheet["verified"] = True
        wiki = source.get("wikipedia")
        if wiki:
            sheet["wikipedia"] = {"title": wiki["title"],
                                  "revid": wiki["revid"]}
    save_sheets(sheets)
    cmd_status(args)


# ---------------------------------------------------------------------------
# Batches (optional, needs ANTHROPIC_API_KEY)
# ---------------------------------------------------------------------------

def estimate(requests, output_tokens: int) -> None:
    chars = sum(len(json.dumps(r["params"]["messages"], ensure_ascii=False))
                for r in requests)
    input_tokens = chars / 3.2 + 1200 * len(requests)
    output = output_tokens * len(requests)
    print(f"{len(requests)} requests, about {input_tokens / 1e6:.2f} M input "
          f"and {output / 1e6:.2f} M output tokens (thinking included). "
          "Batches cost half the model's list price.")


def confirm(args) -> bool:
    if args.yes:
        return True
    return input("Submit the batch? [y/N] ").strip().lower() in ("y", "yes",
                                                                 "o", "oui")


def run_batch(kind: str, requests, species: list[str], model: str, args):
    """Submits (or resumes) a batch and yields (species, result) pairs."""
    import anthropic

    client = anthropic.Anthropic()
    state = load_state()
    pending = state.get(kind)
    if pending:
        print(f"Resuming {kind} batch {pending['id']}.")
    else:
        if not requests:
            print("Nothing to do.")
            return
        estimate(requests, 3000 if kind == "write" else 800)
        if not confirm(args):
            return
        batch = client.messages.batches.create(requests=requests)
        pending = {"id": batch.id, "model": model, "species": species}
        state[kind] = pending
        save_state(state)
        print(f"Batch {batch.id} submitted.")
    while True:
        batch = client.messages.batches.retrieve(pending["id"])
        if batch.processing_status == "ended":
            break
        counts = batch.request_counts
        print(f"  {batch.processing_status}: {counts.processing} processing, "
              f"{counts.succeeded} done (Ctrl+C is safe, re-run to resume)")
        time.sleep(60)
    by_id = {custom_id(s): s for s in pending["species"]}
    for result in client.messages.batches.results(pending["id"]):
        yield by_id.get(result.custom_id), result, pending["model"]
    state = load_state()
    state.pop(kind, None)
    save_state(state)


def result_json(result) -> tuple[dict | None, str | None]:
    """Parsed JSON of a batch result, or None and the reason."""
    if result.result.type != "succeeded":
        return None, result.result.type
    message = result.result.message
    if message.stop_reason in ("refusal", "max_tokens"):
        return None, message.stop_reason
    text = next((b.text for b in message.content if b.type == "text"), "")
    try:
        return json.loads(text), None
    except json.JSONDecodeError:
        return None, "invalid_json"


def cmd_write(args) -> None:
    sheets = load_sheets()
    taxonomy = load_taxonomy()
    requests, species = [], []
    if not load_state().get("write"):
        for row in select_species(args):
            sci = row["scientific_name"]
            if sci in sheets and not args.redo:
                continue
            name = taxonomy.get(sci, {}).get("common_name_fr") or sci
            requests.append(writer_request(row, name, args.model))
            species.append(sci)
    failed = []
    for sci, result, model in run_batch("write", requests, species,
                                        args.model, args):
        data, error = result_json(result)
        if sci is None or data is None:
            failed.append(f"{sci} ({error})")
            continue
        sheets[sci] = {
            "scientific_name": sci,
            "name": taxonomy.get(sci, {}).get("common_name_fr") or sci,
            "fields": {f: data.get(f, "").strip() for f in FIELDS},
            "model": model,
            "generated": datetime.now(timezone.utc).date().isoformat(),
            "flags": [],
            "verified": False,
            "relue": False,
        }
        save_sheets(sheets)
    if failed:
        print(f"Not written, re-run `write` to retry: {', '.join(failed)}")
    cmd_status(args)


def cmd_check(args) -> None:
    sheets = load_sheets()
    requests, species = [], []
    if not load_state().get("check"):
        for sci, sheet in sorted(sheets.items()):
            if sheet.get("checked") or sheet["relue"]:
                continue
            source = load_source(sci)
            if source is None or source.get("wikipedia") is None:
                continue  # Run `verify` first; no article, nothing to check.
            requests.append(checker_request(source, sheet, args.model))
            species.append(sci)
    failed = []
    for sci, result, model in run_batch("check", requests, species,
                                        args.model, args):
        data, error = result_json(result)
        if sci not in sheets or data is None:
            failed.append(f"{sci} ({error})")
            continue
        sheet = sheets[sci]
        sheet["contradictions"] = data["contradictions"]
        sheet["flags"] = [f for f in sheet["flags"]
                          if not f.startswith("contradiction:")]
        for field in sorted({c["field"] for c in data["contradictions"]}):
            sheet["flags"].append(f"contradiction:{field}")
        sheet["checked"] = True
        save_sheets(sheets)
    if failed:
        print(f"Not checked, re-run `check` to retry: {', '.join(failed)}")
    cmd_status(args)


# ---------------------------------------------------------------------------
# Review, bundle, status
# ---------------------------------------------------------------------------

def shippable(sheet: dict) -> bool:
    """Reviewed sheets, and the others as long as nothing flagged them."""
    if sheet.get("rejected"):
        return False
    return sheet["relue"] or not sheet["flags"]


def review_selection(sheets: dict, args) -> list[str]:
    order = [r["scientific_name"] for r in load_region()] \
        if REGION_CSV.exists() else sorted(sheets)
    if args.heard:
        heard = [line.strip() for line in
                 Path(args.heard).read_text(encoding="utf-8").splitlines()]
        order = [s for s in heard if s] + order
    todo = {s for s, sheet in sheets.items()
            if not sheet["relue"] and not sheet.get("rejected")}
    if args.all:
        return [s for s in dict.fromkeys(order) if s in todo]
    selected = []
    for sci in dict.fromkeys(order):
        if sci in todo and len(selected) < args.top:
            selected.append(sci)
    selected += [s for s in sorted(todo)
                 if sheets[s]["flags"] and s not in selected]
    others = sorted(todo - set(selected))
    rng = random.Random(args.seed)
    selected += rng.sample(others, round(len(others) * args.sample))
    return selected


REVIEW_PAGE = """<!doctype html>
<html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Relecture des fiches</title>
<style>
:root { color-scheme: light dark; --muted: #777; --ok: #2e7d32;
  --ko: #c62828; --flag: #b26a00; }
body { font: 16px/1.5 system-ui, sans-serif; max-width: 860px;
  margin: 0 auto; padding: 16px; }
header { position: sticky; top: 0; background: Canvas; padding: 8px 0;
  border-bottom: 1px solid #8884; display: flex; gap: 12px;
  align-items: center; flex-wrap: wrap; }
article { border: 1px solid #8886; border-radius: 12px; padding: 16px;
  margin: 16px 0; }
article.ok { border-color: var(--ok); } article.ko { border-color: var(--ko); }
h2 { margin: 0; font-size: 20px; } .sci { color: var(--muted);
  font-style: italic; } .flags { color: var(--flag); font-size: 14px; }
label { display: block; font-weight: 600; margin-top: 12px; font-size: 14px; }
textarea { width: 100%; box-sizing: border-box; font: inherit;
  min-height: 3.2em; }
.actions { display: flex; gap: 8px; margin-top: 16px; }
button { font: inherit; padding: 6px 14px; border-radius: 8px; }
</style></head><body>
<header><strong>Relecture des fiches</strong>
<span id="progress"></span>
<button id="export">Télécharger les décisions</button></header>
<p>Corrige le texte si besoin, puis « Bonne fiche » ou « À refaire ».
Les signalements sont en orange. Tes choix restent dans ce navigateur
jusqu'au téléchargement.</p>
<main id="list"></main>
<script>
const SHEETS = __SHEETS__;
const LABELS = __LABELS__;
const KEY = "birdygo-review";
let decisions = {};
try { decisions = JSON.parse(localStorage.getItem(KEY) || "{}"); } catch {}
const save = () => {
  try { localStorage.setItem(KEY, JSON.stringify(decisions)); } catch {}
  progress();
};
const progress = () => {
  const done = SHEETS.filter(s => decisions[s.scientific_name]?.status).length;
  document.getElementById("progress").textContent =
    done + " / " + SHEETS.length + " relues";
};
const list = document.getElementById("list");
for (const sheet of SHEETS) {
  const sci = sheet.scientific_name;
  const d = decisions[sci] || (decisions[sci] = { fields: {} });
  const card = document.createElement("article");
  const head = document.createElement("div");
  head.innerHTML = "<h2></h2><div class=sci></div><div class=flags></div>" +
    "<a target=_blank rel=noopener>Article Wikipédia (révision)</a>";
  head.querySelector("h2").textContent = sheet.name;
  head.querySelector(".sci").textContent = sci;
  head.querySelector(".flags").textContent = sheet.flags.join(" · ") +
    (sheet.contradictions || []).map(c => " — " + c.field + " : « " +
      c.claim + " », Wikipédia : « " + c.source_says + " »").join("");
  const link = head.querySelector("a");
  if (sheet.wikipedia) link.href = "https://fr.wikipedia.org/w/index.php?oldid=" +
    sheet.wikipedia.revid; else link.remove();
  card.appendChild(head);
  for (const field of Object.keys(LABELS)) {
    const label = document.createElement("label");
    label.textContent = LABELS[field];
    const area = document.createElement("textarea");
    area.value = d.fields[field] ?? sheet.fields[field] ?? "";
    area.addEventListener("input", () => {
      d.fields[field] = area.value; save();
    });
    card.append(label, area);
  }
  const actions = document.createElement("div");
  actions.className = "actions";
  for (const [status, text] of [["ok", "Bonne fiche"], ["ko", "À refaire"]]) {
    const button = document.createElement("button");
    button.textContent = text;
    button.addEventListener("click", () => {
      d.status = status; card.className = status; save();
    });
    actions.appendChild(button);
  }
  card.className = d.status || "";
  card.appendChild(actions);
  list.appendChild(card);
}
document.getElementById("export").addEventListener("click", () => {
  const blob = new Blob([JSON.stringify(decisions, null, 1)],
    { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "review_decisions.json";
  a.click();
});
progress();
</script></body></html>
"""

REVIEW_LABELS = {
    "summary": "En bref", "size": "Taille", "behaviour": "Ce qu'il fait",
    "why_here": "Pourquoi il est là", "migration": "Migration",
    "by_ear": "À l'oreille", "confusions": "Confusions possibles",
    "anecdote": "Le saviez-vous ?", "hint": "Indice du carnet (jeu)",
}


def cmd_review(args) -> None:
    sheets = load_sheets()
    selected = review_selection(sheets, args)
    payload = [sheets[s] for s in selected]
    page = (REVIEW_PAGE
            .replace("__SHEETS__", json.dumps(payload, ensure_ascii=False)
                     .replace("</", "<\\/"))
            .replace("__LABELS__", json.dumps(REVIEW_LABELS,
                                              ensure_ascii=False)))
    REVIEW_HTML.write_text(page, encoding="utf-8")
    print(f"{len(selected)} sheets to review in "
          f"{REVIEW_HTML.relative_to(ROOT)}")
    if not args.no_open:
        webbrowser.open(REVIEW_HTML.as_uri())


def cmd_apply_review(args) -> None:
    sheets = load_sheets()
    decisions = json.loads(Path(args.decisions).read_text(encoding="utf-8"))
    applied = 0
    for sci, decision in decisions.items():
        sheet = sheets.get(sci)
        status = decision.get("status")
        if sheet is None or status not in ("ok", "ko"):
            continue
        for field, text in decision.get("fields", {}).items():
            if field in sheet["fields"]:
                sheet["fields"][field] = text.strip()
        sheet["relue"] = status == "ok"
        sheet["rejected"] = status == "ko"
        applied += 1
    save_sheets(sheets)
    print(f"{applied} decisions applied to {SHEETS_JSONL.relative_to(ROOT)}")


def bundle_payload(sheets: dict) -> dict:
    species = {}
    for sci, sheet in sorted(sheets.items()):
        if not shippable(sheet):
            continue
        entry = {"name": sheet["name"]}
        for field in FIELDS:
            text = sheet["fields"].get(field, "")
            if text:
                entry[field] = text
        species[sci] = entry
    return {"version": 1, "language": "fr", "species": species}


def cmd_bundle(args) -> None:
    payload = bundle_payload(load_sheets())
    BUNDLE.parent.mkdir(parents=True, exist_ok=True)
    data = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    # mtime=0 keeps the file identical from one run to the next.
    with open(BUNDLE, "wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", mtime=0) as f:
            f.write(data.encode("utf-8"))
    print(f"{len(payload['species'])} sheets -> {BUNDLE.relative_to(ROOT)} "
          f"({BUNDLE.stat().st_size / 1024:.0f} KB)")


def cmd_status(args) -> None:
    sheets = load_sheets()
    region = load_region() if REGION_CSV.exists() else []
    sources = len(list(SOURCES_DIR.glob("*.json"))) if SOURCES_DIR.exists() \
        else 0
    counts = {
        "region birds": len(region),
        "sources collected": sources,
        "sheets written": len(sheets),
        "verified": sum(bool(s.get("verified")) for s in sheets.values()),
        "checked": sum(bool(s.get("checked")) for s in sheets.values()),
        "flagged": sum(bool(s["flags"]) for s in sheets.values()),
        "reviewed": sum(s["relue"] for s in sheets.values()),
        "to redo": sum(bool(s.get("rejected")) for s in sheets.values()),
        "shippable": sum(shippable(s) for s in sheets.values()),
    }
    for label, value in counts.items():
        print(f"{label:>18}: {value}")
    pending = {k: v["id"] for k, v in load_state().items()}
    if pending:
        print(f"Pending batches: {pending}")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="BirdyGo species sheets (J4b).",
        formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    def species_args(p):
        p.add_argument("--pilot", action="store_true",
                       help=f"only the {PILOT_SIZE} most common birds")
        p.add_argument("--only", nargs="+", metavar="SCIENTIFIC_NAME")
        p.add_argument("--limit", type=int)

    p = sub.add_parser("verify", help="free checks with Wikidata, the "
                                      "geomodel and taxonomy.csv")
    p.add_argument("--all", action="store_true",
                   help="also re-check sheets already verified")
    p.add_argument("--refresh", action="store_true",
                   help="fetch the sources again")
    p.set_defaults(func=cmd_verify)

    p = sub.add_parser("write", help="write the sheets (Batches API)")
    species_args(p)
    p.add_argument("--model", required=True,
                   help="Claude model id; check its price first")
    p.add_argument("--redo", action="store_true",
                   help="rewrite sheets that already exist")
    p.add_argument("--yes", action="store_true")
    p.set_defaults(func=cmd_write)

    p = sub.add_parser("check", help="second pass with a cheaper model")
    p.add_argument("--model", required=True,
                   help="a cheaper Claude model id")
    p.add_argument("--yes", action="store_true")
    p.set_defaults(func=cmd_check)

    p = sub.add_parser("review", help="build the local review page")
    p.add_argument("--top", type=int, default=100)
    p.add_argument("--sample", type=float, default=0.1)
    p.add_argument("--seed", type=int, default=1)
    p.add_argument("--heard", help="text file, one scientific name per "
                                   "line, most heard first")
    p.add_argument("--all", action="store_true")
    p.add_argument("--no-open", action="store_true")
    p.set_defaults(func=cmd_review)

    p = sub.add_parser("apply-review", help="apply review_decisions.json")
    p.add_argument("decisions")
    p.set_defaults(func=cmd_apply_review)

    p = sub.add_parser("bundle", help="write the app asset")
    p.set_defaults(func=cmd_bundle)

    p = sub.add_parser("status", help="progress summary")
    p.set_defaults(func=cmd_status)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
