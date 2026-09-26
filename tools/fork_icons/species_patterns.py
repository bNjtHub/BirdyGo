"""Diagnostic plumage marks layered onto the adjustable family silhouettes.

Marks reuse colors from the sourced species row. They are intentionally sparse:
at 34 dp a collar or face mask communicates more than detailed feather texture.
Historical reference drawings bypass this renderer and remain unchanged.
"""

from __future__ import annotations

from typing import Mapping

from fork.maquette import icons_gen as geometry


def _lighten(color: str, amount: float) -> str:
    channels = [int(color[i:i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(value + (255 - value) * amount):02X}" for value in channels)


def species_marks(
    scientific_name: str | None,
    template_id: str,
    palette: Mapping[str, str],
    *,
    head: tuple[float, float, float],
    body: tuple[float, float, float],
    morphotype: str = "",
) -> str:
    """Return clipped vector marks; an unknown species stays unmarked."""
    name = (scientific_name or "").casefold()
    hx, hy, hr = head
    bx, by, br = body
    n = geometry.n
    circle, path, line = geometry.circle, geometry.path, geometry.line
    marks = ""

    if name == "carduelis carduelis" and template_id == "fringillidae":
        # Red mask, pale cheek and black nape: the goldfinch's three-part face.
        marks += circle((hx, hy), hr * .97, palette["belly"])
        marks += path(
            f"M{n(hx - hr * .12)} {n(hy - hr)}"
            f"Q{n(hx + hr * 1.15)} {n(hy - hr * .7)} {n(hx + hr * .8)} {n(hy + hr * .75)}"
            f"L{n(hx + hr * .3)} {n(hy + hr * .45)}"
            f"Q{n(hx + hr * .35)} {n(hy - hr * .5)} {n(hx - hr * .12)} {n(hy - hr)}Z",
            palette["crown"],
        )
        marks += circle((hx - hr * .62, hy), hr * .57, palette["cheek"])
        marks += circle((hx + hr * .02, hy + hr * .25), hr * .29, palette["belly"])
    elif name == "anas platyrhynchos" and template_id == "anatidae":
        marks += circle((hx, hy), hr * 1.04, palette["crown"])
        marks += line((hx - hr * .1, hy + hr * .9),
                      (hx + hr * .78, hy + hr * .66), 1.8,
                      _lighten(palette["belly"], .78))
    elif name == "columba palumbus" and template_id == "columbidae":
        marks += path(
            f"M{n(hx + hr * .45)} {n(hy + hr * .32)}"
            f"Q{n(hx + hr * .8)} {n(hy + hr * .62)} {n(hx + hr * .85)} {n(hy + hr * .98)}"
            f"L{n(hx + hr * .3)} {n(hy + hr * 1.17)}"
            f"Q{n(hx + hr * .28)} {n(hy + hr * .65)} {n(hx + hr * .08)} {n(hy + hr * .55)}Z",
            palette["wing_bar"],
        )
    elif name == "streptopelia decaocto" and template_id == "columbidae":
        marks += path(
            f"M{n(hx + hr * .8)} {n(hy + hr * .35)}"
            f"Q{n(hx + hr * .9)} {n(hy + hr * .9)} {n(hx + hr * .2)} {n(hy + hr * 1.03)}",
            "none", f' stroke="{palette["eye"]}" stroke-width="1.8" stroke-linecap="round"',
        )
    elif name == "ardea cinerea" and template_id == "ardeidae":
        # Dark line behind the eye and the sparse streaked front of the neck.
        marks += line((hx - hr * .35, hy - hr * .13),
                      (hx + hr * .9, hy - hr * .4), 1.8, palette["eye"])
        for shift in (0, 2.2, 4.4):
            marks += line((hx + hr * .4 + shift * .4, hy + hr + shift),
                          (hx + hr * .43 + shift * .4, hy + hr + shift + 1.2),
                          .9, palette["wing"])
    elif name == "sturnus vulgaris" and template_id == "sturnidae":
        for dx, dy in ((-.55, -.38), (-.65, -.02), (-.55, .32), (-.29, .52),
                       (.12, .64), (.36, .43), (-.1, -.65), (.25, -.5)):
            marks += circle((bx + br * dx, by + br * dy), .8, palette["wing_bar"])
    elif name == "aegithalos caudatus" and template_id == "aegithalidae":
        marks += path(
            f"M{n(hx - hr * .25)} {n(hy - hr * .15)}"
            f"Q{n(hx + hr * .6)} {n(hy - hr * .8)} {n(hx + hr * .85)} {n(hy + hr * .35)}",
            "none", f' stroke="{palette["back"]}" stroke-width="2.4" stroke-linecap="round"',
        )
    elif name.startswith("sitta ") and template_id == "sittidae":
        marks += line((hx - hr * .87, hy - hr * .1),
                      (hx + hr * .96, hy + hr * .22), 2.3, palette["eye"])
    elif name == "motacilla alba" and template_id == "motacillidae":
        marks += path(
            f"M{n(hx - hr * .5)} {n(hy + hr * .6)}"
            f"L{n(bx - br * .26)} {n(by + br * .12)}"
            f"L{n(hx + hr * .75)} {n(hy + hr * .38)}Z", palette["throat"],
        )
    elif name.startswith("falco ") and template_id == "falconidae":
        marks += path(
            f"M{n(hx - hr * .12)} {n(hy - hr * .13)}"
            f"L{n(hx - hr * .26)} {n(hy + hr * .77)}"
            f"Q{n(hx + hr * .18)} {n(hy + hr * .66)} {n(hx + hr * .22)} {n(hy + hr * .07)}Z",
            palette["wing"],
        )
    elif name == "buteo buteo" and template_id == "accipitridae":
        for dx, dy in ((-.45, .2), (-.2, .32), (.03, .4), (-.35, .52)):
            marks += line((bx + br * dx, by + br * dy),
                          (bx + br * (dx + .12), by + br * (dy + .06)),
                          1.3, palette["breast"])
    if not marks:
        return ""
    return f'<g data-pattern="diagnostic">{marks}</g>'
