import SwiftUI
import Combine

/// The floating overlay: the tortoise himself, animated, with the countdown drawn
/// inside his shell using the same pixel grid as the art.
///
/// Everything is painted in one Canvas so the art, the props, the digits and the
/// progress bar all land on exact pixel boundaries and stay hard-edged at any
/// scale. Motion is stepped by `TortoiseAnimator`, which works in whole cells, so
/// every frame is still pixel art rather than a resampled image.
struct TortoiseOverlayView: View {

    @ObservedObject var engine: PomodoroEngine
    @ObservedObject var animator: TortoiseAnimator

    @State private var lastTick: Date?

    /// Style is read from the engine's settings, so changing it in the menu
    /// re-renders the overlay without any explicit plumbing.
    private var style: TortoiseStyle { engine.settings.tortoiseStyle }

    /// Size of one sprite pixel, in points.
    static var defaultCellSize: CGFloat { TortoiseOverlayMetrics.defaultCellSize }

    private var cell: CGFloat { Self.defaultCellSize }

    var body: some View {
        TimelineView(.periodic(from: .now, by: TortoiseOverlayView.frameInterval)) { timeline in
            Canvas { context, _ in
                draw(into: &context)
            }
            .onChange(of: timeline.date) { _, date in
                step(to: date)
            }
        }
        .frame(width: TortoiseOverlayMetrics.width, height: TortoiseOverlayMetrics.height)
        .accessibilityElement()
        .accessibilityLabel("Tomodoro timer")
        .accessibilityValue("\(engine.phase.displayName) \(Format.clock(engine.remaining))")
        .onAppear {
            animator.isVisible = true
            animator.update(from: engine)
            lastTick = Date()
        }
        .onDisappear {
            animator.isVisible = false
            lastTick = nil
        }
    }

    /// ~30fps. The animator only publishes a new frame when the art actually
    /// changes, so a still tortoise costs one comparison per tick and no redraw.
    /// The poses are held for at least 0.16s, which is five frames at this rate,
    /// so nothing is skipped.
    static let frameInterval: TimeInterval = 1.0 / 30.0

    private func step(to date: Date) {
        defer { lastTick = date }
        // A hidden overlay gets no ticks at all, so a long gap just means the
        // animator should pick up from now rather than replay the downtime.
        guard let last = lastTick, date > last, date.timeIntervalSince(last) < 1 else { return }
        animator.advance(by: date.timeIntervalSince(last))
    }

    // MARK: Drawing

    private func draw(into context: inout GraphicsContext) {
        let palette = TortoisePalette.make(style: style, phase: engine.phase)
        let scene = TortoiseScene(frame: animator.frame)

        drawScene(scene, into: &context, palette: palette)
        drawCountdown(into: &context, palette: palette)
    }

    private func drawScene(_ scene: TortoiseScene, into context: inout GraphicsContext, palette: TortoisePalette) {
        for gy in 0..<TortoiseScene.height {
            for gx in 0..<TortoiseScene.width {
                guard let (cellType, alpha) = scene.cell(x: gx, y: gy) else { continue }
                guard let color = palette.color(for: cellType) else { continue }
                fill(&context, sceneX: gx, sceneY: gy, color: alpha >= 1 ? color : color.withAlpha(alpha))
            }
        }
    }

    /// Lays out the phase label, the clock and the progress bar inside the shell
    /// area reserved by the sprite.
    ///
    /// The shell never moves, whatever pose he is in, so the countdown stays put
    /// while the head bobs or while he sleeps.
    private func drawCountdown(into context: inout GraphicsContext, palette: TortoisePalette) {
        let area = TortoiseOverlayMetrics.textAreaRect

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
        let top = area.minY + ((area.height - contentH) / 2).rounded()

        let ink = engine.isRunning ? palette.ink : palette.ink.withAlpha(0.55)

        drawText(into: &context, text: label, originX: area.minX + ((area.width - labelW) / 2).rounded(),
                 originY: top, cellSize: labelCell, color: palette.trim)

        let clockY = top + labelH + TortoiseOverlayMetrics.labelGap
        drawText(into: &context, text: clock, originX: area.minX + ((area.width - clockW) / 2).rounded(),
                 originY: clockY, cellSize: digitCell, color: ink)

        // Progress bar, inset from the shell edges and aligned to the pixel grid.
        let barInset = cell
        let barX = area.minX + barInset
        let barW = area.width - barInset * 2
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
        _ context: inout GraphicsContext, sceneX: Int, sceneY: Int, color: RGBA
    ) {
        fill(&context, rect: CGRect(
            x: CGFloat(sceneX) * cell, y: CGFloat(sceneY) * cell,
            width: cell, height: cell
        ), color: color)
    }

    private func fill(_ context: inout GraphicsContext, rect: CGRect, color: RGBA) {
        context.fill(Path(rect), with: .color(Color(color)))
    }
}

extension TortoiseAnimator {
    /// Feeds the engine's state in. Called when the overlay appears and on every
    /// engine tick, so pausing, resuming and a minute rolling over are all seen.
    func update(from engine: PomodoroEngine) {
        update(
            isRunning: engine.isRunning,
            // Paused part-way through a session is the sleeping pose. An idle
            // timer at full duration is not asleep, he is just waiting.
            isPaused: !engine.isRunning && engine.isSessionInProgress,
            remaining: engine.remaining
        )
    }
}
