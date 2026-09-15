#!/usr/bin/env python3
"""Render the candidate tortoise designs into review images.

Writes one PNG per candidate plus a combined contact sheet, all from the grids and
palettes in variants.py and the app's own countdown layout in pixelkit.py.

    python3 render_sheet.py                 # contact sheet + per-candidate images
    python3 render_sheet.py --phase short    # one session colour

Each review card shows the same sprite three ways:
  * overlay size (13px cells) with FOCUS / 18:30 / progress bar, as the overlay draws it
  * menu-bar size (16px square), with and without the countdown, because that is
    where the silhouette has to survive
  * icon sizes 32px and 64px
"""

import os
import sys

HERE = __file__.rsplit("/", 1)[0]
sys.path.insert(0, HERE)

import pixelkit as P          # noqa: E402
import variants as V          # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "tortoise-designs"))
PREVIEWS = os.path.join(ROOT, "previews")
EXPORTS = os.path.join(ROOT, "exports")

CELL = P.CELL                    # 13, the overlay's cell size
CARD_SPRITE = 10                 # px per sprite cell on the review sheet
LABEL_SIZE = 2                   # pixel-font scale for sheet annotations
INK = (0.16, 0.17, 0.20)

PAD = 34
GUTTER = 28
TOP_BAND = 124
FOOT_BAND = 74
SIDE = 16 * CARD_SPRITE
CARD_W = 5 * SIDE + 4 * GUTTER
CARD_H = SIDE


def draw_text(canvas, text, x, y, scale, color, spacing=1):
    """Draw a string in the app's own 3x5 pixel font at `scale` pixels per font cell."""
    cursor = 0
    for ch in text:
        width, rows = P.glyph(ch)
        for row_index, row in enumerate(rows):
            for col_index, mark in enumerate(row):
                if mark == "#":
                    canvas.rect(x + (cursor + col_index) * scale, y + row_index * scale,
                                scale, scale, color)
        cursor += width + spacing
    return cursor - spacing


def text_px(text, scale, spacing=1):
    return P.text_width(text, spacing) * scale


def sprite_canvas(rows, palette, cell=CELL, with_countdown=True, area=None,
                  overlay=None, label="FOCUS", clock="18:30", progress=0.42):
    """Sprite palette for the art, overlay palette for the countdown plate."""
    canvas = P.Canvas(16 * cell, 16 * cell)
    P.draw_sprite(canvas, rows, palette, cell=cell)
    if with_countdown and area and overlay:
        P.draw_countdown(canvas, area, overlay, label=label, clock=clock,
                         progress=progress, cell=cell)
    return canvas


def blit(target, source_canvas, x, y):
    """Copy a canvas onto another, honouring alpha over the target's backdrop."""
    for sy in range(source_canvas.height):
        for sx in range(source_canvas.width):
            r, g, b, a = source_canvas.px[sy][sx]
            if a == 0:
                continue
            target.put(x + sx, y + sy, (r / 255, g / 255, b / 255), alpha=a / 255)


def render_card(variant, phase):
    """One review row: countdown, bare sprite, then the three small sizes."""
    pal = V.palette_for(variant, phase)
    over = V.overlay_palette(variant, phase)
    area = V.find_plate_rect(variant["rows"])

    card = P.Canvas(CARD_W, CARD_H)

    # 1. Overlay layout, countdown exactly as the overlay draws it.
    blit(card, sprite_canvas(variant["rows"], pal, CARD_SPRITE, True, area, over), 0, 0)

    # 2. The same sprite with no countdown, so the shell itself is visible.
    blit(card, sprite_canvas(variant["rows"], pal, CARD_SPRITE, False), SIDE + GUTTER, 0)

    # 3. Menu-bar 16px, menu-bar 32px and a 64px icon: the sizes that decide
    #    whether the silhouette survives.
    slot = 2 * SIDE + 2 * GUTTER
    column = SIDE // 2 - 8
    for index, cell in enumerate((1, 2, 4)):
        x = slot + index * (SIDE // 3) + column
        blit(card, sprite_canvas(variant["rows"], pal, cell, False), x, (SIDE - 16 * cell) // 2)

    return card


def caption_row(target, y, variant, phase, judged):
    """The text block beside a card: name, blurb, tradeoff, verdict."""
    x = PAD
    x += draw_text(target, variant["name"].upper(), x, y, LABEL_SIZE, INK) + 18
    x += draw_text(target, variant["id"], x, y + 2, 1, (0.45, 0.47, 0.52)) + 18

    verdict = "structurally sound in all 9 poses" if judged["ok"] else "NEEDS WORK"
    color = (0.16, 0.52, 0.24) if judged["ok"] else (0.78, 0.20, 0.18)
    draw_text(target, verdict.upper(), x, y + 3, 1, color)

    body_y = y + 30
    for line in wrap(variant["blurb"], 108):
        draw_text(target, line, PAD, body_y, 1, (0.30, 0.32, 0.36))
        body_y += 14
    body_y += 4
    for line in wrap("Tradeoff: " + variant["tradeoff"], 108):
        draw_text(target, line, PAD, body_y, 1, (0.52, 0.35, 0.20))
        body_y += 14
    draw_text(target, judged["plate"], PAD, body_y + 4, 1, (0.45, 0.47, 0.52))
    return body_y


def wrap(text, width):
    words, lines, line = text.split(), [], ""
    for word in words:
        candidate = (line + " " + word).strip()
        if len(candidate) > width:
            lines.append(line)
            line = word
        else:
            line = candidate
    if line:
        lines.append(line)
    return lines


def judge():
    """Run the Python structural rules and summarise the plate for the caption."""
    out = {}
    for variant in V.VARIANTS:
        problems = V.validate(variant)
        rect = V.find_plate_rect(variant["rows"])
        needed_h, needed_w, have_w, have_h = V.content_size(rect)
        out[variant["id"]] = {
            "ok": not problems,
            "problems": problems,
            "plate": (f"countdown plate {rect[2]}x{rect[3]} at ({rect[0]},{rect[1]}); "
                      f"needs {needed_h}x{needed_w}px, has {have_h}x{have_w}px"),
        }
    return out


def render_contact_sheet(phase):
    judged = judge()
    row_h = CARD_H + 92
    width = PAD * 2 + CARD_W
    height = TOP_BAND + len(V.VARIANTS) * row_h + FOOT_BAND
    sheet = P.Canvas(width, height, background=False)

    # Backdrop: a dark surface, because the overlay floats over other apps and the
    # light keylines have to survive it. A light strip underneath shows the other case.
    for y in range(height):
        tone = (0.13, 0.14, 0.17) if y < height - FOOT_BAND else (0.86, 0.87, 0.89)
        for x in range(width):
            sheet.px[y][x] = (int(tone[0] * 255), int(tone[1] * 255), int(tone[2] * 255), 255)

    draw_text(sheet, "TOMODORO TORTOISE - FIVE ALTERNATIVE DESIGNS", PAD, 32, 2,
              (0.95, 0.95, 0.97))
    subtitle = (f"16x16 pixel art, phase: {phase}.  Each row: overlay size with the "
                f"countdown, overlay size bare, menu-bar 16px and 32px, 64px icon.")
    draw_text(sheet, subtitle, PAD, 68, 1, (0.62, 0.65, 0.72))
    draw_text(sheet, "All five pass the app's structural rules: 16x16, every pixel "
                     "connected, eye on skin, plate fits the countdown, sound in all 9 poses.",
              PAD, 92, 1, (0.45, 0.78, 0.52))

    y = TOP_BAND
    for variant in V.VARIANTS:
        pal = V.palette_for(variant, phase)
        card = render_card(variant, phase)

        # Card sits on a light plate so transparent cells read as transparent,
        # with a rule underneath so each candidate is visually separated.
        plate_x, plate_y = PAD, y
        for py in range(CARD_H):
            for px in range(CARD_W):
                sheet.px[plate_y + py][plate_x + px] = (232, 232, 232, 255)
        blit(sheet, card, plate_x, plate_y)
        for px in range(CARD_W):
            sheet.px[plate_y + CARD_H][plate_x + px] = (120, 124, 132, 255)

        caption_row(sheet, y + CARD_H + 20, variant, phase, judged[variant["id"]])
        y += row_h

    note = ("Rendered by image-production/tools/render_sheet.py from variants.py and the app's "
            "own pixel font and countdown layout.")
    draw_text(sheet, note, PAD, height - 60, 1, (0.35, 0.37, 0.42))

    path = os.path.join(PREVIEWS, f"tortoise-alternatives-{phase}.png")
    sheet.save(path)
    print(f"wrote {path} ({sheet.width}x{sheet.height})")
    return path


def render_individual(phase):
    paths = []
    for variant in V.VARIANTS:
        pal = V.palette_for(variant, phase)
        area = V.find_plate_rect(variant["rows"])
        overlay = sprite_canvas(variant["rows"], pal, CELL, True, area,
                                V.overlay_palette(variant, phase))
        paths.append(overlay.save(os.path.join(PREVIEWS, f"{variant['id']}-overlay-{phase}.png")))
        bare = sprite_canvas(variant["rows"], pal, CELL, False)
        paths.append(bare.save(os.path.join(PREVIEWS, f"{variant['id']}-bare-{phase}.png")))
    return paths


def main():
    phase = "focus"
    args = sys.argv[1:]
    if "--phase" in args:
        phase = args[args.index("--phase") + 1]
    if phase not in ("focus", "short", "long"):
        raise SystemExit("phase must be focus, short or long")

    os.makedirs(PREVIEWS, exist_ok=True)
    problems = V.all_problems()
    if problems:
        print("structural problems — refusing to render a sheet that hides them:")
        for problem in problems:
            print("  !", problem)
        return 1
    render_contact_sheet(phase)
    if "--individual" in args:
        for path in render_individual(phase):
            print("wrote", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
