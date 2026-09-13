import AppKit
import UserNotifications

/// Appends diagnostics to the file named by the TOMODORO_DIAG_FILE environment
/// variable, when one is supplied.
///
/// Launched through LaunchServices the app has no terminal attached, and reading
/// the unified log needs permissions a sandboxed shell does not have. This gives
/// an inspectable channel for support and for build verification. It is inert
/// unless the variable is set.
enum DiagLog {

    /// Resolved once. Precedence: --diag-file PATH, then TOMODORO_DIAG_FILE, then
    /// the default log under ~/Library/Logs.
    ///
    /// Defaulting to a real log file matters: an app launched through
    /// LaunchServices has no terminal attached, and reading the unified log needs
    /// permissions a sandboxed shell does not have.
    private static let path: String = {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--diag-file"), index + 1 < args.count {
            return args[index + 1]
        }
        if let override = ProcessInfo.processInfo.environment["TOMODORO_DIAG_FILE"] {
            return override
        }
        let logs = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Tomodoro", isDirectory: true)
        try? FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        return logs.appendingPathComponent("diagnostics.log").path
    }()

    /// Keep the default log from growing without bound.
    private static let maxBytes = 256 * 1024

    static func append(_ message: String) {
        let path = self.path

        if let size = try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int,
           size > maxBytes {
            try? FileManager.default.removeItem(atPath: path)
        }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let line = stamp + "  " + message + "\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}

/// Headless self-checks used to verify a build without watching the menu bar.
///
///   Tomodoro.app/Contents/MacOS/Tomodoro --diagnose
///   Tomodoro.app/Contents/MacOS/Tomodoro --test-notification
enum Diagnostics {

    static func run() -> Never {
        print("bundle identifier : " + (Bundle.main.bundleIdentifier ?? "<nil — not running from a bundle>"))
        print("bundle path       : " + Bundle.main.bundlePath)

        let engine = PomodoroEngine(defaults: UserDefaults(suiteName: "tomodoro.diagnostics") ?? .standard)
        print("default phase     : " + engine.phase.rawValue)
        print("default remaining : " + Format.clock(engine.remaining))

        print("hotkey start/pause: " + HotKeyManager.toggleShortcut.displayString)
        print("hotkey reset      : " + HotKeyManager.resetShortcut.displayString)

        let hotKeys = HotKeyManager()
        hotKeys.register(shortcut: HotKeyManager.toggleShortcut, id: .toggleTimer) {}
        hotKeys.register(shortcut: HotKeyManager.resetShortcut, id: .resetTimer) {}
        print("hotkey failures   : " + String(hotKeys.registrationFailures.count)
              + (hotKeys.registrationFailures.isEmpty ? "" : " -> " + hotKeys.registrationFailures.joined(separator: ", ")))

        guard Bundle.main.bundleIdentifier != nil else {
            print("notifications     : unavailable (no bundle identifier)")
            exit(0)
        }

        var finished = false
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let names = [0: "notDetermined", 1: "denied", 2: "authorized", 3: "provisional", 4: "ephemeral"]
            let status = names[settings.authorizationStatus.rawValue] ?? "unknown"
            print("notification auth : " + status + " (" + String(settings.authorizationStatus.rawValue) + ")")
            print("alert setting     : " + String(settings.alertSetting.rawValue))
            print("sound setting     : " + String(settings.soundSetting.rawValue))
            DiagLog.append("diagnose: authorizationStatus=" + status
                           + " alert=" + String(settings.alertSetting.rawValue)
                           + " sound=" + String(settings.soundSetting.rawValue))
            finished = true
            exit(0)
        }

        // Give the async callback a chance to land before giving up.
        let deadline = Date().addingTimeInterval(5)
        while !finished && Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        print("notification auth : <timed out>")
        exit(1)
    }

    /// Requests authorization and posts a real banner, so the end-to-end path can
    /// be confirmed by eye and in the diagnostic log.
    static func runNotificationTest() -> Never {
        DiagLog.append("test: bundle=" + (Bundle.main.bundleIdentifier ?? "<nil>"))
        print("bundle identifier : " + (Bundle.main.bundleIdentifier ?? "<nil>"))

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            let detail = "test: requestAuthorization granted=" + String(granted)
                + " error=" + (error.map { String(describing: $0) } ?? "none")
            DiagLog.append(detail)
            print(detail)

            let content = UNMutableNotificationContent()
            content.title = "Tomodoro"
            content.body = "Notifications are working. The tortoise will keep you posted."
            content.sound = .default

            center.add(UNNotificationRequest(identifier: "tomodoro.test", content: content, trigger: nil)) { addError in
                let line = "test: add error=" + (addError.map { String(describing: $0) } ?? "none")
                DiagLog.append(line)
                print(line)
                exit(addError == nil ? 0 : 1)
            }
        }

        RunLoop.main.run(until: Date().addingTimeInterval(10))
        DiagLog.append("test: timed out waiting for authorization")
        print("test: timed out")
        exit(2)
    }
}
