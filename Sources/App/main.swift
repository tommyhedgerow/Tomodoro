import AppKit

// Build-time helper: emit an .iconset and exit, so build.sh can run this same
// binary to produce the app icon without a separate tool target.
if let index = CommandLine.arguments.firstIndex(of: "--export-iconset"),
   index + 1 < CommandLine.arguments.count {
    let directory = CommandLine.arguments[index + 1]
    let ok = AppIconRenderer.exportIconset(to: directory)
    exit(ok ? 0 : 1)
}

// Headless self-checks, used to verify a build without watching the menu bar.
if CommandLine.arguments.contains("--diagnose") {
    Diagnostics.run()
}
if CommandLine.arguments.contains("--test-notification") {
    Diagnostics.runNotificationTest()
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
