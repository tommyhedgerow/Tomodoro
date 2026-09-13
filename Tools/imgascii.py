#!/usr/bin/env python3
"""Render any PNG as ASCII so reference art can be inspected without viewing it.

Quantises to the most common colours, then prints a character map. Also reports
colour statistics and colour-change positions, which reveal the native pixel
block size of scaled-up pixel art.

Usage:
  python3 imgascii.py image.png [--block N] [--colors K] [--bg-hex RRGGBB]
"""

import os
import sys
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngview import read_png  # noqa: E402

GLYPHS = " .:-=+*#%@" + "ABCDEFGHIJKLMNOPQRSTUVWXYZ" + "abcdefghijklmnopqrstuvwxyz"


def lum(px):
    return 0.299 * px[0] + 0.587 * px[1] + 0.114 * px[2]


def main():
    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    path = args[0]

    block = None
    if "--block" in args:
        block = int(args[args.index("--block") + 1])
    top_k = 8
    if "--colors" in args:
        top_k = int(args[args.index("--colors") + 1])
    bg = None
    if "--bg-hex" in args:
        h = args[args.index("--bg-hex") + 1]
        bg = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

    width, height, pixels = read_png(path)
    print("%s  %dx%d" % (path, width, height))

    counts = Counter()
    for row in pixels:
        for px in row:
            counts[px[:3]] += 1

    print("distinct colours: %d" % len(counts))
    print("top colours:")
    for color, count in counts.most_common(top_k):
        print("  rgb%-18s x%d" % (str(color), count))

    if bg is None:
        bg = counts.most_common(1)[0][0]
    print("background treated as rgb%s" % (str(bg),))

    # Infer the pixel block size from where colours change along a few rows.
    if block is None:
        changes = []
        for y in range(0, height, max(1, height // 20)):
            prev = None
            for x in range(width):
                c = pixels[y][x][:3]
                if prev is not None and c != prev:
                    changes.append(x)
                prev = c
        if changes:
            diffs = [b - a for a, b in zip(changes, changes[1:]) if b > a]
            small = [d for d in diffs if d <= 32]
            if small:
                common = Counter(small).most_common(3)
                print("common colour-run lengths: %s" % common)
                block = common[0][0]
        if block is None:
            block = 8
    print("using block size: %d" % block)

    hue_mode = "--hue" in args
    classes = []
    if not hue_mode:
        classes = [c for c, _ in counts.most_common(top_k + 4)
                   if sum((a - b) ** 2 for a, b in zip(c, bg)) ** 0.5 >= 40][:top_k]
        print("")
        print("class legend (nearest of the top non-background colours):")
        for i, c in enumerate(classes):
            print("  %s = rgb%s" % (GLYPHS[i], str(c)))
        print("")

    def hue_class(px):
        r, g, b = px
        mx, mn = max(px), min(px)
        if mx < 90:
            return "K"                      # outline / very dark
        sat = (mx - mn) / mx if mx else 0
        if sat < 0.18:
            return "W" if mx > 200 else "k"  # light neutral / mid grey
        if g >= r and g >= b:
            return "G"                      # green skin
        if r > g > b:
            return "N" if r > 150 else "n"  # brown shell, bright / shaded
        if b >= r and b >= g:
            return "U"                      # blue
        return "R"                          # red / orange

    if hue_mode:
        print("hue legend: .=bg K=outline G=green N=brown n=dark-brown "
              "W=light k=grey R=red U=blue")
        print("")

    for by in range(0, height, block):
        line = ""
        for bx in range(0, width, block):
            rs = gs = bs = n = 0
            for y in range(by, min(by + block, height)):
                for x in range(bx, min(bx + block, width)):
                    px = pixels[y][x]
                    rs += px[0]; gs += px[1]; bs += px[2]; n += 1
            if n == 0:
                line += "?"
                continue
            avg = (rs // n, gs // n, bs // n)
            if sum((a - b) ** 2 for a, b in zip(avg, bg)) ** 0.5 < 40:
                line += "."
                continue
            if hue_mode:
                line += hue_class(avg)
                continue
            best_i, best_d = 0, None
            for i, c in enumerate(classes):
                d = sum((a - b) ** 2 for a, b in zip(avg, c))
                if best_d is None or d < best_d:
                    best_i, best_d = i, d
            line += GLYPHS[best_i]
        print("%3d %s" % (by, line))


if __name__ == "__main__":
    main()
