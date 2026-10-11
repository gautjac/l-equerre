import Foundation
import AppKit
import SwiftUI
import ServiceManagement

/// App-wide state: owns the `WindowManager`, the live hotkey bindings (persisted
/// to UserDefaults), the Accessibility-trust flag the UI watches, and the
/// launch-at-login toggle. Observable so the popover refreshes as things change.
@MainActor
final class AppState: ObservableObject {
    let manager = WindowManager()

    /// Live bindings, action-key → combo. Seeded from defaults, overridden by
    /// anything the user saved.
    @Published var bindings: [BindableAction: KeyCombo] = [:]

    /// Mirrors `AccessibilityBridge.isTrusted`, polled so the onboarding screen
    /// flips to "granted" the moment the user ticks the box in System Settings.
    @Published var isTrusted: Bool = AccessibilityBridge.isTrusted

    /// Saved layouts (mirror of `LayoutStore`, republished for the UI).
    @Published var layouts: [NamedLayout] = LayoutStore.shared.layouts

    @Published var launchAtLogin: Bool = false

    /// The last flashed status line shown briefly in the popover header.
    @Published var status: String = ""

    private var trustTimer: Timer?
    private let bindingsKey = "lequerre.bindings.v1"

    // MARK: Bridge (x-equerre:// remote control)

    /// The live instance, so the AppDelegate's URL handler can reach it. Weak —
    /// the App owns it as a `@StateObject`; we just borrow a reference.
    static weak var shared: AppState?

    /// URLs that arrived before this instance existed (a cold launch *via* the
    /// URL itself), replayed once we're ready.
    private static var pendingURLs: [URL] = []

    /// Entry point for the AppDelegate: route a `x-equerre://` URL to the live
    /// state, or stash it if we're mid-launch.
    static func receive(url: URL) {
        if let live = shared { live.handle(openURL: url) }
        else { pendingURLs.append(url) }
    }

    // Retry state for `applyLayout(named:)` — see `runRetryPass`.
    private var layoutRetryTimer: Timer?
    private var retryLayout: NamedLayout?
    private var retrySchedule: [TimeInterval] = []

    init() {
        loadBindings()
        registerAllHotkeys()
        refreshLaunchAtLogin()
        startTrustPolling()

        // Become reachable from the URL handler, then drain anything that
        // arrived during a URL-triggered cold launch.
        AppState.shared = self
        let pending = AppState.pendingURLs
        AppState.pendingURLs = []
        pending.forEach { handle(openURL: $0) }
    }

    /// Decode an incoming `x-equerre://` URL and act on it.
    func handle(openURL url: URL) {
        switch BridgeURL.parse(url) {
        case .apply(let name): applyLayout(named: name)
        case .snap(let zone, let bundleID):
            // A named app that isn't running is ignored (we would snap whatever happens to be in front: surprising).
            let target = bundleID.flatMap { id in NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == id } }
            if bundleID != nil, target == nil { break }
            _ = manager.perform(zone, in: target)
        case .none:            break
        }
    }

    // MARK: Bindings persistence

    private func loadBindings() {
        var result: [BindableAction: KeyCombo] = [:]
        // Start from factory defaults.
        for action in BindableAction.allCases { result[action] = action.defaultCombo }
        // Overlay any saved overrides.
        if let data = UserDefaults.standard.data(forKey: bindingsKey),
           let saved = try? JSONDecoder().decode([String: KeyCombo].self, from: data) {
            for (key, combo) in saved {
                if let action = BindableAction(rawValue: key) { result[action] = combo }
            }
        }
        bindings = result
    }

    private func persistBindings() {
        let dict = Dictionary(uniqueKeysWithValues: bindings.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: bindingsKey)
        }
    }

    // MARK: Hotkeys

    /// Register every bound action with the Carbon hotkey manager.
    func registerAllHotkeys() {
        HotkeyManager.shared.unbindAll()
        for action in BindableAction.allCases {
            let combo = bindings[action]
            HotkeyManager.shared.bind(action: action.rawValue, to: combo) { [weak self] in
                guard let self else { return }
                let msg = self.manager.perform(action.snap)
                if let msg { self.flash(msg) }
            }
        }
    }

    /// Rebind one action and re-register just that hotkey.
    func rebind(_ action: BindableAction, to combo: KeyCombo) {
        bindings[action] = combo
        persistBindings()
        HotkeyManager.shared.bind(action: action.rawValue, to: combo) { [weak self] in
            guard let self else { return }
            let msg = self.manager.perform(action.snap)
            if let msg { self.flash(msg) }
        }
    }

    /// Restore every binding to its factory default.
    func resetBindings() {
        for action in BindableAction.allCases { bindings[action] = action.defaultCombo }
        persistBindings()
        registerAllHotkeys()
    }

    // MARK: Snap from the menu (no hotkey)

    func snap(_ action: SnapAction) {
        let msg = manager.perform(action)
        if let msg { flash(msg) }
    }

    // MARK: Layouts

    func saveCurrentLayout(named name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let layout = manager.captureLayout(named: trimmed)
        LayoutStore.shared.add(layout)
        layouts = LayoutStore.shared.layouts
        flash(t("Disposition « \(trimmed) » enregistrée", "Layout “\(trimmed)” saved"))
    }

    func applyLayout(_ layout: NamedLayout) {
        manager.applyLayout(layout)
        flash(t("Disposition « \(layout.name) » appliquée", "Layout “\(layout.name)” applied"))
    }

    /// Apply a disposition looked up by name — the verb behind
    /// `x-equerre://apply?name=…`. Matching is case-insensitive and
    /// whitespace-trimmed. Because the caller (e.g. La Régie) may have launched
    /// the apps a heartbeat ago, this **retries**: it re-applies on a short
    /// schedule until every slot finds its window, or ~2.6 s elapse — so windows
    /// snap into place as they appear, with no fragile fixed delay on the caller.
    func applyLayout(named name: String) {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !key.isEmpty else { return }
        guard let layout = LayoutStore.shared.layouts.first(where: {
            $0.name.lowercased() == key
        }) else {
            flash(t("Disposition « \(name) » introuvable", "Layout “\(name)” not found"))
            return
        }
        guard AccessibilityBridge.isTrusted else {
            flash(t("Permission d'accessibilité requise", "Accessibility permission required"))
            return
        }

        layoutRetryTimer?.invalidate()
        retryLayout = layout
        retrySchedule = [0.3, 0.6, 1.0, 1.6, 2.6]   // delays BETWEEN passes (s)
        runRetryPass()
    }

    /// One pass of `applyLayout(named:)`: place what we can, and if some slots
    /// still have no window, schedule another pass — unless the schedule is
    /// exhausted or every slot is now home.
    private func runRetryPass() {
        guard let layout = retryLayout else { return }
        let (placed, total) = manager.applyLayout(layout)

        if placed >= total || retrySchedule.isEmpty {
            flash(t("Disposition « \(layout.name) » appliquée", "Layout “\(layout.name)” applied"))
            retryLayout = nil
            retrySchedule = []
            return
        }

        let delay = retrySchedule.removeFirst()
        layoutRetryTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.runRetryPass() }
        }
    }

    func deleteLayout(_ layout: NamedLayout) {
        LayoutStore.shared.remove(layout.id)
        layouts = LayoutStore.shared.layouts
    }

    // MARK: Accessibility trust

    func requestTrust() {
        AccessibilityBridge.requestTrust()
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func startTrustPolling() {
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let now = AccessibilityBridge.isTrusted
                if now != self.isTrusted { self.isTrusted = now }
            }
        }
    }

    // MARK: Launch at login

    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else  { try SMAppService.mainApp.unregister() }
        } catch {
            flash(t("Échec du réglage de démarrage", "Login-item change failed"))
        }
        refreshLaunchAtLogin()
    }

    // MARK: Status flash

    private func flash(_ msg: String) {
        status = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { [weak self] in
            if self?.status == msg { self?.status = "" }
        }
    }
}
