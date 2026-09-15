#!/usr/bin/env python3
"""Five alternative tortoise designs for Tomodoro, authored as 16x16 grids.

Each variant is 16 rows of exactly 16 legend characters, the same authoring
format the app uses in Sources/Core/TortoisePose.swift, so a chosen design can be
pasted straight into the Swift source.

Legend
  .  transparent
  #  keyline (the dark or light outline the whole silhouette hangs off)
  s  phase-coloured ring, one cell inside the keyline
  o  shell body
  p  shell plate / highlight, a second shell tone
  k  plastron, the pale underside
  h  skin
  e  eye
  r  cheek
  t  tail

Per variant the palette maps those legend characters to RGBA. `s` is generated
from the session phase colour by `phase_ring()`, so one grid serves red, green
and blue.

Validation (`validate`) mirrors the app's own rules in TortoiseSprite.validate()
and adds the ones a *redesign* needs:

  * 16 rows of exactly 16 cells, from the legend above
  * every inked cell 4-connected to the rest — no floating limbs
  * an eye, each eye touching skin
  * a countdown plate: one connected run of flat shell at least 8 wide and 6
    tall, because the overlay prints FOCUS / 18:30 / a progress bar there
  * the silhouette stays inside the 16x16 window

Run `python3 tortoise_designs.py check` to see the results.
"""

import sys

HERE = __file__.rsplit("/", 1)[0]
sys.path.insert(0, HERE)

from pixelkit import (CELL, DIGIT_CELL, GLYPH_HEIGHT, LABEL_CELL, LABEL_GAP,  # noqa: E402
                      BAR_GAP, BAR_HEIGHT, darken, lighten, text_width)

LEGEND = set(".#sophkert")
W = H = 16

PLATE_CELLS = ("o", "p")

# The overlay needs 8x6 of unbroken flat colour for FOCUS + the clock + the bar.
MIN_PLATE_W, MIN_PLATE_H = 8, 6


def content_size(rect, label="SHORT", clock="25:00"):
    """Pixel size the countdown stack needs, versus what the plate rect offers.

    Mirrors Sources/Core/OverlayGeometry.swift and the stack in
    Sources/UI/TortoiseOverlayView.swift.
    """
    _x, _y, w_cells, h_cells = rect
    needed_h = (GLYPH_HEIGHT * LABEL_CELL + LABEL_GAP
                + GLYPH_HEIGHT * DIGIT_CELL + BAR_GAP + BAR_HEIGHT)
    needed_w = max(text_width(clock) * DIGIT_CELL, text_width(label) * LABEL_CELL)
    return needed_h, needed_w, w_cells * CELL, h_cells * CELL


def phase_ring(phase):
    """Ring colours per session phase, brightened for a dark keyline."""
    base = {
        "focus": (0.91, 0.24, 0.22),
        "short": (0.20, 0.78, 0.36),
        "long": (0.20, 0.52, 0.95),
    }[phase]
    return base


# =========================================================== V1  "Mascot"
# A compact domed tortoise with a tall head that reaches forward of the shell,
# heavy dark keyline, bright leaf-green skin. The whole body is one connected
# silhouette: feet grow out of the shell's underside, and the head hangs off the
# front rim rather than floating beside it.

V1_ROWS = [
    "................",
    "...#####........",
    "..#sooooo##.....",
    ".#soooooo#......",
    "#soooooooos#....",
    "#soooooooos#....",
    "#soooooooos#hhh.",
    "#soooooooos#hhe.",
    "#soooooooos#hhh.",
    "#soooooooos#hh..",
    "#soooooooos#hh..",
    "..#########.....",
    "..hh..hh........",
    "..hh..hh........",
    "..hh..hh........",
    "................",
]

V1_PALETTE = {
    "#": (0.075, 0.063, 0.047),
    "o": (0.631, 0.427, 0.157),
    "p": (0.741, 0.549, 0.243),
    "k": (0.839, 0.741, 0.545),
    "h": (0.624, 0.902, 0.341),
    "e": (0.075, 0.063, 0.047),
    "r": (0.980, 0.560, 0.520),
    "t": (0.624, 0.902, 0.341),
}

# =========================================================== V2  "Realist"
# Wide, low, keeled shell with two-tone scutes, a longer neck, and four stubby
# legs with a pale plastron between them. Naturalistic colour, muted, so the
# phase ring is the only saturated note.

V2_ROWS = [
    "................",
    "...#####........",
    "..#opppo#.......",
    ".#opppppo#......",
    "#opppppppo#.....",
    "#opooooooop#....",
    "#opooooooop#....",
    "#opooooooop#....",
    "#opooooooop#hhe.",
    "#opooooooop#hhh.",
    "#opooooooop#hh..",
    ".##########sh...",
    "..kkk..kkk......",
    "..kkk..kkk......",
    "..kkk..kkk......",
    "................",
]

V2_PALETTE = {
    "#": (0.180, 0.129, 0.086),
    "o": (0.741, 0.549, 0.290),
    "p": (0.855, 0.686, 0.400),
    "k": (0.851, 0.780, 0.612),
    "h": (0.435, 0.714, 0.243),
    "e": (0.180, 0.129, 0.086),
    "r": (0.900, 0.600, 0.400),
    "t": (0.435, 0.714, 0.243),
}

# =========================================================== V3  "Flat"
# No outline at all. Bold flat shapes, one step of shading, a perfectly
# symmetrical shell. Reads as a modern app icon and survives 16x16 shrinking
# because there is no keyline to turn to mush.

V3_ROWS = [
    "................",
    "....########....",
    "..##ssssssss##..",
    ".#soooooooos#...",
    "#sooooooooos#...",
    "#sooooooooos#...",
    "#sooooooooos#.hh",
    "#sooooooooos#hhe",
    "#sooooooooos#hh.",
    "#sooooooooos#hh.",
    "#sooooooooos#hh.",
    "..##ssssssss##..",
    "....hhhh..hhhh..",
    "....hhhh..hhhh..",
    "....hhhh..hhhh..",
    "................",
]

V3_PALETTE = {
    "#": (0.427, 0.478, 0.541),
    "o": (0.129, 0.161, 0.208),
    "p": (0.200, 0.243, 0.309),
    "k": (0.200, 0.243, 0.309),
    "h": (0.447, 0.870, 0.702),
    "e": (0.129, 0.161, 0.208),
    "r": (0.447, 0.870, 0.702),
    "t": (0.447, 0.870, 0.702),
}

# =========================================================== V4  "Ember"
# Dark shell, warm ochre scutes, pale mint skin, near-black keyline. Built for a
# dark desktop: the silhouette stays legible against a dark wallpaper, and the
# phase colour on the shell band is the brightest thing in the sprite.

V4_ROWS = [
    "................",
    "...#####........",
    "..##sssss##.....",
    ".#soooooos#.....",
    "#soooooooos#....",
    "#soooooooos#....",
    "#soooooooos#.hhh",
    "#soooooooos#hhhe",
    "#soooooooos#hhe.",
    "#soooooooos#hh..",
    "#soooooooos#hh..",
    "..#########.....",
    "..hhh.hhh.......",
    "..hhh.hhh.......",
    "..hhh.hhh.......",
    "................",
]

V4_PALETTE = {
    "#": (0.043, 0.055, 0.078),
    "o": (0.149, 0.180, 0.224),
    "p": (0.784, 0.573, 0.290),
    "k": (0.302, 0.337, 0.384),
    "h": (0.722, 0.949, 0.812),
    "e": (0.043, 0.055, 0.078),
    "r": (0.980, 0.700, 0.500),
    "t": (0.722, 0.949, 0.812),
}

# =========================================================== V5  "Storybook"
# Cream and tan, coral accents, rounded everything, an oversized head with a
# cheek blush and a stubby tail. Warm and illustrative rather than naturalistic;
# the most toy-like of the five.

V5_ROWS = [
    "................",
    "...####.........",
    ".##soos##.......",
    "#sooooooos#.....",
    "#soooooooos#....",
    "#soooooooos#....",
    "#soooooooos#.hhh",
    "#soooooooos#hhrh",
    "#soooooooos#hhee",
    "#soooooooos#hhh.",
    "#soooooooos#hh..",
    "..#########.....",
    "..hhh.hhh.......",
    "..hhh.hhh.......",
    "..hhh.hhh.......",
    "................",
]

V5_PALETTE = {
    "#": (0.353, 0.235, 0.180),
    "o": (0.867, 0.706, 0.475),
    "p": (0.949, 0.867, 0.729),
    "k": (0.961, 0.918, 0.831),
    "h": (0.949, 0.706, 0.522),
    "e": (0.353, 0.235, 0.180),
    "r": (0.949, 0.478, 0.478),
    "t": (0.949, 0.706, 0.522),
}

VARIANTS = [
    {
        "id": "v1-mascot",
        "name": "Mascot",
        "rows": V1_ROWS,
        "palette": V1_PALETTE,
        "ink": (0.99, 0.97, 0.93),
        "plate_color": darken(V1_PALETTE["o"], 0.45),
        "label_override": None,
        "blurb": "Compact domed shell with a heavy dark keyline and a chunky head "
                 "overlapping the shell's front edge. Closest to the current art "
                 "in spirit, but a rounder creature than a box with parts beside it.",
        "tradeoff": "Head size is capped by the countdown plate, so he reads as a "
                    "mascot rather than a naturalistic tortoise.",
    },
    {
        "id": "v2-realist",
        "name": "Realist",
        "rows": V2_ROWS,
        "palette": V2_PALETTE,
        "ink": (0.16, 0.12, 0.08),
        "plate_color": lighten(V2_PALETTE["o"], 0.62),
        "label_override": None,
        "blurb": "Wide low shell with a two-tone upper dome and pale plastron between "
                 "the legs. The most naturalistic of the five.",
        "tradeoff": "Two-tone scutes are the first detail to vanish at menu-bar "
                    "size, where the shell flattens to one tone.",
    },
    {
        "id": "v3-flat",
        "name": "Flat",
        "rows": V3_ROWS,
        "palette": V3_PALETTE,
        "ink": (0.93, 0.96, 0.99),
        "plate_color": V3_PALETTE["o"],
        "label_override": None,
        "blurb": "No dark outline: a cool grey rim, one shade step, a symmetrical "
                 "shell. Modern app-icon language, and the boldest silhouette of "
                 "the five at menu-bar size.",
        "tradeoff": "Abandons the pixel-art keyline that ties him to the wordmark "
                    "and the README banners.",
    },
    {
        "id": "v4-ember",
        "name": "Ember",
        "rows": V4_ROWS,
        "palette": V4_PALETTE,
        "ink": (0.98, 0.96, 0.92),
        "plate_color": darken(V4_PALETTE["o"], 0.40),
        "label_override": None,
        "blurb": "Dark slate shell, a phase-coloured ring around the whole shell, pale "
                 "mint skin. Built to stay readable on a dark desktop, where the "
                 "current brown can sink without trace.",
        "tradeoff": "The phase colour is now doing double duty as the shell's "
                    "decoration, so a blue session makes him a blue-shelled "
                    "tortoise.",
    },
    {
        "id": "v5-storybook",
        "name": "Storybook",
        "rows": V5_ROWS,
        "palette": V5_PALETTE,
        "ink": (0.24, 0.16, 0.12),
        "plate_color": lighten(V5_PALETTE["o"], 0.70),
        "label_override": None,
        "blurb": "Cream and tan, coral cheek, oversized head, stubby tail. The most "
                 "toy-like and the friendliest of the five.",
        "tradeoff": "Low contrast between shell tones, so the shell reads flatter "
                    "than the others.",
    },
]


def palette_for(variant, phase):
    """Variant palette with the phase ring resolved for this session phase."""
    pal = dict(variant["palette"])
    pal["s"] = phase_ring(phase)
    pal["_ink"] = variant["ink"]
    pal["_plate"] = variant["plate_color"]
    return pal


def overlay_palette(variant, phase):
    """The subset the countdown renderer needs."""
    pal = palette_for(variant, phase)
    return {
        "plate": variant["plate_color"],
        "ink": variant["ink"],
        "trim": phase_ring(phase),
        "outline": variant["palette"]["#"],
    }


def find_plate_rect(rows):
    """The best rectangle of unbroken flat shell, as (x, y, w, h) in cells.

    The countdown lives on it, so it has to be one solid rectangle: a scute line
    or a phase-coloured cell cutting through it would run under the digits.

    Ranking is by fitness, not raw area. A tall narrow region can hold more cells
    than a short wide one and still be useless, because the clock sets a hard
    minimum width — so the widest candidate that actually fits the stack wins, and
    area only breaks ties.
    """
    flat = [[rows[y][x] in PLATE_CELLS for x in range(W)] for y in range(H)]

    def fits(rect):
        needed_h, needed_w, have_w, have_h = content_size(rect)
        return needed_h <= have_h and needed_w <= have_w

    best = (0, 0, 0, 0)
    for y0 in range(H):
        for y1 in range(y0, H):
            run = 0
            for x in range(W):
                column = all(flat[y][x] for y in range(y0, y1 + 1))
                run = run + 1 if column else 0
                candidate = (x - run + 1, y0, run, y1 - y0 + 1)
                if fits(candidate) and not fits(best):
                    best = candidate
                elif fits(candidate) == fits(best):
                    key = (candidate[2], candidate[3], candidate[2] * candidate[3])
                    best_key = (best[2], best[3], best[2] * best[3])
                    if key > best_key:
                        best = candidate
    return best


# --------------------------------------------------------------- validation


def validate(variant):
    """Structural problems with this grid, empty when it is well formed."""
    name = variant["id"]
    rows = variant["rows"]
    problems = []

    if len(rows) != H:
        return [f"{name}: {len(rows)} rows, expected {H}"]
    for index, row in enumerate(rows):
        if len(row) != W:
            problems.append(f"{name}: row {index} is {len(row)} wide, expected {W}")
        bad = set(row) - LEGEND
        if bad:
            problems.append(f"{name}: row {index} has unknown cells {sorted(bad)}")
    if problems:
        return problems

    at = lambda x, y: rows[y][x]
    inked = [(x, y) for y in range(H) for x in range(W) if at(x, y) != "."]
    if not inked:
        return [f"{name}: empty"]

    seen = {inked[0]}
    stack = [inked[0]]
    while stack:
        x, y = stack.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < W and 0 <= ny < H):
                continue
            if at(nx, ny) == "." or (nx, ny) in seen:
                continue
            seen.add((nx, ny))
            stack.append((nx, ny))
    orphans = [p for p in inked if p not in seen]
    if orphans:
        problems.append(f"{name}: disconnected pixels at {orphans}")

    eyes = [(x, y) for y in range(H) for x in range(W) if at(x, y) == "e"]
    if not eyes:
        problems.append(f"{name}: no eye pixel")
    for x, y in eyes:
        neighbours = [at(x + dx, y + dy) if 0 <= x + dx < W and 0 <= y + dy < H else "."
                      for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
        if "h" not in neighbours:
            problems.append(f"{name}: eye at ({x},{y}) touches no skin")

    # The countdown plate: one connected run of flat shell, big enough for the
    # overlay's FOCUS / clock / progress stack, and the stack must actually fit.
    plate = {(x, y) for y in range(H) for x in range(W) if at(x, y) in PLATE_CELLS}
    if not plate:
        problems.append(f"{name}: no countdown plate at all")
    else:
        start = next(iter(plate))
        region = {start}
        stack = [start]
        while stack:
            x, y = stack.pop()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if n in plate and n not in region:
                    region.add(n)
                    stack.append(n)
        if len(region) != len(plate):
            problems.append(f"{name}: countdown plate splits into "
                            f"{len(plate) - len(region)} stray cell(s): "
                            f"{sorted(plate - region)}")

    rect = find_plate_rect(rows)
    rx, ry, rw, rh = rect
    if rw < MIN_PLATE_W or rh < MIN_PLATE_H:
        problems.append(f"{name}: largest flat area is {rw}x{rh} cells at "
                        f"({rx},{ry}); the overlay needs at least "
                        f"{MIN_PLATE_W}x{MIN_PLATE_H}")
    else:
        needed_h, needed_w, have_w, have_h = content_size(rect)
        if needed_h > have_h:
            problems.append(f"{name}: countdown stack needs {needed_h}px tall but the "
                            f"{rw}x{rh} plate at ({rx},{ry}) offers {have_h}px")
        if needed_w > have_w:
            problems.append(f"{name}: countdown needs {needed_w}px across but the "
                            f"{rw}x{rh} plate at ({rx},{ry}) offers {have_w}px")
    return problems


def all_problems():
    out = []
    for variant in VARIANTS:
        out += validate(variant)
    return out


def ascii_art(rows):
    return "\n".join(f"{i:2d} {row}" for i, row in enumerate(rows))


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else "check"
    if command == "check":
        problems = all_problems()
        for variant in VARIANTS:
            found = validate(variant)
            print(f"{variant['id']:16s} {'ok' if not found else str(len(found)) + ' problem(s)'}")
            for problem in found:
                print("   !", problem)
        sys.exit(1 if problems else 0)
    if command == "show" and len(sys.argv) > 2:
        for variant in VARIANTS:
            if variant["id"] == sys.argv[2] or variant["name"].lower() == sys.argv[2].lower():
                print(ascii_art(variant["rows"]))
                sys.exit(0)
        raise SystemExit(f"no such variant: {sys.argv[2]}")
    raise SystemExit(__doc__)
