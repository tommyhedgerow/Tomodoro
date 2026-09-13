import Foundation
import Combine

/// User-tunable configuration. Persisted to UserDefaults.
struct PomodoroSettings: Codable, Equatable {
    var focusMinutes: Double = 25
    var shortBreakMinutes: Double = 5
    var longBreakMinutes: Double = 15
    var sessionsUntilLongBreak: Int = 4

    /// When true, the next phase starts by itself once one finishes.
    var autoStartNextSession: Bool = true
    var notificationsEnabled: Bool = true
    var playSound: Bool = true
    var showTimeInMenuBar: Bool = true
    var tortoiseStyle: TortoiseStyle = .natural

    static let standard = PomodoroSettings()

    init() {}

    /// Decoded field by field rather than with the synthesised initialiser, so a
    /// settings blob written by an older build still loads once fields are added
    /// or removed. A missing key falls back to its default.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PomodoroSettings()
        focusMinutes = try container.decodeIfPresent(Double.self, forKey: .focusMinutes)
            ?? defaults.focusMinutes
        shortBreakMinutes = try container.decodeIfPresent(Double.self, forKey: .shortBreakMinutes)
            ?? defaults.shortBreakMinutes
        longBreakMinutes = try container.decodeIfPresent(Double.self, forKey: .longBreakMinutes)
            ?? defaults.longBreakMinutes
        sessionsUntilLongBreak = try container.decodeIfPresent(Int.self, forKey: .sessionsUntilLongBreak)
            ?? defaults.sessionsUntilLongBreak
        autoStartNextSession = try container.decodeIfPresent(Bool.self, forKey: .autoStartNextSession)
            ?? defaults.autoStartNextSession
        notificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .notificationsEnabled)
            ?? defaults.notificationsEnabled
        playSound = try container.decodeIfPresent(Bool.self, forKey: .playSound)
            ?? defaults.playSound
        showTimeInMenuBar = try container.decodeIfPresent(Bool.self, forKey: .showTimeInMenuBar)
            ?? defaults.showTimeInMenuBar
        tortoiseStyle = try container.decodeIfPresent(TortoiseStyle.self, forKey: .tortoiseStyle)
            ?? defaults.tortoiseStyle
    }
}

/// Emitted whenever a phase runs to completion.
struct CompletedSession: Equatable {
    let phase: SessionPhase
    let finishedAt: Date
    let nextPhase: SessionPhase
    let autoStarted: Bool
}

/// Date-driven Pomodoro state machine.
///
/// The timer never counts down by decrementing a counter. While running, the
/// single source of truth is endDate - an absolute wall-clock instant. The
/// displayed remaining time is always recomputed as (endDate - now), so a
/// machine that sleeps, hibernates, or has its clock adjusted still reports the
/// truth the moment it wakes, and any phases that elapsed during sleep are
/// reconciled by syncToNow/refresh.
final class PomodoroEngine: ObservableObject {

    // MARK: Published state

    @Published private(set) var phase: SessionPhase = .focus
    @Published private(set) var isRunning = false
    @Published private(set) var remaining: TimeInterval = 25 * 60

    /// Focus sessions completed in the current cycle (resets after a long break).
    @Published private(set) var completedFocusSessions = 0

    /// Total focus sessions completed since the counter was last cleared.
    @Published private(set) var totalFocusSessions = 0

    @Published var settings: PomodoroSettings {
        didSet {
            guard settings != oldValue else { return }
            settingsDidChange(from: oldValue)
            persist()
        }
    }

    /// Called once per refresh with every phase that finished, including phases
    /// that elapsed while the machine was asleep. Batching lets the app collapse a
    /// long sleep into a single notification instead of a burst.
    var onSessionsCompleted: (([CompletedSession]) -> Void)?

    /// Injected for deterministic tests. Restoring persisted state depends on it,
    /// so it is supplied at init rather than patched in afterwards.
    var now: () -> Date

    private let defaults: UserDefaults
    private var endDate: Date?
    private var pausedRemaining: TimeInterval
    private var ticker: Timer?

    /// Guards against an unbounded catch-up loop if the clock jumps wildly.
    private let maxCatchUpIterations = 512

    // MARK: Init

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        let loaded = Self.loadSettings(from: defaults)
        self.settings = loaded
        self.pausedRemaining = loaded.focusMinutes * 60
        restoreState()
        self.remaining = currentRemaining()
    }

    // MARK: Derived

    func duration(for phase: SessionPhase) -> TimeInterval {
        switch phase {
        case .focus:      return settings.focusMinutes * 60
        case .shortBreak: return settings.shortBreakMinutes * 60
        case .longBreak:  return settings.longBreakMinutes * 60
        }
    }

    /// Total length of the phase currently on screen.
    var currentPhaseDuration: TimeInterval { duration(for: phase) }

    /// 0...1, how far through the current phase we are.
    var progress: Double {
        let total = currentPhaseDuration
        guard total > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / total))
    }

    /// Wall-clock instant the current phase will end, when running.
    var phaseEndDate: Date? {
        isRunning ? endDate : nil
    }

    /// True once a session has been started and not reset, whether it is counting
    /// down or paused part-way through. Drives the overlay's automatic visibility.
    var isSessionInProgress: Bool {
        isRunning || remaining < currentPhaseDuration
    }

    /// Focus sessions remaining before the next long break.
    var sessionsUntilLongBreak: Int {
        let cycle = max(1, settings.sessionsUntilLongBreak)
        let done = completedFocusSessions % cycle
        return done == 0 ? cycle : cycle - done
    }

    // MARK: Controls

    func toggle() { isRunning ? pause() : start() }

    func start() {
        guard !isRunning else { return }
        let left = max(0, pausedRemaining)
        // Starting a phase that has already fully elapsed just restarts it.
        let effective = left <= 0 ? currentPhaseDuration : left
        endDate = now().addingTimeInterval(effective)
        isRunning = true
        startTicking()
        refresh(notify: false)
        persist()
    }

    func pause() {
        guard isRunning else { return }
        pausedRemaining = currentRemaining()
        endDate = nil
        isRunning = false
        stopTicking()
        remaining = max(0, pausedRemaining)
        persist()
    }

    /// Restarts the current phase from full duration and pauses.
    func reset() {
        stopTicking()
        isRunning = false
        endDate = nil
        pausedRemaining = currentPhaseDuration
        remaining = pausedRemaining
        persist()
    }

    /// Clears the whole cycle: back to a fresh Focus session, counters zeroed.
    func resetAll() {
        stopTicking()
        isRunning = false
        endDate = nil
        phase = .focus
        completedFocusSessions = 0
        totalFocusSessions = 0
        pausedRemaining = currentPhaseDuration
        remaining = pausedRemaining
        persist()
    }

    /// Jumps to the next phase without counting the current one as completed.
    func skip() {
        advance(from: phase, countingCompletion: false)
        stopTicking()
        isRunning = false
        endDate = nil
        pausedRemaining = currentPhaseDuration
        remaining = pausedRemaining
        persist()
    }

    /// Selects a phase directly, pausing the timer.
    func select(phase newPhase: SessionPhase) {
        stopTicking()
        isRunning = false
        endDate = nil
        phase = newPhase
        pausedRemaining = currentPhaseDuration
        remaining = pausedRemaining
        persist()
    }

    // MARK: Timekeeping

    private func currentRemaining() -> TimeInterval {
        if isRunning, let end = endDate {
            return max(0, end.timeIntervalSince(now()))
        }
        return max(0, pausedRemaining)
    }

    private func startTicking() {
        stopTicking()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.refresh(notify: true)
        }
        // .common keeps the countdown live while menus or the popover are tracking.
        RunLoop.main.add(timer, forMode: .common)
        timer.tolerance = 0.05
        ticker = timer
    }

    private func stopTicking() {
        ticker?.invalidate()
        ticker = nil
    }

    /// Recomputes remaining from the wall clock and reconciles elapsed phases.
    /// Safe to call at any time; this is what runs after a wake from sleep.
    func refresh(notify: Bool = true) {
        guard isRunning else {
            if remaining != pausedRemaining { remaining = pausedRemaining }
            return
        }
        guard let end = endDate else { return }

        let nowValue = now()
        if nowValue < end {
            remaining = end.timeIntervalSince(nowValue)
            return
        }

        // One or more phases elapsed. Walk them forward from the scheduled end
        // instant (not from now) so no drift accumulates across a long sleep.
        var completions: [CompletedSession] = []
        var cursor = end
        var iterations = 0

        while nowValue >= cursor, iterations < maxCatchUpIterations {
            iterations += 1
            let finishedPhase = phase
            let finishedAt = cursor
            advance(from: finishedPhase, countingCompletion: true)

            let nextPhase = phase
            if settings.autoStartNextSession {
                cursor = cursor.addingTimeInterval(duration(for: nextPhase))
                endDate = cursor
                completions.append(CompletedSession(
                    phase: finishedPhase, finishedAt: finishedAt,
                    nextPhase: nextPhase, autoStarted: true))
            } else {
                completions.append(CompletedSession(
                    phase: finishedPhase, finishedAt: finishedAt,
                    nextPhase: nextPhase, autoStarted: false))
                stopTicking()
                isRunning = false
                endDate = nil
                pausedRemaining = duration(for: nextPhase)
                remaining = pausedRemaining
                if notify, !completions.isEmpty { onSessionsCompleted?(completions) }
                persist()
                return
            }
        }

        if iterations >= maxCatchUpIterations {
            // Clock jumped absurdly far; settle on a clean slate rather than loop.
            stopTicking()
            isRunning = false
            endDate = nil
            phase = .focus
            completedFocusSessions = 0
            pausedRemaining = currentPhaseDuration
            remaining = pausedRemaining
            persist()
            return
        }

        remaining = max(0, cursor.timeIntervalSince(nowValue))
        if notify, !completions.isEmpty { onSessionsCompleted?(completions) }
        persist()
    }

    /// Called by the app when the machine wakes from sleep.
    func handleWake() {
        refresh(notify: true)
        // Timers do not fire during sleep and are unreliable afterwards; re-arm.
        if isRunning { startTicking() }
    }

    /// Moves the phase to whatever follows, updating the cycle counter.
    private func advance(from finished: SessionPhase, countingCompletion: Bool) {
        switch finished {
        case .focus:
            if countingCompletion {
                completedFocusSessions += 1
                totalFocusSessions += 1
            }
            let cycle = max(1, settings.sessionsUntilLongBreak)
            // Honours the cadence: a long break lands after every Nth focus session.
            if completedFocusSessions > 0, completedFocusSessions % cycle == 0 {
                phase = .longBreak
            } else {
                phase = .shortBreak
            }
        case .shortBreak:
            phase = .focus
        case .longBreak:
            phase = .focus
            if countingCompletion { completedFocusSessions = 0 }
        }
    }

    private func settingsDidChange(from old: PomodoroSettings) {
        // Only re-time the visible phase when it is not actively counting down.
        guard !isRunning else { return }
        pausedRemaining = currentPhaseDuration
        remaining = pausedRemaining
    }

    // MARK: Persistence

    private struct PersistedState: Codable {
        var phase: SessionPhase
        var isRunning: Bool
        var endDate: Date?
        var pausedRemaining: TimeInterval
        var completedFocusSessions: Int
        var totalFocusSessions: Int
    }

    private static let settingsKey = "tomodoro.settings.v1"
    private static let stateKey = "tomodoro.state.v1"

    private static func loadSettings(from defaults: UserDefaults) -> PomodoroSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(PomodoroSettings.self, from: data)
        else { return .standard }
        return decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: Self.settingsKey)
        }
        let state = PersistedState(
            phase: phase, isRunning: isRunning, endDate: endDate,
            pausedRemaining: pausedRemaining,
            completedFocusSessions: completedFocusSessions,
            totalFocusSessions: totalFocusSessions
        )
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.stateKey)
        }
    }

    /// Restores an in-flight session so quitting and relaunching the app keeps the
    /// schedule intact. Elapsed-while-closed phases are reconciled silently.
    private func restoreState() {
        guard let data = defaults.data(forKey: Self.stateKey),
              let state = try? JSONDecoder().decode(PersistedState.self, from: data)
        else { return }

        phase = state.phase
        completedFocusSessions = state.completedFocusSessions
        totalFocusSessions = state.totalFocusSessions
        pausedRemaining = state.pausedRemaining
        endDate = state.endDate
        isRunning = state.isRunning && state.endDate != nil

        if isRunning {
            // Do not notify about phases that elapsed while the app was closed.
            refresh(notify: false)
            if isRunning { startTicking() }
        }
    }
}
