#!/usr/bin/env python3
"""Author tortoise grids from an outline plus patches, with every width asserted.

Hand-writing 16 strings is how you ship a row that is 17 characters wide, or a
head that floats free of the body. This builds a grid from named row specs and
refuses to emit anything malformed.

    from shape import Shape
    s = Shape()
    s.row(1, "..." + "#####" + "." * 8)
    s.rows(4, 10, "#s" + "o" * 9 + "s#", suffix=lambda y: "hhe." if y == 7 else "....")
    s.check()          # raises on any width or connectivity problem
    print(s.text())

`check()` runs the same structural rules as variants.validate(), so a grid that
passes here is a grid the app's own tests will accept.
"""

import sys

HERE = __file__.rsplit("/", 1)[0]
sys.path.insert(0, HERE)

import variants as V  # noqa: E402

W = H = 16


class Shape:
    def __init__(self):
        self.grid = [["."] * W for _ in range(H)]

    def row(self, y, text, at=0):
        """Place one row of legend characters at column `at`."""
        assert 0 <= y < H, f"row {y} out of range"
        assert at + len(text) <= W, f"row {y} overflows: {at}+{len(text)} > {W}: {text!r}"
        for i, ch in enumerate(text):
            assert ch in V.LEGEND, f"row {y} has unknown cell {ch!r}"
            self.grid[y][at + i] = ch
        return self

    def rows(self, y0, y1, prefix, suffix=""):
        """Fill rows y0..y1 inclusive with prefix at x0 and suffix at the far right."""
        for y in range(y0, y1 + 1):
            self.row(y, prefix + "." * (W - len(prefix) - len(suffix)) + suffix)
        return self

    def put(self, x, y, ch):
        assert ch in V.LEGEND, ch
        self.grid[y][x] = ch
        return self

    def text(self):
        return ["".join(r) for r in self.grid]

    def check(self, name="shape", plate=True):
        rows = self.text()
        problems = []
        for y, row in enumerate(rows):
            if len(row) != W:
                problems.append(f"row {y} is {len(row)} wide")
        if problems:
            raise AssertionError(f"{name}: " + "; ".join(problems))

        at = lambda x, y: rows[y][x]
        inked = [(x, y) for y in range(H) for x in range(W) if at(x, y) != "."]
        if not inked:
            raise AssertionError(f"{name}: empty grid")
        seen, stack = {inked[0]}, [inked[0]]
        while stack:
            x, y = stack.pop()
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                n = (x + dx, y + dy)
                if 0 <= n[0] < W and 0 <= n[1] < H and at(*n) != "." and n not in seen:
                    seen.add(n)
                    stack.append(n)
        orphans = [p for p in inked if p not in seen]
        if orphans:
            raise AssertionError(f"{name}: disconnected pixels {orphans}")

        eyes = [(x, y) for y in range(H) for x in range(W) if at(x, y) == "e"]
        if not eyes:
            raise AssertionError(f"{name}: no eye")
        for x, y in eyes:
            neighbours = [at(x + dx, y + dy) if 0 <= x + dx < W and 0 <= y + dy < H else "."
                          for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            if "h" not in neighbours:
                raise AssertionError(f"{name}: eye at ({x},{y}) touches no skin")

        if plate:
            rect = V.find_plate_rect(rows)
            needed_h, needed_w, have_w, have_h = V.content_size(rect)
            if rect[2] < V.MIN_PLATE_W or rect[3] < V.MIN_PLATE_H:
                raise AssertionError(
                    f"{name}: largest flat area is {rect[2]}x{rect[3]} at ({rect[0]},{rect[1]}), "
                    f"needs {V.MIN_PLATE_W}x{V.MIN_PLATE_H}")
            if needed_h > have_h or needed_w > have_w:
                raise AssertionError(
                    f"{name}: countdown needs {needed_h}x{needed_w}px, the {rect[2]}x{rect[3]} "
                    f"plate at ({rect[0]},{rect[1]}) offers {have_h}x{have_w}px")
        return rows


if __name__ == "__main__":
    # A worked example: the shell V1 needs, with a mouth notch in the head.
    s = Shape()
    s.row(1, "..." + "#####" + "." * 8)
    s.row(2, "..#" + "s" + "o" * 5 + "##" + "." * 5)
    s.row(3, ".#" + "s" + "o" * 6 + "#" + "." * 6)
    s.row(4, "#s" + "o" * 8 + "s#" + "....")
    s.row(5, "#s" + "o" * 8 + "s#" + ".hhh")
    s.row(6, "#s" + "o" * 8 + "s#" + ".hhe")
    s.row(7, "#s" + "o" * 8 + "s#" + ".hhh")
    s.row(8, "#s" + "o" * 8 + "s#" + "hh..")
    s.row(9, "#s" + "o" * 8 + "s#" + "hh..")
    s.row(10, ".." + "#########" + "." * 5)
    s.rows(11, 13, "..hh..hh")
    for row in s.check("example"):
        print(row)
