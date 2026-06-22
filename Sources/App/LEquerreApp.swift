import SwiftUI
import AppKit

/// L'Équerre — a draughtsman's window manager that lives in the menu bar.
///
/// The whole UI is a `MenuBarExtra` popover; there is no main window (the app is
/// an `LSUIElement` agent). The set-square glyph in the menu bar opens the
/// blueprint panel of grid actions, saved layouts and preferences.
@main
struct LEquerreApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(state)
        } label: {
            // A right-angle set square — the app's namesake.
            Image(systemName: "righttriangle")
                .accessibilityLabel("L'Équerre")
        }
        .menuBarExtraStyle(.window)
    }
}

/// Minimal delegate: keeps the app alive as an accessory (no Dock icon) and
/// nudges the Accessibility prompt on first launch if not yet trusted.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if !AccessibilityBridge.isTrusted {
            // Surface the system prompt once; the onboarding screen explains it.
            AccessibilityBridge.requestTrust()
        }
    }
}
