import Foundation

/// A single cell of the 16x16 tortoise bitmap.
enum TortoiseCell: Character {
    case empty   = "."
    case outline = "#"   // shell keyline; warm ochre rather than the reference black
    case shell   = "o"   // shell body
    case trim    = "s"   // decorative band inside the keyline; carries the phase colour
    case skin    = "h"   // head, neck, feet
    case eye     = "e"
    /// A closed eye or a sleeping lid. Dark, like the eye, but drawn as a line.
    case sleep   = "z"
    /// The "z" that drifts above a sleeping tortoise. Its own cell rather than the
    /// keyline's, so it keeps a dark ink now that the shell outline is ochre: the
    /// glyph has to read against whatever is behind the floating overlay.
    case sleepGlyph = "Z"
    /// Dandelion foliage the tortoise reaches for. Phase-independent by design:
    /// the phase colour already rides on the trim band and the countdown.
    case leaf    = "L"
    case stem    = "G"
    case petal   = "Y"
    /// Crumbs left at the mouth mid-chew.
    case crumb   = "r"

    /// True when this cell inkes a pixel, as opposed to leaving it transparent.
    var coversPixel: Bool {
        switch self {
        case .empty: return false
        default:     return true
        }
    }
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
/// The reference art is a brown tortoise with bright green skin, so that is the
/// default; its keyline is drawn in a warm ochre. The phase colour still has to be legible, so
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
    /// Closed eye / sleeping lid. Reads as a dark line across the face.
    var lid: RGBA
    /// The drifting "z" above a sleeping tortoise. Kept dark whatever the shell
    /// keyline does, so the sleep cue reads on a light desktop as well as a dark one.
    var sleepInk: RGBA
    /// Dandelion foliage and flower. Deliberately not phase-coloured, so the leaf
    /// never turns red or blue with the session.
    var leaf: RGBA
    var stem: RGBA
    var petal: RGBA
    var crumb: RGBA

    /// Sampled from the reference image.
    static let referenceShell = RGBA.rgb(0.631, 0.427, 0.157)   // rgb(161, 109, 40)
    static let referenceSkin  = RGBA.rgb(0.624, 0.902, 0.341)   // rgb(159, 230, 87)
    /// The shell keyline: a warm yellow-brown ochre rather than the reference
    /// art's near-black. Light enough to read as a lit rim around the shell, and
    /// saturated enough to stay a tan rather than washing out into a pale sand.
    static let referenceOchre = RGBA.rgb(0.788, 0.635, 0.369)   // rgb(201, 162, 94)
    /// Still the ink of the eye and of the sleeping z's.
    static let referenceInk   = RGBA.rgb(0.075, 0.063, 0.047)

    /// A deeper green than the skin, so a leaf reads against his face.
    static let referenceLeaf  = RGBA.rgb(0.192, 0.478, 0.169)
    static let referenceStem  = RGBA.rgb(0.290, 0.600, 0.235)
    static let referencePetal = RGBA.rgb(0.968, 0.808, 0.180)
    static let referenceCrumb = RGBA.rgb(0.520, 0.700, 0.240)

    static func make(style: TortoiseStyle, phase: SessionPhase) -> TortoisePalette {
        switch style {
        case .natural:
            return TortoisePalette(
                outline: referenceOchre,
                shell: referenceShell,
                trim: phase.baseColor,
                skin: referenceSkin,
                eye: referenceInk,
                // A darker brown so the digits sit on their own plate.
                plate: referenceShell.darkened(0.45),
                ink: .rgb(0.99, 0.97, 0.93),
                lid: referenceSkin.darkened(0.30),
                sleepInk: referenceInk,
                leaf: referenceLeaf,
                stem: referenceStem,
                petal: referencePetal,
                crumb: referenceCrumb
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
                ink: .rgb(0.99, 0.97, 0.93),
                lid: base.lightened(0.18),
                sleepInk: referenceInk,
                leaf: referenceLeaf,
                stem: referenceStem,
                petal: referencePetal,
                crumb: referenceCrumb
            )
        }
    }

    func color(for cell: TortoiseCell) -> RGBA? {
        switch cell {
        case .empty:      return nil
        case .outline:    return outline
        case .shell:      return shell
        case .trim:       return trim
        case .skin:       return skin
        case .eye:        return eye
        case .sleep:      return lid
        case .sleepGlyph: return sleepInk
        case .leaf:       return leaf
        case .stem:       return stem
        case .petal:      return petal
        case .crumb:      return crumb
        }
    }
}

/// The 16x16 pixel-art tortoise: side view facing right, warm ochre keyline, small
/// head and stubby feet, after the reference art.
///
/// The art itself lives in `TortoisePose`, one grid per animation pose. Everything
/// here reads the resting pose, which is what stills, the menu bar icon, the app
/// icon and the README banners are drawn from; the overlay picks a pose per frame.
enum TortoiseSprite {
    static let size = 16

    /// 16 rows of exactly 16 characters for the resting pose, top to bottom.
    /// Legend: "." empty, "#" keyline, "o" shell, "s" trim, "h" skin, "e" eye.
    /// Scene props add "z" for a closed lid and "Z" for a drifting sleep glyph.
    static var rows: [String] { TortoisePose.resting.rows }

    /// Row-major cells of the resting pose, validated once at load.
    static let grid: [[TortoiseCell]] = {
        let rows = TortoisePose.resting.rows
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
    static func isOpaque(x: Int, y: Int) -> Bool { cell(x: x, y: y).coversPixel }

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

    /// Checks the resting pose is well formed, and every animation pose with it.
    /// Exercised by the test suite so art edits cannot silently detach a limb,
    /// punch a hole in the shell, or leave a pose with no face.
    static func validate() -> [String] {
        TortoisePose.allCases.flatMap { $0.problems(textArea: textArea) }
    }

    /// Problems with the resting pose alone, reported without a pose prefix so the
    /// message reads the way it always has.
    static func validateRestingPose() -> [String] {
        TortoisePose.resting.problems(textArea: textArea)
            .map { $0.replacingOccurrences(of: "\(TortoisePose.resting.rawValue): ", with: "") }
    }

    /// ASCII rendering, handy for tests and terminal debugging.
    static func asciiArt() -> String {
        rows.enumerated()
            .map { String(format: "%2d ", $0.offset) + $0.element }
            .joined(separator: "\n")
    }
}
