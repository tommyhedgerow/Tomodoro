#!/usr/bin/env python3
"""Pure-stdlib pixel-art renderer for Tomodoro tortoise design exploration.

No third-party dependencies: zlib and struct write a valid RGBA PNG, so the
design tool runs anywhere the repo does. Everything that the *app* defines — the
3x5 pixel font, the countdown layout, the cell size — is mirrored here so a
design-time preview shows what the app would actually draw.

Source of truth for the mirrored values:
  Sources/Core/PixelFont.swift              glyph table, spacing
  Sources/Core/OverlayGeometry.swift        cell size, label/digit sizes, gaps
  Sources/UI/TortoiseOverlayView.swift      the countdown stack and its centring
"""

import struct
import zlib

# --------------------------------------------------------------- PNG output


def png_bytes(width, height, rows):
    """rows: list of rows, each a list of (r, g, b, a) ints in 0..255."""
    raw = bytearray()
    for row in rows:
        raw.append(0)  # filter type: none
        for r, g, b, a in row:
            raw += bytes((r, g, b, a))

    def chunk(tag, payload):
        return (struct.pack(">I", len(payload)) + tag + payload
                + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF))

    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", header)
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9))
            + chunk(b"IEND", b""))


def write_png(path, width, height, rows):
    with open(path, "wb") as handle:
        handle.write(png_bytes(width, height, rows))
    return path


# --------------------------------------------------------------- colour


def rgb255(c):
    return tuple(max(0, min(255, int(round(v * 255)))) for v in c)


def darken(c, amount):
    return tuple(v * (1 - amount) for v in c)


def lighten(c, amount):
    return tuple(v + (1 - v) * amount for v in c)


def checkered(x, y, size=6, light=(232, 232, 232), dark=(203, 203, 203)):
    """A checkerboard reads alpha honestly in any image viewer."""
    return light if ((x // size) + (y // size)) % 2 == 0 else dark


class Canvas:
    """An RGBA pixel buffer with a checkerboard backdrop for transparency."""

    def __init__(self, width, height, background=True):
        self.width = width
        self.height = height
        self.background = background
        self.px = [[(0, 0, 0, 0)] * width for _ in range(height)]

    def _base(self, x, y):
        if not self.background:
            return (0, 0, 0, 0)
        r, g, b = checkered(x, y)
        return (r, g, b, 255)

    def put(self, x, y, color, alpha=1.0):
        """Composite one source pixel over the backdrop."""
        if not (0 <= x < self.width and 0 <= y < self.height):
            return
        if alpha <= 0:
            return
        base = self._base(x, y)
        r255, g255, b255 = rgb255(color)
        out = tuple(int(round(src * alpha + back * (1 - alpha)))
                    for src, back in zip((r255, g255, b255), base[:3]))
        a = int(round(alpha * 255 + base[3] * (1 - alpha))) if self.background else int(round(alpha * 255))
        self.px[y][x] = (out[0], out[1], out[2], 255 if self.background else a)

    def rect(self, x, y, w, h, color, alpha=1.0):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.put(xx, yy, color, alpha)

    def rows(self):
        return self.px

    def save(self, path):
        return write_png(path, self.width, self.height, self.px)


# --------------------------------------------------------------- pixel font
# Mirrors Sources/Core/PixelFont.swift exactly.

FONT = {
    "0": (3, ["###", "#.#", "#.#", "#.#", "###"]),
    "1": (3, [".#.", "##.", ".#.", ".#.", "###"]),
    "2": (3, ["###", "..#", "###", "#..", "###"]),
    "3": (3, ["###", "..#", "###", "..#", "###"]),
    "4": (3, ["#.#", "#.#", "###", "..#", "..#"]),
    "5": (3, ["###", "#..", "###", "..#", "###"]),
    "6": (3, ["###", "#..", "###", "#.#", "###"]),
    "7": (3, ["###", "..#", "..#", "..#", "..#"]),
    "8": (3, ["###", "#.#", "###", "#.#", "###"]),
    "9": (3, ["###", "#.#", "###", "..#", "###"]),
    ":": (1, ["#", ".", "#", ".", "#"]),
    " ": (2, ["..", "..", "..", "..", ".."]),
}
for _ch, _rows in {
    "A": ["###", "#.#", "###", "#.#", "#.#"], "B": ["##.", "#.#", "##.", "#.#", "##."],
    "C": ["###", "#..", "#..", "#..", "###"], "D": ["##.", "#.#", "#.#", "#.#", "##."],
    "E": ["###", "#..", "##.", "#..", "###"], "F": ["###", "#..", "##.", "#..", "#.."],
    "G": ["###", "#..", "#.#", "#.#", "###"], "H": ["#.#", "#.#", "###", "#.#", "#.#"],
    "I": ["###", ".#.", ".#.", ".#.", "###"], "J": ["..#", "..#", "..#", "#.#", "###"],
    "K": ["#.#", "#.#", "##.", "#.#", "#.#"], "L": ["#..", "#..", "#..", "#..", "###"],
    "M": ["#.#", "###", "###", "#.#", "#.#"], "N": ["##.", "#.#", "#.#", "#.#", "#.#"],
    "O": ["###", "#.#", "#.#", "#.#", "###"], "P": ["###", "#.#", "###", "#..", "#.."],
    "Q": ["###", "#.#", "#.#", "###", "..#"], "R": ["###", "#.#", "##.", "#.#", "#.#"],
    "S": ["###", "#..", "###", "..#", "###"], "T": ["###", ".#.", ".#.", ".#.", ".#."],
    "U": ["#.#", "#.#", "#.#", "#.#", "###"], "V": ["#.#", "#.#", "#.#", "#.#", ".#."],
    "W": ["#.#", "#.#", "###", "###", "#.#"], "X": ["#.#", "#.#", ".#.", "#.#", "#.#"],
    "Y": ["#.#", "#.#", ".#.", ".#.", ".#."], "Z": ["###", "..#", ".#.", "#..", "###"],
}.items():
    FONT[_ch] = (3, _rows)

GLYPH_HEIGHT = 5
SPACING = 1


def glyph(ch):
    return FONT.get(ch, (3, ["###", "#.#", "#.#", "#.#", "###"]))


def text_width(text, spacing=SPACING):
    if not text:
        return 0
    return sum(glyph(c)[0] for c in text) + spacing * (len(text) - 1)


def filled_cells(text, spacing=SPACING):
    """(x, y) offsets from the text origin, in font cells, exactly as the app draws."""
    out = []
    cursor = 0
    for ch in text:
        width, rows = glyph(ch)
        for row_index, row in enumerate(rows):
            for col_index, mark in enumerate(row):
                if mark == "#":
                    out.append((cursor + col_index, row_index))
        cursor += width + spacing
    return out


# --------------------------------------------------------------- overlay layout
# Mirrors Sources/Core/OverlayGeometry.swift and the countdown stack in
# Sources/UI/TortoiseOverlayView.swift.

CELL = 13              # defaultCellSize
LABEL_CELL = 3
DIGIT_CELL = 5
BAR_HEIGHT = 6
LABEL_GAP = 6
BAR_GAP = 8


def countdown_rect(area, cell=CELL):
    """Sprite-cell text area -> pixel rect, as the overlay computes it."""
    ax, ay, aw, ah = area
    return (ax * cell, ay * cell, aw * cell, ah * cell)


def countdown_metrics(cell=CELL):
    """The overlay's label / digit / bar sizes, scaled with the sprite cell."""
    scale = cell / CELL
    return {
        "label": max(1, int(round(LABEL_CELL * scale))),
        "digit": max(1, int(round(DIGIT_CELL * scale))),
        "bar": max(1, int(round(BAR_HEIGHT * scale))),
        "label_gap": int(round(LABEL_GAP * scale)),
        "bar_gap": int(round(BAR_GAP * scale)),
    }


def draw_countdown(canvas, area, palette, label="FOCUS", clock="18:30", progress=0.42,
                   origin=(0, 0), running=True, cell=CELL):
    """Draw the label / clock / progress stack inside the shell, pixel for pixel.

    `cell` must match the sprite cell size the art was drawn at, so a zoomed
    preview scales the countdown with the tortoise instead of drawing it at the
    overlay's fixed 13px. palette keys used: plate, ink, trim.
    """
    ox, oy = origin
    m = countdown_metrics(cell)
    label_cell, digit_cell = m["label"], m["digit"]
    bar_height, label_gap, bar_gap = m["bar"], m["label_gap"], m["bar_gap"]

    px, py, pw, ph = countdown_rect(area, cell)
    canvas.rect(ox + px, oy + py, pw, ph, palette["plate"])

    label_w = text_width(label) * label_cell
    label_h = GLYPH_HEIGHT * label_cell
    clock_w = text_width(clock) * digit_cell
    clock_h = GLYPH_HEIGHT * digit_cell

    content_h = label_h + label_gap + clock_h + bar_gap + bar_height
    top = py + (ph - content_h) // 2

    ink = palette["ink"] if running else None

    label_x = px + (pw - label_w) // 2
    for fx, fy in filled_cells(label):
        canvas.rect(ox + label_x + fx * label_cell, oy + top + fy * label_cell,
                    label_cell, label_cell, palette["trim"])

    clock_y = top + label_h + label_gap
    clock_x = px + (pw - clock_w) // 2
    for fx, fy in filled_cells(clock):
        alpha = 0.55 if ink is None else 1.0
        canvas.rect(ox + clock_x + fx * digit_cell, oy + clock_y + fy * digit_cell,
                    digit_cell, digit_cell, palette["ink"], alpha=alpha)

    bar_x = px + cell
    bar_w = pw - cell * 2
    bar_y = clock_y + clock_h + bar_gap
    canvas.rect(ox + bar_x, oy + bar_y, bar_w, bar_height, palette["outline"], alpha=0.45)
    filled = int(round(bar_w * progress))
    if filled >= 1:
        canvas.rect(ox + bar_x, oy + bar_y, filled, bar_height, palette["trim"])


# --------------------------------------------------------------- sprite drawing


def draw_sprite(canvas, rows, palette, origin=(0, 0), cell=CELL, alpha_cells=None):
    """Stamp one 16x16 grid of legend characters at `cell` pixels per sprite cell."""
    ox, oy = origin
    alpha_cells = alpha_cells or {}
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == ".":
                continue
            color = palette.get(ch)
            if color is None:
                continue
            a = alpha_cells.get((x, y), 1.0)
            canvas.rect(ox + x * cell, oy + y * cell, cell, cell, color, alpha=a)
    return canvas
