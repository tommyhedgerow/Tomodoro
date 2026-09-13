import Foundation

/// Whether the tortoise overlay is on screen.
///
/// Stored rather than derived, because the user can override the automatic
/// behaviour in either direction from the menu and expects the choice to stick.
enum OverlayVisibility: String, Codable, CaseIterable {
    /// Visible while a session is running or paused part-way through.
    case automatic
    /// Never hidden automatically.
    case alwaysVisible
    /// Never shown, even during a session.
    case hidden

    /// Whether the user currently has the overlay switched on.
    var isShown: Bool { self != .hidden }

    var displayName: String {
        switch self {
        case .automatic:     return "Automatic"
        case .alwaysVisible: return "Always visible"
        case .hidden:        return "Hidden"
        }
    }

    /// Whether the overlay should be on screen right now.
    func shouldShow(sessionInProgress: Bool) -> Bool {
        switch self {
        case .hidden:        return false
        case .alwaysVisible: return true
        case .automatic:     return sessionInProgress
        }
    }

    /// The mode to move to when the user flips the Show Overlay switch.
    ///
    /// Re-showing during a session restores the automatic behaviour; re-showing
    /// while idle pins it instead, so switching the overlay back on always has a
    /// visible effect rather than appearing to do nothing until the next session.
    func toggled(sessionInProgress: Bool) -> OverlayVisibility {
        guard self == .hidden else { return .hidden }
        return sessionInProgress ? .automatic : .alwaysVisible
    }

    /// The mode to move to when the user flips Keep Visible When Idle.
    func settingKeepVisibleWhenIdle(_ keep: Bool) -> OverlayVisibility {
        if keep { return .alwaysVisible }
        return self == .alwaysVisible ? .automatic : self
    }
}
