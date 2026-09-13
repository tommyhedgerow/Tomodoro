import Foundation
import UserNotifications
import AppKit

/// Thin wrapper over UNUserNotificationCenter.
///
/// UNUserNotificationCenter requires a real bundle, so the app must be launched
/// from Tomodoro.app rather than as a bare executable. When that is not the case
/// (running the raw binary during development) this degrades to a log line
/// instead of trapping.
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    private(set) var isAuthorized = false
    private var isAvailable: Bool { Bundle.main.bundleIdentifier != nil }

    func bootstrap() {
        guard isAvailable else {
            NSLog("Tomodoro: running outside an app bundle; notifications disabled")
            return
        }
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            DispatchQueue.main.async {
                self?.isAuthorized = granted
                if let error {
                    NSLog("Tomodoro: notification authorization error: \(error.localizedDescription)")
                    DiagLog.append("app: authorization error=\(error.localizedDescription)")
                } else {
                    NSLog("Tomodoro: notification authorization granted=\(granted)")
                    DiagLog.append("app: authorization granted=\(granted)")
                }
                self?.logCurrentSettings()
            }
        }
    }

    /// Diagnostic helper: reports what the system currently thinks of us, which
    /// distinguishes "user said no" from "this bundle cannot post at all".
    func logCurrentSettings() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            NSLog("Tomodoro: notification settings authorizationStatus=\(settings.authorizationStatus.rawValue) "
                  + "alertSetting=\(settings.alertSetting.rawValue) soundSetting=\(settings.soundSetting.rawValue)")
            DiagLog.append("app: settings authorizationStatus=\(settings.authorizationStatus.rawValue) "
                           + "alert=\(settings.alertSetting.rawValue) sound=\(settings.soundSetting.rawValue)")
        }
    }

    /// Posts one notification for a batch of finished phases.
    ///
    /// A machine that slept through several sessions produces a batch; collapsing
    /// it into a single banner avoids a stack of stale alerts on wake.
    func notify(completions: [CompletedSession], playSound: Bool) {
        guard let last = completions.last else { return }
        guard isAvailable else {
            if playSound { NSSound.beep() }
            return
        }

        let title: String
        switch last.phase {
        case .focus:      title = "Focus session complete"
        case .shortBreak: title = "Short break over"
        case .longBreak:  title = "Long break over"
        }

        var body: String
        switch last.nextPhase {
        case .focus:
            body = last.autoStarted
                ? "Back to focus — the tortoise is off again."
                : "Ready for the next focus session."
        case .shortBreak:
            body = last.autoStarted ? "Short break started — 5 minutes." : "Time for a short break."
        case .longBreak:
            body = last.autoStarted ? "Long break started — you earned it." : "Time for a long break."
        }

        if completions.count > 1 {
            body = "\(completions.count) sessions elapsed while you were away. " + body
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = playSound ? .default : nil
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "tomodoro.\(last.phase.rawValue).\(UUID().uuidString)",
            content: content,
            trigger: nil   // deliver immediately
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("Tomodoro: failed to post notification: \(error.localizedDescription)")
            }
        }
    }

    // Show banners even when Tomodoro itself is the active app.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
