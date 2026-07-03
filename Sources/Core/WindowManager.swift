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
        // The two-window verb has its own flow (it touches two windows, not the
        // single focused window every other action operates on).
        if action == .sideBySide { return sideBySide() }

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

    // MARK: Side-by-side (one-shot two-window tiling)

    /// Tile the two front-most windows side by side on the active screen in a
    /// single action — the focused window on the **left** half, the next window
    /// behind it on the **right** — so the user never has to focus each window
    /// and snap it by hand.
    ///
    /// This is the direct fix for "I pressed Right then Left and they still
    /// overlapped": L'Équerre is focus-based, so both presses landed on the same
    /// focused window (one app moved, the other never did). `sideBySide` instead
    /// places *two distinct* windows at once.
    @discardableResult
    func sideBySide() -> String? {
        guard AccessibilityBridge.isTrusted else {
            return t("Permission d'accessibilité requise", "Accessibility permission required")
        }
        guard let (front, _) = AccessibilityBridge.focusedWindow(),
              AccessibilityBridge.isResizable(front),
              let frontQuartz = AccessibilityBridge.frame(of: front) else {
            return t("Aucune fenêtre active", "No focused window")
        }

        let frontScreen = ScreenInfo.screen(forQuartzFrame: frontQuartz)
        let visibleAppKit = frontScreen.visibleFrame

        // The next distinct, resizable window in z-order on the same screen.
        let other = AccessibilityBridge.zOrderedWindows().first { entry in
            !CFEqual(entry.window, front)
                && AccessibilityBridge.isResizable(entry.window)
                && ScreenInfo.screen(forQuartzFrame: entry.frame) === frontScreen
        }

        let leftQuartz = ScreenInfo.flip(GridGeometry.frame(for: .cols(0, 6), in: visibleAppKit, gap: gap))

        guard let other else {
            // Only one window in play: place it left so the action still does
            // something predictable, and say why nothing paired with it.
            AccessibilityBridge.setFrame(leftQuartz, of: front)
            return t("Une seule fenêtre — placée à gauche", "Only one window — placed left")
        }

        let rightQuartz = ScreenInfo.flip(GridGeometry.frame(for: .cols(6, 6), in: visibleAppKit, gap: gap))

        // Place the background window first, then the focused one, so the window
        // the user is looking at settles last and stays key.
        AccessibilityBridge.setFrame(rightQuartz, of: other.window)
        AccessibilityBridge.setFrame(leftQuartz, of: front)

        // If a minimum-width app (Chromium/Electron — e.g. Comet, Claude Desktop)
        // couldn't shrink to its half and now bleeds past the seam, pin it flush
        // to the screen's right edge so it overlaps as little as possible. We
        // can't force an app below its own minimum width.
        if let got = AccessibilityBridge.frame(of: other.window) {
            let gotAppKit = ScreenInfo.flip(got)
            if gotAppKit.maxX > visibleAppKit.maxX + 1 {
                var pinned = gotAppKit
                pinned.origin.x = visibleAppKit.maxX - gotAppKit.width
                AccessibilityBridge.setFrame(ScreenInfo.flip(pinned), of: other.window)
            }
        }
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
    ///
    /// Returns `(placed, total)` — how many of the layout's slots found a live
    /// window to land on this pass, out of the total. Callers use this to retry:
    /// when a sibling app (La Régie) has *just* launched the apps, their windows
    /// may not exist yet, so re-running until `placed == total` (or a timeout)
    /// catches them as they appear. Re-placing an already-placed window is
    /// idempotent, so retries are harmless.
    @discardableResult
    func applyLayout(_ layout: NamedLayout) -> (placed: Int, total: Int) {
        guard AccessibilityBridge.isTrusted else { return (0, layout.slots.count) }

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

        var placed = 0
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
            placed += 1
        }
        return (placed, layout.slots.count)
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
