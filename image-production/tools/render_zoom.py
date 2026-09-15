#!/usr/bin/env python3
"""Render one candidate large enough to judge, with its countdown.

The contact sheet is for comparison; this is for looking. At 24px per sprite cell
the head, the feet and the shell edge are all legible, which is where the design
decisions actually live.

    python3 render_zoom.py v1-mascot            # bare + countdown, focus phase
    python3 render_zoom.py v1-mascot --cell 32
    python3 render_zoom.py --all
"""

import os
import sys

HERE = __file__.rsplit("/", 1)[0]
sys.path.insert(0, HERE)

import pixelkit as P          # noqa: E402
import variants as V          # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "tortoise-designs"))
PREVIEWS = os.path.join(ROOT, "previews")

PAD = 24
GAP = 24


def zoom(variant, phase, cell=24):
    pal = V.palette_for(variant, phase)
    over = V.overlay_palette(variant, phase)
    area = V.find_plate_rect(variant["rows"])

    side = 16 * cell
    width = PAD * 2 + side * 2 + GAP
    height = PAD * 2 + side
    canvas = P.Canvas(width, height)

    for y in range(height):
        for x in range(width):
            canvas.px[y][x] = (44, 46, 52, 255)

    bare = P.Canvas(side, side)
    P.draw_sprite(bare, variant["rows"], pal, cell=cell)
    for by in range(side):
        for bx in range(side):
            r, g, b, a = bare.px[by][bx]
            if a:
                canvas.px[PAD + by][PAD + bx] = (r, g, b, 255)

    # Second panel: same sprite with the app's countdown stack drawn on the plate.
    with_text = P.Canvas(side, side)
    P.draw_sprite(with_text, variant["rows"], pal, cell=cell)
    P.draw_countdown(with_text, area, over, label="FOCUS", clock="18:30",
                     progress=0.42, cell=cell)
    for by in range(side):
        for bx in range(side):
            r, g, b, a = with_text.px[by][bx]
            if a:
                canvas.px[PAD + by][PAD + side + GAP + bx] = (r, g, b, 255)

    path = os.path.join(PREVIEWS, f"zoom-{variant['id']}-{phase}.png")
    canvas.save(path)
    return path


def main():
    args = sys.argv[1:]
    phase = "focus"
    if "--phase" in args:
        phase = args[args.index("--phase") + 1]
    cell = 24
    if "--cell" in args:
        cell = int(args[args.index("--cell") + 1])

    os.makedirs(PREVIEWS, exist_ok=True)
    wanted = V.VARIANTS if (not args or "--all" in args or args[0].startswith("--")) else [
        v for v in V.VARIANTS if v["id"] in args or v["name"].lower() in [a.lower() for a in args]
    ]
    for variant in wanted:
        print("wrote", zoom(variant, phase, cell))
    return 0


if __name__ == "__main__":
    sys.exit(main())
