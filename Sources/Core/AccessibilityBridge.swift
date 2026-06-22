import Foundation
import AppKit
import ApplicationServices

/// Thin, focused wrapper over the Accessibility (AXUIElement) API: read the
/// frontmost app's focused window, read/write a window's position and size, and
/// enumerate every on-screen window per running app for layout capture/apply.
///
/// All geometry here is in the global *Quartz* top-left coordinate space that
/// the AX API reports (origin top-left of the main display, y growing down),
/// which `ScreenInfo` converts to/from AppKit's bottom-left space.
enum AccessibilityBridge {

    // MARK: Permission

    /// Whether the process is currently trusted for Accessibility control.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Prompt the user for Accessibility permission (shows the system dialog
    /// that deep-links to System Settings). Safe to call repeatedly.
    static func requestTrust() {
        // `kAXTrustedCheckOptionPrompt` is a non-Sendable global under Swift 6
        // strict concurrency; its documented value is this exact key string.
        let opts = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    // MARK: Focused window

    /// The AXUIElement for the focused window of the frontmost application,
    /// plus that app's running-application handle. Returns nil when nothing
    /// suitable is focused or permission is missing.
    static func focusedWindow() -> (window: AXUIElement, app: NSRunningApplication)? {
        guard isTrusted,
              let frontApp = NSWorkspace.shared.frontmostApplication,
              frontApp.processIdentifier > 0 else { return nil }

        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        var focused: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focused)
        guard err == .success, let focused else {
            // Fall back to the app's main window if no explicit focused window.
            var main: CFTypeRef?
            let mErr = AXUIElementCopyAttributeValue(appElement, kAXMainWindowAttribute as CFString, &main)
            guard mErr == .success, let main else { return nil }
            return ((main as! AXUIElement), frontApp)
        }
        return ((focused as! AXUIElement), frontApp)
    }

    // MARK: Read geometry

    static func position(of window: AXUIElement) -> CGPoint? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &value) == .success,
              let value else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    static func size(of window: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &value) == .success,
              let value else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    /// The window's frame in the global Quartz top-left space, or nil.
    static func frame(of window: AXUIElement) -> CGRect? {
        guard let p = position(of: window), let s = size(of: window) else { return nil }
        return CGRect(origin: p, size: s)
    }

    static func title(of window: AXUIElement) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value) == .success,
              let s = value as? String else { return "" }
        return s
    }

    /// Whether the window can be moved/resized (skip fullscreen / fixed panels).
    static func isResizable(_ window: AXUIElement) -> Bool {
        var settable = DarwinBoolean(false)
        AXUIElementIsAttributeSettable(window, kAXSizeAttribute as CFString, &settable)
        return settable.boolValue
    }

    // MARK: Write geometry

    /// Set a window's frame in the global Quartz top-left space. Order matters:
    /// some apps clamp size against the *current* position, so we set position,
    /// then size, then position again to settle. Returns whether the first
    /// write succeeded.
    @discardableResult
    static func setFrame(_ frame: CGRect, of window: AXUIElement) -> Bool {
        var pos = frame.origin
        var size = frame.size
        guard let posValue = AXValueCreate(.cgPoint, &pos),
              let sizeValue = AXValueCreate(.cgSize, &size) else { return false }

        let p1 = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
        // Second position pass corrects apps that re-anchored on resize.
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        return p1 == .success
    }

    // MARK: Enumerate (for layout capture / apply)

    /// All standard, titled windows of one running app, as (element, title)
    /// pairs in front-to-back order.
    static func windows(ofPID pid: pid_t) -> [(AXUIElement, String)] {
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return [] }
        return windows.compactMap { w in
            // Skip minimized windows.
            var minimized: CFTypeRef?
            if AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &minimized) == .success,
               (minimized as? Bool) == true { return nil }
            return (w, title(of: w))
        }
    }
}
