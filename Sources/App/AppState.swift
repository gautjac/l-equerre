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

    init() {
        loadBindings()
        registerAllHotkeys()
        refreshLaunchAtLogin()
        startTrustPolling()
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
