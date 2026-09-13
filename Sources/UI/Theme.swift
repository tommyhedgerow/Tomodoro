import SwiftUI
import AppKit

extension Color {
    init(_ rgba: RGBA) {
        self.init(.sRGB, red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
    }
}

extension SessionPhase {
    var color: Color { Color(baseColor) }

    var accentNSColor: NSColor {
        NSColor(srgbRed: CGFloat(baseColor.r), green: CGFloat(baseColor.g),
                blue: CGFloat(baseColor.b), alpha: 1)
    }
}

enum Format {
    /// mm:ss, clamped at zero.
    static func clock(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval).rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func endTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

/// The pixel-art tortoise, rendered from the shared sprite so it stays identical
/// to the menu bar icon and the overlay.
struct TortoiseView: View {
    let style: TortoiseStyle
    let phase: SessionPhase
    var pointSize: CGFloat = 48

    var body: some View {
        Image(nsImage: TortoiseImageFactory.cachedImage(style: style, phase: phase, pointSize: pointSize))
            .resizable()
            .interpolation(.none)          // keep the pixels hard-edged
            .frame(width: pointSize, height: pointSize)
            .accessibilityHidden(true)
    }
}

/// Thin progress bar tinted with the current phase colour.
struct PhaseProgressBar: View {
    let progress: Double
    let color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: max(0, min(1, progress)) * geo.size.width)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// One dot per focus session in the current cycle.
struct SessionDots: View {
    let completedInCycle: Int
    let cycleLength: Int
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(1, cycleLength), id: \.self) { index in
                Circle()
                    .fill(index < completedInCycle ? color : Color.primary.opacity(0.16))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityHidden(true)
    }
}

extension NSScreen {
    /// Visible height, used to bound the dropdown so it cannot overflow the screen.
    var tomodoroPopupHeight: CGFloat {
        PopoverMetrics.contentHeight(availableHeight: visibleFrame.height)
    }
}
