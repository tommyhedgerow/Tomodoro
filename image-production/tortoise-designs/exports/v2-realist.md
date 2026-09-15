## Realist — `v2-realist`

Wide low shell with a two-tone upper dome and pale plastron between the legs. The most naturalistic of the five.

**Tradeoff.** Two-tone scutes are the first detail to vanish at menu-bar size, where the shell flattens to one tone.

```swift
/// Realist — v2-realist
/// Paste over TortoisePose.baseRows.
static let baseRows: [String] = [
    "................",
    "...#####........",
    "..#opppo#.......",
    ".#opppppo#......",
    "#opppppppo#.....",
    "#opooooooop#....",
    "#opooooooop#....",
    "#opooooooop#....",
    "#opooooooop#hhe.",
    "#opooooooop#hhh.",
    "#opooooooop#hh..",
    ".##########sh...",
    "..kkk..kkk......",
    "..kkk..kkk......",
    "..kkk..kkk......",
    "................",
]
```

Countdown plate rect: `(x: 1, y: 5, width: 10, height: 6)`

Palette:

| Cell | Meaning | RGBA | Hex |
| --- | --- | --- | --- |
| `#` | keyline / outline | (0.180, 0.129, 0.086) | `#2E2116` |
| `o` | shell body | (0.741, 0.549, 0.290) | `#BD8C4A` |
| `p` | second shell tone | (0.855, 0.686, 0.400) | `#DAAF66` |
| `k` | plastron | (0.851, 0.780, 0.612) | `#D9C79C` |
| `h` | skin | (0.435, 0.714, 0.243) | `#6FB63E` |
| `e` | eye | (0.180, 0.129, 0.086) | `#2E2116` |
| `r` | cheek | (0.900, 0.600, 0.400) | `#E69966` |
| `t` | tail | (0.435, 0.714, 0.243) | `#6FB63E` |
| — | countdown plate | (0.902, 0.829, 0.730) | `#E6D3BA` |
