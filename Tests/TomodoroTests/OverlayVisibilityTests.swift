import XCTest

/// The overlay's show/hide logic, driven from the menus.
final class OverlayVisibilityTests: XCTestCase {

    // MARK: Should it be on screen?

    func testAutomaticShowsOnlyDuringASession() {
        XCTAssertTrue(OverlayVisibility.automatic.shouldShow(sessionInProgress: true))
        XCTAssertFalse(OverlayVisibility.automatic.shouldShow(sessionInProgress: false))
    }

    func testAlwaysVisibleIgnoresTheTimer() {
        XCTAssertTrue(OverlayVisibility.alwaysVisible.shouldShow(sessionInProgress: false))
        XCTAssertTrue(OverlayVisibility.alwaysVisible.shouldShow(sessionInProgress: true))
    }

    func testHiddenStaysHiddenEvenMidSession() {
        XCTAssertFalse(OverlayVisibility.hidden.shouldShow(sessionInProgress: true))
        XCTAssertFalse(OverlayVisibility.hidden.shouldShow(sessionInProgress: false))
    }

    func testOnlyHiddenCountsAsSwitchedOff() {
        XCTAssertTrue(OverlayVisibility.automatic.isShown)
        XCTAssertTrue(OverlayVisibility.alwaysVisible.isShown)
        XCTAssertFalse(OverlayVisibility.hidden.isShown)
    }

    // MARK: The Show Overlay switch

    func testTogglingFromShownHidesIt() {
        XCTAssertEqual(OverlayVisibility.automatic.toggled(sessionInProgress: true), .hidden)
        XCTAssertEqual(OverlayVisibility.alwaysVisible.toggled(sessionInProgress: false), .hidden)
    }

    func testTogglingBackOnDuringASessionRestoresAutomatic() {
        XCTAssertEqual(OverlayVisibility.hidden.toggled(sessionInProgress: true), .automatic)
    }

    /// Switching the overlay back on while idle must actually show something,
    /// rather than silently staying invisible until the next session starts.
    func testTogglingBackOnWhileIdlePinsItSoSomethingAppears() {
        let restored = OverlayVisibility.hidden.toggled(sessionInProgress: false)
        XCTAssertEqual(restored, .alwaysVisible)
        XCTAssertTrue(restored.shouldShow(sessionInProgress: false))
    }

    func testHidingThenShowingLandsVisible() {
        for mode in [OverlayVisibility.automatic, .alwaysVisible] {
            for inProgress in [true, false] {
                let hidden = mode.toggled(sessionInProgress: inProgress)
                XCTAssertEqual(hidden, .hidden, "toggling a visible overlay hides it")

                let back = hidden.toggled(sessionInProgress: inProgress)
                XCTAssertTrue(back.shouldShow(sessionInProgress: inProgress),
                              "\(mode) toggled twice should be visible again "
                              + "with sessionInProgress=\(inProgress)")
            }
        }
    }

    func testShowingThenHidingLandsHidden() {
        for inProgress in [true, false] {
            let shown = OverlayVisibility.hidden.toggled(sessionInProgress: inProgress)
            XCTAssertTrue(shown.shouldShow(sessionInProgress: inProgress))

            let hidden = shown.toggled(sessionInProgress: inProgress)
            XCTAssertEqual(hidden, .hidden, "a second toggle hides it again")
        }
    }

    // MARK: Keep Visible When Idle

    func testTurningKeepVisibleOnPinsTheOverlay() {
        XCTAssertEqual(OverlayVisibility.automatic.settingKeepVisibleWhenIdle(true), .alwaysVisible)
        XCTAssertEqual(OverlayVisibility.hidden.settingKeepVisibleWhenIdle(true), .alwaysVisible)
    }

    func testTurningKeepVisibleOffReturnsToAutomatic() {
        XCTAssertEqual(OverlayVisibility.alwaysVisible.settingKeepVisibleWhenIdle(false), .automatic)
    }

    func testTurningKeepVisibleOffLeavesAHiddenOverlayHidden() {
        XCTAssertEqual(OverlayVisibility.hidden.settingKeepVisibleWhenIdle(false), .hidden)
    }

    func testKeepVisibleRoundTrips() {
        let pinned = OverlayVisibility.automatic.settingKeepVisibleWhenIdle(true)
        XCTAssertTrue(pinned.shouldShow(sessionInProgress: false))
        let unpinned = pinned.settingKeepVisibleWhenIdle(false)
        XCTAssertFalse(unpinned.shouldShow(sessionInProgress: false))
    }

    func testPersistedRepresentationIsStable() {
        // The raw values are written to UserDefaults, so they are part of the
        // on-disk format and must not drift.
        XCTAssertEqual(OverlayVisibility.automatic.rawValue, "automatic")
        XCTAssertEqual(OverlayVisibility.alwaysVisible.rawValue, "alwaysVisible")
        XCTAssertEqual(OverlayVisibility.hidden.rawValue, "hidden")
        for mode in OverlayVisibility.allCases {
            XCTAssertEqual(OverlayVisibility(rawValue: mode.rawValue), mode)
        }
    }
}
