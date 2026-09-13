import XCTest

/// Geometry that keeps both surfaces on screen.
final class OverlayGeometryTests: XCTestCase {

    func testOverlayIsSixteenPixelsSquare() {
        XCTAssertEqual(TortoiseOverlayMetrics.side,
                       TortoiseOverlayMetrics.defaultCellSize * 16)
    }

    func testStackedContentFitsInsideTheShell() {
        XCTAssertTrue(TortoiseOverlayMetrics.contentFitsShell(),
                      "the label, clock and progress bar must fit the reserved shell area")
    }

    func testClockFitsTheShellWithMargin() {
        let area = TortoiseOverlayMetrics.textAreaRect
        let width = CGFloat(PixelFont.width(of: "25:00")) * TortoiseOverlayMetrics.digitCellSize
        XCTAssertLessThan(width, area.width, "the clock should not touch the shell edges")
        XCTAssertGreaterThan(area.width - width, 8, "leave at least 8pt of margin")
    }

    // MARK: Hit testing

    private var bounds: CGRect { CGRect(x: 0, y: 0, width: TortoiseOverlayMetrics.side,
                                        height: TortoiseOverlayMetrics.side) }

    /// Centre of the given sprite cell, in bottom-left coordinates.
    private func point(cellX: Int, cellY: Int) -> CGPoint {
        let cell = TortoiseOverlayMetrics.defaultCellSize
        return CGPoint(x: (CGFloat(cellX) + 0.5) * cell,
                       y: bounds.height - (CGFloat(cellY) + 0.5) * cell)
    }

    func testCellMappingIsNotVerticallyFlipped() {
        let top = TortoiseOverlayMetrics.spriteCell(forPoint: point(cellX: 0, cellY: 0), in: bounds)
        XCTAssertEqual(top.x, 0)
        XCTAssertEqual(top.y, 0, "the top of the window must map to sprite row 0")

        let bottom = TortoiseOverlayMetrics.spriteCell(forPoint: point(cellX: 0, cellY: 15), in: bounds)
        XCTAssertEqual(bottom.y, 15)
    }

    func testClicksOnTheShellAreAccepted() {
        // The shell body, where the countdown sits.
        XCTAssertTrue(TortoiseOverlayMetrics.isHit(point: point(cellX: 5, cellY: 6), in: bounds))
    }

    func testClicksOnTheHeadAndFeetAreAccepted() {
        XCTAssertTrue(TortoiseOverlayMetrics.isHit(point: point(cellX: 13, cellY: 7), in: bounds))
        XCTAssertTrue(TortoiseOverlayMetrics.isHit(point: point(cellX: 3, cellY: 13), in: bounds))
    }

    func testClicksOnTransparentCornersFallThrough() {
        // So the window does not swallow clicks meant for the app behind it.
        for corner in [(0, 0), (15, 0), (0, 15), (15, 15)] {
            XCTAssertFalse(TortoiseOverlayMetrics.isHit(point: point(cellX: corner.0, cellY: corner.1),
                                                        in: bounds),
                           "cell \(corner) should pass clicks through")
        }
    }

    func testEveryHitCellIsOpaqueInTheSprite() {
        var hits = 0
        for y in 0..<16 {
            for x in 0..<16 where TortoiseOverlayMetrics.isHit(point: point(cellX: x, cellY: y), in: bounds) {
                hits += 1
                XCTAssertTrue(TortoiseSprite.isOpaque(x: x, y: y))
            }
        }
        XCTAssertGreaterThan(hits, 60, "the tortoise should cover a decent share of the window")
    }

    // MARK: Popover bounding

    func testPopoverUsesPreferredHeightOnATallScreen() {
        XCTAssertEqual(PopoverMetrics.contentHeight(availableHeight: 1200),
                       PopoverMetrics.preferredHeight)
    }

    func testPopoverShrinksOnAShortScreen() {
        // The bug this guards: content taller than the screen pushed the dropdown
        // off the top of the display.
        let height = PopoverMetrics.contentHeight(availableHeight: 400)
        XCTAssertLessThanOrEqual(height, 400 - 24)
        XCTAssertGreaterThanOrEqual(height, PopoverMetrics.minimumHeight)
    }

    func testPopoverNeverExceedsTheAvailableHeight() {
        for available in stride(from: CGFloat(280), through: 2000, by: 20) {
            let height = PopoverMetrics.contentHeight(availableHeight: available)
            XCTAssertLessThanOrEqual(height, max(PopoverMetrics.minimumHeight, available),
                                     "content is taller than the screen at \(available)pt")
        }
    }

    func testPopoverFallsBackToPreferredWhenHeightIsUnknown() {
        XCTAssertEqual(PopoverMetrics.contentHeight(availableHeight: nil),
                       PopoverMetrics.preferredHeight)
        XCTAssertEqual(PopoverMetrics.contentHeight(availableHeight: .infinity),
                       PopoverMetrics.preferredHeight)
    }

    func testPopoverWidthIsFixed() {
        XCTAssertEqual(PopoverMetrics.contentSize(availableHeight: 900).width, PopoverMetrics.width)
    }
}
