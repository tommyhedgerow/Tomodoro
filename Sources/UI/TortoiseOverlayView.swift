import SwiftUI

/// The floating overlay: the tortoise itself, with the countdown drawn inside its
/// shell using the same pixel grid as the sprite.
///
/// Everything is painted in one Canvas so the art, the digits and the progress bar
/// all land on exact pixel boundaries and stay hard-edged at any scale.
struct TortoiseOverlayView: View {

    @ObservedObject var engine: PomodoroEngine

    /// Style is read from the engine's settings, so changing it in the menu
    /// re-renders the overlay without any explicit plumbing.
    private var style: TortoiseStyle { engine.settings.tortoiseStyle }

    /// Size of one sprite pixel, in points. The overlay is always 16 of these square.
    static var defaultCellSize: CGFloat { TortoiseOverlayMetrics.defaultCellSize }

    private var cell: CGFloat { Self.defaultCellSize }
    private var side: CGFloat { cell * CGFloat(TortoiseSprite.size) }

    var body: some View {
        Canvas { context, _ in
            draw(into: &context)
        }
        .frame(width: side, height: side)
        .accessibilityElement()
        .accessibilityLabel("Tomodoro timer")
        .accessibilityValue("\(engine.phase.displayName) \(Format.clock(engine.remaining))")
    }

    // MARK: Drawing

    private func draw(into context: inout GraphicsContext) {
        let palette = TortoisePalette.make(style: style, phase: engine.phase)

        drawSprite(into: &context, palette: palette)
        drawCountdown(into: &context, palette: palette)
    }

    private func drawSprite(into context: inout GraphicsContext, palette: TortoisePalette) {
        for gy in 0..<TortoiseSprite.size {
            for gx in 0..<TortoiseSprite.size {
                guard let color = palette.color(for: TortoiseSprite.cell(x: gx, y: gy)) else { continue }
                fill(&context, cellX: gx, cellY: gy, cellsWide: 1, cellsHigh: 1, color: color)
            }
        }
    }

    /// Lays out the phase label, the clock and the progress bar inside the shell
    /// area reserved by the sprite.
    private func drawCountdown(into context: inout GraphicsContext, palette: TortoisePalette) {
        let area = TortoiseSprite.textArea
        let areaX = CGFloat(area.x) * cell
        let areaY = CGFloat(area.y) * cell
        let areaW = CGFloat(area.width) * cell
        let areaH = CGFloat(area.height) * cell

        // Three stacked elements, sized to leave even margins inside the shell.
        let labelCell = TortoiseOverlayMetrics.labelCellSize
        let digitCell = TortoiseOverlayMetrics.digitCellSize
        let barHeight = TortoiseOverlayMetrics.barHeight

        let label = engine.phase.shortName.uppercased()
        let labelW = CGFloat(PixelFont.width(of: label)) * labelCell
        let labelH = CGFloat(PixelFont.glyphHeight) * labelCell

        let clock = Format.clock(engine.remaining)
        let clockW = CGFloat(PixelFont.width(of: clock)) * digitCell
        let clockH = CGFloat(PixelFont.glyphHeight) * digitCell

        let contentH = labelH + TortoiseOverlayMetrics.labelGap
            + clockH + TortoiseOverlayMetrics.barGap + barHeight
        let top = areaY + ((areaH - contentH) / 2).rounded()

        let ink = engine.isRunning ? palette.ink : palette.ink.withAlpha(0.55)

        drawText(into: &context, text: label, originX: areaX + ((areaW - labelW) / 2).rounded(),
                 originY: top, cellSize: labelCell, color: palette.trim)

        let clockY = top + labelH + TortoiseOverlayMetrics.labelGap
        drawText(into: &context, text: clock, originX: areaX + ((areaW - clockW) / 2).rounded(),
                 originY: clockY, cellSize: digitCell, color: ink)

        // Progress bar, inset from the shell edges and aligned to the pixel grid.
        let barInset = cell
        let barX = areaX + barInset
        let barW = areaW - barInset * 2
        let barY = clockY + clockH + TortoiseOverlayMetrics.barGap

        fill(&context, rect: CGRect(x: barX, y: barY, width: barW, height: barHeight),
             color: palette.outline.withAlpha(0.45))

        let filled = (barW * CGFloat(min(1, max(0, engine.progress)))).rounded()
        if filled >= 1 {
            fill(&context, rect: CGRect(x: barX, y: barY, width: filled, height: barHeight),
                 color: engine.isRunning ? palette.trim : palette.trim.withAlpha(0.55))
        }
    }

    private func drawText(
        into context: inout GraphicsContext, text: String,
        originX: CGFloat, originY: CGFloat, cellSize: CGFloat, color: RGBA
    ) {
        for point in PixelFont.filledCells(of: text) {
            fill(&context, rect: CGRect(
                x: originX + CGFloat(point.x) * cellSize,
                y: originY + CGFloat(point.y) * cellSize,
                width: cellSize, height: cellSize
            ), color: color)
        }
    }

    // MARK: Pixel helpers

    private func fill(
        _ context: inout GraphicsContext, cellX: Int, cellY: Int,
        cellsWide: Int, cellsHigh: Int, color: RGBA
    ) {
        fill(&context, rect: CGRect(
            x: CGFloat(cellX) * cell, y: CGFloat(cellY) * cell,
            width: CGFloat(cellsWide) * cell, height: CGFloat(cellsHigh) * cell
        ), color: color)
    }

    private func fill(_ context: inout GraphicsContext, rect: CGRect, color: RGBA) {
        context.fill(Path(rect), with: .color(Color(color)))
    }
}
