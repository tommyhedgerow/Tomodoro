#!/usr/bin/env python3
"""Print a design grid with column rulers, plus the plate analysis.

Authoring 16x16 pixel art blind is how you end up with a head that disconnects
when it nods, so this lays the facts out: where every cell sits, which flat
rectangle the countdown will occupy, and how many pixels each legend character
accounts for.

    python3 gridmap.py v1-mascot
    python3 gridmap.py --all
"""

import sys

HERE = __file__.rsplit("/", 1)[0]
sys.path.insert(0, HERE)

import variants as V  # noqa: E402


def show(variant):
    rows = variant["rows"]
    print(f"== {variant['id']}  ({variant['name']})")
    print("    " + "".join(str(x % 10) for x in range(V.W)))
    for y, row in enumerate(rows):
        print(f"{y:3d} {row}")
    print("    " + "".join(str(x % 10) for x in range(V.W)))

    counts = {}
    for row in rows:
        for ch in row:
            counts[ch] = counts.get(ch, 0) + 1
    legend = " ".join(f"{ch}={counts.get(ch, 0)}" for ch in sorted(counts) if ch != ".")
    print(f"    inked {sum(c for ch, c in counts.items() if ch != '.')} px   {legend}")

    rect = V.find_plate_rect(rows)
    needed_h, needed_w, have_w, have_h = V.content_size(rect)
    print(f"    countdown plate {rect[2]}x{rect[3]} at ({rect[0]},{rect[1]})"
          f"   stack needs {needed_h}x{needed_w}px, plate offers {have_h}x{have_w}px")

    # Where the flat shell is, so a trim ring that pinches the plate is obvious.
    print("    flat shell map ( # flat, : not flat ):")
    print("        " + "".join(str(x % 10) for x in range(V.W)))
    for y, row in enumerate(rows):
        marks = "".join("#" if ch in V.PLATE_CELLS else ":" for ch in row)
        print(f"    {y:3d} {marks}")

    problems = V.validate(variant)
    print("    " + ("structurally sound" if not problems else "PROBLEMS:"))
    for problem in problems:
        print("      ! " + problem)
    print()


def main():
    args = sys.argv[1:]
    if not args or args[0] == "--all":
        for variant in V.VARIANTS:
            show(variant)
        return 0
    for variant in V.VARIANTS:
        if variant["id"] in args or variant["name"].lower() in [a.lower() for a in args]:
            show(variant)
    return 0


if __name__ == "__main__":
    sys.exit(main())
