# Tortoise redesign — brief and direction

## Objective

Give the owner of Tomodoro five meaningfully different tortoise designs to choose
between, each one a drop-in candidate for the app's 16×16 mascot rather than a
mood-board sketch.

## What the asset actually is

This is worth stating before anything else, because it decides what a "design"
can be here.

The tortoise is not an image file. It is 16 rows of 16 characters in
`Sources/Core/TortoisePose.swift`, one character per pixel, rendered by the app
itself. The same grid drives the desktop overlay, the menu-bar icon, the app icon
and the README banners, and nine animation poses are derived from it
programmatically. So a design alternative has to be *another 16×16 grid* — a PNG
proposal would be unusable without redrawing it by hand.

## Content hierarchy

1. Reads as a tortoise at menu-bar size (16×16), without the countdown.
2. Keeps the countdown (`FOCUS` / `18:30` / progress bar) legible on the shell.
3. Survives the animation: every pose connected, no limb torn off by a nod.
4. Expresses the session phase through colour.
5. Carries the app's pixel-art language, so it belongs with the wordmark.

## Fixed constraints (measured, not assumed)

| Constraint | Value | Source |
| --- | --- | --- |
| Grid | 16×16, one legend character per pixel | `TortoiseSprite.size` |
| Head columns | x13…15, because poses move the head by clearing and restamping these columns | `TortoisePose.headColumns` |
| Countdown content | 60px tall, 85px wide, plus a bar inset of one cell | `TortoiseOverlayMetrics`, `drawCountdown` |
| Minimum plate | 8 sprite cells wide × 6 tall | derived from the stack above |
| Pitches | cell 13px, label 3px, digits 5px, bar 6px | `TortoiseOverlayMetrics` |
| Transparency | transparent pixels must fall through to the app behind | overlay hit testing |

Corollary that governs the whole exploration: **the countdown and the head
compete for the same 16 columns.** A plate 8 cells wide plus a keyline plus a
readable head is close to the limit at this size.

## Directions proposed

Five, chosen to differ in decision-relevant ways rather than in decoration. Three
differ in form and two in palette, which is the split that kept each comparison
honest:

| # | Direction | Axis it explores | Plate | Head |
| --- | --- | --- | --- | --- |
| 1 | Mascot | Rounded dome, heavy keyline, head overlapping the shell's front edge | 8×7 | 3 cells |
| 2 | Realist | Wide low shell, two-tone dome, pale plastron | 10×6 | 3 cells |
| 3 | Flat | No dark outline; cool rim, one shade step, symmetrical shell | 9×8 | 3 cells |
| 4 | Ember | Dark shell with the phase colour ringing the whole silhouette | 8×7 | 3 cells |
| 5 | Storybook | Cream and tan, coral cheek, tail stub | 8×7 | 3 cells |

## Exclusions

* No change to the countdown's position or font.
* No new poses, no change to the animation state machine.
* No sprite size change: 16×16 is fixed by the scene and window geometry.
* No imitation of any specific artist, game or existing mascot. The reference in
  `Reference/` is used for palette and silhouette evidence only.

## Acceptance tests

A candidate is shippable only when all of these hold:

1. 16 rows of 16 characters, all from the legend.
2. Every inked pixel 4-connected to the rest — no floating limbs.
3. At least one eye, each eye touching skin.
4. One unbroken flat plate at least 8×6 cells, and the countdown stack fits it.
5. Sound in all nine poses under the app's real `reeling` and tuck.
6. The head block owns its columns, so a nod cannot delete a non-head pixel.

Both validators are in `tools/` and all five pass every test. Note that test 5
found real defects during authoring: two candidates originally had the head
sharing columns with the shell, and a nod tore pixels out of the silhouette. That
is what the check exists for.

## Open decisions for the owner

These are yours, not the art's:

1. **Countdown vs. head.** If you want the reference's chunky head, the countdown
   must give up space — smaller digits, or a plate outside the shell. Which
   matters more?
2. **Naturalistic or mascot?** Realist is more tortoise; Mascot and Storybook are
   more toy. This is a taste call about the app's character.
3. **Is the keyline sacred?** Flat drops the dark outline entirely. It is the
   boldest at small sizes and the least like the current art.
4. **Phase colour placement.** Ember puts it on the shell's ring, so a blue
   session gives you a blue-shelled tortoise. The others keep it thin.
5. **Sleep rule.** Realist needs `TortoisePose.tucked` to find the shell rim
   instead of a hardcoded column 13. A one-function change, but it is code.

## Deliverable matrix

| Type | Path | Purpose |
| --- | --- | --- |
| Review sheet | `previews/tortoise-alternatives-<phase>.png` | The decision artefact |
| Lineup | `previews/lineup-<phase>.png` | Five bare sprites side by side |
| Zoom | `previews/zoom-<id>-<phase>.png` | One candidate, countdown and bare |
| Single sprite | `previews/<id>-{overlay,bare}-<phase>.png` | Overlay-size, both states |
| Art source | `tools/variants.py` | The grids, in the app's own format |
| Notes | `notes/design-notes.md` | Per-candidate grids, plate maths, apply steps |
| Expo-ready grids | `exports/` | Copy-paste blocks per candidate |

`<phase>` is `focus`, `short` or `long`.

## Provenance and reproducibility

All pixels are drawn by `tools/render_sheet.py`, `render_lineup.py` and
`render_zoom.py` from the grids in `tools/variants.py`, using the app's own pixel
font and countdown layout mirrored in `tools/pixelkit.py`. No generative image
provider was used and no third-party image tooling is installed in this
environment, so every preview is deterministic: rerunning the commands produces
byte-identical PNGs. Nothing here is a trace of an external model.
