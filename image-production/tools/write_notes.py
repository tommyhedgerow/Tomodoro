#!/usr/bin/env python3
"""Write the review notes for the candidate tortoise designs.

Generated from variants.py so the grids in the notes are the grids that were
validated and rendered, never a hand-copied approximation.

    python3 write_notes.py
"""

import os
import sys

HERE = __file__.rsplit("/", 1)[0]
sys.path.insert(0, HERE)

import variants as V  # noqa: E402

ROOT = os.path.abspath(os.path.join(HERE, "..", "tortoise-designs"))

HEADER = """# Tortoise design alternatives

Five alternative tortoises for Tomodoro, authored as 16x16 grids in the same
text format the app already uses, so any of them can be pasted straight into
`Sources/Core/TortoisePose.swift`.

Every candidate was checked by two independent validators before it was drawn:

| Check | What it enforces |
| --- | --- |
| `tools/variants.py check` | 16 rows of 16, every pixel 4-connected, an eye on skin, one unbroken countdown plate big enough for the overlay's FOCUS / clock / progress stack |
| `tools/posecheck` (Swift) | The rules above applied to **all nine animation poses**, using the app's real `TortoisePose.reeling` and tuck, plus a head-overlap rule that catches a nod tearing the silhouette |

Result: **all five are structurally sound across all nine poses.**

None of this is a visual verdict. Structural validity is necessary, not
sufficient — see *Judging* below for what the checks cannot tell you.

## How to read the previews

| File | What it shows |
| --- | --- |
| `previews/lineup-<phase>.png` | All five side by side, bare, at 26px per sprite cell |
| `previews/zoom-<id>-<phase>.png` | One candidate: bare, then with the real countdown stack |
| `previews/tortoise-alternatives-<phase>.png` | The full review sheet: overlay size with and without the countdown, menu-bar 16px and 32px, 64px icon, name and tradeoff |
| `<id>-overlay-<phase>.png` | Overlay size with the countdown drawn as the app draws it |
| `<id>-bare-<phase>.png` | Overlay size, shell alone |

`<phase>` is `focus`, `short` or `long`, so the phase-coloured ring can be
compared across all three session colours.

## Judging

What the previews let you judge: silhouette at menu-bar size, whether the head
reads, whether the countdown stays legible on the shell, and whether the phase
colour is doing enough work.

What they do not show: motion. The nod, blink, sleep and eat poses are all
validated but none of them are animated in these stills. If a candidate is close,
the next step is rendering its animation sheet through the app itself.

### The constraint that shapes all five

The countdown lives inside the shell, and the overlay prints `FOCUS` / `18:30` /
a progress bar there. The clock is 7 font cells wide at 5px per cell, so the flat
plate has to be at least 8 sprite cells across and 6 tall.

That leaves roughly three columns of the 16 for the head and its keyline. The
reference art in `Reference/tortoise-ref.webp` has a head nearly half the width
of its shell; at 16x16 *with the countdown inside the shell*, that is not
reachable. Every candidate here trades head size against countdown room, and they
trade it differently:

* **Mascot** and **Storybook** keep the countdown generous and give the head the
  three columns that are left.
* **Flat** keeps the widest plate (11 cells) and therefore the smallest head.
* **Realist** and **Ember** sit between, and buy the head contrast instead of size.

If the head should be genuinely large, the countdown has to give something up —
smaller digits, or a plate that sits below the tortoise rather than in its shell.
That is a bigger change than a sprite swap, and it is a decision for you, not for
the art.

---

## The candidates

"""

FOOTER = """---

## Applying a chosen design

1. Open `Sources/Core/TortoisePose.swift` and replace the 16 rows of
   `TortoisePose.baseRows` with the grid above.
2. Set the palette in `Sources/Core/TortoiseSprite.swift`. The legend maps as:

   | Cell | Meaning | Swift case |
   | --- | --- | --- |
   | `.` | transparent | `.empty` |
   | `#` | keyline | `.outline` |
   | `s` | phase-coloured ring | `.trim` |
   | `o` | shell body | `.shell` |
   | `p` | second shell tone | needs a new case, or map to `.shell` |
   | `k` | plastron | needs a new case, or map to `.shell` |
   | `h` | skin | `.skin` |
   | `e` | eye | `.eye` |
   | `r` | cheek | needs a new case, or map to `.skin` |
   | `t` | tail | map to `.skin` |

   `p`, `k`, `r` and `t` are new cells this exploration introduced. Mapping them
   onto an existing case is enough to try a design; adding cases to
   `TortoiseCell` and `TortoisePalette` is the clean version.
3. Update `TortoiseSprite.textArea` to the plate rectangle listed for the
   candidate, or the countdown will print in the wrong place.
4. For **Realist**, widen `TortoisePose.tucked` so it finds the shell's front rim
   per row instead of clearing everything from column 13 right. Realist's shell is
   one column wider than the shipped one, so a fixed column 13 puts the sleeping
   face outside the shell. It is a one-function change, not an art problem. The
   other four pass the sleep poses under the app's current tuck unchanged.
5. Run the test suite, then regenerate the previews:
   `Tomodoro.app/Contents/MacOS/Tomodoro --export-animation .build/frames`

## Reproducing this work

```sh
cd image-production/tools

# structural checks
python3 variants.py check
python3 gen_posecheck.py
swiftc -Onone -o /tmp/posecheck ../../Sources/Core/TortoiseSprite.swift \\
       ../../Sources/Core/TortoisePose.swift main.swift && /tmp/posecheck

# previews
python3 render_sheet.py --phase focus --individual
python3 render_lineup.py --cell 26
python3 render_zoom.py --all

# these notes
python3 write_notes.py
```

`main.swift` is generated by `gen_posecheck.py` and is disposable. Edit
`variants.py`, never `main.swift`.
"""


def grid_block(rows):
    return "\n".join(rows)


def candidate_section(variant, index):
    problems = V.validate(variant)
    rect = V.find_plate_rect(variant["rows"])
    needed_h, needed_w, have_w, have_h = V.content_size(rect)

    lines = [f"### {index}. {variant['name']} — `{variant['id']}`", ""]
    lines.append(variant["blurb"])
    lines.append("")
    lines.append(f"**Tradeoff.** {variant['tradeoff']}")
    lines.append("")
    lines.append("```")
    lines.append("    " + "".join(str(x % 10) for x in range(16)))
    for y, row in enumerate(variant["rows"]):
        lines.append(f"{y:3d} {row}")
    lines.append("```")
    lines.append("")
    lines.append(f"* Countdown plate: **{rect[2]}x{rect[3]} cells** at "
                 f"({rect[0]},{rect[1]}) — the overlay needs {needed_h}px tall and "
                 f"{needed_w}px across; this plate offers {have_h}px by {have_w}px.")
    lines.append(f"* Structural check: "
                 f"{'sound' if not problems else str(len(problems)) + ' problem(s)'}"
                 + ("" if not problems else ": " + "; ".join(problems)))
    lines.append(f"* Sleep rule: the app's current fixed-column tuck "
                 f"{'works unchanged' if variant['id'] != 'v2-realist' else 'needs the rim-aware version'}.")
    lines.append(f"* Preview: `previews/zoom-{variant['id']}-focus.png`")
    lines.append("")
    return lines


def main():
    out = [HEADER]
    for index, variant in enumerate(V.VARIANTS, start=1):
        out.append("\n".join(candidate_section(variant, index)))
        out.append("---\n")
    out.append(FOOTER)

    path = os.path.join(ROOT, "notes", "design-notes.md")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as handle:
        handle.write("\n".join(out))
    print("wrote", path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
