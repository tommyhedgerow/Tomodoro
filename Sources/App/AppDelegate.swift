import AppKit
import Combine

/// Wires the engine to the menu bar, the tortoise overlay, global hotkeys,
/// notifications, and sleep/wake handling.
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let engine = PomodoroEngine()
    private let ui = UIState()
    private let notifications = NotificationManager()
    private let hotKeys = HotKeyManager()

    /// Owns the tortoise's idle animation. Kept at app scope so the overlay can be
    /// hidden and shown without the tortoise's state resetting.
    private let animator = TortoiseAnimator()

    /// Retained so the diagnostic probe can drive the same actions the menus use.
    private var actions: AppActions?
    private var statusController: StatusItemController?
    private var overlayController: OverlayWindowController?
    private var cancellables = Set<AnyCancellable>()
    private var workspaceObservers: [NSObjectProtocol] = []
    private var clockObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let actions = makeActions()
        self.actions = actions
        statusController = StatusItemController(
            engine: engine, ui: ui, actions: actions,
            initiallyShowSettings: CommandLine.arguments.contains("--settings-open")
        )

        let overlay = OverlayWindowController(engine: engine, animator: animator)
        overlay.onVisibilityChanged = { [weak self] visibility in
            self?.ui.overlayVisibility = visibility
        }
        overlayController = overlay
        ui.overlayVisibility = overlay.visibility
        animator.update(from: engine)

        notifications.bootstrap()
        engine.onSessionsCompleted = { [weak self] completions in
            guard let self, !completions.isEmpty else { return }
            let settings = self.engine.settings
            DiagLog.append("app: session(s) completed="
                           + completions.map { $0.phase.rawValue }.joined(separator: ",")
                           + " next=" + (completions.last?.nextPhase.rawValue ?? "?"))
            self.handleSessionEnd(completions: completions, settings: settings)
        }

        registerHotKeys()
        observeEngine()
        observeSystemEvents()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            // A display change can strand the overlay; re-clamp it.
            self?.overlayController?.updateVisibility()
        }

        // Drives the Show Overlay switch through the same action the menus call,
        // so the menu wiring can be verified without clicking anything.
        if CommandLine.arguments.contains("--overlay-probe") {
            func later(_ delay: Double, _ body: @escaping () -> Void) {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: body)
            }
            later(1.5) { self.engine.start() }
            later(2.5) { self.actions?.toggleOverlay() }   // hide
            later(3.5) { self.actions?.toggleOverlay() }   // show again
            later(4.5) { self.actions?.setOverlayShown(false) }
            later(5.5) { self.actions?.toggleOverlay() }
            later(6.5) { exit(0) }
        }

        if CommandLine.arguments.contains("--popover-probe") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.statusController?.openPopoverForDiagnostics()
                // Long enough for an external screen capture to catch it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 14.0) { exit(0) }
            }
        }

        NSLog("Tomodoro ready — phase=\(engine.phase.rawValue) "
              + "running=\(engine.isRunning) remaining=\(Int(engine.remaining))s "
              + "hotkeys=\(HotKeyManager.toggleShortcut.displayString)/\(HotKeyManager.resetShortcut.displayString) "
              + "hotkeyFailures=\(hotKeys.registrationFailures.count)")
    }

    private func handleSessionEnd(completions: [CompletedSession], settings: PomodoroSettings) {
        // A focus session that finished earns the dandelion. Break sessions do
        // not: he earns a treat for the work, not for the rest.
        if completions.contains(where: { $0.phase == .focus }) {
            animator.update(from: engine)
            animator.requestMunch()
        } else {
            animator.update(from: engine)
        }

        var bannerPosted = false
        if settings.notificationsEnabled, notifications.isAuthorized {
            notifications.notify(completions: completions, playSound: settings.playSound)
            bannerPosted = true
        }
        // Fallbacks. macOS refuses notification authorization to ad-hoc signed
        // builds, so a session ending must never be silent.
        if settings.playSound && !bannerPosted {
            NSSound.beep()
        }
        statusController?.flashSessionEnd()
    }

    func applicationWillTerminate(_ notification: Notification) {
        for observer in workspaceObservers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let clockObserver {
            NotificationCenter.default.removeObserver(clockObserver)
        }
    }

    // MARK: Actions

    private func makeActions() -> AppActions {
        AppActions(
            toggle: { [weak self] in self?.engine.toggle() },
            reset: { [weak self] in self?.engine.reset() },
            skip: { [weak self] in self?.engine.skip() },
            resetAll: { [weak self] in self?.engine.resetAll() },
            selectPhase: { [weak self] phase in self?.engine.select(phase: phase) },
            setOverlayShown: { [weak self] shown in self?.overlayController?.setShown(shown) },
            setOverlayKeepVisible: { [weak self] keep in
                self?.overlayController?.setKeepVisibleWhenIdle(keep)
            },
            toggleOverlay: { [weak self] in self?.overlayController?.toggleVisibility() },
            quit: { NSApp.terminate(nil) }
        )
    }

    // MARK: Hotkeys

    private func registerHotKeys() {
        hotKeys.register(shortcut: HotKeyManager.toggleShortcut, id: .toggleTimer) { [weak self] in
            self?.engine.toggle()
        }
        hotKeys.register(shortcut: HotKeyManager.resetShortcut, id: .resetTimer) { [weak self] in
            self?.engine.reset()
        }
        ui.hotKeyWarnings = hotKeys.registrationFailures
        if !ui.hotKeyWarnings.isEmpty {
            NSLog("Tomodoro: hotkeys already taken: \(ui.hotKeyWarnings.joined(separator: ", "))")
        }
    }

    // MARK: Observation

    private func observeEngine() {
        engine.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.statusController?.refresh()
                    self?.ui.notificationsAvailable = self?.notifications.isAuthorized ?? true
                }
            }
            .store(in: &cancellables)
    }

    /// Sleep/wake is the whole reason the timer is date-based: on wake we re-derive
    /// the remaining time from the wall clock and re-arm the ticker.
    private func observeSystemEvents() {
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
            workspaceObservers.append(
                workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    self?.engine.handleWake()
                }
            )
        }

        // A manual clock change or timezone jump should re-derive the countdown too.
        clockObserver = NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            self?.engine.refresh()
        }
    }
}
