import AppKit
import CoreGraphics

/// Draws the README banners from the same sprite, palettes and pixel font the app
/// uses, so the artwork in the docs cannot drift from the artwork in the app.
///
/// Rendered on demand rather than during the build, since it writes into the
/// repository:
///
///     Tomodoro.app/Contents/MacOS/Tomodoro --export-banners Screenshots
///
/// Everything is laid out in logical points and scaled up by an integer factor,
/// which keeps every sprite pixel and glyph pixel perfectly square.
enum BannerRenderer {

    static let scale = 2                      // retina
    static let headerSize = CGSize(width: 1200, height: 380)
    static let footerSize = CGSize(width: 1200, height: 140)

    /// Exposed so tests can tell banner content from empty background.
    static let backgroundColour = RGBA.rgb(0.094, 0.094, 0.121)   // #18181F
    private static let background = BannerRenderer.backgroundColour
    private static let titleInk   = RGBA.rgb(0.973, 0.965, 0.949)
    private static let mutedInk   = RGBA.rgb(0.545, 0.545, 0.612)

    // MARK: Export

    @discardableResult
    static func export(to directory: String) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(atPath: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("Tomodoro: could not create banner directory: \(error)")
            return false
        }

        let jobs: [(String, Data?)] = [
            ("readme-header.png", headerPNG()),
            ("readme-footer.png", footerPNG()),
        ]
        for (name, data) in jobs {
            guard let data else {
                NSLog("Tomodoro: failed to render \(name)")
                return false
            }
            let path = directory + "/" + name
            do {
                try data.write(to: URL(fileURLWithPath: path))
                NSLog("Tomodoro: wrote \(path)")
            } catch {
                NSLog("Tomodoro: could not write \(path): \(error)")
                return false
            }
        }
        return true
    }

    // MARK: Header

    static func headerPNG() -> Data? {
        var canvas = PixelCanvas(size: headerSize, scale: scale)
        canvas.fill(background)

        // Title.
        drawCentred(PixelFont.width(of: "TOMODORO"), atY: 40, cell: 22, ink: titleInk,
                    text: "TOMODORO", in: &canvas)

        // Rule in the three session colours: red focus, green short break, blue long break.
        let ruleWidth: CGFloat = 200
        let ruleHeight: CGFloat = 6
        let ruleY: CGFloat = 170
        var ruleX = (headerSize.width - ruleWidth * 3) / 2
        for phase in SessionPhase.allCases {
            canvas.rect(x: ruleX, y: ruleY, width: ruleWidth, height: ruleHeight,
                        color: phase.baseColor)
            ruleX += ruleWidth
        }

        // Cell 5 rather than 4: GitHub scales a 1200pt banner to roughly 880px,
        // and anything smaller stops being comfortably legible at that size.
        drawCentred(PixelFont.width(of: "A POMODORO TIMER FOR YOUR MENU BAR"),
                    atY: 194, cell: 5, ink: mutedInk,
                    text: "A POMODORO TIMER FOR YOUR MENU BAR", in: &canvas)

        // A parade of tortoises: the mascot itself, then one per session colour.
        let parade: [TortoisePalette] = [
            .make(style: .natural, phase: .focus),
            .make(style: .tinted, phase: .focus),
            .make(style: .tinted, phase: .shortBreak),
            .make(style: .tinted, phase: .longBreak),
        ]
        let cell: CGFloat = 8
        let sprite = cell * CGFloat(TortoiseSprite.size)
        let spacing: CGFloat = 176
        let total = spacing * CGFloat(parade.count - 1) + sprite
        var x = (headerSize.width - total) / 2
        for palette in parade {
            canvas.sprite(palette, atX: x, atY: 232, cell: cell)
            x += spacing
        }

        return canvas.pngData()
    }

    // MARK: Footer

    static func footerPNG() -> Data? {
        var canvas = PixelCanvas(size: footerSize, scale: scale)
        canvas.fill(background)

        // A frieze of tortoises cycling through the same four palettes.
        let palettes: [TortoisePalette] = [
            .make(style: .natural, phase: .focus),
            .make(style: .tinted, phase: .focus),
            .make(style: .tinted, phase: .shortBreak),
            .make(style: .tinted, phase: .longBreak),
        ]
        let cell: CGFloat = 5
        let sprite = cell * CGFloat(TortoiseSprite.size)
        // Spacing wider than the sprite so the tortoises read as separate
        // characters rather than one continuous band.
        let spacing: CGFloat = 96
        let count = 12
        let total = spacing * CGFloat(count - 1) + sprite
        var x = (footerSize.width - total) / 2
        for index in 0..<count {
            canvas.sprite(palettes[index % palettes.count], atX: x, atY: 12, cell: cell)
            x += spacing
        }

        // Each phase named in its own colour.
        let segments: [(text: String, ink: RGBA)] = [
            ("FOCUS", SessionPhase.focus.baseColor),
            ("SHORT BREAK", SessionPhase.shortBreak.baseColor),
            ("LONG BREAK", SessionPhase.longBreak.baseColor),
        ]
        drawCentred(segments: segments, atY: 98, cell: 5, gap: 8, in: &canvas)

        return canvas.pngData()
    }

    // MARK: Text helpers

    private static func drawCentred(
        _ width: Int, atY y: CGFloat, cell: CGFloat, ink: RGBA, text: String,
        in canvas: inout PixelCanvas
    ) {
        let x = (headerSize.width - CGFloat(width) * cell) / 2
        canvas.text(text, atX: x, atY: y, cell: cell, ink: ink)
    }

    /// Draws several coloured runs of text centred as one line.
    private static func drawCentred(
        segments: [(text: String, ink: RGBA)], atY y: CGFloat, cell: CGFloat, gap: Int,
        in canvas: inout PixelCanvas
    ) {
        var cells = 0
        for (index, segment) in segments.enumerated() {
            cells += PixelFont.width(of: segment.text)
            if index < segments.count - 1 { cells += gap }
        }
        var x = (footerSize.width - CGFloat(cells) * cell) / 2
        for (index, segment) in segments.enumerated() {
            canvas.text(segment.text, atX: x, atY: y, cell: cell, ink: segment.ink)
            x += CGFloat(PixelFont.width(of: segment.text) + gap) * cell
        }
    }
}

/// A mutable RGBA raster addressed in logical points.
///
/// Coordinates are top-left origin, matching both the sprite and the pixel font.
struct PixelCanvas {
    let width: Int
    let height: Int
    let scale: Int
    private var pixels: [UInt8]

    init(size: CGSize, scale: Int) {
        self.width = Int(size.width) * scale
        self.height = Int(size.height) * scale
        self.scale = scale
        self.pixels = [UInt8](repeating: 0, count: width * height * 4)
    }

    mutating func fill(_ color: RGBA) {
        for index in stride(from: 0, to: pixels.count, by: 4) {
            write(color, at: index)
        }
    }

    /// Rectangle given in logical points.
    mutating func rect(x: CGFloat, y: CGFloat, width w: CGFloat, height h: CGFloat, color: RGBA) {
        let x0 = Int((x * CGFloat(scale)).rounded())
        let y0 = Int((y * CGFloat(scale)).rounded())
        let x1 = Int(((x + w) * CGFloat(scale)).rounded())
        let y1 = Int(((y + h) * CGFloat(scale)).rounded())

        for py in max(0, y0)..<min(height, y1) {
            for px in max(0, x0)..<min(width, x1) {
                write(color, at: (py * width + px) * 4)
            }
        }
    }

    /// One sprite pixel per point, scaled.
    mutating func sprite(_ palette: TortoisePalette, atX x: CGFloat, atY y: CGFloat, cell: CGFloat) {
        for gy in 0..<TortoiseSprite.size {
            for gx in 0..<TortoiseSprite.size {
                guard let color = palette.color(for: TortoiseSprite.cell(x: gx, y: gy)) else { continue }
                rect(x: x + CGFloat(gx) * cell, y: y + CGFloat(gy) * cell,
                     width: cell, height: cell, color: color)
            }
        }
    }

    /// Pixel-font text: one font cell per point, scaled.
    mutating func text(_ string: String, atX x: CGFloat, atY y: CGFloat, cell: CGFloat, ink: RGBA) {
        for point in PixelFont.filledCells(of: string) {
            rect(x: x + CGFloat(point.x) * cell, y: y + CGFloat(point.y) * cell,
                 width: cell, height: cell, color: ink)
        }
    }

    private mutating func write(_ color: RGBA, at index: Int) {
        pixels[index + 0] = UInt8(max(0, min(255, color.r * 255)))
        pixels[index + 1] = UInt8(max(0, min(255, color.g * 255)))
        pixels[index + 2] = UInt8(max(0, min(255, color.b * 255)))
        pixels[index + 3] = UInt8(max(0, min(255, color.a * 255)))
    }

    /// PNG bytes, written straight from the buffer (top-down scanlines).
    func pngData() -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4, bitsPerPixel: 32
        ), let destination = rep.bitmapData else { return nil }

        pixels.withUnsafeBytes { source in
            destination.update(from: source.bindMemory(to: UInt8.self).baseAddress!, count: pixels.count)
        }
        return rep.representation(using: .png, properties: [:])
    }
}
