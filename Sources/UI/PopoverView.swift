import SwiftUI

/// Actions the views can trigger, supplied by the app delegate.
struct AppActions {
    var toggle: () -> Void = {}
    var reset: () -> Void = {}
    var skip: () -> Void = {}
    var resetAll: () -> Void = {}
    var selectPhase: (SessionPhase) -> Void = { _ in }
    var setOverlayShown: (Bool) -> Void = { _ in }
    var setOverlayKeepVisible: (Bool) -> Void = { _ in }
    var toggleOverlay: () -> Void = {}
    var quit: () -> Void = {}
}

/// UI-only state that is not part of the timer itself.
final class UIState: ObservableObject {
    /// Mirrors OverlayWindowController so the menus can show the current state.
    @Published var overlayVisibility: OverlayVisibility = .automatic
    @Published var hotKeyWarnings: [String] = []
    @Published var notificationsAvailable: Bool = true
}

/// The menu bar dropdown.
///
/// The whole thing lives in a ScrollView with a fixed width and a height bounded
/// by PopoverMetrics, so the settings section can never grow the popover past the
/// screen.
struct PopoverView: View {
    @ObservedObject var engine: PomodoroEngine
    @ObservedObject var ui: UIState
    let actions: AppActions

    @State private var showSettings: Bool

    private var phaseColor: Color { engine.phase.color }

    /// - Parameter initiallyShowSettings: seeds the settings disclosure, so a
    ///   screenshot build can capture the panel already expanded.
    init(engine: PomodoroEngine, ui: UIState, actions: AppActions,
         initiallyShowSettings: Bool = false) {
        self.engine = engine
        self.ui = ui
        self.actions = actions
        _showSettings = State(initialValue: initiallyShowSettings)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                header
                PhaseProgressBar(progress: engine.progress, color: phaseColor)
                cycleRow
                dandelionRow
                controls
                Divider()
                phasePicker
                Divider()
                settingsSection
                Divider()
                footer
            }
            .padding(16)
            .frame(width: PopoverMetrics.width - 8, alignment: .leading)
        }
        .frame(width: PopoverMetrics.width)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            TortoiseView(style: engine.settings.tortoiseStyle, phase: engine.phase, pointSize: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(engine.phase.displayName.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(phaseColor)
                Text(Format.clock(engine.remaining))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(statusLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var statusLine: String {
        if engine.isRunning, let end = engine.phaseEndDate {
            return "Ends at " + Format.endTime(end)
        }
        return engine.remaining < engine.currentPhaseDuration ? "Paused" : "Ready"
    }

    // MARK: Cycle

    private var cycleRow: some View {
        HStack(spacing: 8) {
            SessionDots(
                completedInCycle: engine.completedFocusSessions % max(1, engine.settings.sessionsUntilLongBreak),
                cycleLength: max(1, engine.settings.sessionsUntilLongBreak),
                color: phaseColor
            )
            Text(cycleText)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
        }
    }

    private var cycleText: String {
        let n = engine.sessionsUntilLongBreak
        let base = n == 1 ? "Long break after the next focus session"
                          : "\(n) focus sessions until a long break"
        return engine.totalFocusSessions > 0 ? base + "  ·  \(engine.totalFocusSessions) total" : base
    }

    /// The dandelions he has eaten: one per focus session that finished. It is
    /// the app's currency, so it is shown as a running total of its own rather
    /// than as a detail of the current session.
    private var dandelionRow: some View {
        HStack(spacing: 10) {
            DandelionBadge(pointSize: 3)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(engine.dandelionsEaten)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(engine.dandelionsEaten == 1 ? "dandelion eaten" : "dandelions eaten")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05))
        )
        .help("He eats a dandelion every time a focus session finishes. "
              + "Dandelions are his currency.")
        .accessibilityElement(children: .combine)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 8) {
            Button(action: actions.toggle) {
                Label(engine.isRunning ? "Pause" : "Start",
                      systemImage: engine.isRunning ? "pause.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(phaseColor)

            Button(action: actions.reset) {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)

            Button(action: actions.skip) {
                Label("Skip", systemImage: "forward.end.fill")
            }
            .buttonStyle(.bordered)
            .help("Skip to the next phase")
        }
        .labelStyle(.titleAndIcon)
        .controlSize(.large)
    }

    // MARK: Phase picker

    private var phasePicker: some View {
        HStack(spacing: 6) {
            ForEach(SessionPhase.allCases, id: \.self) { phase in
                Button {
                    actions.selectPhase(phase)
                } label: {
                    HStack(spacing: 5) {
                        Circle().fill(phase.color).frame(width: 7, height: 7)
                        Text(phase.shortName)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(engine.phase == phase ? phase.color.opacity(0.16) : Color.clear)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(engine.phase == phase ? phase.color : Color.secondary)
            }
        }
    }

    // MARK: Settings

    private var settingsSection: some View {
        DisclosureGroup(isExpanded: $showSettings) {
            VStack(alignment: .leading, spacing: 10) {
                durationStepper("Focus", value: $engine.settings.focusMinutes, range: 1...180)
                durationStepper("Short break", value: $engine.settings.shortBreakMinutes, range: 1...60)
                durationStepper("Long break", value: $engine.settings.longBreakMinutes, range: 1...120)
                durationStepper("Long break every", value: $engine.settings.sessionsUntilLongBreak,
                                range: 1...12, unit: "sessions")

                Divider()

                Toggle("Auto-start next session", isOn: $engine.settings.autoStartNextSession)
                Toggle("Notifications", isOn: $engine.settings.notificationsEnabled)
                Toggle("Sound", isOn: $engine.settings.playSound)
                Toggle("Show time in menu bar", isOn: $engine.settings.showTimeInMenuBar)

                Divider()

                Toggle("Show overlay", isOn: Binding(
                    get: { ui.overlayVisibility.isShown },
                    set: { actions.setOverlayShown($0) }
                ))
                Toggle("Keep overlay visible when idle", isOn: Binding(
                    get: { ui.overlayVisibility == .alwaysVisible },
                    set: { actions.setOverlayKeepVisible($0) }
                ))
                .disabled(!ui.overlayVisibility.isShown)
                .help("Without this the overlay hides when the timer is idle at full duration.")

                Divider()

                Picker("Tortoise", selection: $engine.settings.tortoiseStyle) {
                    ForEach(TortoiseStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Button("Reset cycle counter", action: actions.resetAll)
                    .buttonStyle(.link)
                    .font(.system(size: 11))
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .font(.system(size: 12))
            .padding(.top, 8)
        } label: {
            Label("Settings", systemImage: "gearshape")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func durationStepper(
        _ title: String, value: Binding<Double>, range: ClosedRange<Double>, unit: String = "min"
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(Int(value.wrappedValue)) \(unit)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: range, step: 1)
                .labelsHidden()
        }
    }

    private func durationStepper(
        _ title: String, value: Binding<Int>, range: ClosedRange<Int>, unit: String
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(value.wrappedValue) \(unit)")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            Stepper("", value: value, in: range)
                .labelsHidden()
        }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !ui.hotKeyWarnings.isEmpty {
                Label("Hotkey unavailable: " + ui.hotKeyWarnings.joined(separator: ", "),
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
            }
            if !ui.notificationsAvailable {
                Label("Notifications need a signed build; using the flash and sound instead.",
                      systemImage: "bell.slash")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "keyboard")
                Text(HotKeyManager.toggleShortcut.displayString)
                Text("start / pause")
                Text("·").foregroundStyle(.tertiary)
                Text(HotKeyManager.resetShortcut.displayString)
                Text("reset")
                Spacer(minLength: 0)
                Button("Quit", action: actions.quit)
                    .buttonStyle(.link)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)

            Text("Click the tortoise to start or pause. Drag to move it, right-click for options.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}
