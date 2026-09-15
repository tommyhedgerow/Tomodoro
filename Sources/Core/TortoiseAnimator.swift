import Foundation
import Combine

/// Which scripted behaviour the tortoise is running.
enum TortoiseMotion: Equatable {
    /// Withdrawn into the shell, z's drifting up. What pausing looks like.
    case sleeping
    /// Awake: an occasional blink, no other movement.
    case sittingIdle
    /// A focus session is counting down.
    case trotting
    /// One-shot: the dandelion at the end of a focus session.
    case munching
    /// One-shot: the leaf nibbled off at each minute.
    case eating
    /// One-shot: a blink, fired by the idle loop.
    case blinking
}

/// A frame and how long it is held, in seconds.
struct Footage {
    var duration: Double
    var frame: TortoiseFrame
}

/// Drives the tortoise's sporadic animation.
///
/// Deliberately a plain, clock-injected state machine rather than something built
/// on SwiftUI's animation system: the sprite is 16x16 pixel art on a fixed grid,
/// so every transition has to be a whole-cell pose change, and the overlay only
/// has to redraw when `advance(by:)` says a new frame is ready.
///
/// The randomness is not random. Blink timing comes from a sine of the elapsed
/// time, which looks irregular enough to read as alive and lets the tests assert
/// exact behaviour over a simulated hour.
final class TortoiseAnimator: ObservableObject {

    @Published private(set) var motion: TortoiseMotion = .sittingIdle
    @Published private(set) var frame: TortoiseFrame = .rest

    /// Set while an overlay is on screen. With no overlay there is nothing to
    /// animate, so `advance(by:)` becomes a no-op and the app idles.
    var isVisible = false

    private var script: [Footage] = []
    private var index = 0
    private var held = 0.0
    private var elapsed = 0.0
    private var nextBlink = TortoiseAnimator.blinkDelay(at: 0)

    // MARK: Tuning

    /// Slow, deliberate breathing while asleep, with a z on every cycle. He is
    /// withdrawn for all of it — the shell is the entire silhouette — so the
    /// breath is carried by the pace of the z's rather than by the art moving.
    static let sleepCycle = [0.9, 0.7, 1.3, 0.7]
    /// A blink is two frames of the same whole-cell change: lid down, then the
    /// head a row higher, still with the lid down. Held long enough to register
    /// at overlay size without reading as a twitch. There is no frame with the
    /// eye open in between, which at one cell would just flicker.
    static let blinkHold = 0.22
    /// The gap between blinks. Both values are long enough that a blink reads as
    /// a small surprise rather than a tic, and short enough to be seen inside a
    /// single focus session. Idle sitting blinks more often than trotting.
    static let blinkRangeTrotting: ClosedRange<Double> = 6.0...13.0
    static let blinkRangeSitting: ClosedRange<Double> = 4.0...9.0
    /// Slack after a one-shot clip before it hands back to the idle loop, so a
    /// minute boundary landing on a blink does not cut the blink short.
    static let handbackSlack = 0.2

    /// The nibble at each minute boundary, and the dandelion at the end of a
    /// focus session. Written out as the exact frame list so the timing is
    /// readable and testable.
    static func eatFootage() -> [Footage] {
        [
            Footage(duration: 0.30, frame: TortoiseFrame(pose: .headUp, leaf: .sprig)),
            Footage(duration: 0.16, frame: TortoiseFrame(pose: .headChew, leaf: .sprig)),
            Footage(duration: 0.22, frame: TortoiseFrame(pose: .resting, leaf: .sprig)),
            Footage(duration: 0.20, frame: TortoiseFrame(pose: .headDown)),
            Footage(duration: 0.30, frame: TortoiseFrame(pose: .blinking, crumbs: 0.9)),
            Footage(duration: 0.18, frame: TortoiseFrame(pose: .headChew)),
            Footage(duration: 0.26, frame: TortoiseFrame(pose: .resting, crumbs: 0.45)),
            Footage(duration: 0.22, frame: TortoiseFrame(pose: .headDown)),
        ]
    }

    static func munchFootage() -> [Footage] {
        [
            Footage(duration: 0.45, frame: TortoiseFrame(pose: .resting, plant: .dandelion)),
            Footage(duration: 0.35, frame: TortoiseFrame(pose: .headUp, plant: .dandelion)),
            Footage(duration: 0.30, frame: TortoiseFrame(pose: .headChew, plant: .dandelion)),
            Footage(duration: 0.45, frame: TortoiseFrame(pose: .resting, plant: .dandelion)),
            Footage(duration: 0.22, frame: TortoiseFrame(pose: .resting, plant: .dandelion)),
            Footage(duration: 0.35, frame: TortoiseFrame(pose: .headChew, plant: .dandelion, crumbs: 0.9)),
            Footage(duration: 0.45, frame: TortoiseFrame(pose: .resting, plant: .dandelion, crumbs: 0.9)),
            Footage(duration: 0.40, frame: TortoiseFrame(pose: .headUp, plant: .rosette)),
            Footage(duration: 0.40, frame: TortoiseFrame(pose: .headChew, plant: .rosette, crumbs: 0.6)),
            Footage(duration: 0.30, frame: TortoiseFrame(pose: .resting, plant: .rosette)),
            Footage(duration: 0.35, frame: TortoiseFrame(pose: .headDown, plant: .rosette, plantAlpha: 0.6)),
            Footage(duration: 0.40, frame: TortoiseFrame(pose: .headDown, plant: .rosette, plantAlpha: 0.25)),
            Footage(duration: 0.50, frame: TortoiseFrame(pose: .resting)),
        ]
    }

    // MARK: Scripts

    private static func sleepScript() -> [Footage] {
        [
            Footage(duration: sleepCycle[0], frame: TortoiseFrame(pose: .sleeping)),
            Footage(duration: sleepCycle[1], frame: TortoiseFrame(pose: .sleeping, sleepZ: 0.15)),
            Footage(duration: sleepCycle[2], frame: TortoiseFrame(pose: .sleeping, sleepZ: 0.55)),
            Footage(duration: sleepCycle[3], frame: TortoiseFrame(pose: .sleeping, sleepZ: 0.9)),
        ]
    }

    /// Awake and still. An empty script: the idle loop starts a blink when its
    /// timer comes round, and there is nothing else to do between blinks.
    private static func sitScript() -> [Footage] { [] }

    private static func blinkScript() -> [Footage] {
        [
            Footage(duration: blinkHold, frame: TortoiseFrame(pose: .blinking)),
            Footage(duration: blinkHold, frame: TortoiseFrame(pose: .blinkingUp)),
        ]
    }

    /// Total length of a clip, for tests and for reasoning about overlaps.
    static func totalDuration(of footage: [Footage]) -> Double {
        footage.reduce(0) { $0 + $1.duration }
    }

    // MARK: Inputs

    /// Called from the engine's tick.
    ///
    /// `remaining` is watched across whole minutes so a nibble lands on each
    /// minute boundary. A boundary reached while he is already chewing is
    /// dropped: the nibble is short, and queueing them would stack up.
    func update(isRunning: Bool, isPaused: Bool, remaining: TimeInterval) {
        let desired: TortoiseMotion = isRunning ? .trotting : (isPaused ? .sleeping : .sittingIdle)

        if isOneShot(motion) {
            // A one-shot clip is in flight: remember where he should go back to
            // and let it finish. Cutting a chew off mid-bite looks broken.
            if desired != motion { pendingMotion = desired }
        } else {
            // Only on a real change. Re-entering the same motion would restart its
            // script, and this runs on every engine tick.
            if desired != restingMotion {
                restingMotion = desired
                pendingMotion = nil
                setMotion(desired)
            }
        }

        // Rounded, not truncated: the 24:00 remaining boundary sits at exactly
        // 1440.0, and truncating means the crossing is only seen once it has
        // already dropped below it.
        let minute = Int((remaining / 60).rounded())
        // A clock that jumps backwards is a reset or a restored session, not time
        // passing. Only a forward crossing counts as a minute.
        let crossedMinute = lastMinute.map { minute < $0 } ?? false
        if isRunning, crossedMinute, remaining > 2 {
            // Queued rather than dropped. A minute boundary that lands while he
            // is mid-blink would otherwise be swallowed, and the nibble is the
            // beat the user is watching for.
            request(.eating)
        }
        lastMinute = minute
    }

    /// Sets the next blink a full gap away from now.
    ///
    /// Called when an awake loop is entered, including the handback at the end of
    /// a blink or a nibble. It must not be called on every tick: that would push
    /// the next blink out by a gap each time and he would never blink again.
    private func rearmBlink() {
        nextBlink = elapsed + TortoiseAnimator.blinkDelay(
            at: elapsed, range: TortoiseAnimator.blinkRange(for: motion))
    }

    /// Establishes the current minute without counting it as a boundary crossing.
    ///
    /// Call this when the animator starts watching a clock that is already
    /// running, so the minute he is in the middle of does not fire a nibble.
    func prime(remaining: TimeInterval) {
        lastMinute = Int(remaining / 60)
    }

    /// The dandelion at the end of a focus session.
    func requestMunch() { request(.munching) }

    /// Starts a one-shot clip, or queues it if another is playing. The queue holds
    /// one entry: a nibble and a dandelion landing together would stack into a
    /// long animation, and one of them is always the next minute's problem.
    private func request(_ clip: TortoiseMotion) {
        guard !isOneShot(motion) else {
            // A queued dandelion outranks a nibble: it only happens once a
            // session, and the user has just earned it.
            if clip == .munching || queuedClip == nil { queuedClip = clip }
            return
        }
        start(clip)
    }

    func reset() {
        queuedClip = nil
        lastMinute = nil
        pendingMotion = nil
        elapsed = 0
        nextBlink = TortoiseAnimator.blinkDelay(at: 0)
        restingMotion = .sittingIdle
        setMotion(.sittingIdle)
    }

    /// Last whole minute seen, so a nibble can be fired on the boundary crossing.
    private var lastMinute: Int?
    /// Where to return when the one-shot clip in flight finishes.
    private var pendingMotion: TortoiseMotion?
    /// The motion he is not one-shotting: what a clip hands back to when it ends,
    /// and what `update` compares against so a tick cannot restart a script.
    private var restingMotion: TortoiseMotion = .sittingIdle
    /// A clip asked for while another was already playing.
    private var queuedClip: TortoiseMotion?

    // MARK: Advancing

    /// Consumes `delta` seconds. Returns true when a new frame was produced, so
    /// the caller can skip redrawing a static tortoise.
    @discardableResult
    func advance(by delta: TimeInterval) -> Bool {
        guard isVisible, delta > 0 else { return false }
        elapsed += delta
        held += delta

        if isOneShot(motion) {
            var changed = false
            var guardCount = 0
            while held >= currentDuration, guardCount < 64 {
                guardCount += 1
                // Reassigned, not subtracted: the new release overwrites the old
                // one, which keeps it equal to held and cannot drift. Subtracting
                // from `held` would carry a stale remainder into the next frame.
                held = held - currentDuration
                index += 1
                if index >= script.count {
                    finishOneShot()
                    return true
                }
                if script[index].frame != frame {
                    frame = script[index].frame
                    changed = true
                }
                if !isOneShot(motion) { break }
            }
            return changed
        }

        // Sleeping is a loop too: a slow breath and a z drifting up, cycling for
        // as long as he is paused.
        if motion == .sleeping, !script.isEmpty {
            var changed = false
            while held >= currentDuration {
                held -= currentDuration
                index = (index + 1) % script.count
                if script[index].frame != frame {
                    frame = script[index].frame
                    changed = true
                }
            }
            return changed
        }

        // Awake loops: a single still frame, so the only thing that can change is
        // a blink coming round. A sleeping tortoise is not in this branch — its
        // script still advances, and it must not blink.
        if isAwake, elapsed >= nextBlink {
            start(.blinking)
            return true
        }
        return false
    }

    private var currentDuration: Double {
        guard index >= 0, index < script.count else { return 0.25 }
        return script[index].duration
    }

    private func isOneShot(_ motion: TortoiseMotion) -> Bool {
        switch motion {
        case .munching, .eating, .blinking: return true
        default: return false
        }
    }

    /// Trotting or sitting: awake, and running a script that only a blink moves.
    private var isAwake: Bool {
        motion == .trotting || motion == .sittingIdle
    }

    // MARK: Transitions

    private func setMotion(_ next: TortoiseMotion) {
        motion = next
        index = 0
        held = 0
        pendingMotion = nil
        switch next {
        case .sleeping:
            script = TortoiseAnimator.sleepScript()
            frame = script[0].frame
        case .sittingIdle:
            script = TortoiseAnimator.sitScript()
            frame = .rest
            rearmBlink()
        case .trotting:
            script = TortoiseAnimator.sitScript()
            frame = .rest
            rearmBlink()
        default:
            start(next)
        }
    }

    /// Starts a one-shot clip, remembering where he was.
    private func start(_ oneShot: TortoiseMotion) {
        script = {
            switch oneShot {
            case .munching: return TortoiseAnimator.munchFootage()
            case .eating:   return TortoiseAnimator.eatFootage()
            case .blinking: return TortoiseAnimator.blinkScript()
            default:        return []
            }
        }()
        motion = oneShot
        index = 0
        held = 0
        // Show the first frame on the same tick the clip starts. Waiting for the
        // next tick would swallow it, and for a blink that meant the lid never
        // went down at all — only the frame that lifts it again.
        frame = script.first?.frame ?? frame
        // A clip in flight owns the screen. Pushing the blink out past its end
        // stops one coming due mid-chew; the handback re-arms it properly.
        nextBlink = elapsed + 3600
    }

    /// What to do at the end of a one-shot clip.
    private func finishOneShot() {
        index = 0
        held = 0
        if let queued = queuedClip {
            queuedClip = nil
            start(queued)
            return
        }
        setMotion(pendingMotion ?? restingMotion)
        rearmBlink()
    }

    // MARK: Timing

    /// Blink spacing, in seconds. A sine of the elapsed time keeps it irregular
    /// without a random number generator, which keeps the tests exact.
    static func blinkDelay(
        at time: TimeInterval,
        range: ClosedRange<Double> = TortoiseAnimator.blinkRangeSitting
    ) -> Double {
        // A sine of the elapsed time, mapped into the range. Irregular enough to
        // read as alive, reproducible enough to assert on.
        let blend = (sin(time * 1.7) + 1) / 2
        let delay = range.lowerBound + (range.upperBound - range.lowerBound) * blend
        // Clamped, so a drift in the blend can never collapse the gap to nothing
        // and turn a blink into a tic.
        return min(max(delay, range.lowerBound), range.upperBound)
    }

    /// Blink gap that applies in the current motion.
    static func blinkRange(for motion: TortoiseMotion) -> ClosedRange<Double> {
        motion == .sittingIdle ? blinkRangeSitting : blinkRangeTrotting
    }
}
