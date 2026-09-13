import XCTest

/// The README banners are generated from the sprite, so they get the same
/// protection as the app icon: if the art or the layout changes badly, these fail.
final class BannerRendererTests: XCTestCase {

    private let scale = BannerRenderer.scale

    func testHeaderHasTheExpectedDimensions() throws {
        let data = try XCTUnwrap(BannerRenderer.headerPNG())
        let image = try decodePNG(data)
        XCTAssertEqual(image.width, Int(BannerRenderer.headerSize.width) * scale)
        XCTAssertEqual(image.height, Int(BannerRenderer.headerSize.height) * scale)
    }

    func testFooterHasTheExpectedDimensions() throws {
        let data = try XCTUnwrap(BannerRenderer.footerPNG())
        let image = try decodePNG(data)
        XCTAssertEqual(image.width, Int(BannerRenderer.footerSize.width) * scale)
        XCTAssertEqual(image.height, Int(BannerRenderer.footerSize.height) * scale)
    }

    /// The whole point of the banners is showing the tortoise in several colours.
    func testBannersShowEveryPhaseColour() throws {
        let palettes = SessionPhase.allCases.map { TortoisePalette.make(style: .tinted, phase: $0) }
        for (name, data) in [("header", try XCTUnwrap(BannerRenderer.headerPNG())),
                             ("footer", try XCTUnwrap(BannerRenderer.footerPNG()))] {
            let image = try decodePNG(data)
            for palette in palettes {
                XCTAssertTrue(containsColour(palette.shell, in: image),
                              "\(name) banner is missing the \(palette.shell) shell colour")
            }
            XCTAssertTrue(containsColour(TortoisePalette.referenceShell, in: image),
                          "\(name) banner is missing the natural brown shell")
        }
    }

    /// A banner that runs off its own edge would be cropped wherever it is shown.
    func testContentStaysInsideTheBanner() throws {
        for (name, data) in [("header", try XCTUnwrap(BannerRenderer.headerPNG())),
                             ("footer", try XCTUnwrap(BannerRenderer.footerPNG()))] {
            let image = try decodePNG(data)
            let margin = 8

            for y in 0..<image.height {
                for x in 0..<image.width where x < margin || x >= image.width - margin {
                    XCTAssertFalse(isInk(image.pixel(x: x, y: y), on: BannerRenderer.backgroundColour),
                                   "\(name) banner has content in the side margin at (\(x),\(y))")
                }
            }
            for x in 0..<image.width {
                for y in 0..<image.height where y < margin || y >= image.height - margin {
                    XCTAssertFalse(isInk(image.pixel(x: x, y: y), on: BannerRenderer.backgroundColour),
                                   "\(name) banner has content in the top or bottom margin at (\(x),\(y))")
                }
            }
        }
    }

    func testBannersAreNotBlank() throws {
        for data in [try XCTUnwrap(BannerRenderer.headerPNG()),
                     try XCTUnwrap(BannerRenderer.footerPNG())] {
            let image = try decodePNG(data)
            var inked = 0
            for row in image.rows {
                for pixel in row where isInk(pixel, on: BannerRenderer.backgroundColour) { inked += 1 }
            }
            XCTAssertGreaterThan(inked, 1000, "banner looks empty")
        }
    }

    func testExportWritesBothFiles() throws {
        let directory = NSTemporaryDirectory() + "tomodoro-banner-test-\(UUID().uuidString)"
        defer { try? FileManager.default.removeItem(atPath: directory) }

        XCTAssertTrue(BannerRenderer.export(to: directory))
        for name in ["readme-header.png", "readme-footer.png"] {
            let path = directory + "/" + name
            XCTAssertTrue(FileManager.default.fileExists(atPath: path), "\(name) was not written")
        }
    }

    // MARK: Helpers

    private func isInk(_ pixel: RGBA, on background: RGBA) -> Bool {
        !coloursMatch(pixel, background, tolerance: 0.06)
    }

    private func containsColour(_ colour: RGBA, in image: DecodedPNG) -> Bool {
        for row in image.rows {
            for pixel in row where coloursMatch(pixel, colour, tolerance: 0.02) { return true }
        }
        return false
    }
}
