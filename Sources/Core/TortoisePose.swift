import Foundation

/// The tortoise's animation poses.
///
/// A pose is the same 16 rows of text the base art has always been authored as,
/// which keeps hand-editing possible and lets the structural checker below run
/// over every pose, not just the resting one.
///
/// Two details are load-bearing:
///
/// * The head block is the mirrored `h`/`e` cells in columns 13...15. Poses that
///   nod are produced by `reeling(_:by:)`, which moves that block up or down a
///   row or two. Nothing else in the sprite moves, so the shell — and therefore
///   the countdown printed inside it — stays perfectly still while he bobs.
/// * Sleeping is not just a closed eye: the pose drops everything outside the
///   shell — head, neck and legs — so the whole silhouette is the shell and the
///   countdown printed on it. There is deliberately no face left on screen while
///   he is withdrawn, which is what `isWithdrawn` marks.
enum TortoisePose: String, CaseIterable {
    /// Eyes open, head at rest. The pose in every still rendering.
    case resting
    /// Lid down. Read by the blink.
    case blinking
    /// Lid down and the head lifted a row.
    case blinkingUp
    /// Lid down and the head dipped a row.
    case blinkingDown
    /// Head thrown up, as when spotting the leaf.
    case headUp
    /// Head up one row: the top of the chew.
    case headChew
    /// Head dipped one row: the bite.
    case headDown
    /// Withdrawn into the shell: no head, no neck, no legs. The pause pose.
    case sleeping

    /// 16 rows of exactly 16 cells.
    var rows: [String] {
        switch self {
        case .resting:       return TortoisePose.baseRows
        case .blinking:      return TortoisePose.blinkRows
        case .blinkingUp:    return TortoisePose.reeling(TortoisePose.blinkRows, by: -1)
        case .blinkingDown:  return TortoisePose.reeling(TortoisePose.blinkRows, by: 1)
        case .headUp:        return TortoisePose.reeling(TortoisePose.baseRows, by: -2)
        case .headChew:      return TortoisePose.reeling(TortoisePose.baseRows, by: -1)
        case .headDown:      return TortoisePose.reeling(TortoisePose.baseRows, by: 1)
        case .sleeping:      return TortoisePose.withdrawn()
        }
    }

    /// Row-major cells.
    var grid: [[TortoiseCell]] {
        rows.map { row in row.map { TortoiseCell(rawValue: $0) ?? .empty } }
    }

    // MARK: The art

    /// Side view facing right: brown shell, phase-coloured trim band, bright green
    /// head and feet, warm ochre keyline.
    ///
    /// This is the art as it has always been, bar the legs, the head and the
    /// keyline: the legs are two rows rather than three, the head is a compact
    /// three-row block rather than a long neck with a head on the end, and the
    /// outline is a warm ochre instead of near-black. Poses below are derived
    /// from it, so a still tortoise — the menu bar icon, the app icon, the README
    /// banners — all follow those changes.
    ///
    /// Column 12 is his neck. The head block reels through columns 13...15, so
    /// the neck has to overlap it in every position the block can take, or a nod
    /// would tear the head off the shell: it keeps exactly those three rows.
    static let baseRows: [String] = [
        "................",
        "....####........",
        "..##soos##......",
        ".#soooooos#.....",
        "#soooooooos#....",
        "#soooooooos#....",
        "#soooooooos#hhhh",
        "#soooooooos#hheh",
        "#soooooooos#hhh.",
        "#soooooooos#....",
        ".#soooooos#.....",
        "..########......",
        "...hh..hh.......",
        "..hhh..hhh......",
        "................",
        "................",
    ]

    /// A blink closes the lid over the eye: the pupil is replaced by lid and the
    /// skin cell below it becomes the matching lid line, so the eye reads as one
    /// dark two-cell line across the face for the length of the blink.
    static let blinkRows: [String] = {
        var rows = baseRows
        rows[7] = "#soooooooos#hhzh"
        rows[8] = "#soooooooos#hhz."
        return rows
    }()

    /// Columns where the head starts. Everything from here right is head.
    static let headColumns = 13...15

    /// True for the poses that draw nothing but the shell: while he sleeps his
    /// head and his legs are inside it, so the silhouette is the rim and nothing
    /// else. Nothing may move — the countdown is printed on the shell — so a
    /// withdrawn pose is still, and the animation carries the slow breath through
    /// the z's that drift above him.
    var isWithdrawn: Bool { self == .sleeping }

    /// Bounding box of the shell: the keyline, the body and the trim band of the
    /// resting pose, which is exactly the ink a withdrawn tortoise keeps.
    ///
    /// Read off the art rather than written down, so shortening a leg or
    /// reshaping the rim can never leave it stale.
    static let shellBounds: (x: Int, y: Int, width: Int, height: Int) = {
        var minX = TortoiseSprite.size, minY = TortoiseSprite.size
        var maxX = -1, maxY = -1
        let shellCells: Set<Character> = ["#", "o", "s"]
        for (y, row) in baseRows.enumerated() {
            for (x, cell) in row.enumerated() where shellCells.contains(cell) {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else {
            return (x: 0, y: 0, width: TortoiseSprite.size, height: TortoiseSprite.size)
        }
        return (x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }()

    /// Shifts the head block by `dy` rows, leaving the shell untouched.
    ///
    /// Everything the head occupied before *and* after the shift is cleared, then
    /// the block is stamped at its new position. Clearing only the old position
    /// would leave a stray skin cell behind wherever the new one does not overlap
    /// it — a lone pixel floating beside the neck, which is exactly the kind of
    /// glitch this art cannot afford at this size.
    static func reeling(_ rows: [String], by dy: Int) -> [String] {
        guard dy != 0 else { return rows }
        var out = rows.map { Array($0) }
        let block: [(Int, Int, Character)] = rows.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, cell in
                guard headColumns.contains(x), "hez".contains(cell) else { return nil }
                return (x, y, cell)
            }
        }
        // Clear the union of both positions, then stamp the new one.
        for (x, y, _) in block {
            out[y][x] = "."
            let ny = y + dy
            if ny >= 0, ny < out.count { out[ny][x] = "." }
        }
        for (x, y, cell) in block {
            let ny = y + dy
            guard ny >= 0, ny < out.count else { continue }
            out[ny][x] = cell
        }
        return out.map { String($0) }
    }

    /// Withdraws him completely: every cell outside the shell goes, head, neck and
    /// legs alike, leaving the shell — and the countdown printed on it — as the
    /// whole silhouette.
    static func withdrawn() -> [String] {
        let box = shellBounds
        var out = baseRows.map { Array($0) }
        for y in out.indices {
            for x in out[y].indices {
                let inside = x >= box.x && x < box.x + box.width
                    && y >= box.y && y < box.y + box.height
                if !inside { out[y][x] = "." }
            }
        }
        return out.map { String($0) }
    }

    // MARK: Validation

    /// Structural problems with this pose, empty when it is well formed.
    ///
    /// Mirrors and extends `TortoiseSprite.validate()`: art is authored as text,
    /// and it is easy to detach a limb or punch a hole in the shell where the
    /// countdown is printed.
    func problems(textArea: (x: Int, y: Int, width: Int, height: Int)) -> [String] {
        var problems: [String] = []
        let name = rawValue
        let rows = self.rows

        guard rows.count == TortoiseSprite.size else {
            return ["\(name): \(rows.count) rows, expected \(TortoiseSprite.size)"]
        }
        for (index, row) in rows.enumerated() where row.count != TortoiseSprite.size {
            problems.append("\(name): row \(index) is \(row.count) wide, expected \(TortoiseSprite.size)")
        }
        guard problems.isEmpty else { return problems }

        let grid = self.grid
        func cell(_ x: Int, _ y: Int) -> TortoiseCell {
            guard x >= 0, x < grid.count, y >= 0, y < grid.count else { return .empty }
            return grid[y][x]
        }

        // Every inked pixel reachable from every other: no limb floats free.
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
            problems.append("\(name): disconnected pixels at "
                            + orphans.map { "(\($0.x),\($0.y))" }.joined(separator: " "))
        }

        // A face: at least one eye or closed-lid cell, sitting on skin. A
        // withdrawn pose is the exception, and is checked for the opposite — he
        // has no face on screen at all, and nothing but shell is drawn.
        let eyes = (0..<grid.count).flatMap { y in (0..<grid.count).map { (x: $0, y: y) } }
            .filter { cell($0.x, $0.y) == .eye || cell($0.x, $0.y) == .sleep }
        if isWithdrawn {
            if !eyes.isEmpty {
                problems.append("\(name): a withdrawn pose should show no face")
            }
            let box = TortoisePose.shellBounds
            let outside = inked.filter {
                $0.x < box.x || $0.x >= box.x + box.width
                    || $0.y < box.y || $0.y >= box.y + box.height
            }
            if !outside.isEmpty {
                problems.append("\(name): withdrawn pose draws outside the shell at "
                                + outside.map { "(\($0.x),\($0.y))" }.joined(separator: " "))
            }
        } else {
            if eyes.isEmpty { problems.append("\(name): pose has no eye") }
            for eye in eyes {
                let neighbours = [(1, 0), (-1, 0), (0, 1), (0, -1)]
                    .map { cell(eye.x + $0.0, eye.y + $0.1) }
                if !neighbours.contains(.skin) {
                    problems.append("\(name): eye at (\(eye.x),\(eye.y)) touches no skin")
                }
            }
        }

        // The countdown is printed on the shell, so the plate stays plain body.
        for y in textArea.y..<(textArea.y + textArea.height) {
            for x in textArea.x..<(textArea.x + textArea.width) where cell(x, y) != .shell {
                problems.append("\(name): countdown plate is not plain shell at (\(x),\(y))")
            }
        }

        return problems
    }
}
