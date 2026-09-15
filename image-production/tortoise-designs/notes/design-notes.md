# Tortoise design alternatives

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


### 1. Mascot — `v1-mascot`

Compact domed shell with a heavy dark keyline and a chunky head overlapping the shell's front edge. Closest to the current art in spirit, but a rounder creature than a box with parts beside it.

**Tradeoff.** Head size is capped by the countdown plate, so he reads as a mascot rather than a naturalistic tortoise.

```
    0123456789012345
  0 ................
  1 ...#####........
  2 ..#sooooo##.....
  3 .#soooooo#......
  4 #soooooooos#....
  5 #soooooooos#....
  6 #soooooooos#hhh.
  7 #soooooooos#hhe.
  8 #soooooooos#hhh.
  9 #soooooooos#hh..
 10 #soooooooos#hh..
 11 ..#########.....
 12 ..hh..hh........
 13 ..hh..hh........
 14 ..hh..hh........
 15 ................
```

* Countdown plate: **8x7 cells** at (2,4) — the overlay needs 60px tall and 85px across; this plate offers 91px by 104px.
* Structural check: sound
* Sleep rule: the app's current fixed-column tuck works unchanged.
* Preview: `previews/zoom-v1-mascot-focus.png`

---

### 2. Realist — `v2-realist`

Wide low shell with a two-tone upper dome and pale plastron between the legs. The most naturalistic of the five.

**Tradeoff.** Two-tone scutes are the first detail to vanish at menu-bar size, where the shell flattens to one tone.

```
    0123456789012345
  0 ................
  1 ...#####........
  2 ..#opppo#.......
  3 .#opppppo#......
  4 #opppppppo#.....
  5 #opooooooop#....
  6 #opooooooop#....
  7 #opooooooop#....
  8 #opooooooop#hhe.
  9 #opooooooop#hhh.
 10 #opooooooop#hh..
 11 .##########sh...
 12 ..kkk..kkk......
 13 ..kkk..kkk......
 14 ..kkk..kkk......
 15 ................
```

* Countdown plate: **10x6 cells** at (1,5) — the overlay needs 60px tall and 85px across; this plate offers 78px by 130px.
* Structural check: sound
* Sleep rule: the app's current fixed-column tuck needs the rim-aware version.
* Preview: `previews/zoom-v2-realist-focus.png`

---

### 3. Flat — `v3-flat`

No dark outline: a cool grey rim, one shade step, a symmetrical shell. Modern app-icon language, and the boldest silhouette of the five at menu-bar size.

**Tradeoff.** Abandons the pixel-art keyline that ties him to the wordmark and the README banners.

```
    0123456789012345
  0 ................
  1 ....########....
  2 ..##ssssssss##..
  3 .#soooooooos#...
  4 #sooooooooos#...
  5 #sooooooooos#...
  6 #sooooooooos#.hh
  7 #sooooooooos#hhe
  8 #sooooooooos#hh.
  9 #sooooooooos#hh.
 10 #sooooooooos#hh.
 11 ..##ssssssss##..
 12 ....hhhh..hhhh..
 13 ....hhhh..hhhh..
 14 ....hhhh..hhhh..
 15 ................
```

* Countdown plate: **9x7 cells** at (2,4) — the overlay needs 60px tall and 85px across; this plate offers 91px by 117px.
* Structural check: sound
* Sleep rule: the app's current fixed-column tuck works unchanged.
* Preview: `previews/zoom-v3-flat-focus.png`

---

### 4. Ember — `v4-ember`

Dark slate shell, a phase-coloured ring around the whole shell, pale mint skin. Built to stay readable on a dark desktop, where the current brown can sink without trace.

**Tradeoff.** The phase colour is now doing double duty as the shell's decoration, so a blue session makes him a blue-shelled tortoise.

```
    0123456789012345
  0 ................
  1 ...#####........
  2 ..##sssss##.....
  3 .#soooooos#.....
  4 #soooooooos#....
  5 #soooooooos#....
  6 #soooooooos#.hhh
  7 #soooooooos#hhhe
  8 #soooooooos#hhe.
  9 #soooooooos#hh..
 10 #soooooooos#hh..
 11 ..#########.....
 12 ..hhh.hhh.......
 13 ..hhh.hhh.......
 14 ..hhh.hhh.......
 15 ................
```

* Countdown plate: **8x7 cells** at (2,4) — the overlay needs 60px tall and 85px across; this plate offers 91px by 104px.
* Structural check: sound
* Sleep rule: the app's current fixed-column tuck works unchanged.
* Preview: `previews/zoom-v4-ember-focus.png`

---

### 5. Storybook — `v5-storybook`

Cream and tan, coral cheek, oversized head, stubby tail. The most toy-like and the friendliest of the five.

**Tradeoff.** Low contrast between shell tones, so the shell reads flatter than the others.

```
    0123456789012345
  0 ................
  1 ...####.........
  2 .##soos##.......
  3 #sooooooos#.....
  4 #soooooooos#....
  5 #soooooooos#....
  6 #soooooooos#.hhh
  7 #soooooooos#hhrh
  8 #soooooooos#hhee
  9 #soooooooos#hhh.
 10 #soooooooos#hh..
 11 ..#########.....
 12 ..hhh.hhh.......
 13 ..hhh.hhh.......
 14 ..hhh.hhh.......
 15 ................
```

* Countdown plate: **8x7 cells** at (2,4) — the overlay needs 60px tall and 85px across; this plate offers 91px by 104px.
* Structural check: sound
* Sleep rule: the app's current fixed-column tuck works unchanged.
* Preview: `previews/zoom-v5-storybook-focus.png`

---

---

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
swiftc -Onone -o /tmp/posecheck ../../Sources/Core/TortoiseSprite.swift \
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
