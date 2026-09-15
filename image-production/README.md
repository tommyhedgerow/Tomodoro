# image-production

Design exploration assets for Tomodoro's tortoise mascot. Everything here is
generated from source that lives in this folder; nothing is imported from
elsewhere except the app's own art, which is the thing being redesigned.

## Start here

**`tortoise-designs/notes/design-notes.md`** — the five candidate tortoises, their
grids, their tradeoffs, and how to apply one.
**`tortoise-designs/notes/design-brief.md`** — the brief, the measured
constraints, the acceptance tests, and the decisions left to the owner.
**`tortoise-designs/previews/tortoise-alternatives-focus.png`** — the review sheet.

## Layout

```
image-production/
  tools/                      generators; all output is reproducible from here
    variants.py               the five grids + palettes + structural validation
    pixelkit.py               stdlib PNG writer, the app's pixel font and countdown layout
    shape.py                  grid builder that asserts width and connectivity
    render_sheet.py           the review sheet and per-candidate previews
    render_lineup.py          five bare sprites side by side
    render_zoom.py            one candidate, large, with and without the countdown
    gen_posecheck.py          generates main.swift from variants.py
    main.swift                GENERATED - the Swift drop-in checker
    write_notes.py            generates the design notes
    write_exports.py          generates the paste-ready blocks
    gridmap.py                print a grid with rulers and plate analysis
  tortoise-designs/
    notes/                    brief and design notes
    previews/                 all rendered PNGs
    exports/                  per-candidate Swift rows and palettes
```

## Why the art is Python text, not PNG

The tortoise is not an image file in this app. It is 16 rows of 16 characters in
`Sources/Core/TortoisePose.swift`, and the app renders it. A design alternative
therefore has to *be* a 16×16 grid — so the canonical source here is
`tools/variants.py`, and the PNGs are derived from it.

## Reproducing everything

```sh
cd image-production/tools

python3 variants.py check                 # structural rules, Python mirror
python3 gen_posecheck.py                  # regenerate main.swift
swiftc -Onone -o /tmp/posecheck \
       ../../Sources/Core/TortoiseSprite.swift \
       ../../Sources/Core/TortoisePose.swift main.swift && /tmp/posecheck

python3 render_sheet.py --phase focus --individual
python3 render_lineup.py --cell 26
python3 render_zoom.py --all
python3 write_notes.py
python3 write_exports.py
```

Use `--phase short` or `--phase long` to render a different session colour.

## Determinism and provenance

Every pixel is drawn by these scripts from `variants.py`, using the app's own
pixel font and countdown geometry mirrored in `pixelkit.py`. No generative image
provider was used, and none is configured in this environment. Rerunning the
commands produces byte-identical PNGs, so a preview can always be traced back to
the grid and palette that produced it.

## A note on the interpreter

`/usr/bin/python3` on this machine is Apple's shim and started failing partway
through this work with an Xcode licence prompt. The scripts are stdlib-only and
run on any Python 3.8+, for example
`/Library/Developer/CommandLineTools/usr/bin/python3`.
