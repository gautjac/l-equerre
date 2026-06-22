import Foundation
import AppKit

/// Bridges the two coordinate spaces macOS forces a window manager to juggle:
///
///  - **AppKit** (`NSScreen.visibleFrame`): origin at the **bottom-left** of the
///    primary display, y growing **up**. The visible frame already excludes the
///    menu bar and the Dock — exactly the area we want to tile inside.
///  - **Quartz / Accessibility** (`AXUIElementCopyAttributeValue`): origin at the
///    **top-left** of the primary display, y growing **down**. This is the space
///    `AccessibilityBridge` reads and writes window frames in.
///
/// `GridGeometry` works entirely in AppKit space; `ScreenInfo` converts the
/// final AppKit frame to Quartz space just before it's written to a window, and
/// converts a window's Quartz frame back to AppKit space to decide which screen
/// it lives on and where it sits in the cycle.
enum ScreenInfo {

    /// Total height of the global display arrangement in AppKit's primary-screen
    /// coordinate space — the pivot used to flip y between the two spaces.
    static var globalHeight: CGFloat {
        // The primary screen is the one whose frame origin is (0,0) in AppKit.
        // Its full (not visible) height is the flip pivot for top↔bottom origin.
        NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? 0
    }

    /// Flip a rect between AppKit (bottom-left) and Quartz (top-left) space.
    /// The transform is its own inverse, so one function serves both ways.
    static func flip(_ rect: CGRect) -> CGRect {
        let h = globalHeight
        return CGRect(x: rect.minX,
                      y: h - rect.maxY,
                      width: rect.width,
                      height: rect.height)
    }

    /// The `NSScreen` a window (given in Quartz top-left space) sits on — the
    /// screen containing its centre, falling back to the main screen.
    static func screen(forQuartzFrame frame: CGRect) -> NSScreen {
        let appKitFrame = flip(frame)
        let center = CGPoint(x: appKitFrame.midX, y: appKitFrame.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(center) })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }

    /// The visible frame (menu bar + Dock excluded) of the screen a window is
    /// on, in AppKit space.
    static func visibleFrame(forQuartzFrame frame: CGRect) -> CGRect {
        screen(forQuartzFrame: frame).visibleFrame
    }
}
