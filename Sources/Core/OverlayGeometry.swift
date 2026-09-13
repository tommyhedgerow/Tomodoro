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

    static var side: CGFloat { defaultCellSize * CGFloat(TortoiseSprite.size) }

    /// The countdown area of the shell, in points.
    static var textAreaRect: CGRect {
        let area = TortoiseSprite.textArea
        return CGRect(
            x: CGFloat(area.x) * defaultCellSize,
            y: CGFloat(area.y) * defaultCellSize,
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

    /// Maps a point to a sprite cell.
    ///
    /// The point and bounds are in AppKit's default bottom-left coordinate space,
    /// while the sprite is authored top-down, so the row is measured from the top.
    static func spriteCell(forPoint point: CGPoint, in bounds: CGRect) -> (x: Int, y: Int) {
        let column = Int(floor(point.x / defaultCellSize))
        let row = Int(floor((bounds.height - point.y) / defaultCellSize))
        return (x: column, y: row)
    }

    /// Whether a click at this point lands on the tortoise rather than on the
    /// transparent surround. Transparent pixels fall through to whatever is behind.
    static func isHit(point: CGPoint, in bounds: CGRect) -> Bool {
        let cell = spriteCell(forPoint: point, in: bounds)
        return TortoiseSprite.isOpaque(x: cell.x, y: cell.y)
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
