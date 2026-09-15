#!/usr/bin/env python3
"""One row of bare sprites at a large cell size, for judging shape.

    python3 render_lineup.py [--cell 28] [--phase focus]
"""

import os
import sys

HERE = __file__.rsplit("/", 1)[0]
sys.path.insert(0, HERE)

import pixelkit as P          # noqa: E402
import variants as V          # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "tortoise-designs"))


def main():
    args = sys.argv[1:]
    cell = 28
    if "--cell" in args:
        cell = int(args[args.index("--cell") + 1])
    phase = "focus"
    if "--phase" in args:
        phase = args[args.index("--phase") + 1]

    pad, gap = 20, 24
    side = 16 * cell
    width = pad * 2 + len(V.VARIANTS) * side + (len(V.VARIANTS) - 1) * gap
    height = pad * 2 + side
    canvas = P.Canvas(width, height)
    for y in range(height):
        for x in range(width):
            canvas.px[y][x] = (44, 46, 52, 255)

    for index, variant in enumerate(V.VARIANTS):
        pal = V.palette_for(variant, phase)
        sprite = P.Canvas(side, side, background=False)
        P.draw_sprite(sprite, variant["rows"], pal, cell=cell)
        offset = pad + index * (side + gap)
        for sy in range(side):
            for sx in range(side):
                r, g, b, a = sprite.px[sy][sx]
                if a:
                    canvas.px[pad + sy][offset + sx] = (r, g, b, 255)

    path = os.path.join(ROOT, "previews", f"lineup-{phase}.png")
    canvas.save(path)
    print("wrote", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
