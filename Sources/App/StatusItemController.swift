import AppKit
import SwiftUI

/// Menu bar presence: the tortoise icon, the optional countdown, the dropdown,
/// and a right-click menu of the common commands.
final class StatusItemController: NSObject, NSPopoverDelegate {

    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let engine: PomodoroEngine
    private let ui: UIState
    private let actions: AppActions

    private var lastClock: String?
    private var lastPhase: SessionPhase?
    private var lastStyle: TortoiseStyle?
    private var lastShowTime: Bool?

    private var flashTimer: Timer?
    private var flashTicksRemaining = 0
    private var flashOn = false

    init(engine: PomodoroEngine, ui: UIState, actions: AppActions) {
        self.engine = engine
        self.ui = ui
        self.actions = actions
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        let hosting = NSHostingController(
            rootView: PopoverView(engine: engine, ui: ui, actions: actions)
        )
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.delegate = self
        // Pin the size explicitly. Left to itself the popover adopts the hosting
        // view's ideal height, which grows with the settings section and can push
        // the dropdown off the top of the screen.
        popover.contentSize = PopoverMetrics.contentSize(
            availableHeight: NSScreen.main?.visibleFrame.height
        )

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
            button.toolTip = "Tomodoro"
        }

        refresh(force: true)
    }

    /// Repaints the icon and title, skipping work when nothing visible changed.
    /// Called on every engine tick, so it must stay cheap.
    func refresh(force: Bool = false) {
        guard let button = statusItem.button else { return }
        let showTime = engine.settings.showTimeInMenuBar
        let clock = showTime ? Format.clock(engine.remaining) : ""
        let style = engine.settings.tortoiseStyle

        // While the end-of-session flash is running it owns the image.
        if flashTimer == nil, force || lastPhase != engine.phase || lastStyle != style {
            button.image = TortoiseImageFactory.menuBarIcon(style: style, phase: engine.phase)
            lastPhase = engine.phase
            lastStyle = style
        }
        if force || lastClock != clock || lastShowTime != showTime {
            button.title = clock.isEmpty ? "" : " " + clock
            lastClock = clock
            lastShowTime = showTime
        }
    }

    /// Pulses a bell in the menu bar when a session ends.
    ///
    /// This is the guaranteed-visible cue: macOS refuses notification
    /// authorization to ad-hoc signed builds, so the app must not depend on a
    /// banner actually appearing.
    func flashSessionEnd() {
        flashTimer?.invalidate()
        flashTicksRemaining = 8
        flashOn = true

        let timer = Timer(timeInterval: 0.35, repeats: true) { [weak self] timer in
            guard let self else { return }
            self.flashOn.toggle()
            self.flashTicksRemaining -= 1
            self.applyFlash()

            if self.flashTicksRemaining <= 0 {
                timer.invalidate()
                self.flashTimer = nil
                self.flashOn = false
                self.lastPhase = nil          // force the tortoise back
                self.refresh(force: true)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        flashTimer = timer
        applyFlash()
    }

    private func applyFlash() {
        guard let button = statusItem.button else { return }
        if flashOn {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            let bell = NSImage(systemSymbolName: "bell.fill",
                               accessibilityDescription: "Session ended")?
                .withSymbolConfiguration(config)
            bell?.isTemplate = true
            button.image = bell
                ?? TortoiseImageFactory.menuBarIcon(style: engine.settings.tortoiseStyle,
                                                    phase: engine.phase)
        } else {
            button.image = TortoiseImageFactory.menuBarIcon(style: engine.settings.tortoiseStyle,
                                                           phase: engine.phase)
        }
    }

    // MARK: Click handling

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true

        if isRightClick {
            showContextMenu(from: sender)
        } else {
            togglePopover(from: sender)
        }
    }

    /// Opens the dropdown without a click, so a build can be verified headlessly.
    func openPopoverForDiagnostics() {
        guard let button = statusItem.button else { return }
        togglePopover(from: button)
    }

    private func togglePopover(from sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        // Re-measure: the status item may now be on a different display.
        popover.contentSize = PopoverMetrics.contentSize(
            availableHeight: (sender.window?.screen ?? NSScreen.main)?.visibleFrame.height
        )
        // An accessory app still needs to be active for the popover to take keys.
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        DiagLog.append("popover: size=\(popover.contentSize) "
                       + "frame=\(popover.contentViewController?.view.window?.frame ?? .zero)")
    }

    private func showContextMenu(from sender: NSStatusBarButton) {
        let menu = NSMenu()

        menu.addItem(withTitle: engine.isRunning ? "Pause" : "Start",
                     action: #selector(menuToggle), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Reset Session",
                     action: #selector(menuReset), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Skip to Next Phase",
                     action: #selector(menuSkip), keyEquivalent: "").target = self

        menu.addItem(.separator())

        // The overlay's show/hide switch, mirroring the dropdown's setting.
        let overlayItem = menu.addItem(withTitle: "Show Overlay",
                                       action: #selector(menuToggleOverlay), keyEquivalent: "")
        overlayItem.target = self
        overlayItem.state = ui.overlayVisibility.isShown ? .on : .off

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Tomodoro", action: #selector(menuQuit), keyEquivalent: "q")
            .target = self

        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: sender.bounds.height + 6),
                   in: sender)
    }

    @objc private func menuToggle() { actions.toggle() }
    @objc private func menuReset() { actions.reset() }
    @objc private func menuSkip() { actions.skip() }
    @objc private func menuQuit() { actions.quit() }
    @objc private func menuToggleOverlay() { actions.toggleOverlay() }
}
