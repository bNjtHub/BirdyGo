"""Optional soft-edged plumage treatment for generated SVG icons.

The transformation is deliberately conservative. Template icons soften only
circle fills directly owned by the six broad plumage zone groups. Approved
legacy drawings have no zone metadata, so only direct circle/ellipse children
of clipped groups are eligible; matches are intentionally partial. Nested
marks, front-layer eyes, outlines, and every other diagnostic shape stay crisp.
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET

SVG_NAMESPACE = "http://www.w3.org/2000/svg"
_SVG = f"{{{SVG_NAMESPACE}}}"
_SOLID_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")
SOFT_TEMPLATE_ZONES = frozenset(
    {"back", "breast", "belly", "crown", "cheek", "throat"}
)

ET.register_namespace("", SVG_NAMESPACE)


def _direct_soft_shapes(root: ET.Element, *, legacy: bool) -> list[tuple[ET.Element, str]]:
    matches: list[tuple[ET.Element, str]] = []
    for group in root.iter(f"{_SVG}g"):
        if legacy:
            if "clip-path" not in group.attrib:
                continue
            zone = "legacy"
        else:
            zone = group.get("data-zone", "")
            if zone not in SOFT_TEMPLATE_ZONES:
                continue
        for child in list(group):
            if child.tag not in (f"{_SVG}circle", f"{_SVG}ellipse"):
                continue
            color = child.get("fill", "")
            if _SOLID_COLOR.fullmatch(color):
                matches.append((child, zone))
    return matches


def soften_plumage(svg: str, *, slug: str, legacy: bool = False) -> str:
    """Return *svg* with soft edges on eligible plumage circles.

    Colors and geometry are unchanged. Each solid fill becomes a native radial
    gradient with an opaque center and a short transparent edge. Gradient IDs
    include the species slug and a per-zone counter, making independent icons
    safe to embed in one document without sharing another species' colors.
    """
    root = ET.fromstring(svg)
    targets = _direct_soft_shapes(root, legacy=legacy)
    if not targets:
        return ET.tostring(root, encoding="unicode")

    definitions = root.find(f"{_SVG}defs")
    if definitions is None:
        definitions = ET.Element(f"{_SVG}defs")
        root.insert(0, definitions)
    used_ids = {node.get("id") for node in root.iter() if node.get("id")}
    zone_counters: dict[str, int] = {}

    for shape, zone in targets:
        color = shape.get("fill", "")
        counter = zone_counters.get(zone, 0) + 1
        gradient_id = f"{slug}-plumage-{zone}-{counter}"
        while gradient_id in used_ids:
            counter += 1
            gradient_id = f"{slug}-plumage-{zone}-{counter}"
        zone_counters[zone] = counter
        used_ids.add(gradient_id)

        gradient = ET.SubElement(
            definitions,
            f"{_SVG}radialGradient",
            {"id": gradient_id},
        )
        for offset, opacity in (
            ("0", "1"),
            (".78", "1"),
            (".92", ".65"),
            ("1", "0"),
        ):
            ET.SubElement(
                gradient,
                f"{_SVG}stop",
                {
                    "offset": offset,
                    "stop-color": color,
                    "stop-opacity": opacity,
                },
            )
        shape.set("fill", f"url(#{gradient_id})")

    return ET.tostring(root, encoding="unicode")
