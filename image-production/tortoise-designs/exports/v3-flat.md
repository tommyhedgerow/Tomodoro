## Flat — `v3-flat`

No dark outline: a cool grey rim, one shade step, a symmetrical shell. Modern app-icon language, and the boldest silhouette of the five at menu-bar size.

**Tradeoff.** Abandons the pixel-art keyline that ties him to the wordmark and the README banners.

```swift
/// Flat — v3-flat
/// Paste over TortoisePose.baseRows.
static let baseRows: [String] = [
    "................",
    "....########....",
    "..##ssssssss##..",
    ".#soooooooos#...",
    "#sooooooooos#...",
    "#sooooooooos#...",
    "#sooooooooos#.hh",
    "#sooooooooos#hhe",
    "#sooooooooos#hh.",
    "#sooooooooos#hh.",
    "#sooooooooos#hh.",
    "..##ssssssss##..",
    "....hhhh..hhhh..",
    "....hhhh..hhhh..",
    "....hhhh..hhhh..",
    "................",
]
```

Countdown plate rect: `(x: 2, y: 4, width: 9, height: 7)`

Palette:

| Cell | Meaning | RGBA | Hex |
| --- | --- | --- | --- |
| `#` | keyline / outline | (0.427, 0.478, 0.541) | `#6D7A8A` |
| `o` | shell body | (0.129, 0.161, 0.208) | `#212935` |
| `p` | second shell tone | (0.200, 0.243, 0.309) | `#333E4F` |
| `k` | plastron | (0.200, 0.243, 0.309) | `#333E4F` |
| `h` | skin | (0.447, 0.870, 0.702) | `#72DEB3` |
| `e` | eye | (0.129, 0.161, 0.208) | `#212935` |
| `r` | cheek | (0.447, 0.870, 0.702) | `#72DEB3` |
| `t` | tail | (0.447, 0.870, 0.702) | `#72DEB3` |
| — | countdown plate | (0.129, 0.161, 0.208) | `#212935` |
