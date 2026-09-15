import CoreGraphics
import Foundation

/// Layout constants for the tortoise overlay.
///
/// Kept out of the view so the fit between the clock and the shell can be tested
/// directly, without instantiating any UI.
enum TortoiseOverlayMetrics {

    /// Size of one sprite pixel in points. Larger means a chunkier tortoise.
    static let defaultCellSize: CGFloat = 13
    static let labelCellSize: CGFloat = 3
    static let digitCellSize: CGFloat = 5
    static let barHeight: CGFloat = 6

    /// Gap above the clock and below it, in points.
    static let labelGap: CGFloat = 6
    static let barGap: CGFloat = 8

    /// The tortoise occupies the bottom-left 16x16 of a larger scene; the extra
    /// columns and rows are where his dandelion and his sleeping z's live. He is
    /// bottom-anchored, so the window can grow without moving him on screen.
    static var spriteSide: CGFloat { defaultCellSize * CGFloat(TortoiseSprite.size) }
    static var width: CGFloat { defaultCellSize * CGFloat(TortoiseScene.width) }
    static var height: CGFloat { defaultCellSize * CGFloat(TortoiseScene.height) }

    /// Kept for callers that only care about the tortoise's own square.
    static var side: CGFloat { spriteSide }

    /// The scene rectangle the overlay draws into.
    static var bounds: CGRect { CGRect(x: 0, y: 0, width: width, height: height) }

    /// Top edge of the tortoise within the window, in points. Everything above it
    /// is the headroom props are drawn in.
    static var spriteTop: CGFloat { CGFloat(TortoiseScene.spriteY) * defaultCellSize }

    /// The countdown area of the shell, in points, in window coordinates.
    static var textAreaRect: CGRect {
        let area = TortoiseSprite.textArea
        return CGRect(
            x: CGFloat(area.x + TortoiseScene.spriteX) * defaultCellSize,
            y: spriteTop + CGFloat(area.y) * defaultCellSize,
            width: CGFloat(area.width) * defaultCellSize,
            height: CGFloat(area.height) * defaultCellSize
        )
    }

    /// Total height of the stacked label, clock and progress bar.
    static var stackedContentHeight: CGFloat {
        CGFloat(PixelFont.glyphHeight) * labelCellSize
            + labelGap
            + CGFloat(PixelFont.glyphHeight) * digitCellSize
            + barGap
            + barHeight
    }

    /// Maps a point in the window to a scene cell.
    ///
    /// The point and bounds are in AppKit's default bottom-left coordinate space,
    /// while the scene is authored top-down, so the row is measured from the top.
    static func sceneCell(forPoint point: CGPoint, in bounds: CGRect) -> (x: Int, y: Int) {
        let column = Int(floor(point.x / defaultCellSize))
        let row = Int(floor((bounds.height - point.y) / defaultCellSize))
        return (x: column, y: row)
    }

    /// Maps a point in the window to a sprite cell. Offsets account for the
    /// headroom above the tortoise, so the result is always a sprite coordinate.
    static func spriteCell(forPoint point: CGPoint, in bounds: CGRect) -> (x: Int, y: Int) {
        let scene = sceneCell(forPoint: point, in: bounds)
        return (x: scene.x - TortoiseScene.spriteX, y: scene.y - TortoiseScene.spriteY)
    }

    /// Whether a click at this point lands on the tortoise or on a prop rather
    /// than on the transparent surround. Transparent pixels fall through to
    /// whatever is behind.
    static func isHit(point: CGPoint, in bounds: CGRect, scene: TortoiseScene? = nil) -> Bool {
        let cell = sceneCell(forPoint: point, in: bounds)
        if let scene { return scene.covers(x: cell.x, y: cell.y) }
        let sprite = spriteCell(forPoint: point, in: bounds)
        return TortoiseSprite.isOpaque(x: sprite.x, y: sprite.y)
    }

    /// True when the stacked content fits the reserved shell area.
    static func contentFitsShell() -> Bool {
        let area = textAreaRect
        let clockWidth = CGFloat(PixelFont.width(of: "25:00")) * digitCellSize
        let labelWidth = CGFloat(PixelFont.width(of: "SHORT")) * labelCellSize
        let barWidth = area.width - defaultCellSize * 2      // inset matches the view
        return stackedContentHeight <= area.height
            && clockWidth <= area.width
            && labelWidth <= area.width
            && barWidth > 0
    }
}

/// Geometry for the menu bar dropdown.
///
/// AppKit anchors the popover below the status item correctly, but its height is
/// only safe if the content is bounded: an unbounded SwiftUI stack grows tall
/// enough to push the dropdown off the top of the screen.
enum PopoverMetrics {
    static let width: CGFloat = 312
    /// Comfortable height with the settings section collapsed.
    static let preferredHeight: CGFloat = 470
    static let minimumHeight: CGFloat = 260

    /// Height that fits the screen, never exceeding what is actually available.
    static func contentHeight(availableHeight: CGFloat?) -> CGFloat {
        guard let availableHeight, availableHeight.isFinite else { return preferredHeight }
        // Leave a margin so the popover never touches the bottom edge.
        let usable = availableHeight - 24
        return max(minimumHeight, min(preferredHeight, usable))
    }

    static func contentSize(availableHeight: CGFloat?) -> CGSize {
        CGSize(width: width, height: contentHeight(availableHeight: availableHeight))
    }
}
