import AppKit

/// Exports a contact sheet of every frame the animator can produce.
///
/// This runs the app's own pose data, scene builder and palette — the same code
/// the overlay draws with — so the sheet cannot show something the app would not.
/// It exists because the animation is sporadic: a still pose looks fine and the
/// blink that only shows its open frame, or the prop that lands a cell off the
/// mouth, are invisible until you look at every frame side by side.
///
/// Written by `Tomodoro --export-animation <dir>`.
enum AnimationSheetRenderer {

    /// Pixels per sprite cell in the output.
    static var cell: CGFloat = 10
    /// Gap between frames, in cells.
    private static let gap = 2
    /// Gap between groups of frames, in cells.
    private static let groupGap = 4

    /// The frames worth showing, grouped by the clip they belong to.
    private static func groups() -> [(name: String, frames: [TortoiseFrame])] {
        let poses = TortoisePose.allCases.map { TortoiseFrame(pose: $0) }

        let eat = TortoiseAnimator.eatFootage().map(\.frame)
        let munch = TortoiseAnimator.munchFootage().map(\.frame)

        let sleep = [
            TortoiseFrame(pose: .sleeping),
            TortoiseFrame(pose: .sleeping, sleepZ: 0.0),
            TortoiseFrame(pose: .sleeping, sleepZ: 0.35),
            TortoiseFrame(pose: .sleeping, sleepZ: 0.7),
            TortoiseFrame(pose: .sleeping, sleepZ: 1.0),
        ]

        return [
            ("poses", poses),
            ("sleep", sleep),
            ("eat", eat),
            ("munch", munch),
        ]
    }

    /// Every frame, one per column, one group per row.
    static func data(style: TortoiseStyle = .natural, phase: SessionPhase = .focus) -> Data? {
        let palette = TortoisePalette.make(style: style, phase: phase)
        let rows = groups()
        let frameW = CGFloat(TortoiseScene.width) * cell
        let frameH = CGFloat(TortoiseScene.height) * cell
        let gapW = CGFloat(gap) * cell
        let gapH = CGFloat(groupGap) * cell

        let columns = rows.map(\.frames.count).max() ?? 1
        let size = CGSize(
            width: CGFloat(columns) * frameW + CGFloat(columns - 1) * gapW,
            height: CGFloat(rows.count) * frameH + CGFloat(rows.count - 1) * gapH
        )

        var canvas = PixelCanvas(size: size, scale: 2)
        // A light plate behind everything, so transparent cells and the props that
        // sit over them are both readable.
        canvas.fill(.rgb(0.93, 0.93, 0.94))

        for (rowIndex, group) in rows.enumerated() {
            for (columnIndex, frame) in group.frames.enumerated() {
                canvas.scene(
                    TortoiseScene(frame: frame), palette: palette,
                    atX: CGFloat(columnIndex) * (frameW + gapW),
                    atY: CGFloat(rowIndex) * (frameH + gapH),
                    cell: cell
                )
            }
        }

        return canvas.pngData()
    }

    /// The pose grids as text, so a reviewer can check the art directly.
    static func poseText() -> String {
        var out = ""
        for pose in TortoisePose.allCases {
            out += "\(pose.rawValue)\n"
            out += pose.rows.enumerated()
                .map { String(format: "%2d %@", $0.offset, $0.element) }
                .joined(separator: "\n")
            out += "\n\n"
        }
        return out
    }

    /// Writes the sheet, one per phase, into `directory`.
    @discardableResult
    static func export(to directory: String) -> Bool {
        let url = URL(fileURLWithPath: directory, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)

        try? Data(poseText().utf8).write(to: url.appendingPathComponent("tortoise-poses.txt"))

        var ok = true
        for phase in SessionPhase.allCases {
            guard let data = data(phase: phase) else { ok = false; continue }
            let name = "tortoise-animation-\(phase.rawValue).png"
            do {
                try data.write(to: url.appendingPathComponent(name))
            } catch {
                // Kept free of DiagLog so this renderer stays in the test target,
                // where the exported sheet is compared against the source grids.
                NSLog("animation export failed for \(phase.rawValue): \(error)")
                ok = false
            }
        }
        return ok
    }
}
