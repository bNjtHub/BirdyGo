# BirdyGo — mockup UI spec (single source of truth)

Lead designer spec for the 14 artboards of the BirdyGo canvas. Five builders read this file and must produce one consistent app. Precedence: `RULES.md` wins on file format, this spec wins on everything visual, textual and numeric. `fork/DESIGN.md` is the owner's direction; where this spec departs from it, the reason is written next to the decision.

Everything a builder needs is here: tokens, a shared `<helmet>` block, copy‑paste components, animation language, the game rules, one dataset, and a screen-by-screen layout with exact French copy.

---

## 0. How to use this spec

### 0.1 Files and suggested split

| Builder | Artboards (all 390 × 844, in `canvas/project/`) | Theme |
|---|---|---|
| A — listening | `Live.dc.html`, `LiveSpectre.dc.html`, `Arrivee.dc.html` | dark |
| B — moments | `Premiere.dc.html`, `Rare.dc.html`, `Niveau.dc.html` | dark |
| C — session loop | `Main.dc.html`, `Resume.dc.html`, `Revue.dc.html` | light |
| D — collection | `Carnet.dc.html`, `Profil.dc.html`, `Palmares.dc.html` | light |
| E — place and bird | `Carte.dc.html`, `Fiche.dc.html` | light |

Builder B draws a dimmed Live screen behind its moments: copy the Live header, band and rows from section 5 (not from builder A's file).

### 0.2 Non-negotiables (checked at review)

1. Copy the `<helmet>` block of section 3 verbatim into every artboard (change only `body{background}` for light boards). Never rename a keyframe; add board-specific keyframes only with a board prefix (`carte-…`).
2. Colors, radii, type sizes: only the tokens of section 2. No other hex value except inside species icons, the brand mark, the spectrogram tile and the map drawing.
3. Components: paste the snippets of section 5, then change text, numbers and links. Do not restyle them.
4. Numbers, names, times and places: only the dataset of section 8. If a number is not there, do not invent one; ask or leave it out.
5. French copy exactly as written here (tutoiement, sentence case, no uppercase labels, no overline above blocks, no emoji). The six fixed action names are always spelled: « Écouter », « Arrêter », « Réécouter », « C'est bien lui », « Ce n'est pas lui », « Je ne sais pas ». In this spec the outer « … » only delimit the exact on-screen text; any quotes inside are part of the text (write inner quotes as “ ” when they sit inside a sentence, e.g. le défi “Oiseaux des haies”).
6. Species shown with an icon: only the 14 icon keys of section 4.2. The 11 other discovered species exist in the numbers but are never drawn.
7. No sound anywhere, no modal that hides « Arrêter », no red error screen, no countdown pressure, no leaderboard of people.

### 0.3 Placeholders used in snippets

`<!--BIRD key size-->` means: paste the `<svg>` of that key from `fork/maquette/birds.md`, set `width` and `height` to `size`, and add `style="display:block;flex:none"` on the `<svg>`. Example: `<!--BIRD rougegorge 42-->`.

Icon ids: species icons use ids `<key>-c`, `<key>-s` (and `pie-t`), the brand mark uses `bm-teal`, `bm-deep`, the spectrogram uses `sp-low`, `sp-glow`, the review clip uses `rv-glow`. **If the same drawing appears more than once in one artboard, rename the ids of every copy after the first** by appending `-2`, `-3`… in both `id="…"` and `url(#…)`. Do it even when a copy is hidden with `display: none`.

---

## 1. Design principles

DESIGN.md asks for a calm field notebook that is bold only at bird moments. The owner asks for "simple et hi-tech, pour un enfant quasiment", a spectrum he can enlarge or reduce, beautiful bird appearances, counters, a status game and "tout ce qui se fait chez les autres". The rules below reconcile both.

1. **One big action per screen**, thumb-reachable at the bottom: Accueil = « Écouter », Live = « Arrêter », Bilan = « Vérifier 3 détections », Revue = the three verdict buttons, moments = « Continuer l'écoute ». Everything else is quieter (secondary, tonal or icon buttons).
2. **Pictures before words.** Every species appears with its icon; every reliability level has a shape (1, 2 or 3 bars), not only a color; status is an emblem in a ring; progress is a bar or dots.
3. **Big numbers.** Counters use Atkinson Hyperlegible Next 800 in tabular figures (26–34 px for headline numbers, 20 px for the per-row session count).
4. **Targets ≥ 48 px** everywhere, 56–72 px for main actions. Chips are 48 px tall.
5. **Two moods.** Dark "hi-tech" when listening and for the four moments (glowing spectrum, live table, celebrations); light "field notebook" everywhere else. Dark boards: `Live`, `LiveSpectre`, `Arrivee`, `Premiere`, `Rare`, `Niveau`. Light boards: `Main`, `Resume`, `Revue`, `Carnet`, `Profil`, `Palmares`, `Carte`, `Fiche`.
6. **Color comes from birds.** The frame stays Encre/Brume; each species brings its accent (row halo, glow, fiche header, podium, map ring, celebration wave); each status brings its own color.
7. **Motion is rationed** (DESIGN.md frequency rule). Tabs, lists and scrolling do not animate. A re-heard bird glows; a new bird springs in; a first-ever bird and a rare bird get a big moment; a new status gets one in the recap. Nothing plays a sound.
8. **Honest game.** Only verified species count (section 7.1). A rare bird is checked before it is celebrated. « Je ne sais pas » is always a good answer.
9. **The spectrum has a job.** It shows where each detected call is (colored marks under the calls, outlined boxes with names when enlarged), and it has three sizes: réduit (56 px strip of the logo's wing bars), normal (120 px), agrandi (≈ 60 % of the screen).
10. **Kid-safe.** No account, no chat, no public ranking, no guilt notification, precise positions stay on the phone, playback is quiet and explained.

Where each owner wish lives:

| Wish (owner's words) | Where |
|---|---|
| « voir le spectre », « version agrandie et réduite » | Live (réduit ↔ normal toggle), LiveSpectre (agrandi, kHz scale, named calls) |
| « belles apparitions des oiseaux » | L1 arrival in Live and Arrivee; L3/L4 moments |
| « un tableau qui s'alimente en continu avec un compteur » | Live table (self-running) + header counters |
| « nombre de fois en session et au total » | ×N and « au total » on every Live row; Fiche sentence; Palmarès |
| « oiseau rare : une superbe animation » | Rare (golden card, verified before the party) |
| « la première fois : une superbe animation » | Premiere (color wave, landing card) |
| « un statut en fonction du nombre d'oiseaux découverts, une sorte de jeu » | Main ring, Profil (ladder, série, badges, défi), Niveau, Carnet collection |
| GPS + « carte avec des icônes d'oiseaux » | Carte |
| « me dire si c'est sûr ou pas » | Sûr / Probable / À vérifier everywhere, Revue rapide |
| fiche IA (taille, migration, anecdote…) | Fiche |
| réécouter pendant l'écoute et plus tard | Live play buttons, Fiche « Mes sons », Revue |
| palmarès | Palmares |
| envoyer à la LPO (Faune-France) | Resume button + rules 7.7 |

Research patterns reused on purpose: Merlin's live list that lights up instead of reshuffling and its "you decide" verification; Seek's certainty meter (our 1–3 bars) and named levels; Pokémon GO's silhouettes for undiscovered species and progress rings; Duolingo's rare full-screen celebrations and forgiving streaks; eBird's rare = more checking; Bird Buddy's "Nouveau" pin until opened; LPO Oizo'lympique's mnemonics in the species sheet.

---

## 2. Design tokens

### 2.1 Brand colors (DESIGN.md)

| Token | Hex | Use |
|---|---|---|
| Encre de nuit | `#13233A` | dark background, text on light |
| Brume | `#EEF1EC` | light background, text on dark |
| Martin-pêcheur | `#19A7B3` | fills of actions (Écouter, play, links as buttons), spectrum glow |
| Loriot | `#F4C542` | new (Première fois, Nouveau), rare (golden card), progress just gained |
| Lichen | `#9DB46A` | Sûr, confirmed |
| Écorce | `#6B5847` | secondary text and quiet icons on light |

### 2.2 Dark theme (listening and moments)

| Token | Value | Contrast / note |
|---|---|---|
| `bg` | `#13233A` | artboard background |
| `bg-deep` | `#0F1D31` | bottom control bar |
| `well` | `linear-gradient(#0B1728, #0F1E33)` | spectrum background |
| `s1` | `#1A2D47` | rows, stat tiles, cards |
| `s2` | `#213852` | raised pills, selected row |
| `s3` | `#29425F` | toast |
| `veil` | `rgba(12,24,41,.78)` | behind moments |
| `line` | `rgba(238,241,236,.08)` | separators |
| `border` | `rgba(238,241,236,.14)` | icon buttons, outlines (`.32` for secondary buttons) |
| `text-1` | `#EEF1EC` | 13.9 : 1 on bg, 10.5 on s2 |
| `text-2` | `#B4C0CC` | 8.5 on bg, 6.5 on s2, 5.6 on s3 |
| `accent` | `#19A7B3` | fills; text on it = `#13233A` (5.4 : 1) |
| `accent-text` | `#4FC3CC` | teal text/icons on dark (6.6 on s1) |
| `loriot` | `#F4C542` | 9.7 on bg; text on it = `#13233A` |

### 2.3 Light theme (notebook)

| Token | Value | Contrast / note |
|---|---|---|
| `bg` | `#EEF1EC` | artboard background |
| `s1` | `#FFFFFF` | cards, sheet, nav (elevation = lighter surface, no grey drop shadow) |
| `tonal` | `#D6EEF0` | tonal buttons; nav active pill `#D1ECEF` |
| `line` | `#DCE2DA` | separators, ring track, progress track |
| `border` | `#C5CCC2` | chips, secondary buttons, sheet handle |
| `dashed` | `#B9C0B5` | mystery cards (1.5 px dashed) |
| `text-1` | `#13233A` | 13.9 on bg, 15.8 on white |
| `text-2` | `#6B5847` | Écorce: 5.9 on bg, 6.8 on white |
| `accent` | `#19A7B3` | fills; text on it = `#13233A` |
| `accent-text` | `#0B6E77` | teal text on light (5.25 on Brume). DESIGN.md's `#0E7C86` drops to 4.3 : 1 on Brume, so it is replaced here. |
| `loriot-text` | `#7A5A00` | Loriot-colored text on light (5.6 on `#FBEFC8`) |
| `float-shadow` | `0 8px 28px rgba(19,35,58,.14)` | only for floating layers: sheet, review card stack |
| `cta-glow` | `0 10px 28px rgba(25,167,179,.35)` | only the big « Écouter » button |

### 2.4 Reliability (J3 levels) — lightness + shape + word

The icon is 3 rising bars (the logo's wing): 3 filled = Sûr, 2 = Probable, 1 = À vérifier. À vérifier is also the only outlined (dashed) badge.

| Level | Rule (J3) | Dark text / fill | Light text / fill |
|---|---|---|---|
| Sûr | score ≥ 0,80 and plausible here | `#B7CF83` on `rgba(157,180,106,.20)` | `#4B6023` on `#E6EDD6` |
| Probable | 0,55 – 0,80 | `#C9D3DD` on `rgba(201,211,221,.12)` | `#34495E` on `#E3E9EF` |
| À vérifier | < 0,55, or Rare/Exceptionnel here | `#F2A677`, 1.5 px dashed, no fill | `#A04A1C`, 1.5 px dashed on white |

The decimal score appears only in details (Revue card, Fiche recordings): « Score 0,58 ».

### 2.5 Species colors (from the icons)

`accent` = row halo (at 20 %), glow (at 22 %), wave, podium, map ring on dark. `tintDark` = celebration card top on dark. `tintLight` = card and header background on light (text `#13233A`, ≥ 12 : 1). `deep` = bars and graphics on light (≥ 3.2 : 1 on white).

| Key | Nom | Latin | accent | tintDark | tintLight | deep |
|---|---|---|---|---|---|---|
| `rougegorge` | Rougegorge familier | Erithacus rubecula | `#EC7A3C` | `#47383A` | `#FCE7DC` | `#DB733C` |
| `mesange-bleue` | Mésange bleue | Cyanistes caeruleus | `#3B8FDB` | `#1D3D61` | `#DCEBF9` | `#3B8FDB` |
| `mesange-charbonniere` | Mésange charbonnière | Parus major | `#E9C13C` | `#46493A` | `#FBF4DC` | `#A58E3B` |
| `merle` | Merle noir | Turdus merula | `#F6B12A` | `#494536` | `#FDF1D9` | `#B2862F` |
| `pic-epeiche` | Pic épeiche | Dendrocopos major | `#D8343A` | `#42273A` | `#F8DADC` | `#D8343A` |
| `pinson` | Pinson des arbres | Fringilla coelebs | `#DD8C6E` | `#433C46` | `#F9EAE5` | `#C17D67` |
| `pie` | Pie bavarde | Pica pica | `#2A9486` | `#193E4C` | `#D9ECE9` | `#2A9486` |
| `troglodyte` | Troglodyte mignon | Troglodytes troglodytes | `#C69A6A` | `#3E4046` | `#F5EDE4` | `#AD8963` |
| `moineau` | Moineau domestique | Passer domesticus | `#C28A55` | `#3D3C40` | `#F4EAE0` | `#B88453` |
| `pouillot` | Pouillot véloce | Phylloscopus collybita | `#A6AA73` | `#364348` | `#EFF0E6` | `#8C9269` |
| `chouette-hulotte` | Chouette hulotte | Strix aluco | `#C49A6C` | `#3D4046` | `#F4EDE5` | `#AB8965` |
| `huppe` | Huppe fasciée | Upupa epops | `#E3A07A` | `#454149` | `#FAEEE7` | `#B5846C` |
| `martin-pecheur` | Martin-pêcheur d'Europe | Alcedo atthis | `#29A9D6` | `#18435F` | `#D8F0F8` | `#2699C3` |
| `loriot` | Loriot d'Europe | Oriolus oriolus | `#F4C542` | `#494A3C` | `#FDF5DD` | `#A38B3F` |

To write an accent with alpha, use `rgba()` of the accent (e.g. `rgba(236,122,60,.20)` for the robin halo).

### 2.6 Status colors (game, section 7)

| # | Statut | Color | Glyph key |
|---|---|---|---|
| 1 | Oisillon | `#F2B98B` | `oisillon` |
| 2 | Jeune plume | `#E9836B` | `plume` |
| 3 | Premier envol | `#9DB46A` | `envol` |
| 4 | Sentinelle des haies | `#5DA46A` | `sentinelle` |
| 5 | Oreille de chouette | `#C28A55` | `chouette` |
| 6 | Grand migrateur | `#5A9BE0` | `migrateur` |
| 7 | Plume d'or | `#F4C542` | `plumedor` |
| 8 | Martin-pêcheur | `#19A7B3` | `martin` |

Glyphs are drawn in `#13233A` on the status color (all ≥ 5.2 : 1). Future statuses: fill `#E1E5DE` (light) or `rgba(238,241,236,.10)` (dark), glyph at 40 % opacity.

### 2.7 Badge tiers

| Tier | Circle fill | Glyph color | Tier dots |
|---|---|---|---|
| locked | `#E6E9E4` | `#9AA39A` + small `lock` | 0 of 3 filled, progress text « 4 sur 10 » |
| 1 plume | `#EADFD1` | `#6B5847` | 1 of 3 |
| 2 plumes | `#E3EBD2` | `#4B6023` | 2 of 3 |
| 3 plumes | `#FBEFC8` | `#7A5A00` | 3 of 3 |

Tier dots: three 6 px circles, filled `#13233A`, empty `#C5CCC2`.

### 2.8 Radii, spacing, sizes

- Radii: **28** hero and celebration cards, sheet top corners, fiche header photo area; **20** cards, rows, tiles; **16** insets (mini spectrum, mini map); **12** small thumbnails; **999** buttons, chips, badges, pills, rings.
- Spacing scale: 4, 8, 12, 16, 20, 24, 32. Page gutter 20 px (light), 16 px (dark header), 8 px (Live list). Card padding 16 (compact 12). Gap between sections 16; inside cards 8–12.
- Touch targets ≥ 48 px. Main action 56 px; « Écouter » 72 px; « Arrêter » / « Pause » 64 px.
- Nav bar 80 px. Top app bar 56 px. Spectrum: réduit 56 px, normal 120 px, agrandi 450 px plot.

### 2.9 Typography

Fonts from the helmet link only. Always set the family inline.

| Style | CSS |
|---|---|
| Display 34 | `font-family: 'Fraunces', Georgia, serif; font-variation-settings: 'SOFT' 100; font-weight: 600; font-size: 34px; line-height: 1.1` |
| Title 26 | same Fraunces, `font-size: 26px; line-height: 1.15` |
| Heading 20 | same Fraunces, `font-size: 20px; line-height: 1.25` (section titles, card titles, top bar) |
| Species 17 | same Fraunces, `font-size: 17px; line-height: 1.2` (species names in lists; 15 px in grid cards and compact rows) |
| Latin | `font-family: 'Fraunces', Georgia, serif; font-style: italic; font-weight: 500` at 17 (headers) or 13–15 (lists) |
| Body 17 / 15 | `font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 17px` or `15px; line-height: 1.45` |
| Label 15 / 13 | Atkinson 700 (buttons 17 or 15, chips 15, badges 13) |
| Caption 13 | Atkinson 400, `line-height: 1.35`, color text-2 |
| Number XL / L / M | Atkinson `font-weight: 800; font-variant-numeric: tabular-nums` at 34 / 26 / 20, `line-height: 1` |

French formats: time of day « 7 h 52 », duration « 42 min », live timer « 12:47 » (mm:ss), date « samedi 26 septembre », decimals « 0,97 », thousands « 1 104 », counts « ×4 », « 142 au total », « 142 fois ».

---

## 3. The shared `<helmet>` (copy verbatim)

Light boards: change only `body{margin:0;background:#13233A}` to `body{margin:0;background:#EEF1EC}`.

```html
<helmet>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Fraunces:ital,opsz,wght,SOFT@0,9..144,500..650,100;1,9..144,500..650,100&amp;family=Atkinson+Hyperlegible+Next:wght@400..800&amp;display=swap" rel="stylesheet">
<style>
body{margin:0;background:#13233A}
a{color:#19A7B3}a:hover{color:#0E7C86}
.bg-press{transition:transform 120ms cubic-bezier(0.23,1,0.32,1)}.bg-press:active{transform:scale(.97)}
@keyframes bg-fade{from{opacity:0}to{opacity:1}}
@keyframes bg-rise{from{opacity:0;transform:translateY(12px) scale(.96)}to{opacity:1;transform:none}}
@keyframes bg-arrive{0%{opacity:0;transform:translateY(-12px) scale(.96)}55%{opacity:1;transform:translateY(2px) scale(1.01)}100%{opacity:1;transform:none}}
@keyframes bg-bump-a{0%{transform:scale(1)}35%{transform:scale(1.15)}100%{transform:scale(1)}}
@keyframes bg-bump-b{0%{transform:scale(1)}35%{transform:scale(1.15)}100%{transform:scale(1)}}
@keyframes bg-glow-a{0%{opacity:0}18%{opacity:1}100%{opacity:0}}
@keyframes bg-glow-b{0%{opacity:0}18%{opacity:1}100%{opacity:0}}
@keyframes bg-sing{0%,100%{transform:scaleY(.35)}50%{transform:scaleY(1)}}
@keyframes bg-scroll{from{transform:translateX(0)}to{transform:translateX(-50%)}}
@keyframes bg-live{0%,100%{opacity:1}50%{opacity:.35}}
@keyframes bg-ripple{0%{opacity:.55;transform:scale(.95)}100%{opacity:0;transform:scale(1.6)}}
@keyframes bg-sheet{0%{opacity:0;transform:translateY(48px)}70%{opacity:1;transform:translateY(-4px)}100%{opacity:1;transform:none}}
@keyframes bg-sweep{from{transform:translateX(-100%)}to{transform:translateX(100%)}}
@keyframes bg-land{0%{opacity:0;transform:translateY(24px) scale(.95)}50%{opacity:1;transform:translateY(-4px) scale(1.03)}100%{opacity:1;transform:none}}
@keyframes bg-pop{0%{opacity:0;transform:scale(.95)}60%{opacity:1;transform:scale(1.04)}100%{opacity:1;transform:none}}
@keyframes bg-ring{0%{opacity:.8;transform:scale(.95)}100%{opacity:0;transform:scale(1.9)}}
@keyframes bg-shimmer{0%{transform:translateX(-120%)}55%,100%{transform:translateX(120%)}}
@keyframes bg-twinkle{0%,100%{opacity:0;transform:scale(.95)}50%{opacity:1;transform:scale(1.05)}}
@keyframes bg-gain{from{transform:scaleX(.05)}to{transform:scaleX(1)}}
@keyframes bg-feather{0%{opacity:0;transform:translate(0,-24px) rotate(-12deg)}15%{opacity:.9}100%{opacity:0;transform:translate(28px,180px) rotate(28deg)}}
@keyframes bg-nudge{0%,62%,78%,94%,100%{transform:none}70%{transform:translateX(16px) rotate(2deg)}86%{transform:translateX(-10px) rotate(-1.5deg)}}
@keyframes bg-fly-right{to{opacity:0;transform:translateX(440px) rotate(14deg)}}
@keyframes bg-fly-left{to{opacity:0;transform:translateX(-440px) rotate(-14deg)}}
@keyframes bg-fly-up{to{opacity:0;transform:translateY(-560px)}}
@keyframes bg-playhead{from{transform:translateX(-100%)}to{transform:translateX(0)}}
@media (prefers-reduced-motion: reduce){[style*="animation"]{animation-name:bg-fade!important;animation-duration:200ms!important;animation-delay:0ms!important;animation-iteration-count:1!important}.fx{display:none!important}}
</style>
</helmet>
```

Root element (after `<helmet>`), dark:
`<div style="width: 390px; height: 844px; box-sizing: border-box; overflow: hidden; position: relative; display: flex; flex-direction: column; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; color: #EEF1EC; background: #13233A">`
Light: same with `color: #13233A; background: #EEF1EC`.

Class names allowed: `bg-press` (press feedback on buttons and links) and `fx` (purely decorative motion layer, removed when reduced motion is on). No other classes.

Keyframe catalogue (use these names, durations and curves):

| Name | Use | Duration | Curve |
|---|---|---|---|
| `bg-fade` | any fade in | 200 ms | `cubic-bezier(0.23,1,0.32,1)` |
| `bg-rise` | element entering (text lines, toast, cards on load) | 220 ms, stagger 40 ms, max 5 items | same |
| `bg-arrive` | new species row in Live | 420 ms | same (overshoot is in the keyframe) |
| `bg-bump-a` / `bg-bump-b` | counter +1 (alternate the two names to restart) | 200 ms | same |
| `bg-glow-a` / `bg-glow-b` | re-heard row glow (alternate) | 900 ms | same |
| `bg-sing` | "chante maintenant" bars, mic level bars, listening logo | 900–1400 ms infinite | `cubic-bezier(0.45,0,0.55,1)` |
| `bg-scroll` | spectrum scroll (element = 2 tiles wide) | 10 s infinite | `linear` |
| `bg-live` | live dot | 1600 ms infinite | `ease-in-out` |
| `bg-ripple` | drawn haptic (ring around the icon) | 600 ms | `cubic-bezier(0.23,1,0.32,1)` |
| `bg-sheet` | bottom sheet entering | 380 ms | same |
| `bg-sweep` | first-time color wave crossing the screen | 600 ms | `cubic-bezier(0.77,0,0.175,1)` |
| `bg-land` | big icon / card landing | 700 ms (first time), 800 ms (rare), 900 ms (status) | `cubic-bezier(0.23,1,0.32,1)` |
| `bg-pop` | pill or badge appearing, next review card | 250 ms | same |
| `bg-ring` | radiating rings (rare, status) | 1800–2400 ms infinite, staggered | same |
| `bg-shimmer` | golden sheen crossing the rare card | 2600 ms infinite | `cubic-bezier(0.45,0,0.55,1)` |
| `bg-twinkle` | light points around a confirmed rare bird | 1600 ms infinite, stagger 130 ms | `ease-in-out` |
| `bg-gain` | progress just gained (Loriot segment) | 600 ms, delay 400 ms | `cubic-bezier(0.23,1,0.32,1)` |
| `bg-feather` | falling feathers (status) | 2600 ms | `cubic-bezier(0.23,1,0.32,1)` |
| `bg-nudge` | idle hint of the swipeable review card | 5200 ms infinite, delay 1600 ms | `cubic-bezier(0.45,0,0.55,1)` |
| `bg-fly-right` / `-left` / `-up` | review card leaving | 260 ms, `forwards` | `cubic-bezier(0.23,1,0.32,1)` |
| `bg-playhead` | clip playhead (element = full width, translate trick) | clip length (3 s) | `linear` |

Rules: animate only `transform` and `opacity`; never start from scale 0 (start at .95 with opacity 0); exits are shorter than entries; no `ease-in`. Reduced motion is handled by the helmet: every inline animation becomes a single 200 ms fade and `.fx` layers disappear, so text and numbers must never live inside an `.fx` element.

To restart a CSS animation from state: switch its name between the `-a` and `-b` twins, or toggle the element's `display` from `none` to its value (all animations inside restart).

---

## 4. Iconography

### 4.1 UI icons (24 × 24 grid, stroke 2, round caps and joins)

Wrapper (set the color with `color:` so filled icons follow it):

```html
<svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#0B6E77"><path d="M8 5.8v12.4a.8.8 0 0 0 1.2.7l9.9-6.2a.8.8 0 0 0 0-1.4L9.2 5.1A.8.8 0 0 0 8 5.8z" fill="currentColor" stroke="none"/></svg>
```

Replace the inner markup with one of these. Sizes: 24 (default), 20–22 in buttons, 18 in chips and links, 12–14 in badges.

| Key | Inner markup |
|---|---|
| `play` | `<path d="M8 5.8v12.4a.8.8 0 0 0 1.2.7l9.9-6.2a.8.8 0 0 0 0-1.4L9.2 5.1A.8.8 0 0 0 8 5.8z" fill="currentColor" stroke="none"/>` |
| `pause` | `<path d="M8.5 5.5v13M15.5 5.5v13" stroke-width="3"/>` |
| `stop` | `<rect x="6" y="6" width="12" height="12" rx="2.5" fill="currentColor" stroke="none"/>` |
| `mic` | `<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21M8.5 21h7"/>` |
| `bars` | `<path d="M4 10.5v3M8 7v10M12 4.5v15M16 8v8M20 10.5v3"/>` |
| `expand` | `<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>` |
| `shrink` | `<path d="M9 4v5H4M15 4v5h5M9 20v-5H4M15 20v-5h5"/>` |
| `chevron-up` | `<path d="m6 15 6-6 6 6"/>` |
| `chevron-down` | `<path d="m6 9 6 6 6-6"/>` |
| `chevron-right` | `<path d="m9 5 7 7-7 7"/>` |
| `back` | `<path d="M19 12H5M11 5l-7 7 7 7"/>` |
| `close` | `<path d="M6 6l12 12M18 6 6 18"/>` |
| `check` | `<path d="M5 12.5l4.5 4.5L19 7.5"/>` |
| `question` | `<path d="M9 9.2a3 3 0 1 1 4.2 2.8c-.8.4-1.2 1-1.2 1.8v.7"/><path d="M12 18.2v.1" stroke-width="2.6"/>` |
| `pin` | `<path d="M12 21s-6.5-5.6-6.5-11a6.5 6.5 0 0 1 13 0c0 5.4-6.5 11-6.5 11z"/><circle cx="12" cy="10" r="2.5"/>` |
| `locate` | `<circle cx="12" cy="12" r="6.5"/><circle cx="12" cy="12" r="2" fill="currentColor"/><path d="M12 2.5v3M12 18.5v3M2.5 12h3M18.5 12h3"/>` |
| `share` | `<path d="M12 3v12M7.5 7.5 12 3l4.5 4.5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/>` |
| `send` | `<path d="M21 3 10.5 13.5M21 3l-6.5 18-4-7.5L3 9.5z"/>` |
| `star` | `<path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8L3.5 9.7l5.9-.9z"/>` |
| `headphones` | `<path d="M4 15v-3a8 8 0 0 1 16 0v3"/><rect x="3" y="14" width="4.5" height="7" rx="1.5"/><rect x="16.5" y="14" width="4.5" height="7" rx="1.5"/>` |
| `volume-low` | `<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9.5a3.5 3.5 0 0 1 0 5"/>` |
| `home` | `<path d="M3.5 10.5 12 3.5l8.5 7V20a1 1 0 0 1-1 1H15v-6H9v6H4.5a1 1 0 0 1-1-1z"/>` |
| `carnet` | `<path d="M5 4.5A1.5 1.5 0 0 1 6.5 3H19v14.5H6.5A1.5 1.5 0 0 0 5 19z"/><path d="M5 19a1.5 1.5 0 0 0 1.5 1.5H19v-3"/><path d="M9.5 7.5h5"/>` |
| `map` | `<path d="M9 4.5 3.5 6.5v13L9 17.5l6 2 5.5-2v-13L15 6.5z"/><path d="M9 4.5v13M15 6.5v13"/>` |
| `profil` | `<circle cx="12" cy="8.5" r="4"/><path d="M4.5 20.5a7.5 7.5 0 0 1 15 0"/>` |
| `podium` | `<path d="M3 20.5h18M4.5 20.5V14h5v6.5M9.5 20.5V8h5v12.5M14.5 20.5V11h5v9.5"/>` |
| `sparkle` | `<path d="M12 2.5C12.7 8 14 9.3 21.5 12 14 14.7 12.7 16 12 21.5 11.3 16 10 14.7 2.5 12 10 9.3 11.3 8 12 2.5z" fill="currentColor" stroke="none"/>` |
| `diamond` | `<path d="M12 3.5 20.5 12 12 20.5 3.5 12z" fill="currentColor" stroke="none"/>` |
| `half` | `<circle cx="12" cy="12" r="7.5"/><path d="M12 4.5a7.5 7.5 0 0 1 0 15z" fill="currentColor" stroke="none"/>` |
| `calendar` | `<rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/>` |
| `clock` | `<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>` |
| `info` | `<circle cx="12" cy="12" r="9"/><path d="M12 11v5.5"/><path d="M12 7.6v.1" stroke-width="2.6"/>` |
| `layers` | `<path d="m12 3.5 9 5-9 5-9-5z"/><path d="m3 13.5 9 5 9-5"/>` |
| `lock` | `<rect x="5" y="10.5" width="14" height="10" rx="2.5"/><path d="M8 10.5V8a4 4 0 0 1 8 0v2.5"/>` |
| `filter` | `<path d="M4 6.5h16M7 12h10M10 17.5h4"/>` |
| `sun` | `<path d="M7.5 17a4.5 4.5 0 0 1 9 0"/><path d="M12 4v3M4.6 9.1l2 1.6M19.4 9.1l-2 1.6M2.5 17h19M7 20.5h10"/>` |
| `moon` | `<path d="M19.5 14.5A8 8 0 0 1 9.5 4.5a8 8 0 1 0 10 10z"/>` |

Icon-only buttons always carry `aria-label` (French, verb first: « Agrandir le spectre », « Réduire le spectre », « Retour », « Fermer », « Partager », « Me localiser », « Fond de carte », « Palmarès », « Ajouter aux favoris », « Réécouter : Rougegorge familier »).

### 4.2 Species icons

Source: `fork/maquette/birds.md` (one `<svg>` per heading, 64 × 64 viewBox, facing left). Keys: `rougegorge`, `mesange-bleue`, `mesange-charbonniere`, `merle`, `pic-epeiche`, `pinson`, `pie`, `troglodyte`, `moineau`, `pouillot`, `chouette-hulotte`, `huppe`, `martin-pecheur`, `loriot`, and `mystere` (undiscovered species). Sizes used: 34 (compact row), 36 (palmarès list), 40 (map sheet, bilan strip), 42 (live row), 48–64 (cards, podium), 72 (carnet grid), 96–176 (hero, moments). Birds face left: place a big icon on the right of its title so it looks at the text.

"Heard but not confirmed" look: the species icon with `filter: grayscale(1); opacity: .45` on its `<svg>`.

### 4.3 Status glyphs (for emblems and rings; 24 grid, stroke `#13233A` 2)

Wrap as `<g fill="none" stroke="#13233A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">…</g>` inside the emblem (see 5.7).

| Key | Inner markup |
|---|---|
| `oisillon` | `<path d="M12 3.5c3.3 0 6 4.9 6 9.3a6 6 0 0 1-12 0c0-4.4 2.7-9.3 6-9.3z"/><path d="M7 12.6l2.4 1.5 2.6-2.1 2.6 2.1 2.4-1.5"/>` |
| `plume` | `<path d="M5.5 20.5 16 10"/><path d="M19.5 3.5C12 3.5 7 7.5 7 15l2 2c7.5 0 11.5-5.5 10.5-13.5z"/>` |
| `envol` | `<path d="M2.5 9.5c2.8-2.3 6-2.3 9.5 1.2 3.5-3.5 6.7-3.5 9.5-1.2"/><path d="M7.5 15.5c1.5-1.1 3-1.1 4.5.5 1.5-1.6 3-1.6 4.5-.5"/>` |
| `sentinelle` | `<path d="M3 13.5S6.5 8 12 8s9 5.5 9 5.5-3.5 5.5-9 5.5-9-5.5-9-5.5z"/><circle cx="12" cy="13.5" r="2.5"/><path d="M12 2.5v2.5M6.5 4.5l1.3 2M17.5 4.5l-1.3 2"/>` |
| `chouette` | `<path d="M5 4l3.2 3.4M19 4l-3.2 3.4"/><path d="M5 4c-.7 2.2-1 4.6-1 7a8 8 0 0 0 16 0c0-2.4-.3-4.8-1-7"/><circle cx="9" cy="11.5" r="2.4"/><circle cx="15" cy="11.5" r="2.4"/><path d="M11 15.8l1 1.4 1-1.4"/>` |
| `migrateur` | `<path d="M2.5 6.5 4.3 8l1.8-1.5M6.8 10.5l1.8 1.5 1.8-1.5M11.1 14.5l1.8 1.5 1.8-1.5M13.6 10.5l1.8 1.5 1.8-1.5M17.9 6.5 19.7 8l1.8-1.5"/>` |
| `plumedor` | `<path d="M4.5 21 14 11.5"/><path d="M17.5 5.5C11 5.5 7 9 7 15.5l1.8 1.8c6.5 0 10-4.3 8.7-11.8z"/><path d="M19.5 1.8c.3 1.6.9 2.2 2.5 2.5-1.6.3-2.2.9-2.5 2.5-.3-1.6-.9-2.2-2.5-2.5 1.6-.3 2.2-.9 2.5-2.5z" fill="#13233A"/>` |
| `martin` | `<path d="M5 10v4M8.5 7v10M12 4.5v15M15.5 8v8M19 10.5v3"/>` |

### 4.4 Brand mark

Derived from `logo/cand-spectre/logo.svg` (round teal bird facing left, eye, open yellow beak, tail up, wing of five spectrum bars with one yellow bar). Cropped viewBox, no animation, ids `bm-*`. Width = height × 1.237.

Static (Accueil top bar, share cards):

```html
<svg viewBox="30 72 460 372" width="40" height="32" role="img" aria-label="BirdyGo" style="display:block;flex:none"><defs><linearGradient id="bm-teal" gradientUnits="userSpaceOnUse" x1="140" y1="100" x2="400" y2="440"><stop offset="0" stop-color="#1DB3BE"/><stop offset="1" stop-color="#0F8792"/></linearGradient><linearGradient id="bm-deep" gradientUnits="userSpaceOnUse" x1="460" y1="150" x2="370" y2="320"><stop offset="0" stop-color="#139AA5"/><stop offset="1" stop-color="#0B6F79"/></linearGradient></defs><path d="M356.7 265.7L439.5 154.3A23 23 0 0 1 478.4 178.6L414.1 301.7A34 34 0 1 1 356.7 265.7Z" fill="url(#bm-deep)"/><g stroke-linejoin="round" stroke-width="12"><path d="M108 200L54 214L126 234Z" fill="#E3A22B" stroke="#E3A22B"/><path d="M132 146L40 156L108 192Z" fill="#F4C542" stroke="#F4C542"/></g><path d="M109.2 227.1A98 98 0 0 1 265.3 110.7A64 64 0 0 0 298.5 129.4A156 156 0 1 1 113.1 251A34 34 0 0 0 109.2 227.1Z" fill="url(#bm-teal)"/><g fill="none" stroke-width="30" stroke-linecap="round"><path d="M206 239v90" stroke="#DDF4F5"/><path d="M250 217v142" stroke="#F4C542"/><path d="M294 240v108" stroke="#A8E2E6"/><path d="M338 269v64" stroke="#79D0D7"/><path d="M382 297v22" stroke="#52C0C9"/></g><circle cx="170" cy="168" r="19" fill="#13233A"/><circle cx="165" cy="162" r="5.5" fill="#FFFFFF"/></svg>
```

Wordmark next to it (8 px gap), same color as text-1 of the theme (no word colored differently):

```html
<span style="font-family: 'Fraunces', Georgia, serif; font-variation-settings: 'SOFT' 100; font-weight: 600; font-size: 20px; line-height: 1; color: #13233A">BirdyGo</span>
```

Listening variant (Live header): the five wing bars move like a level meter.

```html
<svg viewBox="30 72 460 372" width="35" height="28" role="img" aria-label="BirdyGo" style="display:block;flex:none"><defs><linearGradient id="bm-teal" gradientUnits="userSpaceOnUse" x1="140" y1="100" x2="400" y2="440"><stop offset="0" stop-color="#1DB3BE"/><stop offset="1" stop-color="#0F8792"/></linearGradient><linearGradient id="bm-deep" gradientUnits="userSpaceOnUse" x1="460" y1="150" x2="370" y2="320"><stop offset="0" stop-color="#139AA5"/><stop offset="1" stop-color="#0B6F79"/></linearGradient></defs><path d="M356.7 265.7L439.5 154.3A23 23 0 0 1 478.4 178.6L414.1 301.7A34 34 0 1 1 356.7 265.7Z" fill="url(#bm-deep)"/><g stroke-linejoin="round" stroke-width="12"><path d="M108 200L54 214L126 234Z" fill="#E3A22B" stroke="#E3A22B"/><path d="M132 146L40 156L108 192Z" fill="#F4C542" stroke="#F4C542"/></g><path d="M109.2 227.1A98 98 0 0 1 265.3 110.7A64 64 0 0 0 298.5 129.4A156 156 0 1 1 113.1 251A34 34 0 0 0 109.2 227.1Z" fill="url(#bm-teal)"/><g fill="none" stroke-width="30" stroke-linecap="round"><path d="M206 239v90" stroke="#DDF4F5" style="transform-box: fill-box; transform-origin: center; animation: bg-sing 1100ms cubic-bezier(0.45,0,0.55,1) 0ms infinite"/><path d="M250 217v142" stroke="#F4C542" style="transform-box: fill-box; transform-origin: center; animation: bg-sing 1100ms cubic-bezier(0.45,0,0.55,1) 120ms infinite"/><path d="M294 240v108" stroke="#A8E2E6" style="transform-box: fill-box; transform-origin: center; animation: bg-sing 1100ms cubic-bezier(0.45,0,0.55,1) 240ms infinite"/><path d="M338 269v64" stroke="#79D0D7" style="transform-box: fill-box; transform-origin: center; animation: bg-sing 1100ms cubic-bezier(0.45,0,0.55,1) 360ms infinite"/><path d="M382 297v22" stroke="#52C0C9" style="transform-box: fill-box; transform-origin: center; animation: bg-sing 1100ms cubic-bezier(0.45,0,0.55,1) 480ms infinite"/></g><circle cx="170" cy="168" r="19" fill="#13233A"/><circle cx="165" cy="162" r="5.5" fill="#FFFFFF"/></svg>
```

---

## 5. Components (copy-paste)

All snippets are final. Change only text, numbers, `href`, `aria-label`, and the species (icon + accent) where noted.

### 5.1 Buttons

**Big « Écouter »** (Accueil only; full width inside a 20 px gutter; placed 16 px above the nav):

```html
<a href="Live.dc.html" class="bg-press" style="display: flex; align-items: center; justify-content: center; gap: 12px; height: 72px; border-radius: 999px; background: #19A7B3; color: #13233A; text-decoration: none; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 20px; box-shadow: 0 10px 28px rgba(25,167,179,.35)"><svg viewBox="0 0 24 24" width="28" height="28" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M4 10.5v3M8 7v10M12 4.5v15M16 8v8M20 10.5v3"/></svg>Écouter</a>
```

**Primary** (56 px; as `<a>` when it navigates, `<button>` otherwise):

```html
<a href="Live.dc.html" class="bg-press" style="display: flex; align-items: center; justify-content: center; gap: 10px; height: 56px; padding: 0 24px; border-radius: 999px; background: #19A7B3; color: #13233A; text-decoration: none; border: 0; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 17px; white-space: nowrap; cursor: pointer">Continuer l'écoute</a>
```

```html
<button type="button" class="bg-press" style="display: flex; align-items: center; justify-content: center; gap: 10px; height: 56px; padding: 0 24px; border-radius: 999px; background: #19A7B3; color: #13233A; text-decoration: none; border: 0; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 17px; white-space: nowrap; cursor: pointer"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>Vérifier 3 détections</button>
```

**Secondary** light / dark:

```html
<button type="button" class="bg-press" style="display: flex; align-items: center; justify-content: center; gap: 10px; height: 56px; padding: 0 22px; border-radius: 999px; background: #FFFFFF; color: #13233A; text-decoration: none; border: 1.5px solid #C5CCC2; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 17px; white-space: nowrap; cursor: pointer"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M12 3v12M7.5 7.5 12 3l4.5 4.5M5 13v6a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2v-6"/></svg>Partager</button>
```

```html
<button type="button" class="bg-press" style="display: flex; align-items: center; justify-content: center; gap: 10px; height: 56px; padding: 0 22px; border-radius: 999px; background: transparent; color: #EEF1EC; text-decoration: none; border: 1.5px solid rgba(238,241,236,.32); font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 17px; white-space: nowrap; cursor: pointer"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#EEF1EC"><path d="M8 5.8v12.4a.8.8 0 0 0 1.2.7l9.9-6.2a.8.8 0 0 0 0-1.4L9.2 5.1A.8.8 0 0 0 8 5.8z" fill="currentColor" stroke="none"/></svg>Réécouter</button>
```

**Tonal** (48 px, for inline actions like « Chant de référence », « Revoir sur la carte ») light / dark:

```html
<button type="button" class="bg-press" style="display: flex; align-items: center; justify-content: center; gap: 8px; height: 48px; padding: 0 18px; border-radius: 999px; background: #D6EEF0; color: #0B6E77; text-decoration: none; border: 0; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 15px; white-space: nowrap; cursor: pointer"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#0B6E77"><path d="M8 5.8v12.4a.8.8 0 0 0 1.2.7l9.9-6.2a.8.8 0 0 0 0-1.4L9.2 5.1A.8.8 0 0 0 8 5.8z" fill="currentColor" stroke="none"/></svg>Chant de référence</button>
```

```html
<button type="button" class="bg-press" style="display: flex; align-items: center; justify-content: center; gap: 8px; height: 48px; padding: 0 18px; border-radius: 999px; background: rgba(25,167,179,.16); color: #4FC3CC; text-decoration: none; border: 0; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 15px; white-space: nowrap; cursor: pointer"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#4FC3CC"><path d="M8 5.8v12.4a.8.8 0 0 0 1.2.7l9.9-6.2a.8.8 0 0 0 0-1.4L9.2 5.1A.8.8 0 0 0 8 5.8z" fill="currentColor" stroke="none"/></svg>Chant de référence</button>
```

**Icon button** light / dark (48 px circle):

```html
<a href="Carnet.dc.html" aria-label="Retour" class="bg-press" style="display: flex; align-items: center; justify-content: center; flex: none; width: 48px; height: 48px; border-radius: 999px; background: #FFFFFF; border: 1px solid #DCE2DA; color: #13233A; padding: 0; cursor: pointer; text-decoration: none"><svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M19 12H5M11 5l-7 7 7 7"/></svg></a>
```

```html
<a href="LiveSpectre.dc.html" aria-label="Agrandir le spectre" class="bg-press" style="display: flex; align-items: center; justify-content: center; flex: none; width: 48px; height: 48px; border-radius: 999px; background: rgba(238,241,236,.08); border: 1px solid rgba(238,241,236,.14); color: #EEF1EC; padding: 0; cursor: pointer; text-decoration: none"><svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#EEF1EC"><path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/></svg></a>
```

**Réécouter (play) button** dark idle / light idle / playing (same on both themes). Playing = teal fill + pause icon; it stops by itself after the 3 s clip.

```html
<button type="button" aria-label="Réécouter : Rougegorge familier" class="bg-press" style="display: flex; align-items: center; justify-content: center; flex: none; width: 48px; height: 48px; border-radius: 999px; background: transparent; border: 2px solid #4FC3CC; padding: 0; cursor: pointer"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#4FC3CC"><path d="M8 5.8v12.4a.8.8 0 0 0 1.2.7l9.9-6.2a.8.8 0 0 0 0-1.4L9.2 5.1A.8.8 0 0 0 8 5.8z" fill="currentColor" stroke="none"/></svg></button>
```

```html
<button type="button" aria-label="Réécouter : Rougegorge familier" class="bg-press" style="display: flex; align-items: center; justify-content: center; flex: none; width: 48px; height: 48px; border-radius: 999px; background: transparent; border: 2px solid #0B6E77; padding: 0; cursor: pointer"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#0B6E77"><path d="M8 5.8v12.4a.8.8 0 0 0 1.2.7l9.9-6.2a.8.8 0 0 0 0-1.4L9.2 5.1A.8.8 0 0 0 8 5.8z" fill="currentColor" stroke="none"/></svg></button>
```

```html
<button type="button" aria-label="Arrêter la réécoute" class="bg-press" style="display: flex; align-items: center; justify-content: center; flex: none; width: 48px; height: 48px; border-radius: 999px; background: #19A7B3; border: 0; padding: 0; cursor: pointer"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M8.5 5.5v13M15.5 5.5v13" stroke-width="3"/></svg></button>
```

**Live control bar** (dark): « Arrêter » is the main action (Brume fill), « Pause » secondary. Put both in `<div style="display: flex; gap: 12px">`.

```html
<a href="Resume.dc.html" class="bg-press" style="flex: 3; display: flex; align-items: center; justify-content: center; gap: 10px; height: 64px; border-radius: 999px; background: #EEF1EC; color: #13233A; text-decoration: none; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 17px; white-space: nowrap"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><rect x="6" y="6" width="12" height="12" rx="2.5" fill="currentColor" stroke="none"/></svg>Arrêter</a>
<button type="button" class="bg-press" style="flex: 2; display: flex; align-items: center; justify-content: center; gap: 10px; height: 64px; border-radius: 999px; background: transparent; border: 1.5px solid rgba(238,241,236,.32); color: #EEF1EC; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 17px; white-space: nowrap; cursor: pointer"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#EEF1EC"><path d="M8.5 5.5v13M15.5 5.5v13" stroke-width="3"/></svg>Pause</button>
```

When paused, the Pause button shows the `play` icon and the label « Reprendre ».

### 5.2 Reliability badges

Dark:

```html
<span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 10px 0 8px; border-radius: 999px; background: rgba(157,180,106,.20); border: 0; color: #B7CF83; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 12 12" width="12" height="12" aria-hidden="true" style="display:block;flex:none"><rect x="1" y="6.5" width="2.4" height="4.5" rx="1.2" fill="#B7CF83" opacity="1"/><rect x="4.8" y="4" width="2.4" height="7" rx="1.2" fill="#B7CF83" opacity="1"/><rect x="8.6" y="1" width="2.4" height="10" rx="1.2" fill="#B7CF83" opacity="1"/></svg>Sûr</span>
<span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 10px 0 8px; border-radius: 999px; background: rgba(201,211,221,.12); border: 0; color: #C9D3DD; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 12 12" width="12" height="12" aria-hidden="true" style="display:block;flex:none"><rect x="1" y="6.5" width="2.4" height="4.5" rx="1.2" fill="#C9D3DD" opacity="1"/><rect x="4.8" y="4" width="2.4" height="7" rx="1.2" fill="#C9D3DD" opacity="1"/><rect x="8.6" y="1" width="2.4" height="10" rx="1.2" fill="#C9D3DD" opacity="0.3"/></svg>Probable</span>
<span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 8.5px 0 6.5px; border-radius: 999px; background: transparent; border: 1.5px dashed #F2A677; color: #F2A677; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 12 12" width="12" height="12" aria-hidden="true" style="display:block;flex:none"><rect x="1" y="6.5" width="2.4" height="4.5" rx="1.2" fill="#F2A677" opacity="1"/><rect x="4.8" y="4" width="2.4" height="7" rx="1.2" fill="#F2A677" opacity="0.3"/><rect x="8.6" y="1" width="2.4" height="10" rx="1.2" fill="#F2A677" opacity="0.3"/></svg>À vérifier</span>
```

Light:

```html
<span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 10px 0 8px; border-radius: 999px; background: #E6EDD6; border: 0; color: #4B6023; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 12 12" width="12" height="12" aria-hidden="true" style="display:block;flex:none"><rect x="1" y="6.5" width="2.4" height="4.5" rx="1.2" fill="#4B6023" opacity="1"/><rect x="4.8" y="4" width="2.4" height="7" rx="1.2" fill="#4B6023" opacity="1"/><rect x="8.6" y="1" width="2.4" height="10" rx="1.2" fill="#4B6023" opacity="1"/></svg>Sûr</span>
<span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 10px 0 8px; border-radius: 999px; background: #E3E9EF; border: 0; color: #34495E; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 12 12" width="12" height="12" aria-hidden="true" style="display:block;flex:none"><rect x="1" y="6.5" width="2.4" height="4.5" rx="1.2" fill="#34495E" opacity="1"/><rect x="4.8" y="4" width="2.4" height="7" rx="1.2" fill="#34495E" opacity="1"/><rect x="8.6" y="1" width="2.4" height="10" rx="1.2" fill="#34495E" opacity="0.3"/></svg>Probable</span>
<span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 8.5px 0 6.5px; border-radius: 999px; background: #FFFFFF; border: 1.5px dashed #A04A1C; color: #A04A1C; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 12 12" width="12" height="12" aria-hidden="true" style="display:block;flex:none"><rect x="1" y="6.5" width="2.4" height="4.5" rx="1.2" fill="#A04A1C" opacity="1"/><rect x="4.8" y="4" width="2.4" height="7" rx="1.2" fill="#A04A1C" opacity="0.3"/><rect x="8.6" y="1" width="2.4" height="10" rx="1.2" fill="#A04A1C" opacity="0.3"/></svg>À vérifier</span>
```

### 5.3 Chips and pills for novelty and rarity

« Inattendu ici » (geomodel says Rare or Exceptionnel here this week) dark / light:

```html
<span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 10px 0 7px; border-radius: 999px; background: rgba(244,197,66,.16); color: #F4C542; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#F4C542"><path d="M12 3.5 20.5 12 12 20.5 3.5 12z" fill="currentColor" stroke="none"/></svg>Inattendu ici</span>
<span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 10px 0 7px; border-radius: 999px; background: #FBEFC8; color: #7A5A00; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#7A5A00"><path d="M12 3.5 20.5 12 12 20.5 3.5 12z" fill="currentColor" stroke="none"/></svg>Inattendu ici</span>
```

« Première fois » (L3, both themes) and « Nouveau » (carnet card until opened):

```html
<span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 10px 0 7px; border-radius: 999px; background: #F4C542; color: #13233A; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M12 2.5C12.7 8 14 9.3 21.5 12 14 14.7 12.7 16 12 21.5 11.3 16 10 14.7 2.5 12 10 9.3 11.3 8 12 2.5z" fill="currentColor" stroke="none"/></svg>Première fois</span>
<span style="display: inline-flex; align-items: center; align-self: flex-start; gap: 4px; height: 24px; padding: 0 8px 0 6px; border-radius: 999px; background: #F4C542; color: #13233A; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M12 2.5C12.7 8 14 9.3 21.5 12 14 14.7 12.7 16 12 21.5 11.3 16 10 14.7 2.5 12 10 9.3 11.3 8 12 2.5z" fill="currentColor" stroke="none"/></svg>Nouveau</span>
```

« Nouveau cette année » (L2) dark / light:

```html
<span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 9px 0 6px; border-radius: 999px; border: 1.5px solid #F4C542; color: #F4C542; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#F4C542"><path d="M12 2.5C12.7 8 14 9.3 21.5 12 14 14.7 12.7 16 12 21.5 11.3 16 10 14.7 2.5 12 10 9.3 11.3 8 12 2.5z" fill="currentColor" stroke="none"/></svg>Nouveau cette année</span>
<span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 9px 0 6px; border-radius: 999px; border: 1.5px solid #7A5A00; color: #7A5A00; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#7A5A00"><path d="M12 2.5C12.7 8 14 9.3 21.5 12 14 14.7 12.7 16 12 21.5 11.3 16 10 14.7 2.5 12 10 9.3 11.3 8 12 2.5z" fill="currentColor" stroke="none"/></svg>Nouveau cette année</span>
```

Rarity marks (light shown; dark: replace `#6B5847` by `#C9B8A4` and `#7A5A00` by `#F4C542`). « Commun » has no mark. In carnet cards use the icon alone (14 px, top-right).

```html
<span style="display: inline-flex; align-items: center; gap: 4px; color: #6B5847; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#6B5847"><circle cx="12" cy="12" r="7.5"/><path d="M12 4.5a7.5 7.5 0 0 1 0 15z" fill="currentColor" stroke="none"/></svg>Peu commun</span>
<span style="display: inline-flex; align-items: center; gap: 4px; color: #7A5A00; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#7A5A00"><path d="M12 3.5 20.5 12 12 20.5 3.5 12z" fill="currentColor" stroke="none"/></svg>Rare</span>
<span style="display: inline-flex; align-items: center; gap: 4px; color: #7A5A00; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#7A5A00"><path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8L3.5 9.7l5.9-.9z"/></svg>Exceptionnel</span>
```

### 5.4 Counters

Session count (big, right side of a row) and all-time total (line 2 of the row), dark shown (light: `#13233A` / `#6B5847`):

```html
<span style="display: inline-block; min-width: 32px; text-align: right; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 800; font-size: 20px; line-height: 1; color: #EEF1EC; font-variant-numeric: tabular-nums; animation: none">×4</span>
<span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; line-height: 1.2; color: #B4C0CC; font-variant-numeric: tabular-nums; white-space: nowrap">137 au total</span>
```

In Live, the `animation` of the ×N span is a state hole (see 10.1). Stat tiles (header counters) — light / dark:

```html
<div style="display: flex; flex-direction: column; gap: 4px; padding: 12px 14px; border-radius: 20px; background: #FFFFFF; min-width: 0"><span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 800; font-size: 26px; line-height: 1; color: #13233A; font-variant-numeric: tabular-nums">52</span><span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; line-height: 1.2; color: #6B5847">contacts</span></div>
```

```html
<div style="display: flex; flex-direction: column; gap: 4px; padding: 12px 14px; border-radius: 20px; background: #1A2D47; min-width: 0"><span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 800; font-size: 26px; line-height: 1; color: #EEF1EC; font-variant-numeric: tabular-nums">12:47</span><span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; line-height: 1.2; color: #B4C0CC">durée</span></div>
```

### 5.5 Live table row (dark)

72 px min, name may wrap to two lines (never truncate). Parts: glow layer (`.fx`, hidden until re-heard), `<a>` to the fiche (halo + icon + name + "chante" bars + badge + total), then count + play button. Change the species icon, the halo/glow `rgba()` (species accent), name, badge, numbers and aria-label.

```html
<div style="position: relative; display: flex; align-items: center; gap: 8px; min-height: 72px; padding: 8px; box-sizing: border-box; border-radius: 20px; background: #1A2D47; overflow: hidden"><div class="fx" aria-hidden="true" style="position: absolute; inset: 0; border-radius: 20px; background: rgba(236,122,60,0.22); box-shadow: inset 0 0 0 1.5px rgba(236,122,60,0.7); opacity: 0; pointer-events: none; animation: none"></div><a href="Fiche.dc.html" style="position: relative; flex: 1; min-width: 0; display: flex; align-items: center; gap: 10px; text-decoration: none; color: inherit"><span style="flex: none; width: 48px; height: 48px; border-radius: 999px; background: rgba(236,122,60,0.2); display: flex; align-items: center; justify-content: center"><!--BIRD rougegorge 42--></span><span style="min-width: 0; display: flex; flex-direction: column; gap: 6px"><span style="display: flex; align-items: center; gap: 8px; min-width: 0"><span style="font-family: 'Fraunces', Georgia, serif; font-variation-settings: 'SOFT' 100; font-weight: 600; font-size: 17px; line-height: 1.2; color: #EEF1EC">Rougegorge familier</span><span class="fx" aria-hidden="true" style="display: inline-flex; align-items: flex-end; gap: 2px; height: 12px; flex: none"><span style="display: block; width: 3px; height: 12px; border-radius: 2px; background: #4FC3CC; transform-origin: bottom; animation: bg-sing 900ms cubic-bezier(0.45,0,0.55,1) 0ms infinite"></span><span style="display: block; width: 3px; height: 12px; border-radius: 2px; background: #4FC3CC; transform-origin: bottom; animation: bg-sing 900ms cubic-bezier(0.45,0,0.55,1) 150ms infinite"></span><span style="display: block; width: 3px; height: 12px; border-radius: 2px; background: #4FC3CC; transform-origin: bottom; animation: bg-sing 900ms cubic-bezier(0.45,0,0.55,1) 300ms infinite"></span></span></span><span style="display: flex; align-items: center; gap: 8px"><span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 10px 0 8px; border-radius: 999px; background: rgba(157,180,106,.20); border: 0; color: #B7CF83; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 12 12" width="12" height="12" aria-hidden="true" style="display:block;flex:none"><rect x="1" y="6.5" width="2.4" height="4.5" rx="1.2" fill="#B7CF83" opacity="1"/><rect x="4.8" y="4" width="2.4" height="7" rx="1.2" fill="#B7CF83" opacity="1"/><rect x="8.6" y="1" width="2.4" height="10" rx="1.2" fill="#B7CF83" opacity="1"/></svg>Sûr</span><span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; line-height: 1.2; color: #B4C0CC; font-variant-numeric: tabular-nums; white-space: nowrap">137 au total</span></span></span></a><span style="position: relative; display: flex; align-items: center; gap: 6px; flex: none"><span style="display: inline-block; min-width: 32px; text-align: right; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 800; font-size: 20px; line-height: 1; color: #EEF1EC; font-variant-numeric: tabular-nums; animation: none">×4</span><button type="button" aria-label="Réécouter : Rougegorge familier" class="bg-press" style="display: flex; align-items: center; justify-content: center; flex: none; width: 48px; height: 48px; border-radius: 999px; background: transparent; border: 2px solid #4FC3CC; padding: 0; cursor: pointer"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#4FC3CC"><path d="M8 5.8v12.4a.8.8 0 0 0 1.2.7l9.9-6.2a.8.8 0 0 0 0-1.4L9.2 5.1A.8.8 0 0 0 8 5.8z" fill="currentColor" stroke="none"/></svg></button></span></div>
```

"Chante maintenant" bars alone (show only on the row of the last detection):

```html
<span class="fx" aria-hidden="true" style="display: inline-flex; align-items: flex-end; gap: 2px; height: 12px; flex: none"><span style="display: block; width: 3px; height: 12px; border-radius: 2px; background: #4FC3CC; transform-origin: bottom; animation: bg-sing 900ms cubic-bezier(0.45,0,0.55,1) 0ms infinite"></span><span style="display: block; width: 3px; height: 12px; border-radius: 2px; background: #4FC3CC; transform-origin: bottom; animation: bg-sing 900ms cubic-bezier(0.45,0,0.55,1) 150ms infinite"></span><span style="display: block; width: 3px; height: 12px; border-radius: 2px; background: #4FC3CC; transform-origin: bottom; animation: bg-sing 900ms cubic-bezier(0.45,0,0.55,1) 300ms infinite"></span></span>
```

Compact row (60 px, LiveSpectre top 3 and dimmed backgrounds):

```html
<div style="position: relative; display: flex; align-items: center; gap: 8px; min-height: 60px; padding: 6px 8px; box-sizing: border-box; border-radius: 20px; background: #1A2D47"><a href="Fiche.dc.html" style="flex: 1; min-width: 0; display: flex; align-items: center; gap: 10px; text-decoration: none; color: inherit"><span style="flex: none; width: 40px; height: 40px; border-radius: 999px; background: rgba(216,52,58,0.2); display: flex; align-items: center; justify-content: center"><!--BIRD pic-epeiche 34--></span><span style="min-width: 0; display: flex; flex-direction: column; gap: 4px"><span style="font-family: 'Fraunces', Georgia, serif; font-variation-settings: 'SOFT' 100; font-weight: 600; font-size: 15px; line-height: 1.2; color: #EEF1EC; white-space: nowrap; overflow: hidden; text-overflow: ellipsis">Pic épeiche</span><span style="display: flex; align-items: center; gap: 6px"><span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 10px 0 8px; border-radius: 999px; background: rgba(157,180,106,.20); border: 0; color: #B7CF83; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 12 12" width="12" height="12" aria-hidden="true" style="display:block;flex:none"><rect x="1" y="6.5" width="2.4" height="4.5" rx="1.2" fill="#B7CF83" opacity="1"/><rect x="4.8" y="4" width="2.4" height="7" rx="1.2" fill="#B7CF83" opacity="1"/><rect x="8.6" y="1" width="2.4" height="10" rx="1.2" fill="#B7CF83" opacity="1"/></svg>Sûr</span><span style="display: inline-flex; align-items: center; gap: 5px; height: 26px; padding: 0 10px 0 7px; border-radius: 999px; background: #F4C542; color: #13233A; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M12 2.5C12.7 8 14 9.3 21.5 12 14 14.7 12.7 16 12 21.5 11.3 16 10 14.7 2.5 12 10 9.3 11.3 8 12 2.5z" fill="currentColor" stroke="none"/></svg>Première fois</span></span></span></a><span style="display: inline-block; min-width: 32px; text-align: right; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 800; font-size: 20px; line-height: 1; color: #EEF1EC; font-variant-numeric: tabular-nums; animation: none">×2</span><button type="button" aria-label="Réécouter : Pic épeiche" class="bg-press" style="display: flex; align-items: center; justify-content: center; flex: none; width: 48px; height: 48px; border-radius: 999px; background: transparent; border: 2px solid #4FC3CC; padding: 0; cursor: pointer"><svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#4FC3CC"><path d="M8 5.8v12.4a.8.8 0 0 0 1.2.7l9.9-6.2a.8.8 0 0 0 0-1.4L9.2 5.1A.8.8 0 0 0 8 5.8z" fill="currentColor" stroke="none"/></svg></button></div>
```

Extra chips (`pill-first`, `chip-unexpected-dark`) go between the badge and the total; drop the total text when a row has two chips.

### 5.6 Collection cards (Carnet, light; grid of 3, gap 10)

Discovered:

```html
<a href="Fiche.dc.html" style="position: relative; display: flex; flex-direction: column; gap: 6px; min-height: 168px; padding: 10px; box-sizing: border-box; border-radius: 20px; background: #FCE7DC; text-decoration: none; color: #13233A"><span style="position: absolute; top: 10px; right: 10px; display: flex"></span><!--BIRD rougegorge 72--><span style="font-family: 'Fraunces', Georgia, serif; font-variation-settings: 'SOFT' 100; font-weight: 600; font-size: 15px; line-height: 1.2; color: #13233A">Rougegorge familier</span><span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; line-height: 1.2; color: #6B5847; font-variant-numeric: tabular-nums">142 fois</span></a>
```

Discovered, new (pill until the fiche is opened):

```html
<a href="Fiche.dc.html" style="position: relative; display: flex; flex-direction: column; gap: 6px; min-height: 168px; padding: 10px; box-sizing: border-box; border-radius: 20px; background: #F8DADC; text-decoration: none; color: #13233A"><span style="position: absolute; top: 10px; right: 10px; display: flex"></span><!--BIRD pic-epeiche 72--><span style="font-family: 'Fraunces', Georgia, serif; font-variation-settings: 'SOFT' 100; font-weight: 600; font-size: 15px; line-height: 1.2; color: #13233A">Pic épeiche</span><span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; line-height: 1.2; color: #6B5847; font-variant-numeric: tabular-nums">2 fois</span><span style="display: inline-flex; align-items: center; align-self: flex-start; gap: 4px; height: 24px; padding: 0 8px 0 6px; border-radius: 999px; background: #F4C542; color: #13233A; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1; white-space: nowrap"><svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M12 2.5C12.7 8 14 9.3 21.5 12 14 14.7 12.7 16 12 21.5 11.3 16 10 14.7 2.5 12 10 9.3 11.3 8 12 2.5z" fill="currentColor" stroke="none"/></svg>Nouveau</span></a>
```

Discovered with a rarity mark:

```html
<a href="Fiche.dc.html" style="position: relative; display: flex; flex-direction: column; gap: 6px; min-height: 168px; padding: 10px; box-sizing: border-box; border-radius: 20px; background: #D8F0F8; text-decoration: none; color: #13233A"><span style="position: absolute; top: 10px; right: 10px; display: flex"><svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#6B5847"><circle cx="12" cy="12" r="7.5"/><path d="M12 4.5a7.5 7.5 0 0 1 0 15z" fill="currentColor" stroke="none"/></svg></span><!--BIRD martin-pecheur 72--><span style="font-family: 'Fraunces', Georgia, serif; font-variation-settings: 'SOFT' 100; font-weight: 600; font-size: 15px; line-height: 1.2; color: #13233A">Martin-pêcheur d'Europe</span><span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; line-height: 1.2; color: #6B5847; font-variant-numeric: tabular-nums">3 fois</span></a>
```

Mystery (expected here this week, not found; hint from the species sheet, never the name):

```html
<div style="display: flex; flex-direction: column; gap: 6px; min-height: 168px; padding: 10px; box-sizing: border-box; border-radius: 20px; border: 1.5px dashed #B9C0B5; background: transparent"><!--BIRD mystere 72--><span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1.2; color: #6B5847">À découvrir</span><span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; line-height: 1.3; color: #6B5847">Chante au lever du jour dans les haies.</span></div>
```

Heard, waiting for confirmation (goes to Revue):

```html
<a href="Revue.dc.html" style="position: relative; display: flex; flex-direction: column; gap: 6px; min-height: 168px; padding: 10px; box-sizing: border-box; border-radius: 20px; border: 1.5px dashed #A04A1C; background: #FFFFFF; text-decoration: none; color: #13233A"><span style="position: absolute; top: 10px; right: 10px; display: flex"><svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#7A5A00"><path d="M12 3.5 20.5 12 12 20.5 3.5 12z" fill="currentColor" stroke="none"/></svg></span><!--BIRD huppe 72--><span style="font-family: 'Fraunces', Georgia, serif; font-variation-settings: 'SOFT' 100; font-weight: 600; font-size: 15px; line-height: 1.2; color: #13233A">Huppe fasciée</span><span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1.2; color: #A04A1C">À confirmer</span></a>
```

### 5.7 Status ring, emblem, chip, progress

Ring (84 px; track, progress arc, status disc, glyph). `stroke-dasharray` first value = 232.5 × progress (here 4/15 → 62). Dark: track `rgba(238,241,236,.14)`. For 96 px just set width/height.

```html
<svg viewBox="0 0 84 84" width="84" height="84" role="img" aria-label="Progression vers le prochain statut : 27 %" style="display:block;flex:none"><circle cx="42" cy="42" r="37" fill="none" stroke="#DCE2DA" stroke-width="6"/><circle cx="42" cy="42" r="37" fill="none" stroke="#5DA46A" stroke-width="6" stroke-linecap="round" stroke-dasharray="62.0 233" transform="rotate(-90 42 42)"/><circle cx="42" cy="42" r="29" fill="#5DA46A"/><g transform="translate(26 26) scale(1.3333)"><g fill="none" stroke="#13233A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 13.5S6.5 8 12 8s9 5.5 9 5.5-3.5 5.5-9 5.5-9-5.5-9-5.5z"/><circle cx="12" cy="13.5" r="2.5"/><path d="M12 2.5v2.5M6.5 4.5l1.3 2M17.5 4.5l-1.3 2"/></g></g></svg>
```

Emblem alone (any size; here the next status, Oreille de chouette):

```html
<svg viewBox="0 0 24 24" width="40" height="40" aria-hidden="true" style="display:block;flex:none"><circle cx="12" cy="12" r="12" fill="#C28A55"/><g transform="translate(5 5) scale(.5833)"><g fill="none" stroke="#13233A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M5 4l3.2 3.4M19 4l-3.2 3.4"/><path d="M5 4c-.7 2.2-1 4.6-1 7a8 8 0 0 0 16 0c0-2.4-.3-4.8-1-7"/><circle cx="9" cy="11.5" r="2.4"/><circle cx="15" cy="11.5" r="2.4"/><path d="M11 15.8l1 1.4 1-1.4"/></g></g></svg>
```

Status chip light / dark:

```html
<span style="display: inline-flex; align-items: center; gap: 8px; height: 36px; padding: 0 12px 0 4px; border-radius: 999px; background: #FFFFFF; border: 1px solid #DCE2DA; color: #13233A; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; white-space: nowrap"><svg viewBox="0 0 24 24" width="28" height="28" aria-hidden="true" style="display:block;flex:none"><circle cx="12" cy="12" r="12" fill="#5DA46A"/><g transform="translate(5 5) scale(.5833)"><g fill="none" stroke="#13233A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 13.5S6.5 8 12 8s9 5.5 9 5.5-3.5 5.5-9 5.5-9-5.5-9-5.5z"/><circle cx="12" cy="13.5" r="2.5"/><path d="M12 2.5v2.5M6.5 4.5l1.3 2M17.5 4.5l-1.3 2"/></g></g></svg>Sentinelle des haies</span>
```

```html
<span style="display: inline-flex; align-items: center; gap: 8px; height: 36px; padding: 0 12px 0 4px; border-radius: 999px; background: rgba(238,241,236,.08); border: 1px solid rgba(238,241,236,.14); color: #EEF1EC; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; white-space: nowrap"><svg viewBox="0 0 24 24" width="28" height="28" aria-hidden="true" style="display:block;flex:none"><circle cx="12" cy="12" r="12" fill="#5DA46A"/><g transform="translate(5 5) scale(.5833)"><g fill="none" stroke="#13233A" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 13.5S6.5 8 12 8s9 5.5 9 5.5-3.5 5.5-9 5.5-9-5.5-9-5.5z"/><circle cx="12" cy="13.5" r="2.5"/><path d="M12 2.5v2.5M6.5 4.5l1.3 2M17.5 4.5l-1.3 2"/></g></g></svg>Sentinelle des haies</span>
```

Progress bar: the fill already shows the new value; the part just gained is painted over in Loriot (`.fx`, grows once), so reduced motion still shows the right value. Light / dark:

```html
<span style="position: relative; display: block; height: 10px; border-radius: 999px; background: #DCE2DA; overflow: hidden"><span style="position: absolute; top: 0; bottom: 0; left: 0; width: 26.7%; border-radius: 999px; background: #5DA46A"></span><span class="fx" style="position: absolute; top: 0; bottom: 0; left: 20.0%; width: 6.7%; border-radius: 999px; background: #F4C542; transform-origin: left; animation: bg-gain 600ms cubic-bezier(0.23,1,0.32,1) 400ms both"></span></span>
```

```html
<span style="position: relative; display: block; height: 10px; border-radius: 999px; background: rgba(238,241,236,.14); overflow: hidden"><span style="position: absolute; top: 0; bottom: 0; left: 0; width: 26.7%; border-radius: 999px; background: #5DA46A"></span><span class="fx" style="position: absolute; top: 0; bottom: 0; left: 20.0%; width: 6.7%; border-radius: 999px; background: #F4C542; transform-origin: left; animation: bg-gain 600ms cubic-bezier(0.23,1,0.32,1) 400ms both"></span></span>
```

Streak chip (Accueil top bar):

```html
<a href="Profil.dc.html" style="display: inline-flex; align-items: center; gap: 8px; height: 48px; padding: 0 14px 0 12px; border-radius: 999px; background: #FFFFFF; border: 1px solid #DCE2DA; color: #13233A; text-decoration: none; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 15px; font-variant-numeric: tabular-nums; white-space: nowrap"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#0B6E77"><rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/></svg>9 jours</a>
```

### 5.8 Navigation

Bottom nav (light boards Main, Carnet, Carte, Profil only). Active item: teal pill `#D1ECEF`, color `#0B6E77`, weight 700, `aria-current="page"`. Move these three things to the active item; keep the four links as they are.

```html
<nav aria-label="Navigation principale" style="position: absolute; left: 0; right: 0; bottom: 0; height: 80px; box-sizing: border-box; padding: 4px 8px 12px; display: flex; background: #FFFFFF; border-top: 1px solid #DCE2DA"><a href="Main.dc.html" aria-current="page" style="flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; min-height: 64px; text-decoration: none; color: #0B6E77; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; font-weight: 700"><span style="display: flex; align-items: center; justify-content: center; width: 56px; height: 32px; border-radius: 999px; background: #D1ECEF"><svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#0B6E77"><path d="M3.5 10.5 12 3.5l8.5 7V20a1 1 0 0 1-1 1H15v-6H9v6H4.5a1 1 0 0 1-1-1z"/></svg></span>Accueil</a><a href="Carnet.dc.html" style="flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; min-height: 64px; text-decoration: none; color: #6B5847; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; font-weight: 400"><span style="display: flex; align-items: center; justify-content: center; width: 56px; height: 32px; border-radius: 999px; background: transparent"><svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#6B5847"><path d="M5 4.5A1.5 1.5 0 0 1 6.5 3H19v14.5H6.5A1.5 1.5 0 0 0 5 19z"/><path d="M5 19a1.5 1.5 0 0 0 1.5 1.5H19v-3"/><path d="M9.5 7.5h5"/></svg></span>Carnet</a><a href="Carte.dc.html" style="flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; min-height: 64px; text-decoration: none; color: #6B5847; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; font-weight: 400"><span style="display: flex; align-items: center; justify-content: center; width: 56px; height: 32px; border-radius: 999px; background: transparent"><svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#6B5847"><path d="M9 4.5 3.5 6.5v13L9 17.5l6 2 5.5-2v-13L15 6.5z"/><path d="M9 4.5v13M15 6.5v13"/></svg></span>Carte</a><a href="Profil.dc.html" style="flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 4px; min-height: 64px; text-decoration: none; color: #6B5847; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; font-weight: 400"><span style="display: flex; align-items: center; justify-content: center; width: 56px; height: 32px; border-radius: 999px; background: transparent"><svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#6B5847"><circle cx="12" cy="8.5" r="4"/><path d="M4.5 20.5a7.5 7.5 0 0 1 15 0"/></svg></span>Profil</a></nav>
```

Top app bar (sub-pages Resume, Revue, Palmares, Fiche use a back or close icon button + Heading 20):

```html
<div style="display: flex; align-items: center; gap: 8px; height: 56px"><a href="Profil.dc.html" aria-label="Retour" class="bg-press" style="display: flex; align-items: center; justify-content: center; flex: none; width: 48px; height: 48px; border-radius: 999px; background: #FFFFFF; border: 1px solid #DCE2DA; color: #13233A; padding: 0; cursor: pointer; text-decoration: none"><svg viewBox="0 0 24 24" width="24" height="24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M19 12H5M11 5l-7 7 7 7"/></svg></a><h1 style="flex: 1; margin: 0; font-family: 'Fraunces', Georgia, serif; font-variation-settings: 'SOFT' 100; font-weight: 600; font-size: 20px; line-height: 1.25; color: #13233A">Palmarès</h1></div>
```

Section header (optional link on the right, 48 px tall):

```html
<div style="display: flex; align-items: center; justify-content: space-between; gap: 12px"><h2 style="margin: 0; font-family: 'Fraunces', Georgia, serif; font-variation-settings: 'SOFT' 100; font-weight: 600; font-size: 20px; line-height: 1.25; color: #13233A">Mes sons</h2></div>
```

### 5.9 Bottom sheet (light)

Sits above the nav (`bottom: 80px`), enters with `bg-sheet`. Rows inside: see Carte (9.14, overlay 6).

```html
<section style="position: absolute; left: 0; right: 0; bottom: 80px; box-sizing: border-box; padding: 8px 20px 16px; border-radius: 28px 28px 0 0; background: #FFFFFF; box-shadow: 0 -8px 28px rgba(19,35,58,.14); display: flex; flex-direction: column; gap: 12px; animation: bg-sheet 380ms cubic-bezier(0.23,1,0.32,1) both"><span aria-hidden="true" style="align-self: center; width: 36px; height: 4px; border-radius: 2px; background: #C5CCC2"></span><div style="display: flex; flex-direction: column; gap: 2px"><h2 style="margin: 0; font-family: 'Fraunces', Georgia, serif; font-variation-settings: 'SOFT' 100; font-weight: 600; font-size: 20px; line-height: 1.25; color: #13233A">Le jardin</h2><span style="font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 13px; color: #6B5847">8 espèces · 164 contacts en 30 jours</span></div>
  <!-- rows --></section>
```

### 5.10 Filter chips and switch

Light (selected = Encre fill + check), dark:

```html
<button type="button" aria-pressed="true" style="display: inline-flex; align-items: center; gap: 6px; height: 48px; padding: 0 16px 0 12px; border-radius: 999px; background: #13233A; border: 1px solid #13233A; color: #EEF1EC; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 15px; white-space: nowrap; cursor: pointer; flex: none"><svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#EEF1EC"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>Toutes</button>
<button type="button" aria-pressed="false" style="display: inline-flex; align-items: center; gap: 6px; height: 48px; padding: 0 16px; border-radius: 999px; background: #FFFFFF; border: 1px solid #C5CCC2; color: #13233A; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 15px; white-space: nowrap; cursor: pointer; flex: none">Rares</button>
```

```html
<button type="button" aria-pressed="true" style="display: inline-flex; align-items: center; gap: 6px; height: 48px; padding: 0 16px 0 12px; border-radius: 999px; background: #EEF1EC; border: 1px solid #EEF1EC; color: #13233A; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 15px; white-space: nowrap; cursor: pointer; flex: none"><svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg>Toutes</button>
<button type="button" aria-pressed="false" style="display: inline-flex; align-items: center; gap: 6px; height: 48px; padding: 0 16px; border-radius: 999px; background: rgba(238,241,236,.06); border: 1px solid rgba(238,241,236,.22); color: #EEF1EC; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 15px; white-space: nowrap; cursor: pointer; flex: none">Rares</button>
```

Chip rows scroll horizontally: `display: flex; gap: 8px; overflow-x: auto; padding: 0 20px; margin: 0 -20px` (a chip cut at the edge is fine: it signals scroll).

Switch:

```html
<button type="button" role="switch" aria-checked="true" style="display: flex; align-items: center; gap: 10px; min-height: 48px; padding: 0; background: transparent; border: 0; color: #13233A; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 15px; cursor: pointer"><span style="position: relative; width: 44px; height: 26px; border-radius: 999px; background: #19A7B3; flex: none"><span style="position: absolute; top: 3px; left: 21px; width: 20px; height: 20px; border-radius: 999px; background: #FFFFFF; box-shadow: 0 1px 3px rgba(19,35,58,.3)"></span></span>Confirmées seulement</button>
```

### 5.11 Verdict buttons (Revue light, Rare dark)

Same three answers everywhere, in swipe order: left « Ce n'est pas lui », middle « Je ne sais pas », right « C'est bien lui ». Holes `{{ no }}`, `{{ unsure }}`, `{{ yes }}`. Light (Revue, 104 px):

```html
<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px"><button type="button" onClick="{{ no }}" class="bg-press" style="display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; min-height: 104px; padding: 8px 6px; box-sizing: border-box; border-radius: 20px; background: #FFFFFF; border: 1.5px solid #C5CCC2; color: #13233A; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 15px; line-height: 1.2; text-align: center; cursor: pointer"><span style="display: flex; align-items: center; justify-content: center; width: 48px; height: 48px; box-sizing: border-box; border-radius: 999px; background: #FFFFFF; border: 2px solid #A04A1C"><svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#A04A1C"><path d="M6 6l12 12M18 6 6 18"/></svg></span>Ce n&#39;est pas lui</button><button type="button" onClick="{{ unsure }}" class="bg-press" style="display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; min-height: 104px; padding: 8px 6px; box-sizing: border-box; border-radius: 20px; background: #FFFFFF; border: 1.5px solid #C5CCC2; color: #13233A; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 15px; line-height: 1.2; text-align: center; cursor: pointer"><span style="display: flex; align-items: center; justify-content: center; width: 48px; height: 48px; box-sizing: border-box; border-radius: 999px; background: #E3E9EF; border: 0"><svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#34495E"><path d="M9 9.2a3 3 0 1 1 4.2 2.8c-.8.4-1.2 1-1.2 1.8v.7"/><path d="M12 18.2v.1" stroke-width="2.6"/></svg></span>Je ne sais pas</button><button type="button" onClick="{{ yes }}" class="bg-press" style="display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; min-height: 104px; padding: 8px 6px; box-sizing: border-box; border-radius: 20px; background: #E6EDD6; border: 1.5px solid #E6EDD6; color: #13233A; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 15px; line-height: 1.2; text-align: center; cursor: pointer"><span style="display: flex; align-items: center; justify-content: center; width: 48px; height: 48px; box-sizing: border-box; border-radius: 999px; background: #9DB46A; border: 0"><svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></span>C&#39;est bien lui</button></div>
```

Dark compact (Rare card, 88 px, 44 px circles, 13 px labels):

```html
<div style="display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 10px"><button type="button" onClick="{{ no }}" class="bg-press" style="display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; min-height: 88px; padding: 8px 6px; box-sizing: border-box; border-radius: 20px; background: rgba(238,241,236,.06); border: 1.5px solid rgba(238,241,236,.22); color: #EEF1EC; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1.2; text-align: center; cursor: pointer"><span style="display: flex; align-items: center; justify-content: center; width: 44px; height: 44px; box-sizing: border-box; border-radius: 999px; background: transparent; border: 2px solid #F2A677"><svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#F2A677"><path d="M6 6l12 12M18 6 6 18"/></svg></span>Ce n&#39;est pas lui</button><button type="button" onClick="{{ unsure }}" class="bg-press" style="display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; min-height: 88px; padding: 8px 6px; box-sizing: border-box; border-radius: 20px; background: rgba(238,241,236,.06); border: 1.5px solid rgba(238,241,236,.22); color: #EEF1EC; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1.2; text-align: center; cursor: pointer"><span style="display: flex; align-items: center; justify-content: center; width: 44px; height: 44px; box-sizing: border-box; border-radius: 999px; background: rgba(201,211,221,.14); border: 0"><svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#C9D3DD"><path d="M9 9.2a3 3 0 1 1 4.2 2.8c-.8.4-1.2 1-1.2 1.8v.7"/><path d="M12 18.2v.1" stroke-width="2.6"/></svg></span>Je ne sais pas</button><button type="button" onClick="{{ yes }}" class="bg-press" style="display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; min-height: 88px; padding: 8px 6px; box-sizing: border-box; border-radius: 20px; background: rgba(157,180,106,.20); border: 1.5px solid rgba(157,180,106,.5); color: #EEF1EC; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-weight: 700; font-size: 13px; line-height: 1.2; text-align: center; cursor: pointer"><span style="display: flex; align-items: center; justify-content: center; width: 44px; height: 44px; box-sizing: border-box; border-radius: 999px; background: #9DB46A; border: 0"><svg viewBox="0 0 24 24" width="26" height="26" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#13233A"><path d="M5 12.5l4.5 4.5L19 7.5"/></svg></span>C&#39;est bien lui</button></div>
```

### 5.12 Toast (dark)

Shown above the Live control bar while a clip plays.

```html
<div role="status" style="display: flex; align-items: center; gap: 10px; padding: 12px 16px; border-radius: 20px; background: #29425F; color: #EEF1EC; font-family: 'Atkinson Hyperlegible Next', system-ui, sans-serif; font-size: 15px; line-height: 1.35; animation: bg-rise 220ms cubic-bezier(0.23,1,0.32,1) both"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" style="display:block;flex:none;color:#4FC3CC"><path d="M4 15v-3a8 8 0 0 1 16 0v3"/><rect x="3" y="14" width="4.5" height="7" rx="1.5"/><rect x="16.5" y="14" width="4.5" height="7" rx="1.5"/></svg><span>Réécoute à faible volume. L'écoute continue.</span></div>
```

### 5.13 Spectrum

**Normal band (Live, 120 px, full bleed).** The inner 780 px wide `<div>` holds two identical 10 s tiles and scrolls by `-50 %` every 10 s. The teal line at the right is "maintenant". Pause = set `animation-play-state` to `paused` (state hole). Colored bars under the calls = the species detected there (Merlin-style marks).

```html
<div aria-label="Spectre en direct" role="img" style="position: relative; height: 120px; overflow: hidden; background: repeating-linear-gradient(to bottom, transparent 0 23px, rgba(238,241,236,.06) 23px 24px), linear-gradient(#0B1728, #0F1E33)"><div style="width: 780px; height: 120px; animation: bg-scroll 10s linear infinite; animation-play-state: running"><svg viewBox="0 0 780 120" width="780" height="120" preserveAspectRatio="none" aria-hidden="true" style="display:block"><defs><linearGradient id="sp-low" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#19A7B3" stop-opacity="0"/><stop offset="1" stop-color="#19A7B3" stop-opacity=".3"/></linearGradient><filter id="sp-glow" x="-5%" y="-20%" width="110%" height="140%"><feGaussianBlur stdDeviation="1.8" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs><rect x="0" y="100" width="780" height="20" fill="url(#sp-low)"/><g fill="none" stroke-linecap="round" filter="url(#sp-glow)"><g><path d="M175.7 60.9h4.3 M180.8 55.8h3.3 M72.9 56.2h3.4 M306.5 15.2h2.4 M36.8 85.3h3.6 M18.1 102.3h4.4 M253.1 66.3h2 M7.8 57.8h1.7 M75 29.7h1.6 M180.2 49.2h4 M201.3 68.7h3 M256.4 50.8h2.3 M385.1 103.6h4 M273.8 36.9h2.2 M113 12.9h3.8 M155.8 89h2.7 M369.9 89h1.5 M82.5 95.2h2.9 M378.5 44.9h1.7 M243.7 82.3h2.3 M35.5 38.6h4.4 M293.1 17.6h2.2 M40.8 11.9h3.9 M70.2 60.8h2.8 M75.2 77.7h1.9 M249.2 17.4h2.8 M83.7 32.4h4.4 M310.5 35.8h4.2 M82.9 44.6h4.1 M248.5 15.8h4.5 M83.9 31.3h3.8 M128.3 35h1.7 M36.6 63.1h2.2 M232.9 42.4h2.9 M370.3 53.4h3.2 M334.7 23.9h2 M350.8 86.1h2.2 M74.9 78.5h4.3 M77.5 99.1h4.1 M233.8 47.3h1.8 M16.9 100.3h2.2 M272.6 31.2h4 M231 34.8h2 M278.6 12.7h2.2 M216.8 89.5h3.3 M109.6 95.9h2.1 M8.4 32.4h2.8 M25.2 23.3h2.6 M221.7 18.9h2.6 M344.1 102.1h3.5 M267.4 63.3h1.9 M15.5 7.8h4.2 M271.2 100.4h1.6 M246.3 53.3h3.7 M124.5 103.9h1.7 M211.7 78.2h4.2 M285 75h3.9 M353.4 40.5h3.6 M347.9 91.4h2.8 M305.6 90.6h3.2 M242 43.5h3.2 M235.8 13.9h3.4 M383.4 92.2h3.7 M151.2 78h3.2 M171.2 88.2h1.8 M290.1 8.9h3.3 M186.7 28.6h3.6 M192.9 66.2h4.3 M100.2 7.1h2.4 M262.4 25.9h2 M349.8 70.7h2.8 M344.4 38h3.5 M78.2 48.2h3.9 M353.1 92.3h2.7 M225.9 37h1.9 M192.6 88h4 M275.1 99.1h2.3 M66.9 50.2h2.3 M84.2 46.6h3.4 M191.6 36.9h4 M379.1 50.3h1.7 M14.1 91.5h1.6 M274.1 61.9h2.4 M305.9 7.9h1.9 M176.7 8.4h4 M93.2 19.8h1.6 M243.6 49.8h3.4 M253.5 85.1h4.4 M264.8 25.5h2.9 M70.6 7.1h2.9" stroke="#19A7B3" stroke-width="1" opacity="0.2"/><path d="M12.3 37.3l3.2 -5 M18.1 55.1l4 2.5 M23.4 69.2l2.7 8.9 M30.1 65.6l3.4 -8.1 M35.4 75.3l3.6 -2.7 M41.6 69.4l3.4 9.8 M47 38.7l4.1 4.9 M52.8 65.3l4.3 -6.3 M59.2 78.8l4.1 0.8 M63.9 75.3l3.2 7.8 M69.3 50.9l4 1.1 M75.8 29.5l2.6 6.8 M82.1 37l4.1 -3.6 M86.8 35.7l3.9 0.4" stroke="#A8E2E6" stroke-width="1.8"/><path d="M40.5 41h.1 M64 35h.1 M83 60h.1" stroke="#F4C542" stroke-width="2.6"/><path d="M114 24V104M121 28V100" stroke="#DDF4F5" stroke-width="2.2"/><path d="M114 58h.1 M121 62h.1" stroke="#F4C542" stroke-width="2.6"/><path d="M140 36.1V65 M142.8 37.3V61.9 M145.6 37.4V55.4 M148.4 28.7V62.4 M151.2 29.5V65.7 M154 33.7V62.4 M156.8 36.1V63 M159.6 29.7V60.1 M162.4 36.1V68.4 M165.2 28.5V67.6 M168 37.6V62.4 M170.8 32.9V57.2 M173.6 32.4V62.1 M176.4 33.3V54.4 M179.2 37.6V62.3 M182 30.8V66.8 M184.8 32.8V61.9 M187.6 34.3V55.1 M190.4 32.5V60.6 M193.2 37.5V68.8 M196 29.2V61.6 M198.8 27.5V60.9 M201.6 35.8V68.4 M204.4 31.7V59.1 M207.2 28.3V63.9 M210 37.1V56.1" stroke="#79D0D7" stroke-width="1.2"/><path d="M160.6 44h.1 M185.8 47h.1" stroke="#DDF4F5" stroke-width="2.6"/><path d="M238 53l8 3M248 76l7 1.5M259 53l8 3M269 76l7 1.5M280 53l8 3M290 76l7 1.5" stroke="#A8E2E6" stroke-width="2.4"/><path d="M242 54.5h.1 M263 54.5h.1" stroke="#F4C542" stroke-width="2.6"/><path d="M324 96c4-8 8-8 12 0M340 90c3-6 6-7 9-2M352 99c4-10 9-11 14-1" stroke="#52C0C9" stroke-width="2"/><path d="M370 50l6-5" stroke="#DDF4F5" stroke-width="1.6"/><g data-part="marks"><path d="M10 117.5H92" stroke="#EC7A3C" stroke-width="3"/><path d="M110 117.5H126" stroke="#D8343A" stroke-width="3"/><path d="M138 117.5H214" stroke="#C69A6A" stroke-width="3"/><path d="M234 117.5H302" stroke="#E9C13C" stroke-width="3"/><path d="M320 117.5H382" stroke="#F6B12A" stroke-width="3"/></g></g><g transform="translate(390 0)"><path d="M175.7 60.9h4.3 M180.8 55.8h3.3 M72.9 56.2h3.4 M306.5 15.2h2.4 M36.8 85.3h3.6 M18.1 102.3h4.4 M253.1 66.3h2 M7.8 57.8h1.7 M75 29.7h1.6 M180.2 49.2h4 M201.3 68.7h3 M256.4 50.8h2.3 M385.1 103.6h4 M273.8 36.9h2.2 M113 12.9h3.8 M155.8 89h2.7 M369.9 89h1.5 M82.5 95.2h2.9 M378.5 44.9h1.7 M243.7 82.3h2.3 M35.5 38.6h4.4 M293.1 17.6h2.2 M40.8 11.9h3.9 M70.2 60.8h2.8 M75.2 77.7h1.9 M249.2 17.4h2.8 M83.7 32.4h4.4 M310.5 35.8h4.2 M82.9 44.6h4.1 M248.5 15.8h4.5 M83.9 31.3h3.8 M128.3 35h1.7 M36.6 63.1h2.2 M232.9 42.4h2.9 M370.3 53.4h3.2 M334.7 23.9h2 M350.8 86.1h2.2 M74.9 78.5h4.3 M77.5 99.1h4.1 M233.8 47.3h1.8 M16.9 100.3h2.2 M272.6 31.2h4 M231 34.8h2 M278.6 12.7h2.2 M216.8 89.5h3.3 M109.6 95.9h2.1 M8.4 32.4h2.8 M25.2 23.3h2.6 M221.7 18.9h2.6 M344.1 102.1h3.5 M267.4 63.3h1.9 M15.5 7.8h4.2 M271.2 100.4h1.6 M246.3 53.3h3.7 M124.5 103.9h1.7 M211.7 78.2h4.2 M285 75h3.9 M353.4 40.5h3.6 M347.9 91.4h2.8 M305.6 90.6h3.2 M242 43.5h3.2 M235.8 13.9h3.4 M383.4 92.2h3.7 M151.2 78h3.2 M171.2 88.2h1.8 M290.1 8.9h3.3 M186.7 28.6h3.6 M192.9 66.2h4.3 M100.2 7.1h2.4 M262.4 25.9h2 M349.8 70.7h2.8 M344.4 38h3.5 M78.2 48.2h3.9 M353.1 92.3h2.7 M225.9 37h1.9 M192.6 88h4 M275.1 99.1h2.3 M66.9 50.2h2.3 M84.2 46.6h3.4 M191.6 36.9h4 M379.1 50.3h1.7 M14.1 91.5h1.6 M274.1 61.9h2.4 M305.9 7.9h1.9 M176.7 8.4h4 M93.2 19.8h1.6 M243.6 49.8h3.4 M253.5 85.1h4.4 M264.8 25.5h2.9 M70.6 7.1h2.9" stroke="#19A7B3" stroke-width="1" opacity="0.2"/><path d="M12.3 37.3l3.2 -5 M18.1 55.1l4 2.5 M23.4 69.2l2.7 8.9 M30.1 65.6l3.4 -8.1 M35.4 75.3l3.6 -2.7 M41.6 69.4l3.4 9.8 M47 38.7l4.1 4.9 M52.8 65.3l4.3 -6.3 M59.2 78.8l4.1 0.8 M63.9 75.3l3.2 7.8 M69.3 50.9l4 1.1 M75.8 29.5l2.6 6.8 M82.1 37l4.1 -3.6 M86.8 35.7l3.9 0.4" stroke="#A8E2E6" stroke-width="1.8"/><path d="M40.5 41h.1 M64 35h.1 M83 60h.1" stroke="#F4C542" stroke-width="2.6"/><path d="M114 24V104M121 28V100" stroke="#DDF4F5" stroke-width="2.2"/><path d="M114 58h.1 M121 62h.1" stroke="#F4C542" stroke-width="2.6"/><path d="M140 36.1V65 M142.8 37.3V61.9 M145.6 37.4V55.4 M148.4 28.7V62.4 M151.2 29.5V65.7 M154 33.7V62.4 M156.8 36.1V63 M159.6 29.7V60.1 M162.4 36.1V68.4 M165.2 28.5V67.6 M168 37.6V62.4 M170.8 32.9V57.2 M173.6 32.4V62.1 M176.4 33.3V54.4 M179.2 37.6V62.3 M182 30.8V66.8 M184.8 32.8V61.9 M187.6 34.3V55.1 M190.4 32.5V60.6 M193.2 37.5V68.8 M196 29.2V61.6 M198.8 27.5V60.9 M201.6 35.8V68.4 M204.4 31.7V59.1 M207.2 28.3V63.9 M210 37.1V56.1" stroke="#79D0D7" stroke-width="1.2"/><path d="M160.6 44h.1 M185.8 47h.1" stroke="#DDF4F5" stroke-width="2.6"/><path d="M238 53l8 3M248 76l7 1.5M259 53l8 3M269 76l7 1.5M280 53l8 3M290 76l7 1.5" stroke="#A8E2E6" stroke-width="2.4"/><path d="M242 54.5h.1 M263 54.5h.1" stroke="#F4C542" stroke-width="2.6"/><path d="M324 96c4-8 8-8 12 0M340 90c3-6 6-7 9-2M352 99c4-10 9-11 14-1" stroke="#52C0C9" stroke-width="2"/><path d="M370 50l6-5" stroke="#DDF4F5" stroke-width="1.6"/><g data-part="marks"><path d="M10 117.5H92" stroke="#EC7A3C" stroke-width="3"/><path d="M110 117.5H126" stroke="#D8343A" stroke-width="3"/><path d="M138 117.5H214" stroke="#C69A6A" stroke-width="3"/><path d="M234 117.5H302" stroke="#E9C13C" stroke-width="3"/><path d="M320 117.5H382" stroke="#F6B12A" stroke-width="3"/></g></g></g></svg></div><span aria-hidden="true" style="position: absolute; top: 0; bottom: 0; right: 14px; width: 2px; background: #4FC3CC; box-shadow: 0 0 10px #19A7B3; opacity: .8"></span></div>
```

**Réduit strip (56 px):** the logo's wing bars used as a mic level meter; bar 15 is Loriot. Its blurred `.fx` halo (base opacity 0) gets `animation: {{ flash }}` (a `bg-glow` string) so it flashes when a detection lands.

```html
<div role="img" aria-label="Niveau du micro" style="height: 56px; display: flex; align-items: center; justify-content: center; gap: 7px; background: linear-gradient(#0B1728, #0F1E33)"><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #52C0C9; transform-origin: center; animation: bg-sing 800ms cubic-bezier(0.45,0,0.55,1) 0ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #79D0D7; transform-origin: center; animation: bg-sing 937ms cubic-bezier(0.45,0,0.55,1) 97ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #A8E2E6; transform-origin: center; animation: bg-sing 1074ms cubic-bezier(0.45,0,0.55,1) 194ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #DDF4F5; transform-origin: center; animation: bg-sing 1211ms cubic-bezier(0.45,0,0.55,1) 291ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #79D0D7; transform-origin: center; animation: bg-sing 1348ms cubic-bezier(0.45,0,0.55,1) 388ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #52C0C9; transform-origin: center; animation: bg-sing 885ms cubic-bezier(0.45,0,0.55,1) 485ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #52C0C9; transform-origin: center; animation: bg-sing 1022ms cubic-bezier(0.45,0,0.55,1) 582ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #79D0D7; transform-origin: center; animation: bg-sing 1159ms cubic-bezier(0.45,0,0.55,1) 679ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #A8E2E6; transform-origin: center; animation: bg-sing 1296ms cubic-bezier(0.45,0,0.55,1) 76ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #DDF4F5; transform-origin: center; animation: bg-sing 833ms cubic-bezier(0.45,0,0.55,1) 173ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #79D0D7; transform-origin: center; animation: bg-sing 970ms cubic-bezier(0.45,0,0.55,1) 270ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #52C0C9; transform-origin: center; animation: bg-sing 1107ms cubic-bezier(0.45,0,0.55,1) 367ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #52C0C9; transform-origin: center; animation: bg-sing 1244ms cubic-bezier(0.45,0,0.55,1) 464ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #79D0D7; transform-origin: center; animation: bg-sing 1381ms cubic-bezier(0.45,0,0.55,1) 561ms infinite"></span><span style="position: relative; display: block"><span class="fx" style="position: absolute; left: -7px; top: -6px; width: 19px; height: 48px; border-radius: 999px; background: rgba(244,197,66,.55); filter: blur(6px); opacity: 0; animation: none"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #F4C542; transform-origin: center; animation: bg-sing 918ms cubic-bezier(0.45,0,0.55,1) 658ms infinite"></span></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #DDF4F5; transform-origin: center; animation: bg-sing 1055ms cubic-bezier(0.45,0,0.55,1) 55ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #79D0D7; transform-origin: center; animation: bg-sing 1192ms cubic-bezier(0.45,0,0.55,1) 152ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #52C0C9; transform-origin: center; animation: bg-sing 1329ms cubic-bezier(0.45,0,0.55,1) 249ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #52C0C9; transform-origin: center; animation: bg-sing 866ms cubic-bezier(0.45,0,0.55,1) 346ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #79D0D7; transform-origin: center; animation: bg-sing 1003ms cubic-bezier(0.45,0,0.55,1) 443ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #A8E2E6; transform-origin: center; animation: bg-sing 1140ms cubic-bezier(0.45,0,0.55,1) 540ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #DDF4F5; transform-origin: center; animation: bg-sing 1277ms cubic-bezier(0.45,0,0.55,1) 637ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #79D0D7; transform-origin: center; animation: bg-sing 814ms cubic-bezier(0.45,0,0.55,1) 34ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #52C0C9; transform-origin: center; animation: bg-sing 951ms cubic-bezier(0.45,0,0.55,1) 131ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #52C0C9; transform-origin: center; animation: bg-sing 1088ms cubic-bezier(0.45,0,0.55,1) 228ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #79D0D7; transform-origin: center; animation: bg-sing 1225ms cubic-bezier(0.45,0,0.55,1) 325ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #A8E2E6; transform-origin: center; animation: bg-sing 1362ms cubic-bezier(0.45,0,0.55,1) 422ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #DDF4F5; transform-origin: center; animation: bg-sing 899ms cubic-bezier(0.45,0,0.55,1) 519ms infinite"></span><span style="display: block; width: 5px; height: 36px; border-radius: 3px; background: #79D0D7; transform-origin: center; animation: bg-sing 1036ms cubic-bezier(0.45,0,0.55,1) 616ms infinite"></span></div>
```

**Agrandi (LiveSpectre):** reuse the same `<svg>` with `width="1560" height="450"` inside a `<div style="position: absolute; top: 0; left: 0; width: 1560px; height: 450px; animation: bg-scroll 10s linear infinite">`, and delete the two `<g data-part="marks">…</g>` groups (they become boxes, see 9.3). Draw kHz grid lines in the container: `background: repeating-linear-gradient(to bottom, transparent 0 89px, rgba(238,241,236,.07) 89px 90px), linear-gradient(#0B1728, #0F1E33)`.

Tile geometry (for boxes and labels): tile = 390 × 120 units = 10 s × 10 kHz; y = 120 − 12 × kHz. In the agrandi view 1 unit = 2 px horizontally and 3.75 px vertically. Calls in each tile (second tile: add 390 units, i.e. 780 px):

| Call | Species | Tile box (x1–x2, y1–y2 units) | Agrandi box in px (left, top, width, height) |
|---|---|---|---|
| Liquid run of notes | Rougegorge familier | 8–94, 22–88 | 16, 82, 172, 248 |
| Two sharp "kik" | Pic épeiche | 108–128, 18–108 | 216, 68, 40, 337 |
| Dense trill | Troglodyte mignon | 136–216, 20–76 | 272, 75, 160, 210 |
| "ti-tu ti-tu ti-tu" | Mésange charbonnière | 232–304, 46–84 | 464, 172, 144, 143 |
| Low fluty phrase | Merle noir | 318–384, 40–106 | 636, 150, 132, 248 |

**Review clip (Revue and Rare, static, 0–4 kHz, Huppe « oup-oup-oup »):** put it in a dark inset (`background: linear-gradient(#0B1728, #0F1E33); border-radius: 16px; overflow: hidden`).

```html
<svg viewBox="0 0 300 80" width="100%" height="80" preserveAspectRatio="none" aria-hidden="true" style="display:block"><defs><filter id="rv-glow" x="-5%" y="-30%" width="110%" height="160%"><feGaussianBlur stdDeviation="1.6" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs><g fill="none" stroke-linecap="round" filter="url(#rv-glow)"><path d="M185.1 55.9h3.5 M279.1 55.8h3.8 M10.5 36.6h3.9 M192.8 67.1h1.8 M139.9 21.3h2.9 M170.7 4.9h2 M84.2 68.1h3.4 M48.9 59.8h1.8 M183.5 12.9h1.5 M258.2 18.7h2 M290.8 65.1h2.2 M284.7 41.7h3.2 M62.2 69.9h3.2 M286.2 66.6h2.2 M108.2 15.6h1.9 M21.2 25.1h3 M3 51.5h2.3 M93.1 61.3h2.7 M94.8 37.7h3.3 M18.8 72.3h1.6 M222.4 63.1h1.5 M233.6 29.6h2.9 M4.7 7.3h2 M282.8 17.8h3.4 M275.3 69.9h2.4 M106.3 40.7h3.4 M33.8 56.4h3.5 M254.8 6.6h3.9 M28.8 27.9h3 M271.9 27.8h3.8 M162.3 25.9h2.3 M54.2 9.5h1.9 M204.6 73.8h1.9 M16.3 73.1h2.8 M121.3 20.6h3 M244.9 35.9h2.6 M18.4 68.1h1.6 M147.1 62.7h1.8 M217.1 70.5h3.1 M233.7 11.5h2.6" stroke="#19A7B3" stroke-width="1" opacity=".25"/><path d="M23 53h12M47 53h12M71 53h12M169 53h12M193 53h12M217 53h12" stroke="#52C0C9" stroke-width="2.4" opacity=".6"/><path d="M22 66h14M46 66h14M70 66h14M168 66h14M192 66h14M216 66h14" stroke="#DDF4F5" stroke-width="4.5"/><path d="M29 66h.1M53 66h.1M199 66h.1" stroke="#F4C542" stroke-width="3"/></g></svg>
```

Playhead (translate trick) on top of it while "playing":
`<span class="fx" style="position: absolute; inset: 0; border-right: 2px solid #F4C542; animation: bg-playhead 3s linear infinite"></span>`

---

## 6. Animation language

### 6.1 Celebration ladder (who gets what)

| Level | Trigger | What you see | Drawn haptic (`.fx` ripple rings) | Where |
|---|---|---|---|---|
| L0 Réentendu | species already in this session sings again | row glow in its accent (`bg-glow`, 900 ms) + ×N bump (`bg-bump`, 200 ms) + header "contacts" bump + "chante" bars on that row. The row does not move. | none | Live |
| L1 Arrivée | first contact of a species in this session | new row enters at the top with `bg-arrive` (420 ms: slide 12 px, scale .96 → 1, fade) + one ripple from the icon halo + header "espèces" bump; the Loriot bar of the réduit strip flashes | light: 1 ring, 600 ms | Live, Arrivee |
| L2 Nouveau cette année | first contact of the calendar year of a known species | L1 + « Nouveau cette année » pill pops in (`bg-pop` 250 ms, delay 300 ms) | medium: 2 rings, 150 ms apart | Live |
| L3 Première fois | first verified contact ever (Sûr, or confirmed) | takeover of the list area (not the control bar): veil, wave of the bird's colors crossing the screen once (600 ms), card and big icon land (700 ms), lines rise, progress bar gains its Loriot segment; closes by itself after 6 s or on « Continuer l'écoute » | medium: 2 rings | Premiere |
| L3′ Peut-être une première | first-ever species but Probable or À vérifier | no takeover, no wave: the row shows the grey icon look + a line « Peut-être une première. Réécoute-le pour en être sûr. »; the real L3 plays after « C'est bien lui » (live, in Revue or in the Bilan) | light | Live |
| L4 Oiseau rare | Rare or Exceptionnel here (always À vérifier) | golden card lands (800 ms), sheen crosses it every 2.6 s, Loriot rings radiate while it waits; the party (light points, "confirmé", count) happens only after « C'est bien lui » | double pulse: 2 × 2 rings | Rare |
| Statut | a new status is reached | emblem lands (900 ms), rings of the status color, a few feathers fall; plays in the Bilan after « Arrêter », never while listening | medium | Niveau |

Rules: at most one L3/L4 overlay at a time (others wait for the Bilan, marked « Nouveau » until opened); an overlay never covers « Arrêter » / « Pause »; no celebration sound (the mic would hear it and it disturbs birds); no confetti; L3 and L4 never award extra points for rarity.

### 6.2 Everyday motion

- Button press: `class="bg-press"` (scale .97, 120 ms).
- Screen load: up to 5 blocks rise with `bg-rise` 220 ms, 40 ms stagger. Tabs, nav and scrolling: no animation.
- Sheet: `bg-sheet` 380 ms. Next review card: `bg-pop` 250 ms.
- Numbers that change: `bg-bump` on the number only (the line does not move).
- Loops allowed: Live dot, listening logo, spectrum, level strip, "chante" bars, moment boards; on light screens only the map position halo, the Revue card hint and the clip playhead.

### 6.3 Reduced motion

Handled globally by the helmet: each inline animation becomes one 200 ms fade, `.fx` layers (waves, rings, sheen, sparkles, feathers, ripples, playheads, gained segment, glow layer, "chante" bars) disappear. Every piece of information (titles, counts, pills, progress) must stay outside `.fx`, so nothing is lost.

---

## 7. Game system

### 7.1 What counts

- A species counts when it is a bird (J4 "oiseaux seulement") and has at least one **verified** detection: level Sûr, or answered « C'est bien lui ».
- Probable and À vérifier never count until confirmed. An « Inattendu ici » species is always À vérifier, so it always needs « C'est bien lui ».
- « Fois » and « contacts » are the same unit everywhere (Live, fiche, palmarès, carte, exports): detections of one species merged when they are less than 10 s apart.
- « Je ne sais pas » removes nothing, costs nothing, and counts as a review for the Réviseur badge exactly like the two other answers.

### 7.2 The 8 statuts (by verified species)

| # | Statut | From | Line shown when reached (informational, not a command) |
|---|---|---|---|
| — | (before) | 0 | « Ton carnet t'attend. Lance une écoute au lever du jour. » |
| 1 | Oisillon | 1 | « Ta toute première espèce. Tout commence ici. » |
| 2 | Jeune plume | 5 | « Tu reconnais les voix les plus faciles du jardin. » |
| 3 | Premier envol | 10 | « Tu sais repérer les chanteurs du matin. » |
| 4 | Sentinelle des haies | 20 | « Tu reconnais maintenant les voix des haies et des jardins. » |
| 5 | Oreille de chouette | 35 | « Tu entends aussi les oiseaux discrets et ceux de la nuit. » |
| 6 | Grand migrateur | 50 | « Tu suis les oiseaux qui vont et viennent avec les saisons. » |
| 7 | Plume d'or | 75 | « Ton carnet devient une vraie référence. » |
| 8 | Martin-pêcheur | 100 | « Cent espèces à l'oreille. Chapeau. » |

Progress line format: « Encore 11 espèces pour devenir Oreille de chouette ». The first three statuts come within the first week; the last ones take seasons.

### 7.3 Badges (3 tiers: 1, 2, 3 plumes)

| Badge | Rule | Tiers | Glyph (UI icon or species icon) |
|---|---|---|---|
| Chœur de l'aube | 10 verified species in one listening started before 8 h | 1 / 5 / 20 times | `sun` |
| Lève-tôt | a listening started before sunrise | 1 / 5 / 20 | `clock` |
| Noctambule | a verified night species (owls, nightjar…) | 1 / 3 / 6 species | `moon` |
| Réviseur | detections sorted in Revue rapide (all three answers count) | 10 / 50 / 200 | `check` |
| Oreille fine | right answers in the « Qui chante ? » quiz (built from your own verified clips) | 10 / 50 / 150 | `headphones` |
| Migrateur | verified migratory species | 3 / 6 / 12 | status glyph `migrateur` |
| 7 jours d'affilée | a série of 7 days (rest day allowed) | 7 / 30 / 100 days | `calendar` |
| Les mésanges | verified tit species | 2 / 4 / 6 | species icon `mesange-bleue` (32 px) |

Also defined (not drawn in the mockup): Fidèle au jardin (10 / 30 / 100 listenings at one place), Les pics (1 / 2 / 3 woodpeckers), Retour du printemps (first cuckoo and first swallow of the year).

### 7.4 Série (forgiving streak)

- A day counts with at least 5 minutes of listening.
- One rest day per 7 days is automatic and shown as « repos »; the série continues.
- Missing more: the série restarts quietly at the next listening. No loss screen, no notification, the record is kept (« Record : 12 jours »).
- Copy under the calendar: « Le cercle en pointillé, c'est ton jour de repos : un par semaine ne casse pas ta série. »

### 7.5 Défis

- Weekly (Monday–Sunday) and seasonal. Opt-in: nothing counts before « Commencer ». No penalty when a défi ends unfinished (it just closes: « Ce défi est fini. Un autre t'attend lundi. »).
- Active this week: « Trois matins avant 8 h » (2 sur 3). Offered (not started): « Les migrateurs de passage : 5 espèces avant le 30 novembre ». Unlocked by Sentinelle des haies: « Oiseaux des haies : 4 espèces nouvelles ».
- Notifications are opt-in, daytime only, never guilt: « Le soleil se lève à 7 h 41, c'est l'heure du chœur. »

### 7.6 Rarity tiers (geomodel, for this place and this week)

| Tier | Expected presence | Mark | Effect |
|---|---|---|---|
| Commun | ≥ 20 % | none | — |
| Peu commun | 5 – 20 % | `half` | mark only |
| Rare | 1 – 5 % | `diamond` (Loriot) | « Inattendu ici » + À vérifier + L4 golden card |
| Exceptionnel | < 1 % or never reported here this season | `star` (Loriot) | same as Rare |

Copy uses « Présence estimée ici cette semaine : 2 sur 100 ». Rarity never gives points or levels; a confirmed rare bird gets only a special look (Loriot frame and diamond in the carnet, light points once).

### 7.7 Ethics (must be visible in the UI where noted)

1. Nothing is won with an unverified detection (7.1). Shown: Rare card note « Il entre dans ton carnet seulement après ta réponse. »
2. No luring. « Réécouter » plays one clip once, at low volume, headphones advised, the listening continues; never looped; no word like « attirer » or « faire venir ». Shown once in Live (toast) and on the Fiche: « Garde le son pour toi : un chant diffusé fort dérange les oiseaux, surtout au printemps. »
3. Sensitive species: shared cards and exports show the commune only; on shareable map views sensitive species are blurred to a 10 km cell. Shown on Carte: « Tes positions précises restent sur ton téléphone. »
4. LPO / Faune-France: only confirmed observations can be prepared for sending, each with « Contact auditif ; identification assistée par IA puis confirmée par l'observateur. » Shown on Bilan: « Seuls les oiseaux que tu confirmes partent à la LPO. » Shown on Rare (confirmed): « Garde l'extrait : si tu l'envoies à la LPO, ses bénévoles pourront l'écouter. »
5. AI species sheets are written in advance, checked and bundled offline; « Ici en ce moment » comes from the geomodel, never from generated text. Shown on Fiche.
6. No public leaderboard, no chat, no ads, no purchase, no random reward.

---

## 8. Dataset (the only numbers allowed)

"Now" for the whole mockup: **samedi 26 septembre 2026, 8 h 05**, just after a morning listening. Place: **Le jardin**, commune **Beaulieu-sur-Brenne** (fictional), garden with a hedge, a meadow, a small wood and a stream. Sunrise 7 h 41. Revue is the only board that is a few minutes later (2 reviews already done).

### 8.1 The user

| Item | Value |
|---|---|
| First listening | 4 octobre 2025 |
| Listenings / contacts all time | 64 écoutes · 1 104 contacts |
| Verified species | **24** (23 before this morning + Pic épeiche). Huppe fasciée pending → 25 if confirmed |
| Statut | **Sentinelle des haies** since 14 août (20th species: Martin-pêcheur d'Europe) |
| Next statut | Oreille de chouette at 35 → « Encore 11 espèces » ; ring progress 4/15 = 27 % (dasharray 62) ; this morning the bar went 3/15 → 4/15 |
| Série | **9 jours** (vendredi 18 → samedi 26, rest day mardi 22). Record 12 jours |
| Last 14 days (lun 14 → dim 27) | 14 ✓, 15 –, 16 ✓, 17 –, 18 ✓, 19 ✓, 20 ✓, 21 ✓, 22 repos, 23 ✓, 24 ✓, 25 ✓, 26 ✓ (today), 27 (future) |
| Défi de la semaine | « Trois matins avant 8 h » : 2 sur 3 (jeudi 24, samedi 26) |
| Revue | 12 détections à vérifier (9 older + 3 this morning); 36 already sorted before today |
| Species expected in the region | 112 (geomodel, all year) |
| New species in 2026 | 9 (Pouillot véloce, Chouette hulotte, Martin-pêcheur d'Europe, Pic épeiche, Loriot d'Europe, Fauvette à tête noire, Hirondelle rustique, Rougequeue noir, Sittelle torchepot) |
| Verified species without icon (never drawn) | Pigeon ramier, Tourterelle turque, Corneille noire, Geai des chênes, Fauvette à tête noire, Rougequeue noir, Sittelle torchepot, Grive musicienne, Étourneau sansonnet, Chardonneret élégant, Hirondelle rustique |

Badges state: Chœur de l'aube 1 plume (**earned this morning**, « Nouveau »), Lève-tôt 2 plumes (7 écoutes), Noctambule 1 plume (Chouette hulotte), Réviseur 1 plume (36 sur 50), Oreille fine locked (4 sur 10), Migrateur 1 plume (4 espèces), 7 jours d'affilée 1 plume, Les mésanges 1 plume (2 sur 4).

### 8.2 This morning's session

Samedi 26 septembre, **7 h 12 → 7 h 54 (42 min)**, Le jardin. **13 espèces · 52 contacts**. Live list order = order of first contact, newest on top.

| Key (JS key) | Nom | ×session | Total after | First – last | Level (best) | Score | Here this week |
|---|---|---|---|---|---|---|---|
| `rougegorge` (rougegorge) | Rougegorge familier | 9 | 142 | 7 h 13 – 7 h 52 | Sûr | 0,97 | Commun 78 % |
| `chouette-hulotte` (chouette) | Chouette hulotte | 1 | 7 | 7 h 14 | Probable | 0,71 | Peu commun 12 % |
| `troglodyte` (troglodyte) | Troglodyte mignon | 7 | 64 | 7 h 15 – 7 h 50 | Sûr | 0,94 | Commun 52 % |
| `merle` (merle) | Merle noir | 6 | 118 | 7 h 17 – 7 h 49 | Sûr | 0,88 | Commun 70 % |
| `mesange-charbonniere` (charbonniere) | Mésange charbonnière | 6 | 97 | 7 h 19 – 7 h 47 | Sûr | 0,91 | Commun 66 % |
| `mesange-bleue` (bleue) | Mésange bleue | 5 | 71 | 7 h 24 – 7 h 45 | Sûr | 0,89 | Commun 58 % |
| `pinson` (pinson) | Pinson des arbres | 4 | 55 | 7 h 24 – 7 h 44 | Sûr | 0,86 | Commun 44 % |
| `pouillot` (pouillot) | Pouillot véloce | 3 | 31 | 7 h 24 – 7 h 40 | Sûr (Probable at 1st contact, 0,62) | 0,84 | Commun 31 % |
| `pie` (pie) | Pie bavarde | 4 | 38 | 7 h 25 – 7 h 51 | Sûr | 0,90 | Commun 40 % |
| `moineau` (moineau) | Moineau domestique | 3 | 46 | 7 h 25 – 7 h 53 | Sûr | 0,83 | Commun 36 % |
| `pic-epeiche` (pic) | Pic épeiche | 2 | 2 | 7 h 26 – 7 h 33 | Sûr | 0,91 | Commun 27 % — **Première fois, 24e espèce** |
| `martin-pecheur` (martin) | Martin-pêcheur d'Europe | 1 | 3 | 7 h 31 | À vérifier | 0,52 | Peu commun 6 % |
| `huppe` (huppe) | Huppe fasciée | 1 | 1 | 7 h 38 | À vérifier + Inattendu ici | 0,58 | **Rare 2 %** — première possible |

"Total before" = total after − ×session. The three to verify: Chouette hulotte, Martin-pêcheur d'Europe, Huppe fasciée.

### 8.3 Snapshots of the same session

| Moment | Elapsed | Espèces · contacts | Visible rows, top to bottom (×session · total) |
|---|---|---|---|
| Live start (loop start) | 12:40 | 5 · 9 | Mésange charbonnière ×1 · 92, Merle noir ×2 · 114, Troglodyte mignon ×2 · 59, Chouette hulotte ×1 · 7 (Probable), Rougegorge familier ×3 · 136 |
| Live script | +2.5 s each | see 10.1 | 12 events: bleue (new), rougegorge, pinson (new), troglodyte, pouillot (new, Probable), charbonniere, pie (new), rougegorge, pouillot (→ Sûr), merle, moineau (new), bleue |
| Live end of loop | 13:10 | 10 · 21 | Moineau ×1 · 44, Pie ×1 · 35, Pouillot ×2 · 30, Pinson ×1 · 52, Mésange bleue ×2 · 68, Mésange charbonnière ×2 · 93, Merle ×3 · 115, Troglodyte ×3 · 60, Chouette ×1 · 7, Rougegorge ×5 · 138 |
| Arrivee (Pinson arrives) | 12:46 → 12:47 | 6 · 11 → 7 · 12 | Pinson des arbres ×1 · 52 (new), Mésange bleue ×1 · 67, Mésange charbonnière ×1 · 92, Merle noir ×2 · 114, Troglodyte mignon ×2 · 59, Chouette hulotte ×1 · 7, Rougegorge familier ×4 · 137 |
| Premiere (Pic épeiche) | 14:02 | 10 · 21 → 11 · 22 | Pic épeiche ×1 · 1 (new, Première fois), Moineau ×1 · 44, Pie ×1 · 35, Pouillot ×2 · 30, Pinson ×1 · 52 |
| LiveSpectre | 24:18 | 12 · 40, 1 nouvelle | Martin-pêcheur d'Europe ×1 · 3 (À vérifier), Pic épeiche ×2 · 2 (Sûr, Première fois), Moineau domestique ×2 · 45 (Sûr) |
| Rare (Huppe) | 26:04 | 13 · 42 | Huppe fasciée ×1 · 1 (new), Martin-pêcheur ×1 · 3, Pic épeiche ×2 · 2, Moineau ×2 · 45, Pouillot ×3 · 31 |
| Bilan | 42:00 | 13 · 52 | full table 8.2 |

### 8.4 Periods (Palmarès) — contacts per species

| Species | 30 jours | Saison (depuis le 1er septembre) | Année 2026 | Tout (depuis le 4 octobre 2025) |
|---|---|---|---|---|
| Rougegorge familier | 58 | 53 | 118 | 142 |
| Merle noir | 41 | 37 | 97 | 118 |
| Mésange charbonnière | 37 | 33 | 80 | 97 |
| Troglodyte mignon | 29 | 27 | 51 | 64 |
| Mésange bleue | 24 | 22 | 58 | 71 |
| Pinson des arbres | 19 | 17 | 47 | 55 |
| Moineau domestique | 17 | 15 | 39 | 46 |
| Pie bavarde | 14 | 13 | 31 | 38 |
| Pouillot véloce | 9 | 9 | 31 | 31 |
| Species in the period (confirmées seulement / all) | 17 / 18 | 16 / 17 | 23 / 24 | 24 / 25 |
| Period caption | « du 27 août au 26 septembre » | « depuis le 1er septembre » | « en 2026 » | « depuis le 4 octobre 2025 » |

Ranks: 30 jours and Saison: 1 Rougegorge, 2 Merle, 3 Charbonnière, 4 Troglodyte, 5 Mésange bleue, 6 Pinson, 7 Moineau, 8 Pie, 9 Pouillot. Année and Tout: 1–3 same, 4 Mésange bleue, 5 Troglodyte, 6 Pinson, 7 Moineau, 8 Pie, 9 Pouillot (Année tie at 31: Pie first, more days). Header line 2 always: « 9 nouvelles en 2026 ».

### 8.5 Revue queue (cards 3 to 6 of 12)

| Card | Species | Level | When · where | Detail line |
|---|---|---|---|---|
| 3 (top) | Huppe fasciée | À vérifier + Inattendu ici | Ce matin à 7 h 38 · Le jardin | Score 0,58 · présence estimée ici : 2 sur 100 |
| 4 | Pouillot véloce | Probable | Jeudi 24 septembre à 7 h 55 · Le jardin | Score 0,64 |
| 5 | Mésange bleue | À vérifier | Mercredi 23 septembre à 18 h 20 · La haie du chemin | Score 0,49 |
| 6 | Merle noir | Probable | Lundi 21 septembre à 18 h 41 · Le jardin | Score 0,61 |

Cards 1–2 (Chouette hulotte, Martin-pêcheur) were answered « C'est bien lui » a moment ago. After card 6 the demo loops to card 3. Réviseur count: 38 at card 3, +1 per answer.

### 8.6 Map spots (Carte, 30 jours, confirmées)

| Spot | Markers (species · contacts at this spot) | Sheet title / subtitle | Sheet rows |
|---|---|---|---|
| Le jardin (cluster) | cluster « 8 » | « Le jardin » / « 8 espèces · 164 contacts en 30 jours » | Rougegorge familier 44, Merle noir 35, Mésange charbonnière 29 |
| La haie du chemin | Troglodyte 21, Pie 9, Pouillot 7 | « La haie du chemin » / « 5 espèces · 61 contacts en 30 jours » | Troglodyte mignon 21, Pie bavarde 9, Pouillot véloce 7 |
| Le ruisseau | Martin-pêcheur 2 | « Le ruisseau » / « 1 espèce · 2 contacts en 30 jours » | Martin-pêcheur d'Europe 2 (badge À vérifier on today's) |
| Le petit bois | Chouette hulotte 4, Pic épeiche 2 | « Le petit bois » / « 2 espèces · 6 contacts en 30 jours » | Chouette hulotte 4, Pic épeiche 2 |

### 8.7 Fiche (Rougegorge familier)

- Personal line: « Entendu 142 fois sur 38 jours, la dernière fois ce matin à 7 h 52. »
- Reliability: Sûr · « 37 bonnes sur 38 vérifiées »
- Ici en ce moment (geomodel): « Présent toute l'année. Il chante aussi en automne. » Presence bars Jan→Dec (0–1): .9 .9 .95 1 1 1 .95 .9 .95 1 .95 .9, September highlighted.
- Recordings: « 0,97 · ce matin, 7 h 41 » / « Le jardin » (favori ★ filled Loriot); « 0,95 · 12 septembre, 8 h 03 » / « La haie du chemin » (★ outline).
- Activity by hour (24 bars, 0 h → 23 h, relative): 0 0 0 0 0 .1 .35 1 .8 .45 .3 .2 .15 .15 .2 .25 .35 .5 .4 .15 .05 .05 .1 0 (night singing near the street lamp at 22 h).
- Sheet sections (text in 9.13).

---

## 9. Screens

Legend: heights are targets in px; "gap" is the flex gap of the parent. Text styles refer to 2.9. Every clickable thing is a real `<a>` or `<button>`.

### 9.1 `Main.dc.html` — Accueil (light)

Root: light, `padding: 16px 20px 0`, `gap: 12px`. Nav at the bottom (absolute). « Écouter » absolute at `left: 20px; right: 20px; bottom: 96px`.

1. **Top row** (48): brand mark 32 + wordmark (gap 8) · spacer · streak chip « 9 jours » (→ `Profil.dc.html`).
2. **Greeting** (gap 4): « Bonjour » (Display 34). Caption: « Samedi 26 septembre · Beaulieu-sur-Brenne ». Greeting by time: 5–12 h « Bonjour », 12–18 h « Bon après-midi », 18–22 h « Bonsoir », 22–5 h « Bonne nuit ».
3. **Status card** (`<a href="Profil.dc.html">`, white, radius 20, padding 16, gap 16, `bg-rise`): ring 84 (Sentinelle des haies, 4/15) · column: « Sentinelle des haies » (Heading 20), « 24 espèces découvertes » (Body 15, « 24 » weight 800 tabular), caption « Encore 11 pour devenir Oreille de chouette » · `chevron-right` 20 Écorce.
4. **Today tiles** (grid 3, gap 8, stat tile light): « 13 » « espèces ce matin » · « 52 » « contacts » · « 1 » « nouvelle » (number in `#7A5A00`).
5. **Last bird card** (`<a href="Fiche.dc.html">`, background `#FCE7DC`, radius 20, padding 12 16, gap 12, min-height 88): icon rougegorge 64 · column: caption « Dernier oiseau entendu », « Rougegorge familier » (Heading 20), row: badge Sûr (light) + caption « 7 h 52 · 142 au total » · `chevron-right`.
6. **Défi card** (white, radius 20, padding 14 16): 40 px teal circle `#D6EEF0` with `sun` icon `#0B6E77` · column: caption « Défi de la semaine », « Trois matins avant 8 h » (Species 17) · right: three 14 px dots (2 filled `#19A7B3`, 1 outline `#C5CCC2` 2 px) above caption « 2 sur 3 ».
7. **To verify** (`<a href="Revue.dc.html">`, white, radius 20, padding 12 16, min-height 56): 40 px circle `#FFFFFF` with 1.5 px dashed `#A04A1C` and `question` icon `#A04A1C` · « 12 détections à vérifier » (Label 15) + caption « Réécoute-les quand tu as un moment. » · `chevron-right`.
8. **« Écouter »** big button → `Live.dc.html`.
9. **Nav**, Accueil active.

Motion: blocks 3–7 `bg-rise` staggered 40 ms. Nothing loops.

### 9.2 `Live.dc.html` — Écoute en direct (dark, interactive)

Root: dark, no padding, `gap: 0`. Logic: 10.1 (copy it).

1. **Header** (`padding: 16px 16px 12px`, column, gap 12):
   - Row A (48, gap 10): listening brand mark 28 · column: live dot (8 px `#4FC3CC`, glow, `bg-live`) + « En écoute » (Label 15, `{{ liveText }}`: « En pause » when paused), caption « Le jardin · Beaulieu-sur-Brenne » · spacer · icon button dark « Réduire le spectre » / « Afficher le spectre » (`chevron-up` / `chevron-down`, `onClick="{{ toggleSize }}"`) · icon button dark `<a href="LiveSpectre.dc.html" aria-label="Agrandir le spectre">` with `expand`.
   - Row B: grid 3 stat tiles dark: « {{ timer }} » « durée » · « {{ species }} » « espèces » · « {{ contacts }} » « contacts ». The two counts carry `animation: {{ speciesBump }}` / `{{ contactsBump }}` on the number span.
2. **Spectrum**: normal band (5.13) wrapped in `<div style="display: {{ bandNormal }}">`, the inner scrolling div gets `animation-play-state: {{ playState }}`; réduit strip in `<div style="display: {{ bandSmall }}">`; the Loriot halo of bar 15 gets `animation: {{ flash }}`.
3. **Table** (`padding: 12px 8px 0`, column, gap 8, `flex: 1`, `overflow: hidden`): 10 static rows, one per species of the Live script, in any source order, each wrapped in `<div style="display: {{ r.KEY.display }}; order: {{ r.KEY.order }}; animation: bg-arrive 420ms cubic-bezier(0.23,1,0.32,1) both">`. Inside, the 5.5 row with: glow layer `animation: {{ r.KEY.glow }}`, a ripple ring on the halo (`<span class="fx" style="position: absolute; inset: -4px; border-radius: 999px; border: 2px solid ACCENT; opacity: 0; animation: {{ r.KEY.ripple }}"></span>` inside the halo, halo gets `position: relative`), "chante" bars in `<span style="display: {{ r.KEY.sing }}">`, two badges (`display: {{ r.KEY.sur }}` / `{{ r.KEY.prob }}`; Chouette only has Probable, Pouillot has both), total `{{ r.KEY.total }} au total`, count `×{{ r.KEY.n }}` with `animation: {{ r.KEY.bump }}`, play button `onClick="{{ r.KEY.play }}"` whose background is `{{ r.KEY.playBg }}` and which holds both icons (`play` in `display: {{ r.KEY.playIcon }}`, `pause` in `display: {{ r.KEY.pauseIcon }}`; pause icon color `#13233A`). KEY = `rougegorge, chouette, troglodyte, merle, charbonniere, bleue, pinson, pouillot, pie, moineau`.
4. **Control bar** (absolute bottom, `padding: 12px 16px 16px`, `background: #0F1D31`, `border-top: 1px solid rgba(238,241,236,.08)`, column gap 10): toast (5.12) in `display: {{ toast }}` with copy « Réécoute à faible volume. L'écoute continue. » · row: « Arrêter » `<a href="Resume.dc.html">` + « Pause » `<button onClick="{{ togglePause }}">` whose label is two spans (« Pause » `{{ pauseLabel }}`, « Reprendre » `{{ resumeLabel }}`) and two icons (`pause` / `play`).

Rows never reorder; new species enter at the top (arrival order). No sort switch in the mockup. (The brief suggested moving a re-heard row up; DESIGN.md « la ligne ne bouge pas » and Merlin's pattern win: the row lights up and its counter bumps, so a child can keep reading the table.)

### 9.3 `LiveSpectre.dc.html` — Écoute, spectre agrandi (dark)

Static snapshot at 24:18 (8.3). Same visual language as Live; the spectrum still scrolls.

1. **Row A** (`padding: 16px 16px 8px`, 48): listening brand mark 28 · column: live dot + « En écoute · 24:18 » (Label 15, tabular), caption « 12 espèces · 40 contacts · » followed by « 1 nouvelle » in `#F4C542` weight 700 · spacer · `<a href="Live.dc.html" aria-label="Réduire le spectre">` icon button dark with `shrink`.
2. **Spectrum agrandi** (height 470: plot 450 + time row 20): left axis 36 px wide with kHz labels (caption 13, `#B4C0CC`, right-aligned, tabular): « 10 kHz » at top 0, « 8 » at 90, « 6 » at 180, « 4 » at 270, « 2 » at 360, « 0 » at 438. Plot 354 × 450 (`position: relative; overflow: hidden`, grid background of 5.13). Inside the plot, the scrolling 1560 px layer (5.13) containing the tile SVG **and** ten HTML boxes (5 calls × 2 tiles, px table in 5.13): each box `position: absolute; border: 1.5px solid ACCENT; border-radius: 8px; background: rgba(ACCENT,.10)` with a label chip on its top edge (`position: absolute; top: -28px; left: 0; display: inline-flex; align-items: center; gap: 6px; height: 24px; padding: 0 8px; border-radius: 999px; background: rgba(11,23,40,.88); color: #EEF1EC; font 13 / 700; white-space: nowrap` + a 8 px dot of the accent). Labels = species names. Right edge: "maintenant" line (2 px `#4FC3CC` with glow, not scrolling). Top-left overlay legend (not scrolling): `<div>` with caption « Intensité » + an 80 × 8 bar `linear-gradient(90deg, #102A40, #0F7C86, #19A7B3, #A8E2E6, #F4C542)` radius 999 + captions « faible » / « fort ». Time row under the plot (caption 13, text-2): « −4 s » « −3 s » « −2 s » « −1 s » « maintenant » evenly spaced across the plot width.
3. **Top 3 rows** (`padding: 8px 8px 0`, gap 6): compact rows (5.5) — Martin-pêcheur d'Europe (À vérifier) ×1 ; Pic épeiche (Sûr + Première fois pill) ×2 ; Moineau domestique (Sûr) ×2. Under them a centered caption « 9 autres espèces sous le spectre » (13, text-2).
4. **Control bar** as Live, without toast; « Arrêter » → `Resume.dc.html`, « Pause » static.

### 9.4 `Arrivee.dc.html` — Moment : un oiseau arrive (dark, loop 4 s)

The Live screen at 12:46 → 12:47 (8.3), no annotation of any kind. Header, normal band, table and control bar exactly as Live (static values except below). Loop logic 10.3.

- Pinson des arbres row at the top: wrapper `display: {{ pinson }}` with `bg-arrive`; its halo ripple `.fx` ring plays `bg-ripple 600ms 120ms both` on each appearance; its "chante" bars visible.
- Header: « {{ timer }} » (12:46 → 12:47), « {{ species }} » (6 → 7, bump), « {{ contacts }} » (11 → 12, bump).
- Réduit strip not shown; the normal band scrolls continuously (it does not restart).

### 9.5 `Premiere.dc.html` — Moment : première fois (dark, loop 7 s)

Background = Live at 14:02 (8.3) with rows Pic épeiche (top) ×1 · 1, Moineau ×1 · 44, Pie ×1 · 35, Pouillot ×2 · 30, Pinson ×1 · 52; header tiles « 14:02 » « 11 » « 22 ». The control bar (« Arrêter » / « Pause ») stays **above** the overlay (`z-index: 3`). Loop logic 10.3 (stage = everything below).

Stage (`position: absolute; inset: 0 0 92px 0; z-index: 2; display: {{ stage }}; align-items: center; justify-content: center`):

| # | Layer | Style | Animation (delay) |
|---|---|---|---|
| 1 | veil | `position: absolute; inset: 0; background: rgba(12,24,41,.78)` | `bg-fade 200ms` (0) |
| 2 | wave `.fx` | `position: absolute; inset: 0; background: linear-gradient(100deg, transparent 18%, rgba(216,52,58,.85) 40%, rgba(31,36,44,.92) 52%, rgba(245,243,236,.6) 58%, transparent 76%)` | `bg-sweep 600ms cubic-bezier(0.77,0,0.175,1) 100ms both` |
| 3 | color halo `.fx` | 420 px circle centered behind the card, `radial-gradient(closest-side, rgba(216,52,58,.35), transparent)` | `bg-fade 400ms 500ms both` |
| 4 | card | width 350, radius 28, padding 20 16 16, column centered, gap 8, `background: linear-gradient(180deg, #42273A 0%, #1A2D47 70%)`, `border: 1px solid rgba(216,52,58,.5)`, `box-shadow: 0 20px 60px rgba(0,0,0,.35)` | `bg-land 700ms 250ms both` |

Card content, top to bottom (all centered):
1. « L'écoute continue » — caption 13 text-2 with the live dot before it. (`bg-fade`, 300 ms)
2. Icon pic-epeiche 152, inside a 164 px box with two `.fx` ripple rings (border 2 px `#D8343A`) at 350 ms and 500 ms (`bg-ripple 600ms`). Icon: `bg-land 700ms 300ms both`.
3. « Première fois » pill (`bg-pop 250ms 600ms both`).
4. « Première rencontre ! » Display 34 (`bg-rise 220ms 650ms both`).
5. « Pic épeiche » Title 26 + « Dendrocopos major » Latin 17 text-2 (`bg-rise 720ms`).
6. « Ajouté à ton carnet · 24e espèce » Label 15 (`bg-rise 790ms`).
7. Progress block (width 100 %, gap 6, `bg-rise 860ms`): status chip dark « Sentinelle des haies » · progress bar dark 3/15 → 4/15 (gain delay 1000 ms) · caption « Encore 11 espèces pour devenir Oreille de chouette ».
8. Buttons, stacked full width (column, gap 8, `bg-rise 930ms`; two buttons side by side do not fit in 310 px): primary `<a href="Live.dc.html">` « Continuer l'écoute » · secondary dark « Réécouter » (`play`; `onClick="{{ togglePlay }}"`, icon swaps to `pause` while the 3 s clip plays).
9. Caption « Se referme seul dans 6 s. » (13, text-2).

### 9.6 `Rare.dc.html` — Moment : oiseau rare (dark, loop 8 s while asking)

Background = Live at 26:04 (8.3): rows Huppe fasciée (top, À vérifier + Inattendu ici) ×1 · 1, Martin-pêcheur ×1 · 3, Pic épeiche ×2 · 2, Moineau ×2 · 45, Pouillot ×3 · 31; tiles « 26:04 » « 13 » « 42 ». Control bar above the overlay. Logic 10.4.

Stage (as Premiere): veil `bg-fade`; three `.fx` rings behind the icon (190 px circles, `border: 2px solid #F4C542`, `animation: bg-ring 2400ms cubic-bezier(0.23,1,0.32,1) infinite`, delays 800 / 1600 / 2400 ms); **golden card**: width 350, radius 28, padding 18 16 16, column centered, gap 8, `background: linear-gradient(160deg, #3A3320 0%, #1F2A36 55%, #1A2D47 100%)`, `border: 1.5px solid rgba(244,197,66,.65)`, `box-shadow: 0 0 44px rgba(244,197,66,.25)`, `overflow: hidden`, `bg-land 800ms 150ms both`; inside it a `.fx` sheen: `position: absolute; top: 0; bottom: 0; left: 0; width: 60%; background: linear-gradient(100deg, transparent, rgba(244,197,66,.18), rgba(255,255,255,.26), rgba(244,197,66,.18), transparent); animation: bg-shimmer 2600ms cubic-bezier(0.45,0,0.55,1) 900ms infinite`. Drawn haptic: two pairs of ripple rings (`#F4C542`) at 300/400 ms and 700/800 ms.

Card content, phase « ask » (`display: {{ ask }}`):
1. Row of chips (centered, gap 6): « Inattendu ici » (dark) · rarity « Rare » (dark: `#F4C542`) · badge « À vérifier » (dark).
2. Icon huppe 128 (`bg-land 800ms 250ms both`).
3. « Huppe fasciée » Display 34 + « Upupa epops » Latin 17 text-2.
4. « Rare ici fin septembre » (17, 700, `#F4C542`).
5. « Présence estimée ici cette semaine : 2 sur 100. La plupart sont déjà parties vers l'Afrique. » (Body 15, text-2, centered).
6. Clip row (gap 10, width 100 %): play button dark (`onClick="{{ togglePlay }}"`) · 48 px tall review clip inset (5.13) with playhead only while playing · caption « 7 h 38 · 3 s ».
7. « Écoute-le encore avant de fêter : c'est bien lui ? » (Heading 20). Caption « Laisse le micro tourner 30 secondes de plus : il chante peut-être encore. »
8. Verdict grid dark (5.11): « Ce n'est pas lui » (`{{ no }}`) · « Je ne sais pas » (`{{ unsure }}`) · « C'est bien lui » (`{{ yes }}`).
9. Caption « Il entre dans ton carnet seulement après ta réponse. »

Phase « yes » (`display: {{ yesView }}`): same card top (chips replaced by the Sûr badge dark + « Inattendu ici »), icon huppe 128 surrounded by 12 `.fx` light points (6 px circles, alternating `#F4C542` / `#FFFFFF`, on a 172 px circle, `bg-twinkle 1600ms infinite`, delays 0, 130, … 1430 ms); « Oiseau rare confirmé ! » (Display 34); « Huppe fasciée entre dans ton carnet. C'est ta 25e espèce. » (Body 17); caption « Garde l'extrait : si tu l'envoies à la LPO, ses bénévoles pourront l'écouter. »; primary `<a href="Live.dc.html">` « Continuer l'écoute ».
Phase « later » (after « Je ne sais pas », `{{ laterView }}`): toast inside the card: « Gardé pour plus tard, dans la revue rapide. » + tonal `<a href="Revue.dc.html">` « Voir la revue ». Phase « no » (`{{ noView }}`): toast « C'est noté. Il ne comptera pas, merci. ». Toasts in the card use the 5.12 toast.

### 9.7 `Niveau.dc.html` — Moment : nouveau statut (dark, loop 7 s)

Full screen, no Live behind (it plays in the Bilan). Background `#13233A` with `radial-gradient(circle at 50% 34%, rgba(93,164,106,.28), transparent 60%)`. Logic 10.3. Stage column centered, `padding: 64px 20px 24px`, gap 12:

1. Emblem zone (220 × 220, relative): three `.fx` rings (136 px circles, `border: 2px solid #5DA46A`, `bg-ring 1800ms infinite`, delays 300 / 900 / 1500 ms); five `.fx` feathers (the `plume` glyph as a 22 px svg, stroke `#5DA46A` or `#EEF1EC` at .7, positioned at left 30/80/150/170/200 px, top −10 px, `bg-feather 2600ms both`, delays 200/450/700/950/1200 ms); emblem Sentinelle 136 px (status disc + glyph, plus `box-shadow: 0 0 0 6px rgba(238,241,236,.12)`) with `bg-land 900ms 100ms both`.
2. « Tu deviens Sentinelle des haies » Display 34, centered, 2 lines (`bg-rise 700ms`).
3. « 20 espèces découvertes. Tu reconnais maintenant les voix des haies et des jardins. » Body 17 text-2 centered (`bg-rise 780ms`).
4. Chip row (`bg-rise 850ms`): 36 px pill `s1` with icon martin-pecheur 28 + « Ta 20e : Martin-pêcheur d'Europe » (Label 15).
5. Next card (`s1`, radius 20, padding 16, width 100 %, gap 8, `bg-rise 950ms`): caption « Prochain statut » · row: emblem Oreille de chouette 40 at 40 % opacity + « Oreille de chouette, à 35 espèces » (Species 17) · progress bar dark 0/15 (no gain) · caption « Tu débloques le défi “Oiseaux des haies” et un cadre vert pour tes cartes à partager. »
6. Buttons row (gap 10, `bg-rise 1020ms`): secondary dark « Partager » (`share`) · primary `<a href="Profil.dc.html">` « Continuer ».

### 9.8 `Resume.dc.html` — Bilan de l'écoute (light)

Root light, `padding: 16px 20px`, gap 12. Tested to fit exactly; keep sizes.

1. **Top bar** (56): icon button `<a href="Main.dc.html" aria-label="Terminer">` `close` · « Bilan de l'écoute » (Heading 20) · spacer · icon button `<a href="Carte.dc.html" aria-label="Revoir sur la carte">` `map` · icon button « Partager » (`share`).
2. **Hero** (gap 4): « Belle matinée ! » (Display 34) · caption « Samedi 26 septembre · 7 h 12 – 7 h 54 · Beaulieu-sur-Brenne ».
3. **Numbers row** (grid 3, no card, gap 8): « 13 » « espèces » · « 52 » « contacts » · « 42 min » « durée » (Number L + caption).
4. **Novelties** (gap 8): Heading 20 « Une nouvelle, peut-être deux ». Then:
   - Best-moment card `<a href="Premiere.dc.html">` (radius 28, background `#F8DADC`, padding 12 16, min-height 104, gap 14): icon pic-epeiche 80 · column (gap 4, align start): « Première fois » pill, « Pic épeiche » (Title 26), « Ta 24e espèce, à 7 h 26. » (Body 15).
   - Huppe row `<a href="Rare.dc.html">` (white, radius 20, padding 8 12, min-height 56, gap 10): icon huppe 40 with the grey look · column: « Huppe fasciée » (Species 17) + row (gap 6): badge « À vérifier » light + « Inattendu ici » light · `chevron-right`.
5. **Progress card** `<a href="Profil.dc.html">` (white, radius 20, padding 14 16, gap 8): row: status chip « Sentinelle des haies » · spacer · « 24 espèces » (Label 15) + « · +1 » in `#7A5A00`; progress bar light 3/15 → 4/15 with gain; caption « Encore 11 pour devenir Oreille de chouette ».
6. **Species strip** (gap 4): row (space-between): caption « Les 13 espèces de ce matin » · outline pill (the `pill-year-light` style) « Badge : Chœur de l'aube ». Then a horizontal list (gap 10, overflow hidden, 6½ items visible) of 13 items in this order: Rougegorge ×9, Troglodyte ×7, Merle ×6, Charbonnière ×6, Mésange bleue ×5, Pinson ×4, Pie ×4, Pouillot ×3, Moineau ×3, Pic ×2, Chouette ×1, Martin ×1, Huppe ×1. Each item 48 wide: 48 px circle in the species tintLight with icon 40, and « ×9 » (Label 13, tabular) under it. Pending species (Chouette, Martin, Huppe) get an 8 px `#A04A1C` dot at the circle's top-right.
7. **Primary**: `<a href="Revue.dc.html">` primary full width « Vérifier 3 détections » (`check`).
8. **Faune-France**: secondary light full width `<button>` « Envoyer à Faune-France (LPO) » (`send`) + centered caption « Seuls les oiseaux que tu confirmes partent à la LPO. »

The volunteers' check is explained at the first export (not drawn) and on the Rare confirmation.

### 9.9 `Revue.dc.html` — Revue rapide (light, interactive)

Root light, `padding: 16px 20px`, gap 12. Logic 10.5.

1. **Top bar** (56): icon button `<a href="Main.dc.html" aria-label="Fermer">` `close` · « Revue rapide » (Heading 20) · spacer · « {{ pos }} sur 12 » (Label 15, tabular).
2. **Progress** (gap 6): 6 px bar (track `#DCE2DA`, fill `#19A7B3`, width `{{ progress }}`) · caption « Tu as trié {{ done }} détections. Badge Réviseur à 50. »
3. **Card stack** (height 452, relative; test-rendered): two back cards (white, radius 28, `float-shadow`, same size as top card) offset `translateY(16px) scale(.92)` and `translateY(8px) scale(.96)`, opacity .6 / .85. Top card wrapper (`position: absolute; inset: 0 0 16px 0; animation: {{ topAnim }}`), white, radius 28, padding 20, gap 10, `float-shadow`. Inside, four species variants (`display: {{ c.huppe }}` …), each:
   - chips row: level badge light (+ « Inattendu ici » light for Huppe);
   - row: icon 112 · column: name (Title 26), Latin 15, « Ce matin à 7 h 38 · Le jardin » (Body 15), caption detail line (8.5);
   - clip inset (height 80, radius 16, relative): the Huppe clip SVG for all four variants (mockup) + playhead `.fx` + overlay **top-left** (left 10, top 8) "chante" bars + caption « Lecture de l'extrait · 3 s » (13, `#EEF1EC`);
   - row (gap 8): play button light (aria « Réécouter : Huppe fasciée ») + tonal light « Chant de référence » (`play`);
   - caption « Au casque ou à faible volume. »
4. **Swipe hints** (24, row, space-between, caption 13 text-2 with icons 16): `back` « Ce n'est pas lui » · `chevron-up` « Je ne sais pas » · « C'est bien lui » `chevron-right`.
5. **Verdict buttons**: the light verdict grid (5.11), holes `{{ no }}`, `{{ unsure }}`, `{{ yes }}`.
6. Caption (centered): « “Je ne sais pas” est une bonne réponse : la détection reste de côté, sans compter. »

### 9.10 `Carnet.dc.html` — Mon carnet (light, nav)

Root light, `padding: 16px 20px 0`, gap 12. Logic 10.6 (filters).

1. **Title row** (56): « Mon carnet » (Title 26) · spacer · icon button `<a href="Palmares.dc.html" aria-label="Palmarès">` `podium`.
2. **Progress card** (white, radius 20, padding 14 16, gap 8): « 24 espèces sur 112 attendues dans ta région » (Body 15; numbers 800) · progress bar light 24/112 (21.4 %, color `#19A7B3`, no gain) · caption « Les silhouettes sont attendues ici cette semaine. »
3. **Filter chips** (48, scroll row): « Toutes » · « Découvertes » · « À découvrir » · « Rares ».
4. **Grid** (3 columns, gap 10). Order for « Toutes »: Pic épeiche (new pill, 2 fois) · Huppe fasciée (pending) · Martin-pêcheur d'Europe (3 fois, `half` mark) · mystery « Chante au lever du jour dans les haies. » · Rougegorge familier 142 · Troglodyte mignon 64 · Mésange charbonnière 97 · mystery « Voyage en petite bande et crie “tsi-tsi-tsi”. » · Merle noir 118 · Mésange bleue 71 · Pinson des arbres 55 · mystery « Rit très fort : on dirait qu'il se moque de toi. » · Pouillot véloce 31 · Chouette hulotte 7 (`half`) · Moineau domestique 46 · Pie bavarde 38 · Loriot d'Europe 4 (`star` Exceptionnel) · mystery « Lance un chant puissant depuis les buissons du ruisseau. » (rows 4–6 are below the fold; keep them, they show when filtering).
   Filters: Découvertes = the 13 discovered icon species; À découvrir = Huppe (pending) + 4 mysteries + mystery « Le plus petit oiseau d'Europe, chant très aigu. » + mystery « Miaule en tournant dans le ciel. »; Rares = Huppe, Martin-pêcheur, Chouette hulotte, Loriot.
5. **Nav**, Carnet active.

Discovered cards link to `Fiche.dc.html` (the mockup has one fiche). Opening a « Nouveau » card removes the pill in the app.

### 9.11 `Profil.dc.html` — Profil, statut et badges (light, nav)

Root light, `padding: 16px 20px 0`, gap 16.

1. **Status card** (white, radius 28, padding 20, gap 16, row): ring 96 (Sentinelle, 4/15) · column: « Sentinelle des haies » (Title 26), « 24 espèces découvertes » (Body 15), caption « Encore 11 pour devenir Oreille de chouette » · top-right icon button `<a href="Palmares.dc.html" aria-label="Palmarès">` `podium`.
2. **Ladder** (row of 8, space-between, over a 2 px line `#DCE2DA` at the emblems' center): emblems 36 px: 1–4 in their colors (Sentinelle with a 3 px `#13233A` outer ring and 4 px gap = current), 5–8 future look (2.6). Under each, the threshold (caption 13, tabular): 1, 5, 10, 20, 35, 50, 75, 100. Under the row, caption: « 8 statuts, du premier oiseau au centième. »
3. **Série card** (white, radius 20, padding 16, gap 10): row: « Série : 9 jours » (Heading 20) · caption « Record : 12 jours ». Row of 14 day cells (lun 14 → dim 27, gap 2, each `flex: 1`, column centered): weekday initial (caption 13: L M M J V S D) · 20 px circle · day number (caption 13, tabular). Circles: listened = `#19A7B3` fill with `check` 14 `#13233A`; rest day (22) = 2 px dashed `#19A7B3` ring, empty; missed = `#DCE2DA` fill; today (26) = listened + `box-shadow: 0 0 0 2px #FFFFFF, 0 0 0 4px #13233A`; future (27) = 1.5 px `#C5CCC2` ring. Caption: « Le cercle en pointillé, c'est ton jour de repos : un par semaine ne casse pas ta série. »
4. **Badges** (Heading 20 « Badges » + grid 4 × 2, gap 12 8; test-rendered, the défi card below ends partly under the nav, which is fine): each column centered, gap 4: 52 px tier circle (2.7) with glyph 26 · name (Label 13, 2 lines max, centered) · tier dots. Order: Chœur de l'aube (1 plume; the « Nouveau » pill replaces its tier dots, under the name), Lève-tôt (2), Noctambule (1), Réviseur (1, caption « 36 sur 50 »), Oreille fine (locked, « 4 sur 10 »), Migrateur (1), 7 jours d'affilée (1), Les mésanges (1).
5. **Défi card** (white, radius 20, padding 14 16): caption « Défi de la semaine » · « Trois matins avant 8 h » (Species 17) · three 14 px dots (2 filled) + caption « 2 sur 3 · jusqu'à dimanche ». (Partly under the nav is fine.)
6. **Nav**, Profil active.

### 9.12 `Palmares.dc.html` — Palmarès (light, no nav)

Root light, `padding: 16px 20px`, gap 12. Logic 10.7.

1. **Top bar**: back → `Profil.dc.html`, « Palmarès ».
2. **Header** (gap 2): row baseline: « {{ count }} » (Number XL) + « espèces {{ periodLabel }} » (Body 17) — e.g. « 17 espèces en 30 jours »; caption « 9 nouvelles en 2026 · {{ caption }} ».
3. **Period chips**: « 30 jours » (selected) · « Saison » · « Année » · « Tout ».
4. **Row**: switch « Confirmées seulement » (on) · spacer · caption « Classées par contacts ».
5. **Podium** (height 184, grid 3, gap 8, `align-items: end`): 2nd (left, height 150), 1st (center, 184), 3rd (right, 136). Each: species tintLight, radius 20, padding 10, column centered, gap 4: rank disc 24 (1 = `#F4C542`, 2 = `#DCE2DA`, 3 = `#EADFD1`; digit Label 13 `#13233A`) · icon 64 (1st: 80) · name (Species 15, centered) · « {{ n }} » (Number M) + caption « contacts ». Rougegorge (1), Merle noir (2), Mésange charbonnière (3).
6. **List 4–9** (gap 4): each row (min-height 56, gap 10, `order: {{ o.KEY }}`, `<a href="Fiche.dc.html">`): rank « {{ rk.KEY }} » (Label 15 Écorce, width 20) · icon 36 · column flex 1: name (Species 17) + bar (height 8, radius 999, track `#DCE2DA`, fill species `deep`, width `{{ w.KEY }}`) · count « {{ n.KEY }} » (Number M, right).

### 9.13 `Fiche.dc.html` — Fiche espèce (light, no nav)

Root light, gap 16. Logic 10.8 (section chips, play buttons).

1. **Header** (height 184, full bleed, background `#FCE7DC` + `radial-gradient(circle at 78% 60%, rgba(236,122,60,.22), transparent 55%)`, radius 0 0 28 28, relative): top row (padding 16 20 0): icon button light `<a href="Carnet.dc.html" aria-label="Retour">` `back` · spacer · icon button « Ajouter aux favoris » (`star`) · icon button « Partager » (`share`). Icon rougegorge 150 absolute `right: 12px; bottom: 4px` with `bg-land 700ms both`. Bottom-left (left 20, bottom 16, width 210): « Rougegorge familier » (Display 34, 2 lines) + « Erithacus rubecula » (Latin 17 Écorce).
2. **Body** (`padding: 0 20px`, gap 16):
   a. « Entendu **142 fois** sur **38 jours**, la dernière fois ce matin à 7 h 52. » (Body 17) + row: badge Sûr light + caption « 37 bonnes sur 38 vérifiées ».
   b. **Ici en ce moment** (white, radius 20, padding 12 16, row gap 12): column: « Ici en ce moment » (Label 15), « Présent toute l'année. Il chante aussi en automne. » (Body 15) · 12 bars (width 6, gap 3, max height 36, radius 3, `#DCE2DA`, September `#19A7B3`) with caption « janv. – déc. » under.
   c. **Mes sons**: section head « Mes sons » (short on purpose: « Mes enregistrements » wraps next to the button) + tonal light « Chant de référence » (`play`) on the right. Two rows (min-height 56, gap 10): play button light · column « 0,97 · ce matin, 7 h 41 » (Body 15, tabular) + caption « Le jardin » · star icon button (favori: `star` filled `#F4C542` via `fill="currentColor"` color `#F4C542`; second row outline Écorce).
   d. **Sheet chips** (scroll row, 48): « Sa taille » · « Ce qu'il fait » · « Pourquoi il est là » · « Migration » · « Le savais-tu ? » · « Pour le reconnaître ». Under: the selected paragraph (Body 15, 4 lines max) + caption « Texte rédigé par IA à partir de Wikipédia, vérifié et relu. »
      - Sa taille : « 14 cm, à peu près comme un moineau. Il pèse 16 à 22 g, le poids de quatre morceaux de sucre. »
      - Ce qu'il fait : « Il cherche les insectes et les vers au sol, par petits bonds. Il suit parfois le jardinier pour attraper ce que la bêche fait sortir. »
      - Pourquoi il est là : « Il aime les jardins, les haies et les bois avec des buissons. En automne, chacun défend un petit territoire en chantant, même les femelles. »
      - Migration : « La plupart restent toute l'année. En automne, des rougegorges du nord de l'Europe arrivent aussi pour passer l'hiver en France. »
      - Le savais-tu ? : « Il chante parfois la nuit, près des lampadaires. Son chant d'automne est plus doux et un peu mélancolique. »
      - Pour le reconnaître : « Un filet de notes aiguës qui coulent comme de l'eau, avec des pauses. Son cri : un “tic” sec, répété. »
   e. **Two columns** (gap 12, height 104; the whole Fiche was test-rendered and fits 844 with these sizes): left white card (radius 20, padding 12): caption « Activité par heure » + 24 bars (width 4, gap 1.5, max height 52, radius 2, `#DB733C`, heights 8.7) + captions « 0 h » « 12 h » « 23 h ». Right: mini map (radius 16, 1 px `#DCE2DA`, overflow hidden) = a 150 × 80 crop drawn like the Carte palette with 3 teal dots, and `<a href="Carte.dc.html">` « Voir sur la carte » (Label 13 `#0B6E77`) under.
   f. Caption (may fall below the fold): « Texte rédigé par IA à partir de l'article Wikipédia « Rougegorge familier », vérifié et relu. CC BY-SA 4.0. Garde le son pour toi : un chant diffusé fort dérange les oiseaux, surtout au printemps. »

### 9.14 `Carte.dc.html` — Carte des contacts (light, nav)

Root light, `padding: 0`. Everything layered on a full-bleed map SVG (390 × 844, `position: absolute; inset: 0`). Logic 10.9.

**Map drawing** (inline SVG, no tiles; palette only):
- land `#E9EDDF`; fields `#DCE5C4`, `#E6E1C8`, `#D4E0BC` (soft polygons, 1 px `#CFD8BC` edges);
- small wood top-right (≈ x 230–390, y 90–250): base `#B7CC98`, tree blobs `#A3BE82` (circles r 10–18);
- hedge: a thick line from (20, 250) to (370, 330), `stroke #9DB46A; stroke-width 12; stroke-linecap round` with darker blobs `#86A058`;
- stream: a smooth curve from (0, 440) through (130, 420) and (260, 470) to (390, 450): `stroke #9ED3DA` width 16, inner `#C4E7EB` width 6; label « Le ruisseau » (Latin 13, `#0B6E77`) near (40, 470);
- path: dashed `#CDBFAA` 3 px (`stroke-dasharray 6 5`) from (170, 360) to (300, 250);
- road: `#FFFFFF` 10 px over `#D5CEC0` 12 px, from (0, 380) to (390, 395);
- village houses near (60–150, 320–370): rects `#E2D8C8` with `#CDBFAA` 1 px, roofs `#C9B59C`;
- garden: rounded rect `#E4EED3` around (110–220, 330–400) with a dashed white fence;
- place labels (caption 13, `#6B5847`): « Le petit bois », « La haie du chemin », « Le jardin ».

**Overlays**:
1. Chips row (top 16, left 16, gap 8): white chip « Toutes les espèces » + `chevron-down` · selected « 30 jours » · selected « Confirmées ».
2. Right column: icon button « Fond de carte » (`layers`) at top 80, right 16.
3. Markers (buttons, 52 px hit area): white disc 44 with `box-shadow: 0 0 0 3px #19A7B3, 0 4px 12px rgba(19,35,58,.18)`, species icon 34 inside, count badge (min-width 22, height 22, radius 999, `#13233A`, text `#EEF1EC` Label 13 tabular) at top-right. Selected marker: ring `0 0 0 3px #F4C542` via `{{ ring.KEY }}`. Positions (center): Troglodyte (250, 300) « 21 », Pie (330, 318) « 9 », Pouillot (80, 262) « 7 », Martin-pêcheur (96, 432) « 2 », Chouette hulotte (330, 160) « 4 », Pic épeiche (262, 196) « 2 ». Cluster « Le jardin » at (160, 356): 56 px disc `#19A7B3`, 3 px white border, « 8 » (Number M `#13233A`) with caption-size « espèces » under inside.
4. User position (182, 380): 14 px `#19A7B3` dot with 3 px white border + `.fx` halo (`bg-ripple 1600ms infinite`).
5. Locate button: icon button « Me localiser » (`locate`) at right 16, bottom 360.
6. **Bottom sheet** (5.9, bottom 80): content switches with the selected spot (`display: {{ s.jardin }}` …; 8.6): title + subtitle, three rows (min-height 56, gap 10): icon 40 on tintLight circle 44 · name (Species 17) + caption « 44 contacts » · play button light (`onClick` toggles like Live, optional). Last line: `lock` 16 + caption « Tes positions précises restent sur ton téléphone. »
7. **Nav**, Carte active.

---

## 10. Logic recipes (classic JS inside `class Component extends DCLogic`)

Rules: read state with `const s = this.state || {};` (it can be null before the first `setState`); keep constants in a `data()` method, not at top level; every timer is cleared in `componentWillUnmount`; holes are dotted lookups only, so JS keys are camelCase (`charbonniere`, `bleue`, `pic`, `martin`, `chouette`).

### 10.1 Live (tested; copy as is)

```js
class Component extends DCLogic {
  data() {
    return {
      order: ['rougegorge', 'chouette', 'troglodyte', 'merle', 'charbonniere', 'bleue', 'pinson', 'pouillot', 'pie', 'moineau'],
      start: { rougegorge: 3, chouette: 1, troglodyte: 2, merle: 2, charbonniere: 1 },
      pre: { rougegorge: 133, chouette: 6, troglodyte: 57, merle: 112, charbonniere: 91, bleue: 66, pinson: 51, pouillot: 28, pie: 34, moineau: 43 },
      script: ['bleue', 'rougegorge', 'pinson', 'troglodyte', 'pouillot', 'charbonniere', 'pie', 'rougegorge', 'pouillot', 'merle', 'moineau', 'bleue']
    };
  }
  componentDidMount() {
    this.reset();
    this._clock = setInterval(() => {
      const s = this.state || {};
      if (!s.paused) this.setState({ sec: (s.sec || 760) + 1 });
    }, 1000);
    this._feed = setInterval(() => this.next(), 2500);
  }
  componentWillUnmount() {
    clearInterval(this._clock); clearInterval(this._feed); clearTimeout(this._playT);
  }
  reset() {
    this.setState({ sec: 760, step: 0, counts: Object.assign({}, this.data().start), last: null, flip: false, spFlip: false });
  }
  next() {
    const s = this.state || {};
    const D = this.data();
    if (s.paused) return;
    const step = s.step || 0;
    if (step >= D.script.length) { this.reset(); return; }
    const k = D.script[step];
    const counts = Object.assign({}, s.counts || D.start);
    const isNew = !counts[k];
    counts[k] = (counts[k] || 0) + 1;
    this.setState({ step: step + 1, counts: counts, last: k, flip: !s.flip, spFlip: isNew ? !s.spFlip : s.spFlip });
  }
  togglePlay(k) {
    const s = this.state || {};
    clearTimeout(this._playT);
    if (s.playing === k) { this.setState({ playing: null }); return; }
    this.setState({ playing: k });
    this._playT = setTimeout(() => this.setState({ playing: null }), 3000);
  }
  renderVals() {
    const s = this.state || {};
    const D = this.data();
    const counts = s.counts || D.start;
    const bump = (on) => (on ? 'bg-bump-a' : 'bg-bump-b') + ' 200ms cubic-bezier(0.23,1,0.32,1)';
    const r = {};
    let species = 0, contacts = 0;
    D.order.forEach((k, i) => {
      const n = counts[k] || 0;
      if (n > 0) { species += 1; contacts += n; }
      const level = k === 'chouette' ? 'prob' : (k === 'pouillot' && n < 2 ? 'prob' : 'sur');
      const isLast = s.last === k;
      r[k] = {
        display: n > 0 ? 'block' : 'none',
        order: String(100 - i),
        n: n,
        total: D.pre[k] + n,
        bump: isLast ? bump(s.flip) : 'none',
        glow: isLast && n > 1 ? (s.flip ? 'bg-glow-a' : 'bg-glow-b') + ' 900ms cubic-bezier(0.23,1,0.32,1)' : 'none',
        ripple: isLast && n === 1 ? 'bg-ripple 600ms cubic-bezier(0.23,1,0.32,1) 120ms both' : 'none',
        sing: isLast ? 'inline-flex' : 'none',
        sur: level === 'sur' ? 'inline-flex' : 'none',
        prob: level === 'prob' ? 'inline-flex' : 'none',
        playIcon: s.playing === k ? 'none' : 'block',
        pauseIcon: s.playing === k ? 'block' : 'none',
        playBg: s.playing === k ? '#19A7B3' : 'transparent',
        play: () => this.togglePlay(k)
      };
    });
    const sec = s.sec || 760;
    const mm = Math.floor(sec / 60), ss = sec % 60;
    return {
      r: r,
      timer: (mm < 10 ? '0' : '') + mm + ':' + (ss < 10 ? '0' : '') + ss,
      species: species,
      contacts: contacts,
      speciesBump: bump(s.spFlip),
      contactsBump: s.last ? bump(s.flip) : 'none',
      flash: s.last ? (s.flip ? 'bg-glow-a' : 'bg-glow-b') + ' 900ms cubic-bezier(0.23,1,0.32,1)' : 'none',
      bandNormal: s.small ? 'none' : 'block',
      bandSmall: s.small ? 'flex' : 'none',
      sizeLabel: s.small ? 'Afficher le spectre' : 'Réduire le spectre',
      iconUp: s.small ? 'none' : 'block',
      iconDown: s.small ? 'block' : 'none',
      toggleSize: () => this.setState({ small: !s.small }),
      playState: s.paused ? 'paused' : 'running',
      pauseLabel: s.paused ? 'none' : 'inline',
      resumeLabel: s.paused ? 'inline' : 'none',
      pauseIcon: s.paused ? 'none' : 'block',
      resumeIcon: s.paused ? 'block' : 'none',
      liveText: s.paused ? 'En pause' : 'En écoute',
      togglePause: () => this.setState({ paused: !s.paused }),
      toast: s.playing ? 'flex' : 'none'
    };
  }
}

```

### 10.2 Hole checklist for Live

`timer, species, contacts, speciesBump, contactsBump, flash, bandNormal, bandSmall, sizeLabel, iconUp, iconDown, toggleSize, playState, pauseLabel, resumeLabel, pauseIcon, resumeIcon, liveText, togglePause, toast`, and per species `r.KEY.display, order, n, total, bump, glow, ripple, sing, sur, prob, playIcon, pauseIcon, playBg, play`.

### 10.3 Moment loops (Arrivee 4 s, Premiere 7 s, Niveau 7 s)

```js
class Component extends DCLogic {
  componentDidMount() {
    this._loop = setInterval(() => {
      this.setState({ run: false });
      this._t = setTimeout(() => this.setState({ run: true }), 80);
    }, 7000); // Arrivee: see below
  }
  componentWillUnmount() { clearInterval(this._loop); clearTimeout(this._t); clearTimeout(this._p); }
  togglePlay() {
    const s = this.state || {};
    clearTimeout(this._p);
    this.setState({ playing: !s.playing });
    if (!s.playing) this._p = setTimeout(() => this.setState({ playing: false }), 3000);
  }
  renderVals() {
    const s = this.state || {};
    return {
      stage: s.run === false ? 'none' : 'flex',
      togglePlay: () => this.togglePlay(),
      playIcon: s.playing ? 'none' : 'block',
      pauseIcon: s.playing ? 'block' : 'none'
    };
  }
}
```

Arrivee variant: every 4 s set `{ arrived: false }`, then after 700 ms `{ arrived: true, flip: !flip }`. Holes: `pinson` (`'block'`/`'none'`), `timer` (« 12:46 » / « 12:47 »), `species` (6 / 7), `contacts` (11 / 12), `bump` (`(flip ? 'bg-bump-a' : 'bg-bump-b') + ' 200ms cubic-bezier(0.23,1,0.32,1)'` when arrived, else `'none'`). Before mount treat `arrived` as true so the thumbnail shows the arrived state.

### 10.4 Rare

State `phase` ∈ `ask | yes | later | no` (default `ask`) and `run`. The 8 s loop restarts the stage only while `phase === 'ask'`. `answer(p)`: set `phase: p`, then after 7 s (`yes`) or 4 s (`later`, `no`) set `phase: 'ask', run: true`. Holes: `stage, ask, yesView, laterView, noView, yes, unsure, no` (`yes` → `answer('yes')`, `unsure` → `answer('later')`, `no` → `answer('no')`), `togglePlay, playIcon, pauseIcon, playhead` (`'block'` only while playing).

### 10.5 Revue

```js
answer(dir) {
  const s = this.state || {};
  if (s.leaving) return;
  this.setState({ leaving: dir });
  clearTimeout(this._t);
  this._t = setTimeout(() => {
    const t = this.state || {};
    this.setState({ i: ((t.i || 0) + 1) % 4, leaving: null, done: (t.done || 38) + 1 });
  }, 260);
}
// renderVals:
//   i = s.i || 0 ; keys = ['huppe', 'pouillot', 'bleue', 'merle']
//   c[key] = index === i ? 'flex' : 'none'
//   topAnim = leaving ? ({ right: 'bg-fly-right', left: 'bg-fly-left', up: 'bg-fly-up' }[leaving] + ' 260ms cubic-bezier(0.23,1,0.32,1) forwards')
//                     : 'bg-pop 250ms cubic-bezier(0.23,1,0.32,1) both, bg-nudge 5200ms cubic-bezier(0.45,0,0.55,1) 1600ms infinite'
//   pos = 3 + i ; progress = ((3 + i) / 12 * 100).toFixed(1) + '%' ; done = s.done || 38
//   yes = () => this.answer('right') ; no = () => this.answer('left') ; unsure = () => this.answer('up')
```

### 10.6 Carnet filters

State `f` ∈ `toutes | decouvertes | adecouvrir | rares` (default `toutes`). Each card wrapper gets `display: {{ card.KEY }}` computed from its filter list (9.10). Each chip gets `background: {{ chip.KEY.bg }}; color: {{ chip.KEY.fg }}; border-color: {{ chip.KEY.bd }}` (selected `#13233A / #EEF1EC / #13233A`, else `#FFFFFF / #13233A / #C5CCC2`), `aria-pressed="{{ chip.KEY.pressed }}"`, check icon `display: {{ chip.KEY.check }}`, `onClick="{{ chip.KEY.pick }}"`.

### 10.7 Palmarès

State `p` ∈ `j30 | saison | annee | tout` (default `j30`), `conf` (default true). Data = 8.4. Holes: `count` (species of the period, `conf` picks the first or second value), `periodLabel` (« en 30 jours », « cette saison », « en 2026 », « depuis le début »), `caption`, podium numbers `pod.rougegorge / pod.merle / pod.charbonniere`, list `n.KEY`, `rk.KEY`, `o.KEY` (flex order = rank), `w.KEY` (`Math.round(n / leader * 100) + '%'`), chip styles as 10.6, switch `aria-checked` + knob `left` (`'21px'` / `'3px'`) + track color.

### 10.8 Fiche

State `sec` (default `taille`) → six paragraphs with `display: {{ t.KEY }}`; chip styles as 10.6; two play buttons with the Live toggle pattern (`playing` key, 3 s).

### 10.9 Carte

State `spot` ∈ `jardin | haie | ruisseau | bois` (default `jardin`). Markers call `pick.SPOT` (Troglodyte, Pie, Pouillot → `haie`; Martin → `ruisseau`; Chouette, Pic → `bois`; cluster → `jardin`). Holes: `s.SPOT` (sheet variants), `ring.MARKER` (`'0 0 0 3px #F4C542, 0 4px 12px rgba(19,35,58,.18)'` when its spot is selected, else the teal ring).

---

## 11. Review checklist (before handing an artboard back)

- [ ] Helmet verbatim; root 390 × 844; `$preview` matches; `lang="fr"`; short `<title>` (« Accueil », « Écoute en direct », « Spectre agrandi », « Un oiseau arrive », « Première fois », « Oiseau rare », « Nouveau statut », « Bilan de l'écoute », « Revue rapide », « Mon carnet », « Profil », « Palmarès », « Carte des contacts », « Fiche espèce »).
- [ ] Only tokens of section 2; dark or light as listed in 1.5.
- [ ] Every number traces to section 8; the same species has the same counts on every board.
- [ ] Fixed action names spelled exactly; no uppercase label, no emoji, no overline.
- [ ] All clickable elements are `<a>`/`<button>` ≥ 48 px; icon-only ones have `aria-label`.
- [ ] Links: nav (Main, Carnet, Carte, Profil), Écouter → Live, Arrêter → Resume, Agrandir → LiveSpectre, Réduire → Live, rows/cards → Fiche, to-verify → Revue, podium icon → Palmares, Revoir sur la carte → Carte, Continuer l'écoute → Live.
- [ ] Repeated drawings have suffixed ids; no first copy hidden with a shared id.
- [ ] Nothing informative inside `.fx`; animations only on transform/opacity; timers cleared on unmount.
- [ ] No sound, no confetti, no modal over « Arrêter », no public ranking, nothing counted before verification.
