## Mascot — `v1-mascot`

Compact domed shell with a heavy dark keyline and a chunky head overlapping the shell's front edge. Closest to the current art in spirit, but a rounder creature than a box with parts beside it.

**Tradeoff.** Head size is capped by the countdown plate, so he reads as a mascot rather than a naturalistic tortoise.

```swift
/// Mascot — v1-mascot
/// Paste over TortoisePose.baseRows.
static let baseRows: [String] = [
    "................",
    "...#####........",
    "..#sooooo##.....",
    ".#soooooo#......",
    "#soooooooos#....",
    "#soooooooos#....",
    "#soooooooos#hhh.",
    "#soooooooos#hhe.",
    "#soooooooos#hhh.",
    "#soooooooos#hh..",
    "#soooooooos#hh..",
    "..#########.....",
    "..hh..hh........",
    "..hh..hh........",
    "..hh..hh........",
    "................",
]
```

Countdown plate rect: `(x: 2, y: 4, width: 8, height: 7)`

Palette:

| Cell | Meaning | RGBA | Hex |
| --- | --- | --- | --- |
| `#` | keyline / outline | (0.075, 0.063, 0.047) | `#13100C` |
| `o` | shell body | (0.631, 0.427, 0.157) | `#A16D28` |
| `p` | second shell tone | (0.741, 0.549, 0.243) | `#BD8C3E` |
| `k` | plastron | (0.839, 0.741, 0.545) | `#D6BD8B` |
| `h` | skin | (0.624, 0.902, 0.341) | `#9FE657` |
| `e` | eye | (0.075, 0.063, 0.047) | `#13100C` |
| `r` | cheek | (0.980, 0.560, 0.520) | `#FA8F85` |
| `t` | tail | (0.624, 0.902, 0.341) | `#9FE657` |
| — | countdown plate | (0.347, 0.235, 0.086) | `#583C16` |
