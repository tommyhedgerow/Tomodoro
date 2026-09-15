import XCTest

/// Deterministic clock so sleep/wake behaviour can be tested without sleeping.
private final class FakeClock {
    var current: Date
    init(_ start: Date = Date(timeIntervalSince1970: 1_700_000_000)) { current = start }
    func advance(_ seconds: TimeInterval) { current = current.addingTimeInterval(seconds) }
    func advance(minutes: Double) { advance(minutes * 60) }

    func makeEngine(_ suite: String) -> PomodoroEngine {
        let defaults = UserDefaults(suiteName: "tomodoro.tests.\(suite)")!
        defaults.removePersistentDomain(forName: "tomodoro.tests.\(suite)")
        return PomodoroEngine(defaults: defaults) { [weak self] in self?.current ?? Date() }
    }
}

final class PomodoroEngineTests: XCTestCase {

    private func makeEngine(_ suite: String,
                            clock: FakeClock = FakeClock()) -> (PomodoroEngine, FakeClock) {
        (clock.makeEngine(suite), clock)
    }

    func testInitialState() {
        let (engine, _) = makeEngine(#function)
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.remaining, 25 * 60)
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.completedFocusSessions, 0)
    }

    func testCountdownIsDerivedFromTheWallClock() {
        let (engine, clock) = makeEngine(#function)
        engine.start()
        XCTAssertTrue(engine.isRunning)

        // Elapsed time comes from the clock, not from tick callbacks.
        clock.advance(minutes: 10)
        engine.refresh()
        XCTAssertEqual(engine.remaining, 15 * 60)

        clock.advance(minutes: 4)
        engine.refresh()
        XCTAssertEqual(engine.remaining, 11 * 60)
        XCTAssertEqual(engine.progress, 14.0 / 25.0, accuracy: 0.0001)
    }

    func testPausedTimerIgnoresElapsedTime() {
        let (engine, clock) = makeEngine(#function)
        engine.start()
        clock.advance(minutes: 10)
        engine.refresh()
        engine.pause()

        clock.advance(minutes: 30)
        engine.refresh()
        XCTAssertEqual(engine.remaining, 15 * 60, "a paused timer must not drain")
    }

    func testSleepReconciliation() {
        let (engine, clock) = makeEngine(#function)
        var completions: [CompletedSession] = []
        engine.onSessionsCompleted = { completions.append(contentsOf: $0) }

        engine.start()                       // focus ends at +25m
        clock.advance(minutes: 30)           // focus ends, 5m break also elapses
        engine.handleWake()

        XCTAssertEqual(completions.count, 2)
        XCTAssertEqual(completions[0].phase, .focus)
        XCTAssertEqual(completions[1].phase, .shortBreak)
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.remaining, 25 * 60, "no drift after a long sleep")
        XCTAssertTrue(engine.isRunning)
    }

    func testMultiSessionCatchUpStaysExact() {
        let (engine, clock) = makeEngine(#function)
        engine.start()
        clock.advance(minutes: 55)           // 25 + 5 + 25
        engine.refresh()

        XCTAssertEqual(engine.completedFocusSessions, 2)
        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.remaining, 5 * 60)
    }

    func testAbsurdlyLongSleepSettlesCleanly() {
        let (engine, clock) = makeEngine(#function)
        engine.start()
        clock.advance(minutes: 60 * 24 * 3)
        engine.handleWake()
        XCTAssertGreaterThan(engine.remaining, 0)
        XCTAssertLessThanOrEqual(engine.remaining, engine.currentPhaseDuration)
    }

    func testLongBreakAfterFourFocusSessions() {
        let (engine, clock) = makeEngine(#function)
        var cadence: [SessionPhase] = []

        for _ in 0..<4 {
            XCTAssertEqual(engine.phase, .focus)
            engine.start()
            clock.advance(minutes: engine.currentPhaseDuration / 60 + 0.01)
            engine.refresh()
            cadence.append(engine.phase)
            if engine.phase != .focus {
                clock.advance(minutes: engine.currentPhaseDuration / 60 + 0.01)
                engine.refresh()
            }
        }

        XCTAssertEqual(cadence[0], .shortBreak)
        XCTAssertEqual(cadence[1], .shortBreak)
        XCTAssertEqual(cadence[2], .shortBreak)
        XCTAssertEqual(cadence[3], .longBreak, "the fourth focus session earns a long break")
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.completedFocusSessions, 0, "the cycle resets after a long break")
        XCTAssertEqual(engine.totalFocusSessions, 4)
    }

    func testAutoStartDisabledStopsAtTheBoundary() {
        let (engine, clock) = makeEngine(#function)
        engine.settings.autoStartNextSession = false
        engine.start()
        clock.advance(minutes: 25.5)
        engine.refresh()

        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.remaining, 5 * 60)
    }

    func testSessionInProgressTracksRunningAndPaused() {
        let (engine, clock) = makeEngine(#function)
        XCTAssertFalse(engine.isSessionInProgress, "a fresh timer is idle")

        engine.start()
        XCTAssertTrue(engine.isSessionInProgress)

        // Paused part-way through still counts, so the overlay does not vanish
        // the moment you pause.
        clock.advance(minutes: 5)
        engine.pause()
        XCTAssertTrue(engine.isSessionInProgress)

        engine.reset()
        XCTAssertFalse(engine.isSessionInProgress, "resetting returns to idle")
    }

    func testResetRestoresThePhaseAndPauses() {
        let (engine, clock) = makeEngine(#function)
        engine.start()
        clock.advance(minutes: 7)
        engine.refresh()
        engine.reset()

        XCTAssertFalse(engine.isRunning)
        XCTAssertEqual(engine.remaining, 25 * 60)
        XCTAssertEqual(engine.phase, .focus)
    }

    func testSkipDoesNotBankAFocusSession() {
        let (engine, _) = makeEngine(#function)
        engine.skip()
        XCTAssertEqual(engine.phase, .shortBreak)
        XCTAssertEqual(engine.completedFocusSessions, 0)
        XCTAssertEqual(engine.totalFocusSessions, 0)
    }

    func testSelectPhaseChangesDuration() {
        let (engine, _) = makeEngine(#function)
        engine.select(phase: .longBreak)
        XCTAssertEqual(engine.remaining, 15 * 60)
    }

    func testResetAllClearsCounters() {
        let (engine, clock) = makeEngine(#function)
        engine.start()
        clock.advance(minutes: 26)
        engine.refresh()
        engine.resetAll()
        XCTAssertEqual(engine.phase, .focus)
        XCTAssertEqual(engine.totalFocusSessions, 0)
        XCTAssertEqual(engine.completedFocusSessions, 0)
    }

    func testToggleFlipsRunningState() {
        let (engine, _) = makeEngine(#function)
        engine.toggle()
        XCTAssertTrue(engine.isRunning)
        engine.toggle()
        XCTAssertFalse(engine.isRunning)
    }

    func testSettingsChangeReTimesAnIdleTimer() {
        let (engine, _) = makeEngine(#function)
        engine.settings.focusMinutes = 50
        XCTAssertEqual(engine.currentPhaseDuration, 50 * 60)
        XCTAssertEqual(engine.remaining, 50 * 60)
    }

    func testSettingsChangeDoesNotDisturbARunningTimer() {
        let (engine, clock) = makeEngine(#function)
        engine.start()
        clock.advance(minutes: 10)
        engine.settings.focusMinutes = 5
        engine.refresh()
        XCTAssertEqual(engine.remaining, 15 * 60, "the schedule was already committed")
    }

    func testStateSurvivesRelaunch() {
        let clock = FakeClock()
        let suite = "tomodoro.tests.persist"
        UserDefaults(suiteName: suite)!.removePersistentDomain(forName: suite)
        let defaults = UserDefaults(suiteName: suite)!

        let first = PomodoroEngine(defaults: defaults) { [weak clock] in clock?.current ?? Date() }
        first.start()
        clock.advance(minutes: 5)
        first.refresh()
        XCTAssertEqual(first.remaining, 20 * 60)

        clock.advance(minutes: 3)
        let second = PomodoroEngine(defaults: defaults) { [weak clock] in clock?.current ?? Date() }
        XCTAssertEqual(second.phase, .focus)
        XCTAssertTrue(second.isRunning, "a running timer resumes")
        XCTAssertEqual(second.remaining, 17 * 60, "elapsed wall-clock time is accounted for")
    }

    func testSettingsDecodingIsForwardCompatible() throws {
        // A blob written before a field existed must still load.
        let legacy = #"{"focusMinutes":30,"playSound":false}"#
        let decoded = try JSONDecoder().decode(PomodoroSettings.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.focusMinutes, 30)
        XCTAssertFalse(decoded.playSound)
        XCTAssertEqual(decoded.shortBreakMinutes, 5, "missing fields fall back to defaults")
        XCTAssertEqual(decoded.tortoiseStyle, .natural)
    }

    func testSessionsUntilLongBreakCountsDown() {
        let (engine, _) = makeEngine(#function)
        XCTAssertEqual(engine.sessionsUntilLongBreak, 4)
        engine.select(phase: .focus)
        XCTAssertEqual(engine.sessionsUntilLongBreak, 4)
    }

    // MARK: Dandelions, the currency

    /// One dandelion per focus session that ran to completion.
    func testDandelionsAreEarnedByFinishingFocusSessions() {
        let (engine, clock) = makeEngine(#function)
        XCTAssertEqual(engine.dandelionsEaten, 0, "a fresh install has eaten nothing")

        engine.start()
        clock.advance(minutes: 25.5)
        engine.refresh()
        XCTAssertEqual(engine.dandelionsEaten, 1)

        // The break he is on now is rest, not work, and earns nothing.
        clock.advance(minutes: 5.5)
        engine.refresh()
        XCTAssertEqual(engine.dandelionsEaten, 1, "a break is not a treat")

        clock.advance(minutes: 25.5)
        engine.refresh()
        XCTAssertEqual(engine.dandelionsEaten, 2, "the second focus session earns the second")
    }

    /// Sessions that elapsed while the machine slept were still finished, so he
    /// is owed their dandelions too.
    func testEverySessionFinishedDuringASleepIsBanked() {
        let (engine, clock) = makeEngine(#function)
        engine.start()                       // 25 focus + 5 break + 25 focus
        clock.advance(minutes: 55.5)
        engine.refresh()

        XCTAssertEqual(engine.completedFocusSessions, 2)
        XCTAssertEqual(engine.dandelionsEaten, 2)
    }

    func testSkippingAFocusSessionEarnsNothing() {
        let (engine, _) = makeEngine(#function)
        engine.skip()
        XCTAssertEqual(engine.dandelionsEaten, 0)
    }

    func testDandelionsSurviveARelaunch() {
        let clock = FakeClock()
        let suite = "tomodoro.tests.dandelions"
        UserDefaults(suiteName: suite)!.removePersistentDomain(forName: suite)
        let defaults = UserDefaults(suiteName: suite)!

        let first = PomodoroEngine(defaults: defaults) { [weak clock] in clock?.current ?? Date() }
        first.start()
        clock.advance(minutes: 25.5)
        first.refresh()
        XCTAssertEqual(first.dandelionsEaten, 1)

        let second = PomodoroEngine(defaults: defaults) { [weak clock] in clock?.current ?? Date() }
        XCTAssertEqual(second.dandelionsEaten, 1, "the currency is kept across launches")
    }

    /// Clearing the cycle is a change of schedule, not a spend.
    func testResetAllKeepsTheDandelions() {
        let (engine, clock) = makeEngine(#function)
        engine.start()
        clock.advance(minutes: 25.5)
        engine.refresh()
        engine.resetAll()

        XCTAssertEqual(engine.totalFocusSessions, 0)
        XCTAssertEqual(engine.dandelionsEaten, 1, "resetting the cycle must not clear the currency")
    }

    /// A state blob written before the currency existed must still load — losing
    /// it would throw away a running session's schedule on upgrade — and the
    /// focus sessions already in it are the dandelions he has already eaten.
    func testALegacyStateBlobSeedsTheDandelionTotal() throws {
        let suite = "tomodoro.tests.legacycurrency"
        UserDefaults(suiteName: suite)!.removePersistentDomain(forName: suite)
        let defaults = UserDefaults(suiteName: suite)!
        let legacy = "{\"phase\":\"focus\",\"isRunning\":false,\"pausedRemaining\":1500,"
            + "\"completedFocusSessions\":2,\"totalFocusSessions\":7}"
        defaults.set(Data(legacy.utf8), forKey: "tomodoro.state.v1")

        let engine = PomodoroEngine(defaults: defaults)
        XCTAssertEqual(engine.totalFocusSessions, 7)
        XCTAssertEqual(engine.dandelionsEaten, 7,
                       "the upgrade starts from what he has already eaten")
    }
}
