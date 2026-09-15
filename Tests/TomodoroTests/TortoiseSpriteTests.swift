import XCTest

/// Structural guarantees about the 16x16 artwork. These exist because the art is
/// authored by hand as text, where it is easy to detach a leg or leave a stray
/// pixel that only shows up as a visual glitch.
final class TortoiseSpriteTests: XCTestCase {

    func testSpriteIsWellFormed() {
        let problems = TortoiseSprite.validate()
        XCTAssertTrue(problems.isEmpty, "sprite problems: \(problems)")
    }

    func testSpriteIsSixteenBySixteen() {
        XCTAssertEqual(TortoiseSprite.rows.count, 16)
        for (index, row) in TortoiseSprite.rows.enumerated() {
            XCTAssertEqual(row.count, 16, "row \(index) is \(row.count) wide")
        }
    }

    func testEveryPixelIsAConnectedPartOfTheBody() {
        // validate() runs a flood fill; without it a limb can float free of the
        // shell and still look plausible in the source text.
        XCTAssertFalse(TortoiseSprite.validate().contains { $0.contains("disconnected") })
    }

    func testCountdownAreaIsPlainShell() {
        let area = TortoiseSprite.textArea
        for y in area.y..<(area.y + area.height) {
            for x in area.x..<(area.x + area.width) {
                XCTAssertEqual(TortoiseSprite.cell(x: x, y: y), .shell,
                               "countdown area is not plain shell at (\(x),\(y))")
            }
        }
    }

    func testOutOfBoundsLookupsAreEmpty() {
        XCTAssertEqual(TortoiseSprite.cell(x: -1, y: 0), .empty)
        XCTAssertEqual(TortoiseSprite.cell(x: 0, y: 16), .empty)
        XCTAssertFalse(TortoiseSprite.isOpaque(x: 99, y: 99))
    }

    func testEveryStyleAndPhaseProducesVisibleArt() {
        for style in TortoiseStyle.allCases {
            for phase in SessionPhase.allCases {
                let palette = TortoisePalette.make(style: style, phase: phase)
                let buffer = TortoiseSprite.pixelBuffer(palette: palette)
                XCTAssertEqual(buffer.count, 256)
                XCTAssertTrue(buffer.contains { $0 != nil }, "\(style)/\(phase) is blank")
            }
        }
    }

    func testNaturalStyleUsesTheReferenceColours() {
        let palette = TortoisePalette.make(style: .natural, phase: .focus)
        XCTAssertEqual(palette.shell, TortoisePalette.referenceShell)
        XCTAssertEqual(palette.skin, TortoisePalette.referenceSkin)
        XCTAssertEqual(palette.outline, TortoisePalette.referenceOchre)
    }

    /// The keyline is a warm ochre now: lighter than the shell it encloses, far
    /// lighter than the near-black the reference art used, and still a tan rather
    /// than a washed-out sand.
    func testTheShellKeylineIsAWarmLightBrown() {
        let palette = TortoisePalette.make(style: .natural, phase: .focus)
        func luminance(_ colour: RGBA) -> Double {
            0.2126 * colour.r + 0.7152 * colour.g + 0.0722 * colour.b
        }
        XCTAssertGreaterThan(luminance(palette.outline), luminance(palette.shell),
                             "the keyline should read as a light rim on the shell")
        XCTAssertGreaterThan(luminance(palette.outline) - luminance(TortoisePalette.referenceInk),
                             0.5, "the keyline is no longer near-black")

        // Yellow-brown, not grey-beige: the red channel runs well clear of the
        // blue one. The pale sand this replaced scored 0.21 here.
        XCTAssertGreaterThan(palette.outline.r - palette.outline.b, 0.35,
                             "the keyline has gone sandy again: it should be a tan")
        XCTAssertGreaterThan(palette.outline.r - palette.outline.g, 0.1,
                             "and it should lean yellow rather than red")

        // The face and the sleeping z's keep a dark ink, so he still reads as
        // awake or asleep on a light desktop.
        XCTAssertEqual(palette.eye, TortoisePalette.referenceInk)
        XCTAssertEqual(palette.sleepInk, TortoisePalette.referenceInk)
    }

    /// His head is deliberately small: a three-row block against the shell, on a
    /// neck that does not run past it at either end. It used to be a five-row
    /// column, which read as a long neck with a head on the end.
    func testTheHeadIsACompactBlock() {
        // Everything to the right of the shell: the neck and the head. The feet
        // are skin too, but they are under the shell rather than beside it.
        let box = TortoisePose.shellBounds
        let head = TortoisePose.resting.grid.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, cell -> (x: Int, y: Int)? in
                guard cell == .skin, x >= box.x + box.width else { return nil }
                return (x, y)
            }
        }
        XCTAssertEqual(Set(head.map(\.y)).sorted(), [6, 7, 8], "the head spans three rows")
        XCTAssertEqual(head.map(\.x).max(), 15, "the muzzle still reaches column 15")
        XCTAssertEqual(head.map(\.x).min(), 12, "and the neck still meets the shell rim")

        // The neck has to cover every row the head block can reel to, or a nod
        // tears the head off the shell. The flood fill in validate() covers the
        // connectivity; this pins down why all three rows of neck are needed.
        let neck = head.filter { $0.x == 12 }.map(\.y).sorted()
        XCTAssertEqual(neck, [6, 7, 8])
    }

    /// Asleep he is entirely inside his shell: no head, no neck, no legs, and
    /// nothing drawn outside the rim the countdown sits in.
    func testASleepingTortoiseIsNothingButHisShell() {
        let sleeping = TortoisePose.sleeping
        XCTAssertTrue(sleeping.isWithdrawn)
        let cells = sleeping.grid.flatMap { $0 }
        XCTAssertFalse(cells.contains(.skin), "a leg or a head is still out")
        XCTAssertFalse(cells.contains(.eye))
        XCTAssertFalse(cells.contains(.sleep), "there is no face left to close an eye on")

        let box = TortoisePose.shellBounds
        for (y, row) in sleeping.grid.enumerated() {
            for (x, cell) in row.enumerated() where cell != .empty {
                let inside = x >= box.x && x < box.x + box.width
                    && y >= box.y && y < box.y + box.height
                XCTAssertTrue(inside, "he left a pixel outside the shell at (\(x),\(y))")
            }
        }

        // The shell itself is untouched: it carries the countdown.
        let resting = TortoisePose.resting.grid
        for y in 0..<16 where y >= box.y && y < box.y + box.height {
            for x in 0..<16 where x >= box.x && x < box.x + box.width {
                XCTAssertEqual(sleeping.grid[y][x], resting[y][x],
                               "the shell changed shape at (\(x),\(y))")
            }
        }

        // And he really did have limbs to withdraw.
        XCTAssertTrue(TortoisePose.resting.grid.flatMap { $0 }.contains(.skin))
    }

    func testPhaseColourStillDistinguishesEveryPhase() {
        // The phase rides on the trim band, so the trim must differ per phase.
        let trims = SessionPhase.allCases.map { TortoisePalette.make(style: .natural, phase: $0).trim }
        XCTAssertEqual(Set(trims.map { "\($0.r),\($0.g),\($0.b)" }).count, 3)
    }

    func testPhaseDoesNotChangeTheNaturalShell() {
        let shells = SessionPhase.allCases.map { TortoisePalette.make(style: .natural, phase: $0).shell }
        XCTAssertEqual(Set(shells.map { "\($0.r),\($0.g),\($0.b)" }).count, 1,
                       "the natural shell should stay brown regardless of phase")
    }
}
