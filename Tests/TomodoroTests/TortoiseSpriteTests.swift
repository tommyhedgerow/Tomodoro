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
        XCTAssertEqual(palette.outline, TortoisePalette.referenceInk)
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
