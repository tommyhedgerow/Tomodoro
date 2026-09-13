import AppKit

/// Draws the app icon: a rounded tile with the tortoise centred on it.
///
/// Exported as an .iconset by build.sh, then compiled to .icns with iconutil.
/// Uses an offscreen bitmap rather than lockFocus so it works headlessly during
/// a build, before NSApplication exists.
enum AppIconRenderer {

    static let iconsetEntries: [(name: String, pixels: Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32),
        ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256),
        ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]

    @discardableResult
    static func exportIconset(to directory: String) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(atPath: directory, withIntermediateDirectories: true)
        } catch {
            NSLog("Tomodoro: could not create iconset directory: \(error)")
            return false
        }

        // iconutil requires every canonical filename to be present, even where
        // two entries share the same pixel dimensions (1x and @2x slots).
        for entry in iconsetEntries {
            guard let data = png(pixelSize: entry.pixels) else { continue }
            let path = directory + "/" + entry.name + ".png"
            do {
                try data.write(to: URL(fileURLWithPath: path))
            } catch {
                NSLog("Tomodoro: could not write \(path): \(error)")
                return false
            }
        }
        return true
    }

    static func png(pixelSize: Int) -> Data? {
        let side = max(16, pixelSize)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: side * 4, bitsPerPixel: 32
        ) else { return nil }

        guard let context = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .none

        let bounds = NSRect(x: 0, y: 0, width: side, height: side)

        // Rounded tile background.
        let radius = CGFloat(side) * 0.225
        let tile = NSBezierPath(roundedRect: bounds, xRadius: radius, yRadius: radius)
        NSColor(srgbRed: 0.145, green: 0.145, blue: 0.176, alpha: 1).setFill()
        tile.fill()

        // Tortoise, inset so it reads as an icon rather than a full bleed.
        let inset = CGFloat(side) * 0.11
        let artRect = bounds.insetBy(dx: inset, dy: inset)
        let art = TortoiseImageFactory.image(style: .natural, phase: .focus, pointSize: artRect.width)
        art.draw(in: artRect, from: .zero, operation: .sourceOver, fraction: 1,
                 respectFlipped: false,
                 hints: [.interpolation: NSImageInterpolation.none.rawValue])

        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
}
