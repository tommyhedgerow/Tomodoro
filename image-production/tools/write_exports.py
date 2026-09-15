#!/usr/bin/env python3
"""Write copy-paste-ready art and palette blocks for each candidate.

    python3 write_exports.py

Emits, per candidate, a Swift `baseRows` block and a palette table with the RGBA
values the previews used, so nothing has to be transcribed by hand.
"""

import os
import sys

HERE = __file__.rsplit("/", 1)[0]
sys.path.insert(0, HERE)

import pixelkit as P          # noqa: E402
import variants as V          # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "tortoise-designs"))
EXPORTS = os.path.join(ROOT, "exports")


def swift_rows(variant):
    lines = [f"/// {variant['name']} — {variant['id']}",
             "/// Paste over TortoisePose.baseRows.",
             "static let baseRows: [String] = ["]
    for row in variant["rows"]:
        lines.append(f'    "{row}",')
    lines.append("]")
    return "\n".join(lines)


def palette_table(variant):
    pal = V.palette_for(variant, "focus")
    order = ["#", "s", "o", "p", "k", "h", "e", "r", "t"]
    meaning = {
        "#": "keyline / outline", "s": "phase ring (focus shown)", "o": "shell body",
        "p": "second shell tone", "k": "plastron", "h": "skin", "e": "eye",
        "r": "cheek", "t": "tail",
    }
    lines = ["| Cell | Meaning | RGBA | Hex |", "| --- | --- | --- | --- |"]
    for ch in order:
        if ch not in variant["palette"]:
            continue
        c = pal[ch]
        r, g, b = P.rgb255(c)
        lines.append(f"| `{ch}` | {meaning[ch]} | ({c[0]:.3f}, {c[1]:.3f}, {c[2]:.3f}) "
                     f"| `#{r:02X}{g:02X}{b:02X}` |")
    plate = variant["plate_color"]
    pr, pg, pb = P.rgb255(plate)
    lines.append(f"| — | countdown plate | ({plate[0]:.3f}, {plate[1]:.3f}, {plate[2]:.3f}) "
                 f"| `#{pr:02X}{pg:02X}{pb:02X}` |")
    return "\n".join(lines)


def main():
    os.makedirs(EXPORTS, exist_ok=True)
    index = ["# Candidate grids, ready to paste", "",
             "Each file holds the sprite rows and the palette for one candidate.",
             "Update `TortoiseSprite.textArea` to the plate rect below as well.", ""]
    for variant in V.VARIANTS:
        rect = V.find_plate_rect(variant["rows"])
        part = [
            f"## {variant['name']} — `{variant['id']}`",
            "",
            variant["blurb"],
            "",
            f"**Tradeoff.** {variant['tradeoff']}",
            "",
            "```swift",
            swift_rows(variant),
            "```",
            "",
            f"Countdown plate rect: `(x: {rect[0]}, y: {rect[1]}, "
            f"width: {rect[2]}, height: {rect[3]})`",
            "",
            "Palette:",
            "",
            palette_table(variant),
            "",
        ]
        path = os.path.join(EXPORTS, f"{variant['id']}.md")
        with open(path, "w") as handle:
            handle.write("\n".join(part))
        index.append(f"* `{variant['id']}.md` — plate rect "
                     f"({rect[0]},{rect[1]},{rect[2]},{rect[3]})")
        print("wrote", path)

    with open(os.path.join(EXPORTS, "README.md"), "w") as handle:
        handle.write("\n".join(index) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
