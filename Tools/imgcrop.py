#!/usr/bin/env python3
"""Crop a PNG, with a mode that suggests the crop box for you.

Stdlib only. Useful for tightening screenshots before they go in the README,
without needing an image editor.

Usage:
  python3 imgcrop.py image.png --find            # report the content bounding box
  python3 imgcrop.py in.png out.png --box x,y,w,h
"""

import os
import struct
import sys
import zlib
from collections import Counter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from pngview import read_png  # noqa: E402


def write_png(path, width, height, rows):
    """rows is a list of bytearray, one per scanline, RGBA."""
    raw = b"".join(b"\x00" + bytes(row) for row in rows)

    def chunk(tag, data):
        return (struct.pack(">I", len(data)) + tag + data
                + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    out = b"\x89PNG\r\n\x1a\n"
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    out += chunk(b"IDAT", zlib.compress(raw, 9))
    out += chunk(b"IEND", b"")
    with open(path, "wb") as fh:
        fh.write(out)


def border_colour(pixels):
    """Most common colour around the edge of the image."""
    h = len(pixels)
    w = len(pixels[0])
    edge = Counter()
    for x in range(w):
        edge[pixels[0][x][:3]] += 1
        edge[pixels[h - 1][x][:3]] += 1
    for y in range(h):
        edge[pixels[y][0][:3]] += 1
        edge[pixels[y][w - 1][:3]] += 1
    return edge.most_common(1)[0][0]


def find_box(pixels, threshold=40):
    h = len(pixels)
    w = len(pixels[0])
    bg = border_colour(pixels)

    def differs(p):
        return sum((a - b) ** 2 for a, b in zip(p[:3], bg)) > threshold ** 2

    xs = [x for x in range(w) if any(differs(pixels[y][x]) for y in range(h))]
    ys = [y for y in range(h) if any(differs(pixels[y][x]) for x in range(w))]
    if not xs or not ys:
        return None
    return min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1


def main():
    args = sys.argv[1:]
    if not args:
        raise SystemExit(__doc__)
    source = args[0]
    w, h, pixels = read_png(source)

    if "--find" in args:
        box = find_box(pixels)
        if box is None:
            print("no content found")
            return
        x, y, bw, bh = box
        print("%s  %dx%d" % (source, w, h))
        print("  content box: x=%d y=%d w=%d h=%d px  (%dx%d pt at 2x)"
              % (x, y, bw, bh, bw // 2, bh // 2))
        pad = 24
        px = max(0, x - pad)
        py = max(0, y - pad)
        pw = min(w - px, bw + pad * 2)
        ph = min(h - py, bh + pad * 2)
        print("  suggested:   --box %d,%d,%d,%d" % (px, py, pw, ph))
        return

    if "--box" not in args or len(args) < 2:
        raise SystemExit(__doc__)
    spec = args[args.index("--box") + 1]
    x, y, bw, bh = (int(v) for v in spec.split(","))
    target = args[1]

    x = max(0, min(x, w - 1))
    y = max(0, min(y, h - 1))
    bw = min(bw, w - x)
    bh = min(bh, h - y)

    rows = []
    for row in range(y, y + bh):
        line = bytearray()
        for col in range(x, x + bw):
            line += bytes(pixels[row][col])
        rows.append(line)

    write_png(target, bw, bh, rows)
    print("wrote %s  %dx%d px" % (target, bw, bh))


if __name__ == "__main__":
    main()
