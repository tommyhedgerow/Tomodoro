import AppKit
import Carbon.HIToolbox

/// Registers system-wide hotkeys through Carbon.
///
/// Carbon's RegisterEventHotKey is still the only global hotkey API that works
/// without the Accessibility permission, which makes it the right choice for a
/// menu bar utility: no extra prompt, no extra consent to revoke.
final class HotKeyManager {

    /// Identifies a registered hotkey inside the Carbon callback.
    enum HotKeyID: UInt32, CaseIterable {
        case toggleTimer = 1
        case resetTimer = 2

        var signature: OSType { OSType(0x54_4D_44_52) } // 'TMDR'
    }

    struct Shortcut: Equatable {
        var keyCode: UInt32
        var modifiers: UInt32

        var displayString: String {
            var out = ""
            if modifiers & UInt32(cmdKey) != 0 { out += "⌘" }
            if modifiers & UInt32(optionKey) != 0 { out += "⌥" }
            if modifiers & UInt32(controlKey) != 0 { out += "⌃" }
            if modifiers & UInt32(shiftKey) != 0 { out += "⇧" }
            out += Shortcut.keyName(for: keyCode)
            return out
        }

        private static func keyName(for keyCode: UInt32) -> String {
            switch Int(keyCode) {
            case kVK_ANSI_S: return "S"
            case kVK_ANSI_R: return "R"
            case kVK_ANSI_P: return "P"
            case kVK_Space:  return "Space"
            default:         return "?"
            }
        }
    }

    /// Option-Command-S / Option-Command-R, matching the brief.
    static let toggleShortcut = Shortcut(keyCode: UInt32(kVK_ANSI_S),
                                         modifiers: UInt32(optionKey | cmdKey))
    static let resetShortcut = Shortcut(keyCode: UInt32(kVK_ANSI_R),
                                        modifiers: UInt32(optionKey | cmdKey))

    private var handlers: [UInt32: () -> Void] = [:]
    private var registeredRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private(set) var registrationFailures: [String] = []

    private static let eventHandlerCallback: EventHandlerUPP = { _, event, userData in
        guard let event, let userData else { return noErr }
        let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
        return manager.handle(event: event)
    }

    func register(shortcut: Shortcut, id: HotKeyID, handler: @escaping () -> Void) {
        installEventHandlerIfNeeded()

        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: id.signature, id: id.rawValue)
        let status = RegisterEventHotKey(
            shortcut.keyCode, shortcut.modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )

        if status == noErr, let ref = hotKeyRef {
            registeredRefs.append(ref)
            handlers[id.rawValue] = handler
        } else {
            // Usually means another app already owns the combination.
            registrationFailures.append("\(shortcut.displayString) (OSStatus \(status))")
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandlerCallback,
            1, &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func handle(event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event, EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID), nil,
            MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
        )
        guard status == noErr else { return status }
        guard hotKeyID.signature == HotKeyID.toggleTimer.signature else { return noErr }
        // Hop to the next runloop turn so we never mutate state inside the Carbon callback.
        DispatchQueue.main.async { [weak self] in
            self?.handlers[hotKeyID.id]?()
        }
        return noErr
    }

    deinit {
        for ref in registeredRefs { UnregisterEventHotKey(ref) }
        if let eventHandlerRef { RemoveEventHandler(eventHandlerRef) }
    }
}
