import Foundation
import AppKit
import ApplicationServices

/// The conductor: turns a `SnapAction` into a real window move, manages the
/// per-window chainable-verb cycle state, and captures / applies named layouts.
/// AppKit-bound, so it runs on the main actor.
@MainActor
final class WindowManager: ObservableObject {

    /// Configurable gutter between tiled windows (px). 0 = flush tiling.
    @Published var gap: CGFloat = UserDefaults.standard.object(forKey: "lequerre.gap") as? CGFloat ?? 0 {
        didSet { UserDefaults.standard.set(gap, forKey: "lequerre.gap") }
    }

    /// Per-window cycle position, keyed by a stable identity for the focused
    /// window. macOS doesn't hand us a durable window id through AX, so we key
    /// on "bundleID|title|action-ring" — good enough to chain repeated presses
    /// on the same focused window, and it naturally resets when focus moves.
    private var cycleIndex: [String: Int] = [:]
    private var lastActionKey: String?

    // MARK: Snap

    /// Perform a snap action on the currently focused window. Returns a short
    /// status the UI can flash, or nil on success-with-no-message.
    @discardableResult
    func perform(_ action: SnapAction) -> String? {
        guard AccessibilityBridge.isTrusted else {
            return t("Permission d'accessibilité requise", "Accessibility permission required")
        }
        guard let (window, app) = AccessibilityBridge.focusedWindow() else {
            return t("Aucune fenêtre active", "No focused window")
        }
        guard AccessibilityBridge.isResizable(window),
              let currentQuartz = AccessibilityBridge.frame(of: window) else {
            return t("Fenêtre non déplaçable", "Window can't be moved")
        }

        let visibleAppKit = ScreenInfo.visibleFrame(forQuartzFrame: currentQuartz)

        // Resolve the target fraction, honoring cycles and center.
        let targetAppKit: CGRect
        if action == .center {
            targetAppKit = GridGeometry.centered(currentQuartz.size, in: visibleAppKit)
        } else if let ring = Cycles.ring(for: action) {
            let fraction = nextInCycle(ring, action: action, app: app,
                                       window: window, currentQuartz: currentQuartz,
                                       visibleAppKit: visibleAppKit)
            targetAppKit = GridGeometry.frame(for: fraction, in: visibleAppKit, gap: gap)
        } else if let fraction = action.fraction {
            targetAppKit = GridGeometry.frame(for: fraction, in: visibleAppKit,
                                              gap: action == .maximize ? 0 : gap)
        } else {
            return nil
        }

        // AppKit (bottom-left) → Quartz (top-left) for the AX write.
        let targetQuartz = ScreenInfo.flip(targetAppKit)
        AccessibilityBridge.setFrame(targetQuartz, of: window)
        return nil
    }

    /// Walk the cycle ring: if the focused window is the same one we last
    /// chained and it's still at the previous ring position, advance; otherwise
    /// start the ring at index 0.
    private func nextInCycle(_ ring: [FractionRect], action: SnapAction,
                             app: NSRunningApplication, window: AXUIElement,
                             currentQuartz: CGRect, visibleAppKit: CGRect) -> FractionRect {
        let title = AccessibilityBridge.title(of: window)
        let key = "\(app.bundleIdentifier ?? "?")|\(title)|\(action.rawValue)"

        // Determine where the window currently sits in the ring, if anywhere.
        let currentAppKit = ScreenInfo.flip(currentQuartz)
        let matchedIndex = ring.firstIndex { GridGeometry.matches(currentAppKit, $0, in: visibleAppKit) }

        let nextIndex: Int
        if let matched = matchedIndex {
            // Already on the ring → advance to the next slot.
            nextIndex = (matched + 1) % ring.count
        } else if lastActionKey == key, let stored = cycleIndex[key] {
            // We just placed it (it may have nudged), continue from memory.
            nextIndex = (stored + 1) % ring.count
        } else {
            nextIndex = 0
        }

        cycleIndex[key] = nextIndex
        lastActionKey = key
        return ring[nextIndex]
    }

    // MARK: Layouts

    /// Capture the current arrangement of every standard window on the screen
    /// the frontmost window is on, as fractions of that screen's visible frame.
    func captureLayout(named name: String) -> NamedLayout {
        var slots: [WindowSlot] = []

        // Use the frontmost window's screen as the reference screen.
        let referenceVisible: CGRect = {
            if let (w, _) = AccessibilityBridge.focusedWindow(),
               let f = AccessibilityBridge.frame(of: w) {
                return ScreenInfo.visibleFrame(forQuartzFrame: f)
            }
            return NSScreen.main?.visibleFrame ?? .zero
        }()

        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier > 0 {
            for (window, title) in AccessibilityBridge.windows(ofPID: app.processIdentifier) {
                guard let quartz = AccessibilityBridge.frame(of: window) else { continue }
                let appKit = ScreenInfo.flip(quartz)
                // Only windows that live on the reference screen.
                guard referenceVisible.intersects(appKit) else { continue }
                guard let fraction = fractionFor(appKit, in: referenceVisible) else { continue }
                slots.append(WindowSlot(bundleID: app.bundleIdentifier ?? "",
                                        appName: app.localizedName ?? "",
                                        windowTitle: title,
                                        fraction: fraction))
            }
        }
        return NamedLayout(name: name, slots: slots)
    }

    /// Re-apply a saved layout to the currently active screen. Best-effort:
    /// matches each slot to a running app's window by bundle id (and title when
    /// an app has several windows).
    func applyLayout(_ layout: NamedLayout) {
        guard AccessibilityBridge.isTrusted else { return }

        let referenceVisible: CGRect = {
            if let (w, _) = AccessibilityBridge.focusedWindow(),
               let f = AccessibilityBridge.frame(of: w) {
                return ScreenInfo.visibleFrame(forQuartzFrame: f)
            }
            return NSScreen.main?.visibleFrame ?? .zero
        }()

        // Index live windows by bundle id.
        var byBundle: [String: [(AXUIElement, String)]] = [:]
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular && app.processIdentifier > 0 {
            guard let bid = app.bundleIdentifier else { continue }
            byBundle[bid, default: []].append(contentsOf:
                AccessibilityBridge.windows(ofPID: app.processIdentifier))
        }

        for slot in layout.slots {
            guard var candidates = byBundle[slot.bundleID], !candidates.isEmpty else { continue }
            // Prefer an exact title match; else take the first remaining window.
            let pick: Int
            if let exact = candidates.firstIndex(where: { $0.1 == slot.windowTitle }) {
                pick = exact
            } else {
                pick = 0
            }
            let (window, _) = candidates[pick]
            candidates.remove(at: pick)
            byBundle[slot.bundleID] = candidates

            let targetAppKit = GridGeometry.frame(for: slot.fraction, in: referenceVisible, gap: gap)
            AccessibilityBridge.setFrame(ScreenInfo.flip(targetAppKit), of: window)
        }
    }

    /// Express an AppKit-space frame as a fraction of a visible frame, clamped
    /// to 0…1 (top-left space). Returns nil for degenerate frames.
    private func fractionFor(_ frame: CGRect, in visible: CGRect) -> FractionRect? {
        guard visible.width > 1, visible.height > 1 else { return nil }
        let x = (frame.minX - visible.minX) / visible.width
        // Convert bottom-left y to a top-anchored fraction.
        let topY = (visible.maxY - frame.maxY) / visible.height
        let w = frame.width / visible.width
        let h = frame.height / visible.height
        func clamp(_ v: CGFloat) -> Double { Double(min(max(v, 0), 1)) }
        return FractionRect(clamp(x), clamp(topY), clamp(w), clamp(h))
    }
}
