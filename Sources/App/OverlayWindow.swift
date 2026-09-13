import AppKit
import SwiftUI
import Combine

/// Borderless, always-on-top panel that holds the tortoise overlay.
///
/// .nonactivatingPanel matters here: clicking the tortoise must not pull focus
/// away from whatever the user is actually working in.
final class TortoiseOverlayPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        hidesOnDeactivate = false
        becomesKeyOnlyIfNeeded = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false          // the art provides its own silhouette
        animationBehavior = .utilityWindow
        isReleasedWhenClosed = false
        isMovableByWindowBackground = false   // we drag manually, so clicks stay clicks
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Container that turns mouse input into timer commands.
///
/// It also does pixel-accurate hit testing: the window is a square, but only the
/// pixels the tortoise actually covers should intercept a click. Everything else
/// falls through to whatever is behind it.
final class OverlayInteractionView: NSView {

    var onClick: (() -> Void)?
    var onRightClick: ((NSEvent) -> Void)?

    private var mouseDownAt: NSPoint?
    private var didDrag = false

    override init(frame: NSRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        // point arrives in the superview's coordinates.
        let local = convert(point, from: superview)
        guard bounds.contains(local) else { return nil }

        return TortoiseOverlayMetrics.isHit(point: local, in: bounds) ? self : nil
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownAt = event.locationInWindow
        didDrag = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownAt, let window else { return }
        let now = event.locationInWindow
        let dx = now.x - start.x
        let dy = now.y - start.y
        if abs(dx) > 2 || abs(dy) > 2 { didDrag = true }
        guard didDrag else { return }

        var frame = window.frame
        frame.origin.x += dx
        frame.origin.y += dy
        window.setFrame(frame, display: true)
    }

    override func mouseUp(with event: NSEvent) {
        defer { mouseDownAt = nil }
        guard !didDrag else { return }
        onClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?(event)
    }
}

/// Owns the overlay panel and decides when it is on screen.
///
/// Visibility is an explicit, persisted choice (see OverlayVisibility) that the
/// user controls from either menu, rather than something inferred from the timer
/// alone. Automatic mode shows the overlay whenever a session is in progress,
/// running or paused, so pausing to answer the phone does not make it vanish.
final class OverlayWindowController: NSObject, NSWindowDelegate {

    private let panel: TortoiseOverlayPanel
    private let interactionView: OverlayInteractionView
    private let engine: PomodoroEngine
    private var cancellables = Set<AnyCancellable>()

    private static let originKey = "tomodoro.overlay.origin"
    private static let visibilityKey = "tomodoro.overlay.visibility"

    private let cellSize = TortoiseOverlayMetrics.defaultCellSize
    private var size: NSSize { NSSize(width: cellSize * 16, height: cellSize * 16) }

    /// Whether the overlay is allowed on screen. Persisted across launches.
    private(set) var visibility: OverlayVisibility {
        didSet {
            guard visibility != oldValue else { return }
            UserDefaults.standard.set(visibility.rawValue, forKey: Self.visibilityKey)
            DiagLog.append("overlay: visibility=\(visibility.rawValue)")
            onVisibilityChanged?(visibility)
            updateVisibility()
        }
    }

    /// Lets the menus redraw their checkmarks when the state changes.
    var onVisibilityChanged: ((OverlayVisibility) -> Void)?

    /// Switches the overlay on or off, as the Show Overlay menu item does.
    func setShown(_ shown: Bool) {
        guard shown else {
            visibility = .hidden
            return
        }
        visibility = engine.isSessionInProgress ? .automatic : .alwaysVisible
    }

    /// Flips between hidden and shown.
    func toggleVisibility() {
        visibility = visibility.toggled(sessionInProgress: engine.isSessionInProgress)
    }

    /// Keeps the overlay up even with no session running.
    func setKeepVisibleWhenIdle(_ keep: Bool) {
        visibility = visibility.settingKeepVisibleWhenIdle(keep)
    }

    init(engine: PomodoroEngine) {
        self.engine = engine
        self.visibility = Self.loadVisibility()

        let side = cellSize * 16
        let origin = Self.resolvedOrigin(saved: Self.loadSavedOrigin(), size: NSSize(width: side, height: side))
        panel = TortoiseOverlayPanel(contentRect: NSRect(origin: origin, size: NSSize(width: side, height: side)))
        interactionView = OverlayInteractionView(
            frame: NSRect(x: 0, y: 0, width: side, height: side)
        )

        super.init()

        let hosting = NSHostingController(rootView: TortoiseOverlayView(engine: engine))
        // Never let SwiftUI's intrinsic size drive the window: that is what pushes
        // a bottom-anchored panel off the top of the screen.
        hosting.sizingOptions = []

        interactionView.addSubview(hosting.view)
        hosting.view.frame = interactionView.bounds
        hosting.view.autoresizingMask = [.width, .height]

        interactionView.onClick = { [weak self] in self?.engine.toggle() }
        interactionView.onRightClick = { [weak self] event in
            self?.showContextMenu(event: event)
        }

        panel.contentView = interactionView
        panel.setContentSize(NSSize(width: side, height: side))
        panel.delegate = self
        panel.ignoresMouseEvents = false

        observeEngine()
        updateVisibility()
    }

    private func observeEngine() {
        // Hops to the next runloop turn so the state is read after the change,
        // not before it. Covers running, pausing, resetting and phase changes.
        engine.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateVisibility() }
            .store(in: &cancellables)
    }

    func updateVisibility() {
        let shouldShow = visibility.shouldShow(sessionInProgress: engine.isSessionInProgress)

        if shouldShow {
            // Re-clamp on every show so a display change cannot strand the panel.
            let frame = Self.clamped(
                origin: panel.frame.origin, size: size, preferredScreen: panel.screen
            )
            if panel.frame.origin != frame {
                panel.setFrameOrigin(frame)
            }
            if !panel.isVisible {
                panel.orderFrontRegardless()
                DiagLog.append("overlay: shown frame=\(panel.frame) "
                               + "visible=\(panel.screen?.visibleFrame ?? .zero) "
                               + "mode=\(visibility.rawValue) running=\(engine.isRunning)")
            }
        } else if panel.isVisible {
            panel.orderOut(nil)
            DiagLog.append("overlay: hidden mode=\(visibility.rawValue)")
        }
    }

    private func showContextMenu(event: NSEvent) {
        let menu = NSMenu()
        menu.addItem(withTitle: engine.isRunning ? "Pause" : "Start",
                     action: #selector(OverlayMenuTarget.toggle), keyEquivalent: "")
            .target = menuTarget
        menu.addItem(withTitle: "Reset Session",
                     action: #selector(OverlayMenuTarget.reset), keyEquivalent: "")
            .target = menuTarget
        menu.addItem(withTitle: "Skip to Next Phase",
                     action: #selector(OverlayMenuTarget.skip), keyEquivalent: "")
            .target = menuTarget
        menu.addItem(.separator())

        let keep = menu.addItem(withTitle: "Keep Visible When Idle",
                                action: #selector(OverlayMenuTarget.keepVisible), keyEquivalent: "")
        keep.target = menuTarget
        keep.state = visibility == .alwaysVisible ? .on : .off

        menu.addItem(withTitle: "Hide Overlay",
                     action: #selector(OverlayMenuTarget.hide), keyEquivalent: "")
            .target = menuTarget

        menuTarget.actions = (toggle: { [weak self] in self?.engine.toggle() },
                              reset: { [weak self] in self?.engine.reset() },
                              skip: { [weak self] in self?.engine.skip() },
                              keepVisible: { [weak self] in
                                  guard let self else { return }
                                  self.setKeepVisibleWhenIdle(self.visibility != .alwaysVisible)
                              },
                              hide: { [weak self] in self?.setShown(false) })

        if let view = panel.contentView {
            menu.popUp(positioning: nil, at: view.convert(event.locationInWindow, from: nil), in: view)
        }
    }

    private let menuTarget = OverlayMenuTarget()

    // MARK: Placement

    private static func loadVisibility() -> OverlayVisibility {
        guard let raw = UserDefaults.standard.string(forKey: visibilityKey),
              let mode = OverlayVisibility(rawValue: raw)
        else { return .automatic }
        return mode
    }

    private static func loadSavedOrigin() -> NSPoint? {
        guard let value = UserDefaults.standard.string(forKey: originKey) else { return nil }
        let parts = value.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return NSPoint(x: parts[0], y: parts[1])
    }

    /// Restores the saved position, or tucks the overlay under the menu bar on the
    /// right-hand side of the main screen.
    private static func resolvedOrigin(saved: NSPoint?, size: NSSize) -> NSPoint {
        guard let saved else {
            let frame = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
            return NSPoint(x: frame.maxX - size.width - 24, y: frame.maxY - size.height - 24)
        }
        return clamped(origin: saved, size: size, preferredScreen: nil)
    }

    /// Keeps the whole panel inside a screen's visible area. Without this a stale
    /// saved origin, or a display that has since changed, can strand the window
    /// partly off-screen.
    private static func clamped(origin: NSPoint, size: NSSize, preferredScreen: NSScreen?) -> NSPoint {
        let screen = preferredScreen
            ?? NSScreen.screens.first(where: { $0.frame.contains(origin) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let visible = screen?.visibleFrame else { return origin }

        return NSPoint(
            x: min(max(origin.x, visible.minX), max(visible.minX, visible.maxX - size.width)),
            y: min(max(origin.y, visible.minY), max(visible.minY, visible.maxY - size.height))
        )
    }

    func windowDidMove(_ notification: Notification) {
        let origin = panel.frame.origin
        UserDefaults.standard.set("\(origin.x),\(origin.y)", forKey: Self.originKey)
    }
}

/// Small Objective-C target so the overlay's context menu can dispatch back.
final class OverlayMenuTarget: NSObject {
    var actions: (toggle: () -> Void, reset: () -> Void, skip: () -> Void,
                  keepVisible: () -> Void, hide: () -> Void)?

    @objc func toggle() { actions?.toggle() }
    @objc func reset() { actions?.reset() }
    @objc func skip() { actions?.skip() }
    @objc func keepVisible() { actions?.keepVisible() }
    @objc func hide() { actions?.hide() }
}
