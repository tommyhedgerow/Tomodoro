import XCTest

final class PixelFontTests: XCTestCase {

    func testClockWidthIsStableForEveryMinute() {
        // A jumping width would make the countdown jitter inside the shell.
        let widths = Set((0...59).map { PixelFont.width(of: String(format: "%02d:00", $0)) })
        XCTAssertEqual(widths.count, 1, "clock width varies: \(widths)")
    }

    func testEveryGlyphFitsTheDeclaredBox() {
        for character in "0123456789: ABCDEFGHIJKLMNOPQRSTUVWXYZ" {
            let glyph = PixelFont.glyph(for: character)
            XCTAssertEqual(glyph.rows.count, PixelFont.glyphHeight,
                           "glyph \(character) is \(glyph.rows.count) rows tall")
            for row in glyph.rows {
                XCTAssertEqual(row.count, glyph.width,
                               "glyph \(character) row is \(row.count) wide, expected \(glyph.width)")
            }
        }
    }

    func testFilledCellsStayInsideTheReportedWidth() {
        for text in ["25:00", "05:09", "SHORT", "LONG BREAK"] {
            let width = PixelFont.width(of: text)
            for cell in PixelFont.filledCells(of: text) {
                XCTAssertTrue((0..<width).contains(cell.x), "\(text) overflows at x=\(cell.x)")
                XCTAssertTrue((0..<PixelFont.glyphHeight).contains(cell.y))
            }
        }
    }

    func testColonIsNarrowerThanADigit() {
        XCTAssertLessThan(PixelFont.glyph(for: ":").width, PixelFont.glyph(for: "0").width)
    }

    func testCountdownFitsTheShell() {
        // The whole point of the layout: the clock must fit the reserved area.
        let area = TortoiseSprite.textArea
        let cell = TortoiseOverlayMetrics.defaultCellSize
        let digitCell = TortoiseOverlayMetrics.digitCellSize
        let textWidth = CGFloat(PixelFont.width(of: "25:00")) * digitCell
        let textHeight = CGFloat(PixelFont.glyphHeight) * digitCell
        XCTAssertLessThanOrEqual(textWidth, CGFloat(area.width) * cell)
        XCTAssertLessThanOrEqual(textHeight, CGFloat(area.height) * cell)
    }
}
