"""Geometric templates for the BirdyGo species icon generator.

The geometry deliberately reuses the construction helpers from the approved
maquette.  Every template faces left and keeps the logo grammar: joined round
head/body, capsule tail, two-tone beak, glinting eye and spectrogram wing.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass
import html
import math
import re
from typing import Mapping

from fork.maquette import icons_gen as legacy
from tools.fork_icons.species_patterns import species_marks


ZONES = (
    "crown",
    "cheek",
    "throat",
    "breast",
    "belly",
    "back",
    "wing",
    "wing_bar",
    "tail",
    "beak",
    "legs",
    "eye",
)

MORPHOLOGY_CONTROLS = (
    "head_scale",
    "body_scale",
    "beak_length",
    "tail_length",
    "wing_scale",
    "leg_length",
)

ADJUSTMENT_MIN = 0.75
ADJUSTMENT_MAX = 1.30


@dataclass(frozen=True)
class BirdTemplate:
    id: str
    label: str
    kind: str
    head_x: float
    head_y: float
    head_r: float
    body_x: float
    body_y: float
    body_r: float
    beak_length: float
    beak_depth: float
    tail_length: float
    tail_angle: float
    tail_width: float
    wing_x: float
    wing_y: float
    wing_scale: float
    leg_length: float


def _t(
    template_id: str,
    label: str,
    kind: str,
    head: tuple[float, float, float],
    body: tuple[float, float, float],
    beak: tuple[float, float],
    tail: tuple[float, float, float],
    wing: tuple[float, float, float],
    leg: float,
) -> BirdTemplate:
    return BirdTemplate(
        template_id,
        label,
        kind,
        *head,
        *body,
        *beak,
        *tail,
        *wing,
        leg,
    )


# Family-level silhouettes. Close families intentionally share the
# visual grammar, while proportions encode their useful field silhouette.
_TEMPLATES = (
    _t("acrocephalidae", "Rousserolles", "slender", (19, 24, 9), (32, 37, 14), (8, 2.5), (17, -25, 3.4), (32, 37, .94), 7),
    _t("aegithalidae", "Mésanges à longue queue", "round", (24, 23, 12), (34, 38, 16), (5, 3), (24, -28, 3), (34, 38, .94), 6),
    _t("accipitridae", "Rapaces", "raptor", (21, 22, 10), (34, 37, 17), (9, 4), (14, -25, 4.5), (34, 37, 1.15), 8),
    _t("alaudidae", "Alouettes", "passerine", (21, 24, 10), (33, 38, 15), (7, 3), (14, -18, 3.4), (32, 38, .92), 7),
    _t("alcedinidae", "Martins-pêcheurs", "longbill", (25, 24, 11.5), (35, 38, 13), (14, 3), (9, 48, 3.8), (37, 38, .94), 5),
    _t("alcidae", "Alcidés", "seabird", (20, 22, 11), (33, 39, 16), (8, 5), (7, 70, 3.8), (33, 39, .80), 5),
    _t("anatidae", "Canards, oies et cygnes", "waterbird", (18, 25, 9), (37, 38, 18), (10, 5), (9, 15, 4.5), (36, 38, 1.10), 5),
    _t("apodidae", "Martinets", "aerial", (21, 27, 8), (34, 36, 13), (5, 2.5), (24, -25, 2.5), (33, 36, 1.30), 3),
    _t("ardeidae", "Hérons", "wader", (17, 17, 8), (36, 39, 15), (14, 3), (10, 30, 3.5), (36, 39, .95), 14),
    _t("caprimulgidae", "Engoulevents", "ground", (20, 28, 9), (36, 38, 17), (5, 4), (18, -5, 4.2), (36, 38, 1.18), 3),
    _t("certhiidae", "Grimpereaux", "climber", (21, 22, 8), (28, 37, 13), (10, 2), (17, 112, 3), (29, 38, .82), 7),
    _t("charadriidae", "Pluviers", "shorebird", (19, 26, 9), (35, 39, 15), (6, 3), (8, 8, 3.5), (34, 39, .90), 10),
    _t("ciconiidae", "Cigognes", "wader", (16, 15, 7), (37, 39, 16), (17, 3), (9, 25, 3.5), (37, 39, 1.00), 16),
    _t("columbidae", "Pigeons et tourterelles", "pigeon", (21, 23, 10), (35, 38, 18), (5, 3), (13, -12, 4.5), (35, 38, 1.08), 6),
    _t("coraciidae", "Rolliers", "perching", (21, 23, 11), (35, 38, 16), (8, 3.5), (14, -16, 4), (35, 38, 1.05), 6),
    _t("corvidae", "Corvidés", "corvid", (19, 23, 11), (34, 37, 17), (10, 4), (21, -30, 4.2), (34, 37, 1.14), 7),
    _t("cuculidae", "Coucous", "longbird", (19, 23, 9), (34, 37, 15), (8, 3), (24, -18, 3.8), (34, 37, 1.10), 6),
    _t("falconidae", "Faucons", "raptor", (20, 22, 9), (33, 37, 15), (8, 4), (15, -28, 3.6), (33, 37, 1.12), 7),
    _t("emberizidae", "Bruants", "passerine", (22, 23, 11), (34, 38, 17), (7, 5), (15, -22, 3.8), (34, 38, 1.04), 7),
    _t("fringillidae", "Fringilles", "passerine", (23, 23, 12), (34, 37, 17), (6, 5), (13, -28, 4), (34, 38, 1.02), 6),
    _t("gruidae", "Grues", "wader", (16, 13, 7), (37, 38, 17), (13, 3), (10, 22, 3.8), (37, 38, 1.05), 17),
    _t("hirundinidae", "Hirondelles", "aerial", (20, 26, 8), (34, 36, 13), (5, 2.5), (22, -18, 2.7), (33, 36, 1.25), 3),
    _t("laridae", "Mouettes et goélands", "seabird", (20, 23, 9), (36, 38, 17), (11, 3), (12, 4, 4), (36, 38, 1.12), 6),
    _t("meropidae", "Guêpiers", "longbill", (20, 25, 9), (35, 38, 15), (14, 2.5), (19, -24, 3.2), (35, 38, 1.05), 6),
    _t("motacillidae", "Bergeronnettes et pipits", "slender", (19, 25, 9), (32, 37, 14), (7, 2.5), (23, -18, 3.2), (32, 37, .96), 9),
    _t("muscicapidae", "Gobemouches et traquets", "passerine", (23, 23, 11), (34, 37, 17), (7, 3), (14, -38, 4), (34, 38, 1.02), 6),
    _t("oriolidae", "Loriots", "slender", (20, 24, 10), (32, 36, 15), (8, 3), (17, -32, 4), (32, 36, 1.08), 6),
    _t("paridae", "Mésanges", "passerine", (24, 22, 12.5), (34, 37, 18), (6, 3.5), (14, -50, 4), (34, 38, 1.02), 6),
    _t("passeridae", "Moineaux", "passerine", (23, 23, 12), (34, 37, 18), (6, 5), (14, -30, 4), (34, 38, 1.04), 6),
    _t("pelecanidae", "Pélicans", "waterbird", (17, 18, 9), (38, 39, 18), (16, 7), (8, 25, 4.5), (38, 39, 1.05), 7),
    _t("phalacrocoracidae", "Cormorans", "waterbird", (17, 18, 8), (36, 38, 16), (12, 4), (13, 28, 3.5), (36, 38, 1.00), 6),
    _t("phasianidae", "Gallinacés", "ground", (20, 23, 9), (37, 40, 19), (6, 3.5), (15, 4, 4.5), (37, 40, 1.08), 8),
    _t("phoenicopteridae", "Flamants", "wader", (15, 13, 7), (38, 40, 16), (14, 5), (7, 25, 3.5), (38, 40, .90), 18),
    _t("picidae", "Pics", "climber", (23, 18, 9.5), (28, 36, 13), (8, 3), (16, 125, 4), (29, 38, .82), 7),
    _t("podicipedidae", "Grèbes", "waterbird", (19, 24, 9), (36, 40, 16), (8, 3), (5, 65, 3.5), (36, 40, .90), 3),
    _t("phylloscopidae", "Pouillots", "slender", (20, 25, 9.5), (31, 36, 14.5), (7, 2), (16, -35, 3.5), (30, 37, .94), 6),
    _t("prunellidae", "Accenteurs", "passerine", (21, 24, 10), (33, 38, 16), (7, 3), (14, -22, 3.8), (33, 38, 1.00), 7),
    _t("psittacidae", "Perroquets", "parrot", (22, 22, 12), (35, 38, 17), (7, 6), (18, -28, 4), (35, 38, 1.05), 7),
    _t("rallidae", "Râles", "ground", (19, 23, 9), (36, 40, 18), (7, 3), (7, 35, 4), (36, 40, .92), 10),
    _t("recurvirostridae", "Avocettes et échasses", "shorebird", (17, 20, 8), (36, 40, 15), (15, 2), (7, 22, 3.2), (36, 40, .88), 16),
    _t("regulidae", "Roitelets", "round", (23, 24, 11), (34, 38, 16), (5, 2.5), (13, -45, 3.5), (34, 38, .96), 6),
    _t("scolopacidae", "Bécasseaux et chevaliers", "shorebird", (18, 23, 8), (35, 39, 15), (13, 2.5), (8, 15, 3.2), (35, 39, .90), 12),
    _t("sittidae", "Sittelles", "climber", (21, 23, 9), (30, 37, 14), (8, 3), (13, 80, 3.5), (31, 38, .90), 7),
    _t("sternidae", "Sternes", "aerial", (19, 23, 8), (35, 37, 15), (13, 2.5), (18, -12, 2.8), (35, 37, 1.22), 5),
    _t("strigidae", "Chouettes et hiboux", "owl", (28, 23, 15), (33, 42, 16), (4, 5), (8, 45, 4), (38, 42, .92), 8),
    _t("sturnidae", "Étourneaux", "slender", (20, 24, 10), (33, 37, 16), (8, 3), (15, -24, 3.8), (33, 37, 1.07), 7),
    _t("sylviidae", "Fauvettes", "slender", (20, 25, 9.5), (32, 37, 14.5), (7, 2.5), (16, -32, 3.5), (32, 37, .96), 6),
    _t("troglodytidae", "Troglodytes", "round", (23, 27, 9), (32, 39, 14.5), (7, 2.5), (18, -100, 3.5), (32, 40, .90), 6),
    _t("upupidae", "Huppes", "crested", (21, 28, 9), (35, 38, 14), (15, 2), (14, -30, 3.5), (34, 39, 1.08), 7),
)

TEMPLATES = {template.id: template for template in _TEMPLATES}


LEGACY_SPECIES = {
    "Erithacus rubecula": "rougegorge",
    "Cyanistes caeruleus": "mesange-bleue",
    "Parus major": "mesange-charbonniere",
    "Turdus merula": "merle",
    "Dendrocopos major": "pic-epeiche",
    "Fringilla coelebs": "pinson",
    "Pica pica": "pie",
    "Troglodytes troglodytes": "troglodyte",
    "Passer domesticus": "moineau",
    "Phylloscopus collybita": "pouillot",
    "Strix aluco": "chouette-hulotte",
    "Upupa epops": "huppe",
    "Alcedo atthis": "martin-pecheur",
    "Oriolus oriolus": "loriot",
}


def template_catalog() -> list[dict]:
    """Return JSON-serializable descriptions for the editor and review UI."""
    result = []
    for template in _TEMPLATES:
        item = asdict(template)
        item["zones"] = list(ZONES)
        item["morphology"] = {
            key: {"default": 1.0, "min": ADJUSTMENT_MIN, "max": ADJUSTMENT_MAX}
            for key in MORPHOLOGY_CONTROLS
        }
        result.append(item)
    return result


def bounded_adjustments(values: Mapping[str, object] | None = None) -> dict[str, float]:
    """Return all controls, clamped to the safe logo-style interval."""
    unknown = set(values or ()) - set(MORPHOLOGY_CONTROLS)
    if unknown:
        raise ValueError(f"Unknown morphology controls: {', '.join(sorted(unknown))}")
    result = {}
    for key in MORPHOLOGY_CONTROLS:
        try:
            value = float((values or {}).get(key, 1.0))
        except (TypeError, ValueError) as error:
            raise ValueError(f"Morphology control {key!r} must be numeric") from error
        if not math.isfinite(value):
            raise ValueError(f"Morphology control {key!r} must be finite")
        result[key] = min(ADJUSTMENT_MAX, max(ADJUSTMENT_MIN, value))
    return result


def _darken(color: str, factor: float = .72) -> str:
    channels = [int(color[index:index + 2], 16) for index in (1, 3, 5)]
    return "#" + "".join(f"{round(channel * factor):02X}" for channel in channels)


def _namespace_legacy(svg: str, old_key: str, slug: str, label: str) -> str:
    svg = svg.replace(f'id="{old_key}-', f'id="{slug}-')
    svg = svg.replace(f'url(#{old_key}-', f'url(#{slug}-')
    if old_key == "pie":
        svg = svg.replace('id="pie-t"', f'id="{slug}-t"').replace('url(#pie-t)', f'url(#{slug}-t)')
    return re.sub(r'aria-label="[^"]*"', lambda _: f'aria-label="{html.escape(label, quote=True)}"', svg, count=1)


def legacy_species_svg(scientific_name: str, slug: str, label: str) -> str | None:
    """Return an exact approved legacy drawing, with collision-safe IDs."""
    key = LEGACY_SPECIES.get(scientific_name)
    if key is None:
        return None
    return _namespace_legacy(legacy.ICONS[key]["svg"], key, slug, label)


def mystery_svg() -> str:
    """Return the exact approved undiscovered-species reference."""
    return legacy.ICONS["mystere"]["svg"]


def render_template(
    template_id: str,
    palette: Mapping[str, str],
    *,
    label: str,
    slug: str,
    adjustments: Mapping[str, object] | None = None,
    scientific_name: str | None = None,
) -> str:
    """Render one family silhouette with explicit named color zones."""
    try:
        template = TEMPLATES[template_id]
    except KeyError as error:
        raise ValueError(f"Unknown template: {template_id}") from error
    missing = [zone for zone in ZONES if zone not in palette]
    if missing:
        raise ValueError(f"Missing palette zones: {', '.join(missing)}")
    a = bounded_adjustments(adjustments)

    name_parts = (scientific_name or "").split(maxsplit=1)
    genus = name_parts[0].casefold() if name_parts else ""
    morphotype = template.kind
    if template.id == "anatidae":
        morphotype = "swan" if genus == "cygnus" else "goose" if genus in {"anser", "branta"} else "duck"

    hx, hy = template.head_x, template.head_y
    bx, by = template.body_x, template.body_y
    hr = template.head_r * a["head_scale"]
    br = template.body_r * a["body_scale"]
    # The family table remains the source of proportions, while these strong
    # field-shape overrides make the major groups legible at map-marker size.
    if morphotype == "duck":
        hx, hy, bx, by = 17, 28, 37, 40
        hr, br = 9 * a["head_scale"], 15 * a["body_scale"]
    elif morphotype == "goose":
        hx, hy, bx, by = 16, 20, 38, 42
        hr, br = 8 * a["head_scale"], 15 * a["body_scale"]
    elif morphotype == "swan":
        hx, hy, bx, by = 15, 13, 39, 43
        hr, br = 7 * a["head_scale"], 15 * a["body_scale"]
    elif morphotype == "wader":
        hx, hy, bx, by = template.head_x, template.head_y, 38, 39
        hr, br = template.head_r * a["head_scale"], 14 * a["body_scale"]
    elif morphotype == "shorebird":
        hx, hy, bx, by = 17, 27, 37, 38
        hr, br = template.head_r * a["head_scale"], 13 * a["body_scale"]
    elif morphotype == "aerial":
        hx, hy, bx, by = 18, 32, 35, 35
        hr, br = 7 * a["head_scale"], 9.5 * a["body_scale"]
    elif morphotype == "owl":
        hx, hy, bx, by = 30, 23, 33, 42
        hr, br = 15 * a["head_scale"], 16 * a["body_scale"]
    elif morphotype == "pigeon":
        hx, hy, bx, by = 20, 25, 36, 40
        hr, br = 9 * a["head_scale"], 18 * a["body_scale"]
    # Both fillet circles must intersect. A fixed radius produces invalid
    # tangencies (and disappearing bodies) on long-necked birds or small heads.
    distance = math.hypot(bx - hx, by - hy)
    neck_radius = max(0, (distance - hr - br) / 2) + 1
    body_d = legacy.blob((hx, hy), hr, (bx, by), br,
                         max(6, neck_radius), max(3.5, neck_radius))
    body_extra = ""
    clip_extra = ""
    shade_extra = ""
    silhouette_back = ""
    if morphotype in {"duck", "goose", "swan"}:
        # Low horizontal hull, broad chest, and a visible neck.  Swans and
        # geese deliberately stop looking like recoloured ducks.
        body_d = legacy.capsule((bx - br * .62, by), br * .82,
                                (bx + br * .48, by), br)
        if morphotype == "duck":
            neck_d = f'M{legacy.pt((hx + 4, hy + 5))}Q25 36 {legacy.pt((bx - br * .45, by - 2))}'
            neck_w = 9 * a["head_scale"]
        elif morphotype == "goose":
            neck_d = f'M{legacy.pt((hx + 3, hy + 4))}C20 27 21 38 {legacy.pt((bx - br * .48, by - 3))}'
            neck_w = 8 * a["head_scale"]
        else:
            neck_d = f'M{legacy.pt((hx + 3, hy + 3))}C28 17 12 38 {legacy.pt((bx - br * .44, by - 2))}'
            neck_w = 7 * a["head_scale"]
        neck = f'<path d="{neck_d}" fill="none" stroke="{{fill}}" stroke-width="{legacy.n(neck_w)}" stroke-linecap="round"/>'
        head = '<circle cx="%s" cy="%s" r="%s" fill="{fill}"/>' % (legacy.n(hx), legacy.n(hy), legacy.n(hr))
        body_extra = neck.format(fill=palette["belly"]) + head.format(fill=palette["belly"])
        clip_extra = neck.format(fill="#fff") + head.format(fill="#fff")
        shade_extra = neck.format(fill=f'url(#{slug}-s)') + head.format(fill=f'url(#{slug}-s)')
    elif morphotype in {"wader", "shorebird"}:
        body_d = legacy.capsule((bx - br * .65, by), br * .80,
                                (bx + br * .38, by), br)
        if morphotype == "wader":
            neck_d = f'M{legacy.pt((hx + 2, hy + hr * .65))}C30 19 20 35 {legacy.pt((bx - br * .48, by - 2))}'
            neck_w = max(5.2, hr * .82)
        else:
            neck_d = f'M{legacy.pt((hx + 3, hy + hr * .55))}Q25 32 {legacy.pt((bx - br * .50, by - 1))}'
            neck_w = max(4.8, hr * .72)
        neck = f'<path d="{neck_d}" fill="none" stroke="{{fill}}" stroke-width="{legacy.n(neck_w)}" stroke-linecap="round"/>'
        head = '<circle cx="%s" cy="%s" r="%s" fill="{fill}"/>' % (legacy.n(hx), legacy.n(hy), legacy.n(hr))
        body_extra = neck.format(fill=palette["breast"]) + head.format(fill=palette["belly"])
        clip_extra = neck.format(fill="#fff") + head.format(fill="#fff")
        shade_extra = neck.format(fill=f'url(#{slug}-s)') + head.format(fill=f'url(#{slug}-s)')
    elif morphotype == "aerial":
        body_d = legacy.capsule((hx, hy), hr, (bx + 5, by + 2), br)
        # Sickle wings are silhouette, the spectrogram bars remain the inner
        # wing signature rather than pretending to be the whole wing.
        silhouette_back = (
            f'<path d="M27 34C19 23 12 15 5 9C18 11 31 20 39 34Z" fill="{palette["back"]}"/>'
            f'<path d="M33 36C43 25 52 19 61 18C54 29 48 39 39 42Z" fill="{palette["wing"]}"/>'
        )

    tail_length = template.tail_length * a["tail_length"]
    radians = math.radians(template.tail_angle)
    tail_base = (bx + br * .68, by + br * .05)
    tail_tip = (
        tail_base[0] + math.cos(radians) * tail_length,
        tail_base[1] + math.sin(radians) * tail_length,
    )
    tail_d = legacy.capsule(tail_base, template.tail_width, tail_tip, max(2, template.tail_width * .62))

    beak_length = template.beak_length * a["beak_length"]
    beak_depth = template.beak_depth
    beak_base_x = hx - hr * .82
    beak_y = hy
    if morphotype == "duck":
        beak_length = 10 * a["beak_length"]
        beak_depth = 6
    elif morphotype in {"goose", "swan"}:
        beak_length = 9 * a["beak_length"]
        beak_depth = 4.5
    if morphotype == "duck":
        upper = [(beak_base_x, beak_y - 2.8),
                 (beak_base_x - beak_length, beak_y - 1.8),
                 (beak_base_x - beak_length - 1, beak_y),
                 (beak_base_x, beak_y + .2)]
        lower = [(beak_base_x, beak_y + .5),
                 (beak_base_x - beak_length - 1, beak_y + .4),
                 (beak_base_x - beak_length, beak_y + 2.2),
                 (beak_base_x, beak_y + 2.6)]
    else:
        upper = [(beak_base_x, beak_y - beak_depth * .50), (beak_base_x - beak_length, beak_y), (beak_base_x, beak_y + .25)]
        lower = [(beak_base_x, beak_y + .45), (beak_base_x - beak_length * .82, beak_y + beak_depth * .35), (beak_base_x, beak_y + beak_depth * .72)]

    wing_scale = template.wing_scale * a["wing_scale"]
    halves = [4.2 * wing_scale, 6.2 * wing_scale, 4.7 * wing_scale, 2.7 * wing_scale]
    wing_colors = [palette["wing"], palette["wing_bar"], palette["wing"], palette["wing_bar"]]
    clip_id = f"{slug}-c"
    shade_id = f"{slug}-s"

    tail_art = legacy.path(tail_d, palette["tail"])
    if template.kind == "aerial":
        # Split tail feathers distinguish swallows/swifts from perched birds.
        tail_art = "".join(legacy.path(legacy.capsule(
            tail_base, template.tail_width,
            (tail_tip[0], tail_tip[1] + offset), 1.3), palette["tail"])
            for offset in (-3.5, 3.5))
    if morphotype == "duck":
        tail_art = legacy.path(legacy.capsule((bx + br * .55, by - 2), 3.8, (bx + br + 5, by - 5), 1.8), palette["tail"])
    elif morphotype in {"goose", "swan"}:
        tail_art = legacy.path(legacy.capsule((bx + br * .55, by), 3.8, (bx + br + 5, by - 2), 1.8), palette["tail"])
    beak_art = "" if morphotype == "owl" else legacy.beak(
        upper, lower, palette["beak"], _darken(palette["beak"]), 1.1)
    back = (
        f'<g data-morphotype="{morphotype}">{silhouette_back}</g>'
        f'<g data-zone="tail">{tail_art}</g>'
        f'<g data-zone="beak">{beak_art}</g>'
    )
    marks = (
        f'<g data-zone="back">{legacy.circle((bx + br * .48, by - br * .48), br * .82, palette["back"])}</g>'
        f'<g data-zone="belly">{legacy.circle((bx - br * .10, by + br * .78), br * .70, palette["belly"])}</g>'
        f'<g data-zone="breast">{legacy.circle((hx + hr * .42, by + br * .12), br * .62, palette["breast"])}</g>'
        f'<g data-zone="throat">{legacy.circle((hx - hr * .18, hy + hr * .72), hr * .58, palette["throat"])}</g>'
        f'<g data-zone="cheek">{legacy.circle((hx - hr * .38, hy + hr * .18), hr * .52, palette["cheek"])}</g>'
        f'<g data-zone="crown">{legacy.circle((hx + hr * .10, hy - hr * .70), hr * .68, palette["crown"])}</g>'
    )
    eye_at = (hx - hr * .30, hy - hr * .12)
    wing = legacy.bars(template.wing_x, 4.3, template.wing_y, halves, wing_colors, 3.2)
    leg_length = template.leg_length * a["leg_length"]
    legs = (
        legacy.line((bx - 4, by + br * .76), (bx - 6, by + br * .76 + leg_length), 1.8, palette["legs"])
        + legacy.line((bx + 2, by + br * .82), (bx + 3, by + br * .82 + leg_length), 1.8, palette["legs"])
    )
    if morphotype in {"duck", "goose", "swan", "aerial"}:
        legs = ""
    elif morphotype in {"wader", "shorebird"}:
        # Long separated legs and forward/back toes remain readable at 34 px.
        ankle_y = by + br * .65 + leg_length
        legs = ""
        for x, lean in ((bx - 5, -1.5), (bx + 3, 1.2)):
            legs += legacy.line((x, by + br * .60), (x + lean, ankle_y), 1.55, palette["legs"])
            legs += legacy.line((x + lean, ankle_y), (x + lean - 3.5, ankle_y + 1.5), 1.25, palette["legs"])
            legs += legacy.line((x + lean, ankle_y), (x + lean + 4, ankle_y + 1), 1.25, palette["legs"])
    feature = ""
    face = ""
    eye_art = legacy.eye(eye_at, 2.2, palette["eye"])
    if morphotype == "owl":
        face = (legacy.circle((hx - 5.2, hy), hr * .43, palette["cheek"])
                + legacy.circle((hx + 5.2, hy), hr * .43, palette["cheek"])
                + legacy.beak([(hx - 1.5, hy + 3), (hx, hy + 7), (hx + 1.5, hy + 3)], [], palette["beak"], palette["beak"], .8))
        eye_art = (legacy.eye((hx - 5, hy - .5), 2.35, palette["eye"])
                   + legacy.eye((hx + 5, hy - .5), 2.35, palette["eye"]))
    elif template.kind == "crested":
        feature = "".join(legacy.line((hx + 1, hy - hr * .65), (hx + dx, hy - hr - dy), 2.8, palette["crown"]) for dx, dy in ((-8, 5), (-3, 8), (3, 9), (8, 6)))
    elif template.kind == "climber":
        feature = '<rect x="3" y="2" width="7" height="60" rx="3.5" fill="#6B5847"/>'
    elif template.kind == "raptor":
        # Hooked bill tip and grasping toes are the raptor's field marks.
        feature = (f'<path d="M{legacy.n(beak_base_x - beak_length)} {legacy.n(beak_y)}q-.8 2.2 .8 3.4" '
                   f'fill="none" stroke="{_darken(palette["beak"])}" stroke-width="1.5" stroke-linecap="round"/>')
        foot_y = by + br * .76 + leg_length
        legs += (legacy.line((bx - 5, foot_y), (bx - 9, foot_y + 2), 1.6, palette["legs"])
                 + legacy.line((bx - 5, foot_y), (bx - 2, foot_y + 3), 1.6, palette["legs"])
                 + legacy.line((bx + 2, foot_y), (bx + 6, foot_y + 2), 1.6, palette["legs"]))

    diagnostic_marks = species_marks(
        scientific_name,
        template_id,
        palette,
        head=(hx, hy, hr),
        body=(bx, by, br),
        morphotype=morphotype,
    )

    # Fit the whole drawing, including tail caps and legs, inside the icon.
    # Bounds deliberately include stroke margins; rounding the scale downward
    # keeps all coordinate values at one decimal without clipping at extremes.
    min_x = min(hx - hr, bx - br, beak_base_x - beak_length - 1,
                tail_base[0] - template.tail_width,
                tail_tip[0] - template.tail_width) - 1
    max_x = max(hx + hr, bx + br, tail_tip[0] + template.tail_width,
                template.wing_x + 3 * 4.3 + 1.6) + 1
    min_y = min(hy - hr, by - br, tail_base[1] - template.tail_width,
                tail_tip[1] - template.tail_width - 3.5) - 1
    max_y = max(hy + hr, by + br, tail_tip[1] + template.tail_width + 3.5,
                by + br * .82 + leg_length + 1,
                template.wing_y + max(halves) + 1.6) + 1
    if template.kind == "crested":
        min_y = min(min_y, hy - hr - 11)
    elif template.kind == "climber":
        min_x, min_y, max_y = min(min_x, 2), min(min_y, 1), max(max_y, 63)
    if morphotype == "aerial":
        min_x, min_y, max_x, max_y = min(min_x, 4), min(min_y, 8), max(max_x, 62), max(max_y, 48)
    elif morphotype in {"wader", "shorebird"}:
        max_y = max(max_y, by + br * .65 + leg_length + 3)
    elif morphotype == "swan":
        min_y = min(min_y, 5)
    scale = min(1.0, math.floor(min(60 / (max_x - min_x), 60 / (max_y - min_y)) * 10) / 10)
    tx = 32 - (min_x + max_x) * scale / 2
    ty = 32 - (min_y + max_y) * scale / 2
    transform = f'translate({legacy.n(tx)} {legacy.n(ty)}) scale({legacy.n(scale)})'

    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" '
        f'role="img" aria-label="{html.escape(label, quote=True)}">'
        f'<defs><clipPath id="{clip_id}"><path d="{body_d}"/>{clip_extra}</clipPath>'
        f'{legacy.SHADE.format(k=slug)}</defs><g transform="{transform}">{feature}{back}'
        f'<path d="{body_d}" fill="{palette["belly"]}"/>{body_extra}'
        f'<g clip-path="url(#{clip_id})">{marks}{diagnostic_marks}</g>'
        f'<path d="{body_d}" fill="url(#{shade_id})"/>{shade_extra}'
        f'{face}<g data-zone="wing"><g data-zone="wing_bar">{wing}</g></g>'
        f'<g data-zone="legs">{legs}</g>'
        f'<g data-zone="eye">{eye_art}</g>'
        '</g></svg>'
    )
