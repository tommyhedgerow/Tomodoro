import XCTest

/// The animation contact sheet, and the composition details that are easy to get
/// wrong and impossible to catch by reading the pose text.
///
/// The sheet is rendered through the app's own pose data, scene builder and
/// palette, so exporting it exercises the real drawing path without a window.
final class AnimationSheetTests: XCTestCase {

    func testEveryPhaseExportsASheetWithContentInEveryGroup() throws {
        for phase in SessionPhase.allCases {
            let data = try XCTUnwrap(AnimationSheetRenderer.data(phase: phase),
                                     "no sheet for \(phase.rawValue)")
            let decoded = try decodePNG(data)
            XCTAssertGreaterThan(decoded.width, 0)
            XCTAssertGreaterThan(decoded.height, 0)

            // Four groups, one per animation, each a full scene tall. A group that
            // lost its frames would leave a blank band.
            let groupHeight = decoded.height / 4
            for index in 0..<4 {
                let top = index * groupHeight
                let bottom = top + groupHeight
                let inked = (top..<bottom).contains { y in
                    decoded.rows[y].contains { $0.a > 0 && !isBackdrop($0) }
                }
                XCTAssertTrue(inked, "group \(index) of \(phase.rawValue) is blank")
            }
        }
    }

    /// The sheet's plate, so "has content" means ink rather than the backdrop.
    private func isBackdrop(_ pixel: RGBA) -> Bool {
        abs(pixel.r - 0.93) < 0.02 && abs(pixel.g - 0.93) < 0.02 && abs(pixel.b - 0.94) < 0.02
    }

    func testThePoseTextListsEveryPoseInFull() {
        let text = AnimationSheetRenderer.poseText()
        for pose in TortoisePose.allCases {
            // A pose's block is its name on its own line, then 16 numbered rows.
            XCTAssertTrue(text.contains("\(pose.rawValue)\n"),
                          "\(pose.rawValue) is missing from the pose text")
            let rows = text.components(separatedBy: "\(pose.rawValue)\n").dropFirst()
            for block in rows {
                let lines = block.split(separator: "\n").prefix(16)
                XCTAssertEqual(lines.count, 16, "\(pose.rawValue) does not have 16 rows")
                for line in lines {
                    // "NN ................" — two digits, a space, then 16 cells.
                    let cells = line.dropFirst(3)
                    XCTAssertEqual(cells.count, 16, "\(pose.rawValue) row is \(cells.count) wide")
                }
            }
        }
    }

    // MARK: Composition

    /// The blinking pose must actually close the eye. A blink whose pupilless
    /// frame still has pupils is a blink that never happens.
    func testTheBlinkClosesTheEyeRatherThanLookingAside() {
        func pupils(_ pose: TortoisePose) -> Int {
            pose.grid.flatMap { $0 }.filter { $0 == .eye }.count
        }
        XCTAssertGreaterThan(pupils(.resting), 0, "the resting pose must have a pupil")
        XCTAssertEqual(pupils(.blinking), 0, "the blink must have no pupil left")
        XCTAssertGreaterThan(
            TortoisePose.blinking.grid.flatMap { $0 }.filter { $0 == .sleep }.count, 0,
            "the blink should draw a closed lid"
        )
        // The lid lands on the pupil, so the eye reads as closing where it was
        // rather than the face changing shape around it.
        let pupils = Set(locations(of: .eye, in: .resting))
        let lids = Set(locations(of: .sleep, in: .blinking))
        XCTAssertFalse(pupils.isDisjoint(with: lids), "the lid missed the pupil entirely")
        // And the lid is a line, wider than the single-cell pupil it closes.
        XCTAssertGreaterThan(lids.count, pupils.count,
                             "the lid should read as a line, not a dot")
    }

    private func locations(of kind: TortoiseCell, in pose: TortoisePose) -> [[Int]] {
        pose.grid.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, cell in cell == kind ? [x, y] : nil }
        }
    }

    /// While he sleeps, the z's rise from the crown of his shell rather than
    /// floating off in a corner. The lowest of them overlaps the shell's top row
    /// on purpose — it is coming off him — so the check is that they sit in the
    /// headroom over his back, not clear of the whole sprite.
    func testSleepingZsRiseFromAboveHisShell() throws {
        // A fully faded z draws nothing, which is the end of the drift, not a bug.
        var drawn = 0
        for drift in [0.0, 0.2, 0.35, 0.5, 0.7] {
            let frame = TortoiseFrame(pose: .sleeping, sleepZ: drift)
            let scene = TortoiseScene(frame: frame)
            let zProps = scene.props.filter { $0.cell == .sleepGlyph }
            XCTAssertFalse(zProps.isEmpty, "no z drawn at drift \(drift)")
            drawn += 1

            // The crown of the shell, in scene rows.
            let crownRow = try XCTUnwrap(TortoisePose.resting.rows.firstIndex { $0.contains("#") })
            let crown = TortoiseScene.spriteY + crownRow

            let lowest = try XCTUnwrap(zProps.map(\.y).max())
            let highest = try XCTUnwrap(zProps.map(\.y).min())
            XCTAssertLessThanOrEqual(lowest, crown + 1,
                                     "a z at y=\(lowest) has sunk into the shell")
            XCTAssertGreaterThanOrEqual(highest, TortoiseScene.spriteY - TortoiseScene.spriteY,
                                        "a z at y=\(highest) left the scene")

            // Over the crown of his shell rather than beside him: with his head
            // withdrawn there is nothing out to the right for a z to come off.
            let columns = zProps.map(\.x)
            let lowestX = try XCTUnwrap(columns.min())
            let highestX = try XCTUnwrap(columns.max())
            XCTAssertGreaterThanOrEqual(lowestX, TortoiseScene.spriteX + 4,
                                        "the z drifted off to the left of the shell")
            XCTAssertLessThanOrEqual(highestX, TortoiseScene.spriteX + 7,
                                     "the z drifted off the right of the crown")

            // And it is inside the scene, so the window never has to grow.
            for prop in zProps {
                XCTAssertTrue((0..<TortoiseScene.width).contains(prop.x))
                XCTAssertTrue((0..<TortoiseScene.height).contains(prop.y))
            }
        }
        XCTAssertGreaterThan(drawn, 0)
    }

    /// The dandelion's leaves have to reach his mouth, or he is chewing the air.
    func testTheDandelionMeetsHisMouth() throws {
        let pose = TortoisePose.headDown
        let scene = TortoiseScene(frame: TortoiseFrame(pose: pose, plant: .dandelion))

        // Where the mouth actually is, read from the pose rather than assumed: the
        // front edge of the face is the rightmost column holding skin, and the
        // mouth is on its lowest row.
        let skin = pose.grid.enumerated().flatMap { y, row in
            row.enumerated().compactMap { x, cell in cell == .skin ? (x, y) : nil }
        }
        let headEdge = try XCTUnwrap(skin.map(\.0).max())
        let mouthRow = try XCTUnwrap(skin.filter { $0.0 == headEdge }.map(\.1).max())

        let leaves = scene.props.filter { $0.cell == .leaf }
        XCTAssertFalse(leaves.isEmpty, "no leaves drawn")

        // A leaf has to sit right where he is biting: the column past the front of
        // the face, on the row the mouth is on.
        let biteColumn = TortoiseScene.spriteX + headEdge + 1
        let biteRow = TortoiseScene.spriteY + mouthRow
        XCTAssertTrue(leaves.contains { $0.x == biteColumn && $0.y == biteRow },
                      "nothing is at his mouth (\(biteColumn),\(biteRow)); "
                      + "he would be biting the air. Leaves are at "
                      + "\(leaves.map { "(\($0.x),\($0.y))" }.joined(separator: " "))")
    }

    /// The stalk connects the flower head to the leaves instead of floating.
    func testTheDandelionStalkConnectsFlowerToLeaves() {
        let plant = TortoisePlant.dandelion.cells
        let stalk = plant.filter { $0.cell == .stem }
        let petals = plant.filter { $0.cell == .petal }
        let leaves = plant.filter { $0.cell == .leaf }
        XCTAssertFalse(stalk.isEmpty)
        XCTAssertFalse(petals.isEmpty)
        XCTAssertFalse(leaves.isEmpty)

        let stalkX = Set(stalk.map(\.x))
        XCTAssertEqual(stalkX.count, 1, "the stalk should be a single column")
        let x = stalkX.first!
        XCTAssertTrue(petals.contains { $0.x == x }, "the flower is not on the stalk")

        // The stalk runs down to the leaves and no further.
        let stalkTop = stalk.map(\.y).min()!
        let stalkBottom = stalk.map(\.y).max()!
        let leafTop = leaves.map(\.y).min()!
        XCTAssertGreaterThanOrEqual(stalkBottom, leafTop, "the stalk stops above the leaves")
        XCTAssertLessThan(stalkBottom, leaves.map(\.y).max()!, "the stalk runs past the leaves")
        XCTAssertGreaterThan(stalkTop, 0)
    }
}
