import AppKit

/// Renders the 16x16 sprite into an NSImage.
///
/// Every sprite pixel maps to a whole number of device pixels, so the art stays
/// hard-edged at any size. Each image carries a 1x and a 2x representation so it
/// stays crisp on Retina displays and in the menu bar.
enum TortoiseImageFactory {

    private static var cache: [String: NSImage] = [:]

    /// Renders are cheap but happen on every SwiftUI body evaluation, so keep the
    /// handful of distinct combinations we actually use.
    static func cachedImage(style: TortoiseStyle, phase: SessionPhase, pointSize: CGFloat) -> NSImage {
        let key = "\(style.rawValue)-\(phase.rawValue)-\(pointSize)"
        if let hit = cache[key] { return hit }
        let made = image(style: style, phase: phase, pointSize: pointSize)
        cache[key] = made
        return made
    }

    static func image(style: TortoiseStyle, phase: SessionPhase, pointSize: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        let palette = TortoisePalette.make(style: style, phase: phase)

        for scale in [1.0, 2.0] {
            let targetPixels = Int((pointSize * scale).rounded())
            // Largest whole-pixel zoom that fits the requested point size.
            let cell = max(1, Int((Double(targetPixels) / Double(TortoiseSprite.size)).rounded()))
            guard let rep = makeRepresentation(palette: palette, cell: cell, pointSize: pointSize) else { continue }
            image.addRepresentation(rep)
        }
        return image
    }

    private static func makeRepresentation(
        palette: TortoisePalette, cell: Int, pointSize: CGFloat
    ) -> NSBitmapImageRep? {
        let pixels = cell * TortoiseSprite.size
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: pixels * 4, bitsPerPixel: 32
        ), let data = rep.bitmapData else { return nil }

        memset(data, 0, pixels * pixels * 4)

        for gy in 0..<TortoiseSprite.size {
            for gx in 0..<TortoiseSprite.size {
                guard let color = palette.color(for: TortoiseSprite.cell(x: gx, y: gy)) else { continue }
                // NSBitmapImageRep stores scanlines top-down, matching the sprite
                // row order, so no flip is needed.
                fill(data: data, pixels: pixels, x0: gx * cell, y0: gy * cell,
                     size: cell, color: color)
            }
        }

        rep.size = NSSize(width: pointSize, height: pointSize)
        return rep
    }

    private static func fill(
        data: UnsafeMutablePointer<UInt8>, pixels: Int,
        x0: Int, y0: Int, size: Int, color: RGBA
    ) {
        let r = UInt8(max(0, min(255, color.r * 255)))
        let g = UInt8(max(0, min(255, color.g * 255)))
        let b = UInt8(max(0, min(255, color.b * 255)))
        let a = UInt8(max(0, min(255, color.a * 255)))
        for y in y0..<(y0 + size) {
            for x in x0..<(x0 + size) {
                let i = (y * pixels + x) * 4
                data[i + 0] = r
                data[i + 1] = g
                data[i + 2] = b
                data[i + 3] = a
            }
        }
    }

    /// Menu bar icon. Not a template image, so the colour survives.
    static func menuBarIcon(style: TortoiseStyle, phase: SessionPhase) -> NSImage {
        let image = image(style: style, phase: phase, pointSize: 16)
        image.isTemplate = false
        image.accessibilityDescription = "Tomodoro: \(phase.displayName)"
        return image
    }

    /// The sprite scaled to an arbitrary square, for app-icon export and tests.
    static func pngData(style: TortoiseStyle, phase: SessionPhase, pixelSize: Int) -> Data? {
        let palette = TortoisePalette.make(style: style, phase: phase)
        let cell = max(1, pixelSize / TortoiseSprite.size)
        let pixels = cell * TortoiseSprite.size
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: pixels * 4, bitsPerPixel: 32
        ), let data = rep.bitmapData else { return nil }

        memset(data, 0, pixels * pixels * 4)
        for gy in 0..<TortoiseSprite.size {
            for gx in 0..<TortoiseSprite.size {
                guard let color = palette.color(for: TortoiseSprite.cell(x: gx, y: gy)) else { continue }
                fill(data: data, pixels: pixels, x0: gx * cell, y0: gy * cell, size: cell, color: color)
            }
        }
        return rep.representation(using: .png, properties: [:])
    }
}
