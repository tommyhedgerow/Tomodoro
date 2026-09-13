#!/usr/bin/env python3
"""Render a PNG as ASCII so pixel art can be verified without viewing the image.

Stdlib only (zlib + struct). Decodes the real bytes on disk, so it is independent
of whatever coordinate conventions the encoder used - which is exactly what makes
it useful for checking orientation.

Usage:
  python3 pngview.py image.png [--scale N]
"""

import struct
import sys
import zlib


def read_png(path):
    with open(path, "rb") as fh:
        data = fh.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("not a PNG: " + path)

    pos = 8
    header = None
    idat = bytearray()
    palette = None
    trns = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            header = struct.unpack(">IIBBBBB", chunk)
        elif ctype == b"IDAT":
            idat += chunk
        elif ctype == b"PLTE":
            palette = chunk
        elif ctype == b"tRNS":
            trns = chunk
        elif ctype == b"IEND":
            break

    if header is None:
        raise SystemExit("no IHDR")
    width, height, depth, color_type, comp, filt, interlace = header
    if interlace != 0:
        raise SystemExit("interlaced PNGs are not supported")
    if depth != 8:
        raise SystemExit("only 8-bit PNGs are supported, got %d" % depth)

    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color_type)
    if channels is None:
        raise SystemExit("unsupported color type %d" % color_type)

    raw = zlib.decompress(bytes(idat))
    stride = width * channels
    out = bytearray(height * stride)
    prev = bytearray(stride)

    pos = 0
    for y in range(height):
        ftype = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos + stride])
        pos += stride
        if ftype == 1:
            for i in range(channels, stride):
                line[i] = (line[i] + line[i - channels]) & 0xFF
        elif ftype == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 0xFF
        elif ftype == 3:
            for i in range(stride):
                left = line[i - channels] if i >= channels else 0
                line[i] = (line[i] + ((left + prev[i]) >> 1)) & 0xFF
        elif ftype == 4:
            for i in range(stride):
                a = line[i - channels] if i >= channels else 0
                b = prev[i]
                c = prev[i - channels] if i >= channels else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                line[i] = (line[i] + pred) & 0xFF
        elif ftype != 0:
            raise SystemExit("bad filter type %d on row %d" % (ftype, y))
        out[y * stride:(y + 1) * stride] = line
        prev = line

    # Normalise to a list of RGBA tuples.
    pixels = []
    for y in range(height):
        row = []
        for x in range(width):
            i = y * stride + x * channels
            if color_type == 6:
                row.append(tuple(out[i:i + 4]))
            elif color_type == 2:
                row.append((out[i], out[i + 1], out[i + 2], 255))
            elif color_type == 0:
                v = out[i]
                row.append((v, v, v, 255))
            elif color_type == 4:
                v = out[i]
                row.append((v, v, v, out[i + 1]))
            elif color_type == 3:
                idx = out[i]
                r, g, b = palette[idx * 3:idx * 3 + 3]
                a = trns[idx] if trns and idx < len(trns) else 255
                row.append((r, g, b, a))
        pixels.append(row)
    return width, height, pixels


# Focus palette, used to label cells. Kept in sync with TortoisePalette.
def palette_for(base):
    # base is 0...1, matching RGBA in TortoiseSprite.swift. Both blends happen on
    # that scale; bytes are only produced at the end. lighten is not scale
    # invariant, so converting early silently corrupts the expected colours.
    r, g, b = base

    def darken(amount):
        return (round(r * (1 - amount) * 255),
                round(g * (1 - amount) * 255),
                round(b * (1 - amount) * 255))

    def lighten(amount):
        return (round((r + (1 - r) * amount) * 255),
                round((g + (1 - g) * amount) * 255),
                round((b + (1 - b) * amount) * 255))

    return {
        "o": darken(0.0),      # shell
        "#": darken(0.55),     # rim
        "s": darken(0.30),     # scute
        "h": lighten(0.45),    # skin
        "e": (26, 23, 28),     # eye
    }


def classify(px, legend):
    if px[3] == 0:
        return "."
    best, bestd = "?", None
    for ch, (r, g, b) in legend.items():
        d = (px[0] - r) ** 2 + (px[1] - g) ** 2 + (px[2] - b) ** 2
        if bestd is None or d < bestd:
            best, bestd = ch, d
    # Swift truncates where Python rounds, so allow a little slack; the closest
    # distinct palette entries are still thousands of units apart.
    return best if bestd is not None and bestd < 1000 else "?"


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    path = args[0] if args else None
    if not path:
        raise SystemExit(__doc__)
    scale = 1
    if "--scale" in sys.argv:
        scale = int(sys.argv[sys.argv.index("--scale") + 1])

    width, height, pixels = read_png(path)
    print("%s  %dx%d" % (path, width, height))

    if "--colors" in sys.argv:
        seen = {}
        for row in pixels:
            for px in row:
                seen[px] = seen.get(px, 0) + 1
        for px, count in sorted(seen.items(), key=lambda kv: -kv[1]):
            print("  rgba%-22s x%d" % (str(px), count))
        print("expected focus palette:")
        for ch, val in sorted(palette_for((0.91, 0.24, 0.22)).items()):
            print("  %s -> %s" % (ch, val))
        return

    legend = palette_for((0.91, 0.24, 0.22))  # focus red
    print("legend: o=shell #=rim s=scute h=skin e=eye .=transparent")

    for y in range(0, height, scale):
        line = ""
        for x in range(0, width, scale):
            line += classify(pixels[y][x], legend)
        print("%3d %s" % (y, line))


if __name__ == "__main__":
    main()
