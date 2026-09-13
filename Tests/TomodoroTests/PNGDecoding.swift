import XCTest
import CoreGraphics
import ImageIO

/// A decoded PNG, with rows in the same top-down order the sprite is authored in.
struct DecodedPNG {
    let width: Int
    let height: Int
    let rows: [[RGBA]]

    func pixel(x: Int, y: Int) -> RGBA { rows[y][x] }
}

/// Decodes PNG bytes through CoreGraphics.
///
/// A CGBitmapContext's buffer already stores its first row as the top of the
/// image, so the rows come out in the sprite's own order. (Reasoning about this
/// from the context's bottom-left origin gets it backwards; the flip assertions
/// in the rendering tests pin the convention down.)
func decodePNG(_ data: Data) throws -> DecodedPNG {
    let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
    let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
    let width = image.width
    let height = image.height

    var buffer = [UInt8](repeating: 0, count: width * height * 4)
    let context = try XCTUnwrap(CGContext(
        data: &buffer, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

    var rows: [[RGBA]] = []
    rows.reserveCapacity(height)
    for y in 0..<height {
        var row: [RGBA] = []
        row.reserveCapacity(width)
        for x in 0..<width {
            let i = (y * width + x) * 4
            row.append(RGBA(
                r: Double(buffer[i]) / 255,
                g: Double(buffer[i + 1]) / 255,
                b: Double(buffer[i + 2]) / 255,
                a: Double(buffer[i + 3]) / 255
            ))
        }
        rows.append(row)
    }
    return DecodedPNG(width: width, height: height, rows: rows)
}

/// True when two colours match within a small tolerance.
///
/// Colour management can shift a channel by a hair on the way through PNG.
func coloursMatch(_ a: RGBA, _ b: RGBA, tolerance: Double = 0.01) -> Bool {
    abs(a.r - b.r) <= tolerance && abs(a.g - b.g) <= tolerance
        && abs(a.b - b.b) <= tolerance && abs(a.a - b.a) <= tolerance
}
