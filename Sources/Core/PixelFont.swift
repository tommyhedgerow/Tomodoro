import Foundation

/// A 3x5 pixel font for the countdown, so the digits are drawn from the same
/// visual language as the tortoise instead of a system face sitting on top of it.
///
/// Each glyph is authored as rows of "#" and "."; the colon is one pixel wide so
/// a five-character clock stays compact.
enum PixelFont {

    static let glyphHeight = 5
    static let defaultSpacing = 1

    /// width plus the glyph rows, top to bottom.
    private static let table: [Character: (width: Int, rows: [String])] = [
        "0": (3, ["###", "#.#", "#.#", "#.#", "###"]),
        "1": (3, [".#.", "##.", ".#.", ".#.", "###"]),
        "2": (3, ["###", "..#", "###", "#..", "###"]),
        "3": (3, ["###", "..#", "###", "..#", "###"]),
        "4": (3, ["#.#", "#.#", "###", "..#", "..#"]),
        "5": (3, ["###", "#..", "###", "..#", "###"]),
        "6": (3, ["###", "#..", "###", "#.#", "###"]),
        "7": (3, ["###", "..#", "..#", "..#", "..#"]),
        "8": (3, ["###", "#.#", "###", "#.#", "###"]),
        "9": (3, ["###", "#.#", "###", "..#", "###"]),
        ":": (1, ["#", ".", "#", ".", "#"]),
        " ": (2, ["..", "..", "..", "..", ".."]),

        "A": (3, ["###", "#.#", "###", "#.#", "#.#"]),
        "B": (3, ["##.", "#.#", "##.", "#.#", "##."]),
        "C": (3, ["###", "#..", "#..", "#..", "###"]),
        "D": (3, ["##.", "#.#", "#.#", "#.#", "##."]),
        "E": (3, ["###", "#..", "##.", "#..", "###"]),
        "F": (3, ["###", "#..", "##.", "#..", "#.."]),
        "G": (3, ["###", "#..", "#.#", "#.#", "###"]),
        "H": (3, ["#.#", "#.#", "###", "#.#", "#.#"]),
        "I": (3, ["###", ".#.", ".#.", ".#.", "###"]),
        "J": (3, ["..#", "..#", "..#", "#.#", "###"]),
        "K": (3, ["#.#", "#.#", "##.", "#.#", "#.#"]),
        "L": (3, ["#..", "#..", "#..", "#..", "###"]),
        "M": (3, ["#.#", "###", "###", "#.#", "#.#"]),
        "N": (3, ["##.", "#.#", "#.#", "#.#", "#.#"]),
        "O": (3, ["###", "#.#", "#.#", "#.#", "###"]),
        "P": (3, ["###", "#.#", "###", "#..", "#.."]),
        "Q": (3, ["###", "#.#", "#.#", "###", "..#"]),
        "R": (3, ["###", "#.#", "##.", "#.#", "#.#"]),
        "S": (3, ["###", "#..", "###", "..#", "###"]),
        "T": (3, ["###", ".#.", ".#.", ".#.", ".#."]),
        "U": (3, ["#.#", "#.#", "#.#", "#.#", "###"]),
        "V": (3, ["#.#", "#.#", "#.#", "#.#", ".#."]),
        "W": (3, ["#.#", "#.#", "###", "###", "#.#"]),
        "X": (3, ["#.#", "#.#", ".#.", "#.#", "#.#"]),
        "Y": (3, ["#.#", "#.#", ".#.", ".#.", ".#."]),
        "Z": (3, ["###", "..#", ".#.", "#..", "###"]),
    ]

    static func glyph(for character: Character) -> (width: Int, rows: [String]) {
        table[character] ?? (3, ["###", "#.#", "#.#", "#.#", "###"])
    }

    /// Width in font cells, including the gaps between glyphs.
    static func width(of text: String, spacing: Int = defaultSpacing) -> Int {
        guard !text.isEmpty else { return 0 }
        let glyphs = text.map { glyph(for: $0).width }
        return glyphs.reduce(0, +) + spacing * (text.count - 1)
    }

    /// Filled cells as (x, y) offsets from the text's top-left corner, in font cells.
    static func filledCells(of text: String, spacing: Int = defaultSpacing) -> [(x: Int, y: Int)] {
        var out: [(x: Int, y: Int)] = []
        var cursor = 0
        for character in text {
            let g = glyph(for: character)
            for (rowIndex, row) in g.rows.enumerated() {
                for (columnIndex, mark) in row.enumerated() where mark == "#" {
                    out.append((x: cursor + columnIndex, y: rowIndex))
                }
            }
            cursor += g.width + spacing
        }
        return out
    }
}
