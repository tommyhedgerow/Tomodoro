import Foundation

/// A single cell of the 16x16 tortoise bitmap.
enum TortoiseCell: Character {
    case empty   = "."
    case outline = "#"   // bold dark keyline, as in the reference art
    case shell   = "o"   // shell body
    case trim    = "s"   // decorative band inside the keyline; carries the phase colour
    case skin    = "h"   // head, neck, feet
    case eye     = "e"
}

/// Straight RGBA, kept free of SwiftUI/AppKit so this file stays portable and testable.
struct RGBA: Equatable {
    var r: Double, g: Double, b: Double, a: Double

    static func rgb(_ r: Double, _ g: Double, _ b: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: 1) }

    /// Blend toward black (amount 0...1).
    func darkened(_ amount: Double) -> RGBA {
        RGBA(r: r * (1 - amount), g: g * (1 - amount), b: b * (1 - amount), a: a)
    }

    /// Blend toward white (amount 0...1).
    func lightened(_ amount: Double) -> RGBA {
        RGBA(r: r + (1 - r) * amount, g: g + (1 - g) * amount, b: b + (1 - b) * amount, a: a)
    }

    func withAlpha(_ value: Double) -> RGBA { RGBA(r: r, g: g, b: b, a: value) }
}

/// The three Pomodoro session states.
enum SessionPhase: String, CaseIterable, Codable {
    case focus
    case shortBreak
    case longBreak

    var baseColor: RGBA {
        switch self {
        case .focus:      return .rgb(0.91, 0.24, 0.22)   // red
        case .shortBreak: return .rgb(0.20, 0.78, 0.36)   // green
        case .longBreak:  return .rgb(0.20, 0.52, 0.95)   // blue
        }
    }

    var displayName: String {
        switch self {
        case .focus:      return "Focus"
        case .shortBreak: return "Short Break"
        case .longBreak:  return "Long Break"
        }
    }

    var shortName: String {
        switch self {
        case .focus:      return "Focus"
        case .shortBreak: return "Short"
        case .longBreak:  return "Long"
        }
    }
}

/// How the tortoise is coloured.
///
/// The reference art is a brown tortoise with bright green skin and a heavy dark
/// keyline, so that is the default. The phase colour still has to be legible, so
/// it rides on the shell trim band (and the countdown digits in the overlay).
enum TortoiseStyle: String, CaseIterable, Codable {
    /// Reference-inspired: natural brown shell, green skin, phase-coloured trim.
    case natural
    /// Whole body takes the phase colour. The original all-over tint.
    case tinted

    var displayName: String {
        switch self {
        case .natural: return "Natural"
        case .tinted:  return "Phase tint"
        }
    }
}

/// Colour set for one rendering of the tortoise.
struct TortoisePalette {
    var outline: RGBA
    var shell: RGBA
    var trim: RGBA
    var skin: RGBA
    var eye: RGBA
    /// Flat colour behind the countdown digits, for legibility on the shell.
    var plate: RGBA
    /// Countdown digits and progress fill.
    var ink: RGBA

    /// Sampled from the reference image.
    static let referenceShell = RGBA.rgb(0.631, 0.427, 0.157)   // rgb(161, 109, 40)
    static let referenceSkin  = RGBA.rgb(0.624, 0.902, 0.341)   // rgb(159, 230, 87)
    static let referenceInk   = RGBA.rgb(0.075, 0.063, 0.047)   // near-black keyline

    static func make(style: TortoiseStyle, phase: SessionPhase) -> TortoisePalette {
        switch style {
        case .natural:
            return TortoisePalette(
                outline: referenceInk,
                shell: referenceShell,
                trim: phase.baseColor,
                skin: referenceSkin,
                eye: referenceInk,
                // A darker brown so the digits sit on their own plate.
                plate: referenceShell.darkened(0.45),
                ink: .rgb(0.99, 0.97, 0.93)
            )
        case .tinted:
            let base = phase.baseColor
            return TortoisePalette(
                outline: base.darkened(0.62),
                shell: base,
                trim: base.lightened(0.55),
                skin: base.lightened(0.45),
                eye: .rgb(0.10, 0.09, 0.11),
                plate: base.darkened(0.30),
                ink: .rgb(0.99, 0.97, 0.93)
            )
        }
    }

    func color(for cell: TortoiseCell) -> RGBA? {
        switch cell {
        case .empty:   return nil
        case .outline: return outline
        case .shell:   return shell
        case .trim:    return trim
        case .skin:    return skin
        case .eye:     return eye
        }
    }
}

/// The 16x16 pixel-art tortoise: side view facing right, heavy keyline, big round
/// head and stubby feet, after the reference art.
enum TortoiseSprite {
    static let size = 16

    /// 16 rows of exactly 16 characters, top to bottom.
    /// Legend: "." empty, "#" keyline, "o" shell, "s" trim, "h" skin, "e" eye.
    static let rows: [String] = [
        "................",
        "....####........",
        "..##soos##......",
        ".#soooooos#.....",
        "#soooooooos#....",
        "#soooooooos#h...",
        "#soooooooos#hhhh",
        "#soooooooos#hheh",
        "#soooooooos#hhh.",
        "#soooooooos#h...",
        ".#soooooos#.....",
        "..########......",
        "...hh..hh.......",
        "...hh..hh.......",
        "..hhh..hhh......",
        "................",
    ]

    /// Row-major cells, validated once at load.
    static let grid: [[TortoiseCell]] = {
        precondition(rows.count == size, "tortoise sprite must have 16 rows")
        return rows.map { row -> [TortoiseCell] in
            precondition(row.count == size, "sprite row must be 16 chars, got \(row.count): \(row)")
            return row.map { TortoiseCell(rawValue: $0) ?? .empty }
        }
    }()

    /// Flat area of the shell reserved for the countdown, in sprite cells.
    /// Kept free of trim and scutes so digits stay readable.
    static let textArea = (x: 2, y: 4, width: 8, height: 6)

    static func cell(x: Int, y: Int) -> TortoiseCell {
        guard x >= 0, x < size, y >= 0, y < size else { return .empty }
        return grid[y][x]
    }

    /// True when the sprite covers this cell, used for click-through hit testing.
    static func isOpaque(x: Int, y: Int) -> Bool { cell(x: x, y: y) != .empty }

    /// Flat RGBA pixel buffer at 1 pixel per cell, for icon generation.
    static func pixelBuffer(palette: TortoisePalette) -> [RGBA?] {
        var out: [RGBA?] = []
        out.reserveCapacity(size * size)
        for y in 0..<size {
            for x in 0..<size {
                out.append(palette.color(for: cell(x: x, y: y)))
            }
        }
        return out
    }

    // MARK: - Structural validation

    /// Checks the sprite is well formed. Exercised by the test suite so art edits
    /// cannot silently detach a limb or punch a hole in the shell.
    static func validate() -> [String] {
        var problems: [String] = []

        if rows.count != size {
            problems.append("expected 16 rows, found \(rows.count)")
        }
        for (i, row) in rows.enumerated() where row.count != size {
            problems.append("row \(i) has \(row.count) columns, expected 16")
        }
        guard problems.isEmpty else { return problems }

        if !grid.flatMap({ $0 }).contains(.eye) {
            problems.append("sprite has no eye pixel")
        }

        // The countdown sits on the shell; the reserved area must be solid body.
        let area = textArea
        for y in area.y..<(area.y + area.height) {
            for x in area.x..<(area.x + area.width) where cell(x: x, y: y) != .shell {
                problems.append("countdown area is not plain shell at (\(x),\(y))")
            }
        }

        // Every inked pixel must be reachable from the others over 4-neighbourhoods,
        // otherwise a limb or the head has floated off the body.
        var start: (Int, Int)?
        outer: for y in 0..<size {
            for x in 0..<size where cell(x: x, y: y) != .empty {
                start = (x, y); break outer
            }
        }
        guard let seed = start else { return ["sprite is completely empty"] }

        var seen = Set<[Int]>()
        var stack = [seed]
        seen.insert([seed.0, seed.1])
        while let (x, y) = stack.popLast() {
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let nx = x + dx, ny = y + dy
                guard nx >= 0, nx < size, ny >= 0, ny < size else { continue }
                guard cell(x: nx, y: ny) != .empty else { continue }
                guard !seen.contains([nx, ny]) else { continue }
                seen.insert([nx, ny])
                stack.append((nx, ny))
            }
        }

        let inked = (0..<size).flatMap { y in (0..<size).map { (x: $0, y: y) } }
            .filter { cell(x: $0.x, y: $0.y) != .empty }
        let orphans = inked.filter { !seen.contains([$0.x, $0.y]) }
        if !orphans.isEmpty {
            let list = orphans.map { "(\($0.x),\($0.y))" }.joined(separator: " ")
            problems.append("disconnected pixels at \(list)")
        }

        // The eye must be embedded in the head, not floating on transparency.
        for y in 0..<size {
            for x in 0..<size where cell(x: x, y: y) == .eye {
                let neighbours = [(1, 0), (-1, 0), (0, 1), (0, -1)]
                    .map { cell(x: x + $0.0, y: y + $0.1) }
                if !neighbours.contains(.skin) {
                    problems.append("eye at (\(x),\(y)) does not touch any skin pixel")
                }
            }
        }

        return problems
    }

    /// ASCII rendering, handy for tests and terminal debugging.
    static func asciiArt() -> String {
        rows.enumerated()
            .map { String(format: "%2d ", $0.offset) + $0.element }
            .joined(separator: "\n")
    }
}
