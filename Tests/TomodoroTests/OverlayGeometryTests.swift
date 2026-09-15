import XCTest

/// Geometry that keeps both surfaces on screen.
final class OverlayGeometryTests: XCTestCase {

    func testOverlayIsTheSceneNotJustTheTortoise() {
        // The window is larger than the tortoise: the extra columns and rows are
        // where his dandelion and his sleeping z's are drawn, and he stays
        // bottom-anchored inside it.
        XCTAssertEqual(TortoiseOverlayMetrics.width,
                       TortoiseOverlayMetrics.defaultCellSize * CGFloat(TortoiseScene.width))
        XCTAssertEqual(TortoiseOverlayMetrics.height,
                       TortoiseOverlayMetrics.defaultCellSize * CGFloat(TortoiseScene.height))
        XCTAssertEqual(TortoiseOverlayMetrics.spriteSide,
                       TortoiseOverlayMetrics.defaultCellSize * 16)
        XCTAssertGreaterThanOrEqual(TortoiseOverlayMetrics.height, TortoiseOverlayMetrics.spriteSide)
        XCTAssertGreaterThanOrEqual(TortoiseOverlayMetrics.width, TortoiseOverlayMetrics.spriteSide)
        XCTAssertEqual(TortoiseOverlayMetrics.spriteTop,
                       TortoiseOverlayMetrics.defaultCellSize * CGFloat(TortoiseScene.spriteY))
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

    /// The shell never moves, in any pose, so the countdown cannot drift.
    func testTheShellAndTheCountdownStayPutInEveryPose() {
        let resting = TortoiseScene(frame: .rest)
        let area = TortoiseOverlayMetrics.textAreaRect
        let shellCells = { (scene: TortoiseScene) -> [String] in
            var out: [String] = []
            // The reserved countdown plate, in scene coordinates.
            let plate = TortoiseSprite.textArea
            for y in plate.y..<(plate.y + plate.height) {
                for x in plate.x..<(plate.x + plate.width) {
                    let sceneCell = scene.cell(x: x + TortoiseScene.spriteX, y: y + TortoiseScene.spriteY)
                    out.append(sceneCell.map { String($0.cell.rawValue) } ?? ".")
                }
            }
            return out
        }
        XCTAssertEqual(shellCells(resting).count, 48)
        XCTAssertTrue(shellCells(resting).allSatisfy { $0 == "o" })

        for pose in TortoisePose.allCases {
            let scene = TortoiseScene(frame: TortoiseFrame(pose: pose))
            XCTAssertEqual(shellCells(scene), shellCells(resting),
                           "pose \(pose.rawValue) changed the shell under the countdown")
            XCTAssertEqual(TortoiseOverlayMetrics.textAreaRect, area)
        }
    }

    // MARK: Hit testing

    private var bounds: CGRect { TortoiseOverlayMetrics.bounds }

    /// Centre of the given scene cell, in bottom-left coordinates.
    private func point(cellX: Int, cellY: Int) -> CGPoint {
        let cell = TortoiseOverlayMetrics.defaultCellSize
        return CGPoint(x: (CGFloat(cellX) + 0.5) * cell,
                       y: bounds.height - (CGFloat(cellY) + 0.5) * cell)
    }

    /// Centre of the given sprite cell, converted to a scene cell first.
    private func point(spriteX: Int, spriteY: Int) -> CGPoint {
        point(cellX: spriteX + TortoiseScene.spriteX, cellY: spriteY + TortoiseScene.spriteY)
    }

    func testCellMappingIsNotVerticallyFlipped() {
        let top = TortoiseOverlayMetrics.sceneCell(forPoint: point(cellX: 0, cellY: 0), in: bounds)
        XCTAssertEqual(top.x, 0)
        XCTAssertEqual(top.y, 0, "the top of the window must map to scene row 0")

        let bottom = TortoiseOverlayMetrics.sceneCell(
            forPoint: point(cellX: 0, cellY: TortoiseScene.height - 1), in: bounds)
        XCTAssertEqual(bottom.y, TortoiseScene.height - 1)

        // The sprite offset is applied for sprite lookups, so a point over the
        // tortoise's own top row reports sprite row 0, not scene row 4.
        let spriteTop = TortoiseOverlayMetrics.spriteCell(forPoint: point(spriteX: 0, spriteY: 0), in: bounds)
        XCTAssertEqual(spriteTop.y, 0)
        let spriteBottom = TortoiseOverlayMetrics.spriteCell(forPoint: point(spriteX: 0, spriteY: 15), in: bounds)
        XCTAssertEqual(spriteBottom.y, 15)
    }

    func testClicksOnTheShellAreAccepted() {
        // The shell body, where the countdown sits.
        XCTAssertTrue(TortoiseOverlayMetrics.isHit(point: point(spriteX: 5, spriteY: 6), in: bounds))
    }

    func testClicksOnTheHeadAndFeetAreAccepted() {
        XCTAssertTrue(TortoiseOverlayMetrics.isHit(point: point(spriteX: 14, spriteY: 7), in: bounds))
        XCTAssertTrue(TortoiseOverlayMetrics.isHit(point: point(spriteX: 3, spriteY: 13), in: bounds))
    }

    func testClicksOnTransparentCornersFallThrough() {
        // So the window does not swallow clicks meant for the app behind it.
        let corners = [(0, 0), (TortoiseScene.width - 1, 0),
                       (0, TortoiseScene.height - 1),
                       (TortoiseScene.width - 1, TortoiseScene.height - 1)]
        for corner in corners {
            XCTAssertFalse(TortoiseOverlayMetrics.isHit(point: point(cellX: corner.0, cellY: corner.1),
                                                         in: bounds),
                           "cell \(corner) should pass clicks through")
        }
    }

    func testEveryHitCellIsOpaqueInTheSprite() {
        let scene = TortoiseScene(frame: .rest)
        var hits = 0
        for y in 0..<TortoiseScene.height {
            for x in 0..<TortoiseScene.width
            where TortoiseOverlayMetrics.isHit(point: point(cellX: x, cellY: y), in: bounds) {
                hits += 1
                XCTAssertTrue(scene.covers(x: x, y: y))
                XCTAssertTrue(TortoiseSprite.isOpaque(x: x - TortoiseScene.spriteX,
                                                      y: y - TortoiseScene.spriteY))
            }
        }
        XCTAssertGreaterThan(hits, 60, "the tortoise should cover a decent share of the window")
    }

    /// A prop he is eating is part of the overlay, so clicking it counts as
    /// clicking the timer rather than falling through to the app behind.
    ///
    /// Props are already expressed in scene coordinates; the sprite's own cells
    /// are offset by the headroom above him. Mixing the two is the easy mistake,
    /// so this pins both down.
    func testHitTestingFollowsThePoseAndTheProps() {
        func scenePoint(_ x: Int, _ y: Int) -> CGPoint { point(cellX: x, cellY: y) }

        // Poses must not move the shell. The countdown is printed on it, so a
        // shell that shifted with the animation would drag the clock around, and
        // the clickable area would swim under the user's cursor.
        func mask(_ frame: TortoiseFrame) -> Set<[Int]> {
            var out: Set<[Int]> = []
            for y in 0..<TortoiseScene.height {
                for x in 0..<TortoiseScene.width where TortoiseScene(frame: frame).covers(x: x, y: y) {
                    out.insert([x, y])
                }
            }
            return out
        }

        let resting = mask(.rest)
        XCTAssertFalse(resting.isEmpty)

        /// Cells left of the head block: the shell and the legs. The head reels,
        /// so it is the one part of him allowed to move.
        func bodyCells(_ mask: Set<[Int]>) -> Set<[Int]> {
            Set(mask.filter { $0[0] < 13 + TortoiseScene.spriteX })
        }
        XCTAssertGreaterThan(bodyCells(resting).count, 40, "the shell should be the bulk of the tortoise")

        /// The shell itself, in scene coordinates: everything inside the box a
        /// withdrawn tortoise draws in. The countdown is printed on it, so it may
        /// never move, in any pose.
        let box = TortoisePose.shellBounds
        let shell = Set(resting.filter {
            let x = $0[0] - TortoiseScene.spriteX
            let y = $0[1] - TortoiseScene.spriteY
            return x >= box.x && x < box.x + box.width && y >= box.y && y < box.y + box.height
        })

        for pose in TortoisePose.allCases {
            let poseMask = mask(TortoiseFrame(pose: pose))

            switch pose {
            case .sleeping:
                // Withdrawing is a real change in shape: his head and his legs go
                // inside with him, leaving the shell and nothing else.
                XCTAssertLessThan(poseMask.count, resting.count,
                                  "\(pose.rawValue) should visibly withdraw into the shell")
                XCTAssertTrue(poseMask.isSubset(of: resting),
                              "\(pose.rawValue) should only remove cells, never add")
                XCTAssertEqual(poseMask, shell,
                               "\(pose.rawValue) should draw nothing but the shell")
                XCTAssertLessThan(bodyCells(poseMask).count, bodyCells(resting).count,
                                  "his legs should have gone in with him")
            default:
                XCTAssertEqual(bodyCells(poseMask), bodyCells(resting),
                               "\(pose.rawValue) moved the shell or the feet")
                XCTAssertTrue(shell.isSubset(of: poseMask),
                              "\(pose.rawValue) lost part of the shell")
                // Reeling the head moves the block up or down a row or two, which
                // trades cells at its edges, so the silhouette shifts slightly but
                // the tortoise stays exactly the same size. A pose that gained or
                // lost ink would be a drawing mistake, not a movement.
                XCTAssertEqual(poseMask.count, resting.count,
                               "\(pose.rawValue) changed how much tortoise there is")
                XCTAssertLessThanOrEqual(poseMask.symmetricDifference(resting).count, 12,
                                         "\(pose.rawValue) changed the silhouette too much")
                XCTAssertGreaterThan(poseMask.intersection(resting).count,
                                     resting.count - 16,
                                     "\(pose.rawValue) should mostly be where he already was")
            }
        }

        // The leaf sits to his right at mouth height, in scene coordinates.
        let leafCell = (x: 17, y: 11)
        XCTAssertFalse(TortoiseScene(frame: .rest).covers(x: leafCell.x, y: leafCell.y),
                       "with no leaf on screen that cell is transparent")
        let leaf = TortoiseScene(frame: TortoiseFrame(pose: .resting, leaf: .sprig))
        XCTAssertTrue(leaf.covers(x: leafCell.x, y: leafCell.y), "the leaf is drawn there")
        XCTAssertTrue(TortoiseOverlayMetrics.isHit(point: scenePoint(leafCell.x, leafCell.y),
                                                   in: bounds, scene: leaf),
                      "the overlay should accept a click on the leaf")
        XCTAssertFalse(TortoiseOverlayMetrics.isHit(point: scenePoint(leafCell.x, leafCell.y),
                                                    in: bounds, scene: TortoiseScene(frame: .rest)),
                       "and pass it through once the leaf is gone")
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
