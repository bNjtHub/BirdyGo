#!/usr/bin/env python3
"""BirdyGo species icon family generator.
Construction grammar taken from the brand mark (logo.svg, scaled 1/8):
  head circle + body circle joined by concave fillets, tapered capsule tail,
  two-tone beak (upper light / lower dark), dark eye with a white glint,
  wing = vertical rounded 'spectrogram' bars, one light-to-dark shade overlay.
"""
import math, os, re, json

OUT = os.path.dirname(os.path.abspath(__file__))

def n(x):
    s = f"{x:.1f}"
    if s.endswith('.0'): s = s[:-2]
    if s.startswith('0.'): s = s[1:]
    elif s.startswith('-0.'): s = '-' + s[2:]
    if s in ('-0', '-'): s = '0'
    return s

def pt(p): return f"{n(p[0])} {n(p[1])}"

def ang(c, p): return math.atan2(p[1]-c[1], p[0]-c[0])

def arc_cw(c, r, a, b):
    d = (ang(c, b) - ang(c, a)) % (2*math.pi)
    return f"A{n(r)} {n(r)} 0 {1 if d > math.pi else 0} 1 {pt(b)}"

def arc_ccw(c, r, a, b):
    d = (ang(c, a) - ang(c, b)) % (2*math.pi)
    return f"A{n(r)} {n(r)} 0 {1 if d > math.pi else 0} 0 {pt(b)}"

def fillet(c1, r1, c2, r2, rf, side):
    dx, dy = c2[0]-c1[0], c2[1]-c1[1]
    D = math.hypot(dx, dy)
    a, b = r1+rf, r2+rf
    x = (a*a - b*b + D*D) / (2*D)
    h = math.sqrt(max(a*a - x*x, 0))
    ux, uy = dx/D, dy/D
    nx, ny = uy*side, -ux*side
    F = (c1[0]+ux*x+nx*h, c1[1]+uy*x+ny*h)
    t1 = (c1[0]+(F[0]-c1[0])*r1/a, c1[1]+(F[1]-c1[1])*r1/a)
    t2 = (c2[0]+(F[0]-c2[0])*r2/b, c2[1]+(F[1]-c2[1])*r2/b)
    return F, t1, t2

def blob(c1, r1, c2, r2, ft, fb):
    """Union of two circles with concave fillets; c1 is the head (drawn clockwise)."""
    Ft, t1t, t2t = fillet(c1, r1, c2, r2, ft, +1)
    Fb, t1b, t2b = fillet(c1, r1, c2, r2, fb, -1)
    return ("M" + pt(t1b) + arc_cw(c1, r1, t1b, t1t) + arc_ccw(Ft, ft, t1t, t2t)
            + arc_cw(c2, r2, t2t, t2b) + arc_ccw(Fb, fb, t2b, t1b) + "Z")

def capsule(p1, r1, p2, r2):
    """Tapered capsule between circles (p1,r1) and (p2,r2)."""
    dx, dy = p2[0]-p1[0], p2[1]-p1[1]
    D = math.hypot(dx, dy)
    ux, uy = dx/D, dy/D
    th = math.acos(max(-1, min(1, (r1-r2)/D)))
    def rot(t): return (ux*math.cos(t)-uy*math.sin(t), ux*math.sin(t)+uy*math.cos(t))
    np_, nm = rot(th), rot(-th)
    A1 = (p1[0]+r1*np_[0], p1[1]+r1*np_[1]); A2 = (p2[0]+r2*np_[0], p2[1]+r2*np_[1])
    B2 = (p2[0]+r2*nm[0], p2[1]+r2*nm[1]); B1 = (p1[0]+r1*nm[0], p1[1]+r1*nm[1])
    return (f"M{pt(A1)}L{pt(A2)}A{n(r2)} {n(r2)} 0 0 0 {pt(B2)}L{pt(B1)}"
            f"A{n(r1)} {n(r1)} 0 1 0 {pt(A1)}Z")

def poly(*ps): return "M" + "L".join(pt(p) for p in ps) + "Z"

def circle(c, r, fill, extra=""):
    return f'<circle cx="{n(c[0])}" cy="{n(c[1])}" r="{n(r)}" fill="{fill}"{extra}/>'

def path(d, fill, extra=""):
    return f'<path d="{d}" fill="{fill}"{extra}/>'

def line(p1, p2, w, color, cap="round"):
    return (f'<path d="M{pt(p1)}L{pt(p2)}" stroke="{color}" stroke-width="{n(w)}" '
            f'stroke-linecap="{cap}"/>')

def beak(upper, lower, cu, cl, w=1.2):
    """Two-tone beak, rounded by a same-colour stroke like the logo."""
    s = '<g stroke-linejoin="round" stroke-width="%s">' % n(w)
    if lower: s += f'<path d="{poly(*lower)}" fill="{cl}" stroke="{cl}"/>'
    s += f'<path d="{poly(*upper)}" fill="{cu}" stroke="{cu}"/>'
    return s + '</g>'

def bars(x0, dx, cy, halves, colors, w=3.4, tilt=0.0):
    """Spectrogram wing: vertical rounded bars (the brand signature)."""
    groups = {}
    for i, (h, c) in enumerate(zip(halves, colors)):
        x = x0 + i*dx
        y = cy + i*tilt
        groups.setdefault(c, []).append(f"M{n(x)} {n(y-h)}V{n(y+h)}")
    s = f'<g fill="none" stroke-width="{n(w)}" stroke-linecap="round">'
    for c, ds in groups.items():
        s += f'<path d="{"".join(ds)}" stroke="{c}"/>'
    return s + '</g>'

def eye(c, r=2.4, col="#13233A", glint="#FFFFFF", ring=None, ringw=0.9):
    s = ""
    if ring: s += circle(c, r+ringw, ring)
    s += circle(c, r, col)
    s += circle((c[0]-r*0.3, c[1]-r*0.32), max(r*0.3, .7), glint)
    return s

def gloss(c, r, light, dark, off=(1.1, 1.3), shrink=.3):
    """Rim light for black plumage: light disc, darker disc offset down-right."""
    return circle(c, r, light) + circle((c[0]+off[0], c[1]+off[1]), r-shrink, dark)

SHADE = ('<linearGradient id="{k}-s" x2="1" y2="1">'
         '<stop stop-color="#fff" stop-opacity=".16"/>'
         '<stop offset=".45" stop-color="#fff" stop-opacity="0"/>'
         '<stop offset="1" stop-color="#061020" stop-opacity=".28"/></linearGradient>')

def icon(key, label, body_d, base, back=(), marks=(), front=(), shade=True):
    """back: drawn behind the body (tail, beak). marks: clipped to the body.
    front: drawn on top (wing bars, eye)."""
    defs = f'<clipPath id="{key}-c"><path d="{body_d}"/></clipPath>'
    if shade: defs += SHADE.format(k=key)
    s = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" '
         f'role="img" aria-label="{label}"><defs>{defs}</defs>')
    s += "".join(back)
    s += f'<path d="{body_d}" fill="{base}"/>'
    if marks:
        s += f'<g clip-path="url(#{key}-c)">' + "".join(marks) + '</g>'
    if shade:
        s += f'<path d="{body_d}" fill="url(#{key}-s)"/>'
    s += "".join(front)
    return s + '</svg>'

# ---------------------------------------------------------------- archetypes
# A  Rondelet : logo proportions (head r12, body r19), tail up.
H_A, RH_A, B_A, RB_A = (24.5, 23), 12, (33.5, 36), 19
def body_A(h=H_A, rh=RH_A, b=B_A, rb=RB_A, ft=7, fb=4): return blob(h, rh, b, rb, ft, fb)
def tail_A(base=(47.5, 36), tip=(57, 21.5), r1=4.2, r2=2.8): return capsule(base, r1, tip, r2)

ICONS = {}

def reg(key, label, latin, svg):
    ICONS[key] = dict(label=label, latin=latin, svg=svg)

# ---------------------------------------------------------------- Rougegorge
def rougegorge():
    k = "rougegorge"
    brown, orange, grey, belly = "#8A7152", "#EC7A3C", "#A9B6C2", "#F1EBDF"
    E = (20.5, 21.5)
    back = [path(tail_A(), "#6B5847"),
            beak([(14.5, 19.6), (6.8, 21.4), (13.6, 23)], [(13.6, 23.8), (8, 24.4), (14.2, 26)], "#5E4E40", "#352B23", 1.1)]
    marks = [circle((30, 60), 17, belly),
             circle((17.5, 31), 14.6, grey),
             circle((17, 30.5), 13.2, orange)]
    front = [bars(34, 4.6, 38, [4.5, 6.8, 5, 2.8], ["#6B5847", "#C9A36E", "#6B5847", "#7C6650"]),
             eye(E, 2.4, "#13233A")]
    reg(k, "Rougegorge familier", "Erithacus rubecula", icon(k, "Rougegorge familier", body_A(), brown, back, marks, front))

# ---------------------------------------------------------------- Mésange bleue
def mesange_bleue():
    k = "mesange-bleue"
    yellow, green, white, blue, navy = "#F2CF4A", "#A5B866", "#F6F7F2", "#3B8FDB", "#1D3570"
    E = (20.5, 22)
    h, rh = (24, 23), 12.5
    back = [path(tail_A(), "#2F74C0"),
            beak([(13.4, 20.8), (7.8, 22.4), (12.8, 24)], [(12.8, 24.6), (8.6, 25.1), (13, 26.2)], "#56606E", "#2A303B", 1.1)]
    marks = [circle((44, 20), 16, green),
             circle((22.6, 27.2), 10.8, navy),
             circle((21.2, 25.2), 9.4, white),
             circle((23.4, 11.6), 10.2, white),
             circle((16.6, 17.6), 5.2, white),
             circle((26.5, 8.2), 8.8, blue),
             line((12, 21.6), (33, 21), 2.2, navy, "butt")]
    front = [bars(34.5, 4.6, 38, [4.6, 6.8, 5, 2.8], ["#3B8FDB", "#F6F7F2", "#2F74C0", "#2A62A8"]),
             eye(E, 2.2, "#0E1626")]
    reg(k, "Mésange bleue", "Cyanistes caeruleus",
        icon(k, "Mésange bleue", body_A(h, rh), yellow, back, marks, front))

# ---------------------------------------------------------------- Mésange charbonnière
def mesange_charbonniere():
    k = "mesange-charbonniere"
    yellow, green, black, white = "#F2CD48", "#8FA35A", "#1C2129", "#F6F7F2"
    E = (20.5, 20.5)
    back = [path(tail_A(), "#5B7390"),
            beak([(13.4, 20), (8, 21.4), (12.8, 23)], [(12.8, 23.6), (8.8, 24), (13, 25.2)], "#56606E", "#1C2129", 1.1)]
    marks = [circle((45, 21), 15.5, green),
             gloss((23.5, 22.5), 12.5, "#3B4350", black, (1, 1.2), .2),
             circle((22.6, 26.6), 5.6, white),
             line((20, 33), (27, 54), 5.2, black)]
    front = [bars(34.5, 4.6, 38, [4.6, 6.8, 5, 2.8], ["#6F8AA6", "#F6F7F2", "#5B7390", "#4E6480"]),
             eye(E, 2.2, "#05080C", "#FFFFFF")]
    reg(k, "Mésange charbonnière", "Parus major",
        icon(k, "Mésange charbonnière", body_A(), yellow, back, marks, front))

# ---------------------------------------------------------------- Merle noir  (B Élancé)
def merle():
    k = "merle"
    black = "#2A2E36"
    h, rh, b, rb = (20, 24), 10.5, (31, 35), 16
    E = (17.5, 22)
    back = [path(capsule((42, 36), 4.2, (58.5, 24), 3), "#3A404A"),
            beak([(11.4, 21.6), (3.6, 24.4), (11, 26)], [(11, 26.4), (5.2, 26.6), (11.4, 28.2)], "#F6B12A", "#DE8A18", 1)]
    front = [bars(30, 4.4, 36.5, [4.2, 6.2, 4.6, 2.6], ["#3A404A", "#4E5663", "#3A404A", "#343942"]),
             eye(E, 2.3, "#0A0C10", "#FFFFFF", ring="#F6B12A", ringw=1)]
    marks = [circle((h[0]+1.1, h[1]+1.3), rh-.3, black), circle((b[0]+1.1, b[1]+1.3), rb-.3, black)]
    reg(k, "Merle noir", "Turdus merula",
        icon(k, "Merle noir", blob(h, rh, b, rb, 6, 3.5), "#4A515C", back, marks, front))

# ---------------------------------------------------------------- Pic épeiche (D Grimpeur)
def pic_epeiche():
    k = "pic-epeiche"
    black, white, red, buff = "#1F242C", "#F5F3EC", "#D8343A", "#EDE4D2"
    h, rh, b, rb = (23.5, 17), 9.5, (27.5, 35), 12.5
    E = (20.5, 15.8)
    trunk = '<rect x="3" y="2" width="8.5" height="60" rx="4.2" fill="#6B5847"/>'
    back = [trunk,
            path(capsule((25, 45), 4.2, (15.5, 59), 2.2), "#343A44"),
            beak([(15, 13.6), (8, 15.8), (14.8, 18.2)], None, "#5A616D", "#2A2F37", 1.2)]
    marks = [gloss(b, rb, "#3B4350", black, (1.2, 1.2), .2),
             gloss(h, rh, "#3B4350", black, (1.2, 1.2), .2),
             circle((15.5, 37), 9.5, buff),
             circle((18, 47), 5.4, red),
             circle((18.6, 18.4), 5.4, white),
             line((14.5, 21.6), (29, 20.6), 2.1, black),
             circle((32, 13.6), 4, red),
             circle((33.4, 29.6), 4.4, white)]
    front = [bars(31.6, 4.2, 40.6, [2.6, 1.8], [white, white], 2.6),
             eye(E, 2, "#05080C")]
    reg(k, "Pic épeiche", "Dendrocopos major",
        icon(k, "Pic épeiche", blob(h, rh, b, rb, 5, 4), black, back, marks, front))

# ---------------------------------------------------------------- Pinson des arbres
def pinson():
    k = "pinson"
    pink, cap, chest, blk, white = "#DD8C6E", "#7F93AE", "#93644A", "#23262D", "#F6F5EF"
    E = (20.5, 21.5)
    back = [path(tail_A(), "#434953"),
            beak([(13.6, 19.8), (7.4, 21.8), (13, 23.4)], [(13, 24), (8.2, 24.6), (13.4, 25.8)], "#9DB0C6", "#7489A2", 1.1)]
    marks = [circle((32, 58), 13, "#F1E4D8"),
             circle((46, 24), 15, chest),
             circle((27, 9.5), 12, cap)]
    front = [bars(34.5, 4.6, 38, [4.6, 6.8, 5, 2.8], [white, blk, white, blk]),
             eye(E, 2.3, "#13233A")]
    reg(k, "Pinson des arbres", "Fringilla coelebs",
        icon(k, "Pinson des arbres", body_A(), pink, back, marks, front))

# ---------------------------------------------------------------- Pie bavarde (C Longue queue)
def pie():
    k = "pie"
    black, white = "#1F242C", "#F5F5F0"
    h, rh, b, rb = (15.5, 26), 9, (26, 36.5), 13.5
    E = (12.6, 24.4)
    tail = capsule((35, 39), 4.2, (60.5, 13.5), 2.7)
    back = [f'<linearGradient id="{k}-t" x2="1" y2="0"><stop stop-color="#1C3558"/><stop offset="1" stop-color="#2A9486"/></linearGradient>',
            path(tail, f"url(#{k}-t)"),
            beak([(7.4, 23.6), (1.4, 26.2), (7.2, 27.6)], [(7.2, 28), (2.8, 28.4), (7.6, 29.4)], "#56606E", "#1B1F26", 1.1)]
    marks = [gloss(b, rb, "#3B4350", black, (1.2, 1.3), .2),
             gloss(h, rh, "#3B4350", black, (1.1, 1.3), .2),
             circle((28, 49), 10.5, white)]
    front = [bars(27, 4.5, 34, [5.4, 5.8, 3.8], [white, "#3A6FC0", "#2A9486"], 3.4),
             eye(E, 2.1, "#05080C")]
    reg(k, "Pie bavarde", "Pica pica",
        icon(k, "Pie bavarde", blob(h, rh, b, rb, 5, 3), black, back, marks, front))

# ---------------------------------------------------------------- Troglodyte (E Boule)
def troglodyte():
    k = "troglodyte"
    brown, pale, dark, brow = "#9A6A43", "#D2AE84", "#6A4630", "#E6D0A8"
    h, rh, b, rb = (23, 27), 9, (31.5, 38), 14.5
    E = (20, 25.5)
    back = [path(capsule((40, 32), 3.6, (43.5, 13), 2.4), dark),
            beak([(15.4, 24.8), (7.2, 27), (15, 27.8)], [(15, 28.2), (8.6, 28.6), (15.4, 29.6)], "#6E5745", "#3C2E23", 1)]
    marks = [circle((22, 44), 10, pale),
             line((19, 22.6), (30, 22.4), 1.6, brow)]
    front = [bars(31, 4, 40, [3.6, 5, 3.6, 2.2], [dark, "#C69A6A", dark, "#C69A6A"], 3),
             eye(E, 2, "#13233A")]
    reg(k, "Troglodyte mignon", "Troglodytes troglodytes",
        icon(k, "Troglodyte mignon", blob(h, rh, b, rb, 5, 3), brown, back, marks, front))

# ---------------------------------------------------------------- Moineau domestique
def moineau():
    k = "moineau"
    buff, grey, chest, cheek, black, brown = "#C9C3B6", "#8E97A0", "#9B5A2E", "#E4E2DA", "#1E2126", "#A87646"
    E = (20.5, 21.5)
    back = [path(tail_A(), "#6E4C30"),
            beak([(13.6, 19.8), (7.2, 21.8), (13, 23.4)], [(13, 24), (8, 24.6), (13.4, 25.8)], "#56606E", "#1E2126", 1.3)]
    marks = [circle((46, 24), 15.5, brown),
             circle((26, 18), 11.5, chest),
             circle((24, 10), 9.8, grey),
             circle((21, 28), 7.5, cheek),
             path(capsule((14.2, 27.4), 3.2, (16.4, 34.2), 5), black)]
    front = [bars(34.5, 4.6, 38, [4.6, 6.8, 5, 2.8], ["#6E4C30", "#F3F1EA", "#2B2A2C", "#8C5E36"]),
             eye(E, 2.3, "#13233A")]
    reg(k, "Moineau domestique", "Passer domesticus",
        icon(k, "Moineau domestique", body_A(), buff, back, marks, front))

# ---------------------------------------------------------------- Pouillot véloce (B Élancé)
def pouillot():
    k = "pouillot"
    olive, under, brow, stripe = "#8C9160", "#E8E4C2", "#EFEBCB", "#5B5E3C"
    h, rh, b, rb = (20, 25), 9.5, (31, 36), 14.5
    E = (17.8, 24)
    back = [path(capsule((41, 38), 3.6, (57, 26), 2.5), "#6E7249"),
            beak([(11.8, 23.2), (4.8, 24.8), (11.4, 26)], [(11.4, 26.4), (6.2, 26.8), (11.8, 27.8)], "#6A6A50", "#34342A", 1)]
    marks = [circle((24, 48), 12.5, under),
             line((11, 24.2), (24.5, 23.8), 1.7, stripe),
             line((13.6, 20.8), (22.4, 20.6), 1.9, brow)]
    front = [bars(30, 4.3, 37, [4, 5.8, 4.2, 2.4], ["#6E7249", "#A6AA73", "#6E7249", "#7C8052"], 3.2),
             eye(E, 2, "#13233A")]
    reg(k, "Pouillot véloce", "Phylloscopus collybita",
        icon(k, "Pouillot véloce", blob(h, rh, b, rb, 5, 3), olive, back, marks, front))

# ---------------------------------------------------------------- Chouette hulotte (F Dressé)
def chouette():
    k = "chouette-hulotte"
    brown, disc, rim, dark, beakc = "#9A6843", "#D2AE82", "#5E3F28", "#1A120E", "#E6D29C"
    h, rh, b, rb = (29, 24), 15, (33, 42), 16
    back = [path(capsule((40, 52), 4, (46, 58), 3), "#6A4630")]
    marks = [circle((32, 58), 12, "#C49A6C"),
             circle((24, 25.5), 11.4, rim),
             circle((19.5, 25), 6.8, disc),
             circle((29.5, 25), 6.8, disc)]
    front = [bars(37.5, 4.4, 42, [5, 6.6, 4.2], ["#6E4A2E", "#E3CBA0", "#6E4A2E"], 3.2),
             eye((19.5, 24.6), 2.9, dark), eye((29.5, 24.6), 2.9, dark),
             beak([(22.8, 27.6), (26.2, 27.6), (24.5, 32)], None, beakc, beakc, 1)]
    reg(k, "Chouette hulotte", "Strix aluco",
        icon(k, "Chouette hulotte", blob(h, rh, b, rb, 4, 4), brown, back, marks, front))

# ---------------------------------------------------------------- Huppe fasciée (G Long bec)
def huppe():
    k = "huppe"
    cinn, belly, blk, white = "#E3A07A", "#F0CDAE", "#1E2126", "#F6F2EA"
    h, rh, b, rb = (21, 28), 8.8, (34, 38), 13.5
    E = (18.5, 26.5)
    crest = []
    for a, L in [(-172, 11), (-142, 14), (-112, 15.5), (-82, 15), (-54, 13), (-30, 10.5)]:
        t = math.radians(a); c, sn = math.cos(t), math.sin(t)
        base = (23 + 3*c, 26 + 3*sn)
        tip = (23 + L*c, 26 + L*sn)
        mid = (23 + (L-2.6)*c, 26 + (L-2.6)*sn)
        crest.append((f"M{pt(base)}L{pt(tip)}", f"M{pt(base)}L{pt(mid)}"))
    crest = ['<g fill="none" stroke-width="4.4" stroke-linecap="round">'
             f'<path d="{"".join(c[0] for c in crest)}" stroke="{blk}"/>'
             f'<path d="{"".join(c[1] for c in crest)}" stroke="{cinn}"/></g>']
    bill = "M13.4 26.2C9 27 5.2 29.6 2.6 34.2C5.8 31.6 9.4 29.6 13.6 29.2Z"
    back = crest + [
        path(capsule((45, 40), 3.8, (58, 31), 2.8), "#343A44"),
        line((49.8, 33.4), (53.2, 38.4), 2.3, white, "butt"),
        f'<path d="{bill}" fill="#343A44" stroke="#343A44" stroke-width="1" stroke-linejoin="round"/>']
    marks = [circle((28, 52), 11, belly)]
    front = [bars(30.5, 3.9, 39, [4.6, 6.4, 5.6, 4, 2.4], [blk, white, blk, white, blk], 3),
             eye(E, 2, "#13233A")]
    reg(k, "Huppe fasciée", "Upupa epops",
        icon(k, "Huppe fasciée", blob(h, rh, b, rb, 4, 3), cinn, back, marks, front))

# ---------------------------------------------------------------- Martin-pêcheur (G Long bec)
def martin():
    k = "martin-pecheur"
    blue, orange, white, cyan = "#1C8FB8", "#EC7A3C", "#F6F7F2", "#62E1F0"
    h, rh, b, rb = (25, 24), 11.5, (35, 38), 13
    E = (22.5, 22.5)
    back = [path(capsule((44, 46), 3.8, (52, 55), 2.6), "#15607F"),
            beak([(15.4, 20.8), (1.8, 25.2), (14.6, 26.2)], [(14.6, 26.6), (3.4, 25.8), (15, 28.8)], "#3B414C", "#1D2128", .9)]
    marks = [circle((30, 52), 14, orange),
             circle((25.5, 27.5), 5.6, orange),
             circle((32.5, 30), 3, white),
             circle((17.5, 31), 4.6, white)]
    front = [bars(37, 4.4, 38, [4.4, 6.4, 4], ["#1C8FB8", cyan, "#15607F"], 3.2),
             eye(E, 2.2, "#0E1626")]
    reg(k, "Martin-pêcheur d'Europe", "Alcedo atthis",
        icon(k, "Martin-pêcheur d'Europe", blob(h, rh, b, rb, 5, 3), blue, back, marks, front))

# ---------------------------------------------------------------- Loriot (B Élancé)
def loriot():
    k = "loriot"
    yellow, blk = "#F4C542", "#1E2126"
    h, rh, b, rb = (20, 25), 10, (31, 36), 15.5
    E = (17.5, 23.5)
    back = [path(capsule((42, 37), 4, (57.5, 26), 2.8), "#2F343C"),
            beak([(11.6, 22.4), (4.4, 24.4), (11.2, 26)], [(11.2, 26.4), (5.8, 26.8), (11.6, 28)], "#E07F87", "#B4525C", 1.1)]
    marks = [line((11, 24.4), (17, 23.8), 2.2, blk)]
    front = [path(capsule((33, 35), 6.4, (47, 41.5), 3), blk),
             bars(31, 0, 35.6, [2.8], [yellow], 3),
             eye(E, 2.1, "#5A1A20")]
    reg(k, "Loriot d'Europe", "Oriolus oriolus",
        icon(k, "Loriot d'Europe", blob(h, rh, b, rb, 6, 3.5), yellow, back, marks, front))

# ---------------------------------------------------------------- Mystère
def mystere():
    k = "mystere"
    c = "#818A94"
    body = body_A()
    q = ('<path d="M29.5 31.5a4.5 4.5 0 1 1 6.2 4.2c-1.4.6-2.2 1.6-2.2 3.2v.8" fill="none" '
         f'stroke="{c}" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round" stroke-opacity=".9"/>'
         f'<circle cx="33.5" cy="45.2" r="2" fill="{c}" fill-opacity=".9"/>')
    s = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64" '
         f'role="img" aria-label="Espèce à découvrir"><g fill="{c}" opacity=".3">'
         f'<path d="{tail_A()}"/>'
         f'<path d="{poly((14.5, 19.6), (7.2, 21.4), (14, 25))}" stroke="{c}" stroke-width="1.2" stroke-linejoin="round"/>'
         f'<path d="{body}"/></g>{q}</svg>')
    reg(k, "Espèce à découvrir", "", s)

ORDER = ["rougegorge", "mesange-bleue", "mesange-charbonniere", "merle", "pic-epeiche",
         "pinson", "pie", "troglodyte", "moineau", "pouillot",
         "chouette-hulotte", "huppe", "martin-pecheur", "loriot", "mystere"]

for fn in [rougegorge, mesange_bleue, mesange_charbonniere, merle, pic_epeiche, pinson, pie,
           troglodyte, moineau, pouillot, chouette, huppe, martin, loriot, mystere]:
    fn()

def main():
    # birds.md
    md = ["# BirdyGo — icônes d'espèces", "",
          "Famille construite sur la grammaire du logo : cercle de tête + cercle de corps raccordés, "
          "queue en capsule, bec deux tons, oeil sombre avec reflet, aile en barres de spectrogramme. "
          "Chaque SVG est autonome (viewBox 64, ids préfixés par la clé). Orientés vers la gauche.", "",
          "Six silhouettes de base : rondelet (rougegorge, mésanges, pinson, moineau, mystère), "
          "élancé (merle, pouillot, loriot, pie à longue queue), boule à queue dressée (troglodyte), "
          "grimpeur sur tronc (pic épeiche), dressé à disque facial (chouette hulotte), "
          "grosse tête et long bec (martin-pêcheur, huppe).", "",
          "Intégration : pas de <style>, pas de <use>, pas de texte. Ids utilisés : <clé>-c (clipPath), "
          "<clé>-s (dégradé d'ombre), pie-t (queue). Si la même icône apparaît deux fois dans une page, "
          "les ids se répètent mais pointent vers des définitions identiques ; éviter seulement que la "
          "première copie soit en display:none. Le mystère utilise un gris neutre à 30 % (#818A94), "
          "identique à Brume 15 % sur Encre de nuit et encore visible sur Brume.", ""]
    for k in ORDER:
        d = ICONS[k]
        md += [f"## {k} — {d['label']}", "", d["svg"], ""]
    open(os.path.join(OUT, "birds.md"), "w").write("\n".join(md))
    # sheet.svg : 5 x 3 grid, 80 units per cell
    cells = []
    for i, k in enumerate(ORDER):
        x, y = (i % 5)*80 + 8, (i // 5)*80 + 8
        inner = re.sub(r'^<svg[^>]*>', '', ICONS[k]["svg"])[:-6]
        cells.append(f'<svg x="{x}" y="{y}" width="64" height="64" viewBox="0 0 64 64">{inner}</svg>')
    sheet = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 400 240" width="400" height="240">'
             + "".join(cells) + '</svg>')
    open(os.path.join(OUT, "icons_sheet.svg"), "w").write(sheet)
    json.dump({k: ICONS[k] for k in ORDER}, open(os.path.join(OUT, "icons.json"), "w"), ensure_ascii=False)
    for k in ORDER:
        print(f"{k:22s} {len(ICONS[k]['svg'].encode()):5d} B")

main()
