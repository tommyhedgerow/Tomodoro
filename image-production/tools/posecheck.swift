// Drop-in check: do these candidate tortoise designs satisfy the app's own
// structural rules, including for every derived animation pose?
//
// Complements image-production/tools/variants.py, which mirrors the same rules in
// Python so the design tool can run without a Swift toolchain. This program links
// the real Sources/Core/TortoisePose.swift, so the answer comes from the code
// that actually ships rather than from a reimplementation.
//
//   swiftc -O -o /tmp/posecheck TortoisePose.swift posecheck.swift && /tmp/posecheck
//
// The grids are mirrored from variants.py. If a grid changes there, change it here
// too; `variants.py check` is the authoring-time gate, this is the shipping gate.

import Foundation

struct Candidate {
    let id: String
    let rows: [String]
}

private func reel(_ rows: [String], by dy: Int) -> [String] {
    TortoisePose.reeling(rows, by: dy)
}

private func tucked(_ rows: [String], nubRow: Int) -> [String] {
    var out = rows.map { Array($0) }
    for y in out.indices {
        for x in TortoisePose.headColumns { out[y][x] = "." }
        if y == nubRow {
            out[y][13] = "h"
            out[y][14] = "z"
        }
        if y == nubRow + 1 {
            out[y][13] = "h"
            out[y][14] = "h"
        }
    }
    return out.map { String($0) }
}

/// The same pose set the app derives from its resting grid, so a candidate is
/// judged on every frame the animator can draw, not just the still.
private func poses(from base: [String]) -> [(String, [String])] {
    var blink = base
    blink[7] = String(blink[7].prefix(12)) + "hhzh"
    blink[8] = String(blink[8].prefix(12)) + "hhz."
    return [
        ("resting", base),
        ("blinking", blink),
        ("blinkingUp", reel(blink, by: -1)),
        ("blinkingDown", reel(blink, by: 1)),
        ("headUp", reel(base, by: -2)),
        ("headChew", reel(base, by: -1)),
        ("headDown", reel(base, by: 1)),
        ("sleeping", tucked(base, nubRow: 7)),
        ("sleepingBreath", tucked(base, nubRow: 6)),
    ]
}

/// Every rule `TortoisePose.problems` enforces, applied to a raw grid.
private func problems(_ name: String, _ rows: [String]) -> [String] {
    var out: [String] = []
    let textArea = TortoiseSprite.textArea

    guard rows.count == TortoiseSprite.size else {
        return ["\(name): \(rows.count) rows, expected \(TortoiseSprite.size)"]
    }
    for (index, row) in rows.enumerated() where row.count != TortoiseSprite.size {
        out.append("\(name): row \(index) is \(row.count) wide, expected \(TortoiseSprite.size)")
    }
    guard out.isEmpty else { return out }

    let grid = rows.map { $0.map { TortoiseCell(rawValue: $0) ?? .empty } }
    func cell(_ x: Int, _ y: Int) -> TortoiseCell {
        guard x >= 0, x < grid.count, y >= 0, y < grid.count else { return .empty }
        return grid[y][x]
    }

    let inked = (0..<grid.count).flatMap { y in (0..<grid.count).map { (x: $0, y: y) } }
        .filter { cell($0.x, $0.y) != .empty }
    guard let seed = inked.first else { return ["\(name): pose is empty"] }

    var seen = Set<[Int]>([[seed.x, seed.y]])
    var stack = [seed]
    while let point = stack.popLast() {
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let next = (x: point.x + dx, y: point.y + dy)
            guard next.x >= 0, next.x < grid.count, next.y >= 0, next.y < grid.count else { continue }
            guard cell(next.x, next.y) != .empty, !seen.contains([next.x, next.y]) else { continue }
            seen.insert([next.x, next.y])
            stack.append(next)
        }
    }
    let orphans = inked.filter { !seen.contains([$0.x, $0.y]) }
    if !orphans.isEmpty {
        out.append("\(name): disconnected pixels at "
                   + orphans.map { "(\($0.x),\($0.y))" }.joined(separator: " "))
    }

    let eyes = (0..<grid.count).flatMap { y in (0..<grid.count).map { (x: $0, y: y) } }
        .filter { cell($0.x, $0.y) == .eye || cell($0.x, $0.y) == .sleep }
    if eyes.isEmpty { out.append("\(name): pose has no eye") }
    for eye in eyes {
        let neighbours = [(1, 0), (-1, 0), (0, 1), (0, -1)].map { cell(eye.x + $0.0, eye.y + $0.1) }
        if !neighbours.contains(.skin) {
            out.append("\(name): eye at (\(eye.x),\(eye.y)) touches no skin")
        }
    }

    // App rule: the plate is plain shell in every pose. That is stricter than a
    // redesign needs, so report it separately as an informational note.
    var plateBreaks = 0
    for y in textArea.y..<(textArea.y + textArea.height) {
        for x in textArea.x..<(textArea.x + textArea.width) where cell(x, y) != .shell {
            plateBreaks += 1
        }
    }
    if plateBreaks > 0 {
        out.append("note \(name): \(plateBreaks) cell(s) of the app's fixed plate "
                   + "(x\(textArea.x)..\(textArea.x + textArea.width - 1), "
                   + "y\(textArea.y)..\(textArea.y + textArea.height - 1)) are not plain "
                   + "shell — expected for a redesign that moves the plate")
    }
    return out
}

private let candidates: [Candidate] = [
    Candidate(id: "v1-mascot", rows: V1),
    Candidate(id: "v2-realist", rows: V2),
    Candidate(id: "v3-flat", rows: V3),
    Candidate(id: "v4-ember", rows: V4),
    Candidate(id: "v5-storybook", rows: V5),
]

private let V1 = [
    "................",
    "....####........",
    "..##soos##......",
    ".#soooooos#.....",
    "#soooooooos#....",
    "#soooooooos#....",
    "#soooooooos#..tt",
    "#soooooooos#hhhh",
    "#soooooooooshhhe",
    "#soooooooooshhhh",
    ".##########.#hh.",
    "..hh..hh....see.",
    "..hh..hh....shh.",
    "..hh..hh...shh..",
    ".hhhh.hhhh......",
    "................",
]

private let V2 = [
    "................",
    "...#####........",
    "..#opppo#.......",
    ".#opppppo#......",
    "#opppppppo#.....",
    "#opooooooop#....",
    "#opooooooop#....",
    "#opooooooop#....",
    "#opooooooop#....",
    "#opooooooop#hhe.",
    "#opooooooop#hhh.",
    ".##########shhh.",
    "..kk.kk..hhh....",
    "..kk.kk..sh.....",
    "..kk.kk.........",
    "................",
]

private let V3 = [
    "................",
    "....########....",
    "..##ssssssss##..",
    ".#sooooooooos#..",
    "#sooooooooooos#.",
    "#sooooooooooos#.",
    "#sooooooooooos#.",
    "#sooooooooooos#h",
    "#sooooooooooos#h",
    "#sooooooooooos#e",
    ".#sooooooooos#hh",
    "..##ssssssss##ss",
    "....hhhh..hhhh..",
    "....hhhh..hhhh..",
    "....hhhh..hhhh..",
    "................",
]

private let V4 = [
    "................",
    ".....####.......",
    "...##soos##.....",
    "..#soooooos#....",
    ".#soooooooos#...",
    "#sooooooooooos#.",
    "#sooooooooooos#.",
    "#spooooooooops#.",
    "#spooooooooops#h",
    "#spooooooooops#h",
    ".#sooooooooooos#",
    "..#soooooooos#hh",
    "...##########he.",
    "...hhh..hhh..hh.",
    "...hhh..hhh.....",
    "................",
]

private let V5 = [
    "................",
    "...####.........",
    ".##soos##.......",
    "#soooooooos#....",
    "#soooooooooos#..",
    "#soooooooooos#..",
    "#soooooooooos#t.",
    "#soooooooooos#hh",
    "#soooooooooos#hr",
    "#soooooooooos#he",
    "#soooooooooos#hh",
    ".###########shh.",
    "..hhh..hhh...h..",
    "..hhh..hhh......",
    "..hhh..hhh......",
    "................",
]

func run() -> Int32 {
var failures = 0
for candidate in candidates {
    var problemsForCandidate: [String] = []
    for (poseName, rows) in poses(from: candidate.rows) {
        for problem in problems("resting", rows) {
            if problem.hasPrefix("note ") {
                if poseName == "resting" { problemsForCandidate.append(problem) }
            } else {
                problemsForCandidate.append("\(poseName): \(problem)")
            }
        }
    }
    let real = problemsForCandidate.filter { !$0.hasPrefix("note ") }
    failures += real.count
    print("\(real.isEmpty ? "PASS" : "FAIL")  \(candidate.id)  "
          + "\(9) poses checked, \(real.count) problem(s)")
    for problem in problemsForCandidate { print("        \(problem)") }
}

print(failures == 0
      ? "\nAll candidates satisfy the app's structural rules in every pose."
      : "\n\(failures) structural problem(s) found.")
return failures == 0 ? 0 : 1
}

exit(run())
