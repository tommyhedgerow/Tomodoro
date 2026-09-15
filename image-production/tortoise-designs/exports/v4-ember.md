## Ember — `v4-ember`

Dark slate shell, a phase-coloured ring around the whole shell, pale mint skin. Built to stay readable on a dark desktop, where the current brown can sink without trace.

**Tradeoff.** The phase colour is now doing double duty as the shell's decoration, so a blue session makes him a blue-shelled tortoise.

```swift
/// Ember — v4-ember
/// Paste over TortoisePose.baseRows.
static let baseRows: [String] = [
    "................",
    "...#####........",
    "..##sssss##.....",
    ".#soooooos#.....",
    "#soooooooos#....",
    "#soooooooos#....",
    "#soooooooos#.hhh",
    "#soooooooos#hhhe",
    "#soooooooos#hhe.",
    "#soooooooos#hh..",
    "#soooooooos#hh..",
    "..#########.....",
    "..hhh.hhh.......",
    "..hhh.hhh.......",
    "..hhh.hhh.......",
    "................",
]
```

Countdown plate rect: `(x: 2, y: 4, width: 8, height: 7)`

Palette:

| Cell | Meaning | RGBA | Hex |
| --- | --- | --- | --- |
| `#` | keyline / outline | (0.043, 0.055, 0.078) | `#0B0E14` |
| `o` | shell body | (0.149, 0.180, 0.224) | `#262E39` |
| `p` | second shell tone | (0.784, 0.573, 0.290) | `#C8924A` |
| `k` | plastron | (0.302, 0.337, 0.384) | `#4D5662` |
| `h` | skin | (0.722, 0.949, 0.812) | `#B8F2CF` |
| `e` | eye | (0.043, 0.055, 0.078) | `#0B0E14` |
| `r` | cheek | (0.980, 0.700, 0.500) | `#FAB280` |
| `t` | tail | (0.722, 0.949, 0.812) | `#B8F2CF` |
| — | countdown plate | (0.089, 0.108, 0.134) | `#171C22` |
