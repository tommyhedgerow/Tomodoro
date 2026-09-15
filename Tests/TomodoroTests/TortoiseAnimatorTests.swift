import XCTest

/// The animation state machine.
///
/// These tests exist because the animation is sporadic: it fires on minute
/// boundaries and on gaps that look irregular. That is exactly the kind of
/// behaviour that is easy to get subtly wrong and impossible to check by eye, so
/// the clock is injected and the whole timeline is simulated instead.
final class TortoiseAnimatorTests: XCTestCase {

    private let step = 1.0 / 30.0

    /// An animator trotting from `remaining`, already primed so the minute it is
    /// in counts as the current one rather than as a boundary just crossed. Tests
    /// then run the clock forward from the same value; jumping it instead would
    /// fire a nibble before the window they are measuring.
    private func makeAnimator(visible: Bool = true, remaining: TimeInterval = 24 * 60) -> TortoiseAnimator {
        let animator = TortoiseAnimator()
        animator.isVisible = visible
        animator.update(isRunning: true, isPaused: false, remaining: remaining)
        animator.prime(remaining: remaining)
        return animator
    }

    /// Runs the clock forward, feeding the animator the same way the app does.
    private func run(
        _ animator: TortoiseAnimator, seconds: Double,
        from start: TimeInterval, isRunning: Bool = true, isPaused: Bool = false,
        record: ((TortoiseFrame) -> Void)? = nil
    ) -> TimeInterval {
        var remaining = start
        var elapsed = 0.0
        while elapsed < seconds {
            remaining = max(0, start - elapsed)
            animator.update(isRunning: isRunning, isPaused: isPaused, remaining: remaining)
            let before = animator.frame
            animator.advance(by: step)
            if animator.frame != before { record?(animator.frame) }
            elapsed += step
        }
        return remaining
    }

    // MARK: Sleeping

    func testPausingWithdrawsHimIntoHisShell() {
        let animator = makeAnimator()
        XCTAssertEqual(animator.motion, .trotting)

        run(animator, seconds: 4, from: 20 * 60, isRunning: false, isPaused: true)

        XCTAssertEqual(animator.motion, .sleeping)
        XCTAssertEqual(animator.frame.pose, .sleeping)
    }

    /// He breathes while he sleeps, and the breath shows as the z's drifting up
    /// at the pace of the cycle: the art itself is completely still, because he
    /// is withdrawn into the shell and the shell carries the countdown.
    func testSleepingStaysWithdrawnAndFloatsAZ() {
        let animator = makeAnimator()
        var clock: TimeInterval = 24 * 60
        clock = run(animator, seconds: 1, from: clock, isRunning: false, isPaused: true)

        var poses = Set<TortoisePose>()
        var drifts: [Double] = []
        run(animator, seconds: 12, from: clock, isRunning: false, isPaused: true) { frame in
            poses.insert(frame.pose)
            if let drift = frame.sleepZ { drifts.append(drift) }
        }

        XCTAssertEqual(poses, [.sleeping], "the whole loop is the withdrawn pose")
        XCTAssertTrue(poses.allSatisfy { $0.isWithdrawn })
        XCTAssertFalse(drifts.isEmpty, "a z should drift up while he sleeps")
        XCTAssertTrue(drifts.allSatisfy { $0 >= 0 && $0 < 1 }, "drift is a 0...1 progress: \(drifts)")
        XCTAssertGreaterThanOrEqual(Set(drifts).count, 2, "the z should move between frames")
    }

    /// A paused timer at full duration is idle, not asleep. Pausing part-way
    /// through a session is what puts him to sleep.
    func testAnIdleTimerAtFullDurationIsNotAsleep() {
        let animator = TortoiseAnimator()
        animator.isVisible = true
        animator.update(isRunning: false, isPaused: false, remaining: 25 * 60)
        run(animator, seconds: 2, from: 25 * 60, isRunning: false, isPaused: false)
        XCTAssertEqual(animator.motion, .sittingIdle)
        XCTAssertEqual(animator.frame.pose, .resting)
    }

    func testResumingWakesHimUp() {
        let animator = makeAnimator()
        // Starting one minute in, and the same start for both halves, so neither
        // run crosses a minute boundary and triggers a nibble.
        var clock: TimeInterval = 24 * 60
        clock = run(animator, seconds: 2, from: clock, isRunning: false, isPaused: true)
        XCTAssertEqual(animator.frame.pose, .sleeping)

        // The countdown carries on from where it was; it does not rewind.
        run(animator, seconds: 2, from: clock, isRunning: true, isPaused: false)
        XCTAssertEqual(animator.motion, .trotting)
        XCTAssertEqual(animator.frame.pose, .resting)
    }

    // MARK: Blinking

    func testHeBlinksWhileTrotting() {
        let animator = makeAnimator()
        // No priming needed: makeAnimator already sits at 24:00.
        var blinks = 0
        let start: TimeInterval = 24 * 60
        run(animator, seconds: 3 * 60, from: start) { frame in
            if frame.pose == .blinking { blinks += 1 }
        }
        // Roughly one every 6-13s: over three minutes that is a handful, not a
        // flicker and not nothing.
        XCTAssertGreaterThanOrEqual(blinks, 8, "he should blink over three minutes")
        XCTAssertLessThanOrEqual(blinks, 40, "blinking this often would be a tic")
    }

    /// Idle sitting is livelier than trotting, so the overlay does not look frozen
    /// when no session is running.
    func testHeBlinksMoreOftenWhenIdleThanWhenTrotting() {
        /// Counts blinks over two minutes from a given starting state. Both runs
        /// start a minute in so neither is interrupted by its own minute nibble.
        func blinks(isRunning: Bool) -> Int {
            let animator = TortoiseAnimator()
            animator.isVisible = true
            animator.update(isRunning: isRunning, isPaused: false, remaining: 25 * 60)
            animator.prime(remaining: 24 * 60)
            var count = 0
            run(animator, seconds: 120, from: 24 * 60, isRunning: isRunning,
                isPaused: false) { frame in
                if frame.pose == .blinking { count += 1 }
            }
            // A blink may still be in flight when the window ends, which is fine;
            // what matters is that he is on the awake loop and not asleep.
            XCTAssertNotEqual(animator.motion, .sleeping, "the tortoise should not be asleep")
            return count
        }

        let idle = blinks(isRunning: false)
        let trotting = blinks(isRunning: true)

        XCTAssertGreaterThan(idle, 0, "the idle tortoise should blink")
        XCTAssertGreaterThan(idle, trotting, "the idle tortoise should blink more often")
    }

    // MARK: Eating

    func testHeNibblesALeafAtEveryMinuteBoundary() {
        let animator = makeAnimator(remaining: 5 * 60 + 15)
        // Start part-way into a minute, and prime on the near side of that minute
        // so the first crossing counted is a real one the countdown makes.
        let start: TimeInterval = 5 * 60 + 15
        let duration: TimeInterval = 3 * 60 + 10
        // Primed one minute further on, so the animator starts already inside the
        // minute it is about to count down. Priming on the wrong side of the
        // boundary would fire a nibble before the window begins.
        animator.prime(remaining: 5 * 60 + 60)

        var leaves = 0
        var lastLeaf: TortoiseLeaf = .none
        run(animator, seconds: duration, from: start) { frame in
            // A nibble begins when a leaf appears out of nothing, not on every
            // frame of the clip.
            if frame.leaf != .none, lastLeaf == .none { leaves += 1 }
            lastLeaf = frame.leaf
        }

        // Every whole minute the countdown passed, and nothing else.
        let boundaries = Int(start / 60) - Int((start - duration) / 60) + 1
        XCTAssertEqual(boundaries, 4)
        XCTAssertEqual(leaves, boundaries, "one leaf per minute boundary crossed")
        XCTAssertEqual(animator.motion, .trotting, "and he is back to trotting after them")
    }

    func testTheNibbleEndsAndLeavesNothingBehind() {
        let animator = makeAnimator()
        // Cross one minute boundary, then let the clip run out on the same clock.
        var clock: TimeInterval = 24 * 60
        clock = run(animator, seconds: 61, from: clock)
        let clipLength = TortoiseAnimator.totalDuration(of: TortoiseAnimator.eatFootage())
        run(animator, seconds: clipLength + 0.5, from: clock)
        XCTAssertEqual(animator.frame, .rest)
        XCTAssertEqual(animator.motion, .trotting)
    }

    func testNoLeafIsEatenWhilePaused() {
        let animator = makeAnimator()
        var sawLeaf = false
        run(animator, seconds: 3 * 60, from: 24 * 60, isRunning: false, isPaused: true) { frame in
            if frame.leaf != .none { sawLeaf = true }
        }
        XCTAssertFalse(sawLeaf, "a paused tortoise does not eat")
    }

    // MARK: The dandelion

    func testASessionEndSummonsTheDandelion() {
        let animator = makeAnimator()
        animator.requestMunch()
        XCTAssertEqual(animator.motion, .munching)

        var sawFlower = false
        var sawRosette = false
        run(animator, seconds: TortoiseAnimator.totalDuration(of: TortoiseAnimator.munchFootage()),
            from: 24 * 60) { frame in
            switch frame.plant {
            case .dandelion: sawFlower = true
            case .rosette:   sawRosette = true
            case .none:      break
            }
        }
        XCTAssertTrue(sawFlower, "the whole dandelion should appear first")
        XCTAssertTrue(sawRosette, "the flower head should be eaten before the leaves")
    }

    func testTheDandelionIsFinishedAndHeGoesBackToTrotting() {
        let animator = makeAnimator()
        animator.requestMunch()
        let total = TortoiseAnimator.totalDuration(of: TortoiseAnimator.munchFootage())
        run(animator, seconds: total + 1, from: 24 * 60)
        XCTAssertEqual(animator.frame, .rest)
        XCTAssertEqual(animator.frame.plant, .none)
        XCTAssertEqual(animator.motion, .trotting)
    }

    /// A session ending mid-blink must not lose the treat.
    func testAMunchRequestedDuringAClipIsNotDropped() {
        let animator = makeAnimator()
        animator.requestMunch()
        animator.requestMunch()   // arrives while the first is still playing

        let total = TortoiseAnimator.totalDuration(of: TortoiseAnimator.munchFootage())
        var munches = 0
        var wasMunching = false
        run(animator, seconds: total * 2 + 1, from: 24 * 60) { frame in
            let munching = frame.plant != .none
            if munching, !wasMunching { munches += 1 }
            wasMunching = munching
        }
        XCTAssertEqual(munches, 2, "both dandelions should be eaten")
        XCTAssertEqual(animator.motion, .trotting)
    }

    func testPausingDuringAMunchStillPutsHimToSleepAfterwards() {
        let animator = makeAnimator()
        animator.requestMunch()
        let total = TortoiseAnimator.totalDuration(of: TortoiseAnimator.munchFootage())
        // The dandelion plays out with the timer paused, as it does when a focus
        // session ends and the user walks away.
        run(animator, seconds: total + 0.5, from: 24 * 60, isRunning: false, isPaused: true)
        XCTAssertEqual(animator.motion, .sleeping)
        XCTAssertEqual(animator.frame.pose, .sleeping)
    }

    // MARK: Behaviour that keeps the overlay cheap

    func testNothingHappensWhileTheOverlayIsHidden() {
        let animator = makeAnimator(visible: false)
        XCTAssertFalse(animator.advance(by: 30))
        XCTAssertEqual(animator.frame, .rest)
        animator.isVisible = true
        XCTAssertTrue(animator.advance(by: 30) || animator.frame != .rest || animator.motion == .blinking,
                      "once visible again he should carry on")
    }

    func testAStillTortoiseDoesNotProduceFrames() {
        let animator = makeAnimator()
        // The same minute throughout: a boundary crossing would rightly make him
        // eat, so this test holds the clock still.
        var changes = 0
        for _ in 0..<30 {
            animator.update(isRunning: true, isPaused: false, remaining: 25 * 60)
            if animator.advance(by: step) { changes += 1 }
        }
        XCTAssertEqual(changes, 0, "a resting tortoise should not redraw")
    }

    // MARK: Frame sanity

    /// Every frame the animator can produce must be structurally valid art, and
    /// must keep the countdown plate clear.
    func testEveryFrameInEveryScriptIsValid() {
        var frames: [TortoiseFrame] = []
        for pose in TortoisePose.allCases { frames.append(TortoiseFrame(pose: pose)) }
        for footage in TortoiseAnimator.eatFootage() + TortoiseAnimator.munchFootage() {
            frames.append(footage.frame)
        }
        for plant in [TortoisePlant.none, .dandelion, .rosette] {
            for alpha in [1.0, 0.6, 0.25] {
                frames.append(TortoiseFrame(pose: .resting, plant: plant, plantAlpha: alpha))
            }
        }
        for leaf in [TortoiseLeaf.none, .sprig, .stripped] {
            frames.append(TortoiseFrame(pose: .resting, leaf: leaf))
        }
        for drift in [0.0, 0.1, 0.45, 0.55, 0.9, 1.0] {
            frames.append(TortoiseFrame(pose: .sleeping, sleepZ: drift))
        }

        for frame in frames {
            let problems = frame.pose.problems(textArea: TortoiseSprite.textArea)
            XCTAssertTrue(problems.isEmpty, "invalid pose \(frame.pose.rawValue): \(problems)")

            // The scene must stay inside its own bounds, or the window would have
            // to resize as he animates.
            let scene = TortoiseScene(frame: frame)
            for prop in scene.props {
                XCTAssertTrue((0..<TortoiseScene.width).contains(prop.x),
                              "prop at x=\(prop.x) is outside the scene")
                XCTAssertTrue((0..<TortoiseScene.height).contains(prop.y),
                              "prop at y=\(prop.y) is outside the scene")
                XCTAssertTrue(prop.alpha > 0 && prop.alpha <= 1,
                              "prop alpha \(prop.alpha) out of range")
            }
        }
    }

    /// The props must never cover the countdown, whatever is on screen.
    func testPropsNeverCoverTheCountdown() {
        let plate = TortoiseSprite.textArea
        let plateCells = Set((plate.y..<(plate.y + plate.height)).flatMap { y in
            (plate.x..<(plate.x + plate.width)).map { x in
                [x + TortoiseScene.spriteX, y + TortoiseScene.spriteY]
            }
        })
        var frames: [TortoiseFrame] = [TortoiseFrame(pose: .resting, plant: .dandelion),
                                       TortoiseFrame(pose: .resting, leaf: .sprig),
                                       TortoiseFrame(pose: .sleeping, sleepZ: 0.1),
                                       TortoiseFrame(pose: .sleeping, sleepZ: 0.9)]
        for pose in TortoisePose.allCases { frames.append(TortoiseFrame(pose: pose)) }

        for frame in frames {
            for prop in TortoiseScene(frame: frame).props {
                XCTAssertFalse(plateCells.contains([prop.x, prop.y]),
                               "\(prop.cell) at (\(prop.x),\(prop.y)) covers the countdown")
            }
        }
    }

    func testBlinkDelayStaysInsideItsRange() {
        for range in [TortoiseAnimator.blinkRangeTrotting, TortoiseAnimator.blinkRangeSitting] {
            for tick in stride(from: 0.0, through: 3600, by: 0.37) {
                let delay = TortoiseAnimator.blinkDelay(at: tick, range: range)
                XCTAssertGreaterThanOrEqual(delay, range.lowerBound)
                XCTAssertLessThanOrEqual(delay, range.upperBound)
            }
        }
    }
}
