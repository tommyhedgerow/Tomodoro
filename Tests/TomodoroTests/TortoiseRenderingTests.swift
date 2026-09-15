import XCTest
import CoreGraphics
import ImageIO

/// Renders the sprite through the same code path the app uses, decodes the PNG
/// bytes back, and checks the result.
///
/// This is the test that catches a flipped or mirrored sprite. A unit test that
/// only inspects the source grid cannot see an encoder that writes scanlines in
/// the wrong order, which is exactly the bug this guards against.
final class TortoiseRenderingTests: XCTestCase {

    private struct Decoded {
        let width: Int
        let height: Int
        /// Rows top-down, matching the sprite's own row order.
        let rows: [[RGBA]]
    }

    /// Decodes a PNG into top-down RGBA rows.
    ///
    /// A CGBitmapContext's buffer already stores its first row as the top of the
    /// image, so the rows come out in the same order the sprite is authored in.
    /// (Reasoning about this from the context's bottom-left origin gets it
    /// backwards; the assertion in testImageIsNotVerticallyFlipped pins it down.)
    private func decodeTopDown(_ data: Data) throws -> Decoded {
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
        for y in 0..<height {
            let sourceRow = y
            var row: [RGBA] = []
            for x in 0..<width {
                let i = (sourceRow * width + x) * 4
                row.append(RGBA(
                    r: Double(buffer[i]) / 255,
                    g: Double(buffer[i + 1]) / 255,
                    b: Double(buffer[i + 2]) / 255,
                    a: Double(buffer[i + 3]) / 255
                ))
            }
            rows.append(row)
        }
        return Decoded(width: width, height: height, rows: rows)
    }

    private func close(_ a: RGBA, _ b: RGBA) -> Bool {
        // Colour management can shift a channel by a hair on the round trip.
        func near(_ x: Double, _ y: Double) -> Bool { abs(x - y) <= 0.01 }
        return near(a.r, b.r) && near(a.g, b.g) && near(a.b, b.b) && near(a.a, b.a)
    }

    func testRenderedSpriteMatchesTheSourceGrid() throws {
        for phase in SessionPhase.allCases {
            let data = try XCTUnwrap(
                TortoiseImageFactory.pngData(style: .natural, phase: phase, pixelSize: 16),
                "no PNG for \(phase)"
            )
            let decoded = try decodeTopDown(data)
            XCTAssertEqual(decoded.width, 16)
            XCTAssertEqual(decoded.height, 16)

            let palette = TortoisePalette.make(style: .natural, phase: phase)
            for y in 0..<16 {
                for x in 0..<16 {
                    let cell = TortoiseSprite.cell(x: x, y: y)
                    let actual = decoded.rows[y][x]
                    if let expected = palette.color(for: cell) {
                        XCTAssertTrue(close(actual, expected),
                                      "\(phase) pixel (\(x),\(y)) is \(actual), expected \(expected)")
                    } else {
                        XCTAssertEqual(actual.a, 0, "\(phase) pixel (\(x),\(y)) should be transparent")
                    }
                }
            }
        }
    }

    /// Guards the specific regression where the sprite rendered upside down:
    /// bitmap scanline order is top-down, and flipping it put the feet on top.
    func testImageIsNotVerticallyFlipped() throws {
        let data = try XCTUnwrap(TortoiseImageFactory.pngData(style: .natural, phase: .focus, pixelSize: 16))
        let decoded = try decodeTopDown(data)

        let inkedRows = (0..<16).filter { y in decoded.rows[y].contains { $0.a > 0 } }
        XCTAssertEqual(inkedRows.first, 1, "the shell top should be the first inked row")
        XCTAssertEqual(inkedRows.last, 13, "the feet should be the last inked row")

        // Row 1 is the crown of the shell: four pixels in the middle.
        let topColumns = (0..<16).filter { decoded.rows[1][$0].a > 0 }
        XCTAssertEqual(topColumns, [4, 5, 6, 7], "top row shape is wrong; image may be flipped")

        // Row 13 is the feet: two separate groups, on the flared last row of
        // the legs, which is the row below the straight part of each leg.
        let footColumns = (0..<16).filter { decoded.rows[13][$0].a > 0 }
        XCTAssertEqual(footColumns, [2, 3, 4, 7, 8, 9])
        let legColumns = (0..<16).filter { decoded.rows[12][$0].a > 0 }
        XCTAssertEqual(legColumns, [3, 4, 7, 8], "one straight row above the feet")
    }

    func testImageIsNotHorizontallyMirrored() throws {
        let data = try XCTUnwrap(TortoiseImageFactory.pngData(style: .natural, phase: .focus, pixelSize: 16))
        let decoded = try decodeTopDown(data)
        // The head is on the right: row 7 has skin on its right-hand side only.
        let palette = TortoisePalette.make(style: .natural, phase: .focus)
        for x in 0..<12 {
            XCTAssertFalse(close(decoded.rows[7][x], palette.skin),
                           "skin found at x=\(x) on the left; the image may be mirrored")
        }
        XCTAssertTrue(close(decoded.rows[7][13], palette.skin))
    }

    func testMenuBarIconIsNotATemplate() {
        let icon = TortoiseImageFactory.menuBarIcon(style: .natural, phase: .focus)
        XCTAssertFalse(icon.isTemplate, "a template image would be drawn monochrome in the menu bar")
        XCTAssertEqual(icon.size.width, 16)
    }

    func testCachedImageIsStable() {
        let first = TortoiseImageFactory.cachedImage(style: .natural, phase: .focus, pointSize: 56)
        let second = TortoiseImageFactory.cachedImage(style: .natural, phase: .focus, pointSize: 56)
        XCTAssertTrue(first === second, "the cache should return the same instance")
    }
}
