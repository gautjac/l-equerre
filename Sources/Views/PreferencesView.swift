import SwiftUI
import AppKit
import Carbon.HIToolbox

/// Preferences: rebind the core verbs, set the tiling gutter, and toggle
/// launch-at-login. Stays inside the popover — no separate window — to keep the
/// menu-bar agent feel.
struct PreferencesView: View {
    @EnvironmentObject var state: AppState
    var onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.accent)
                    }.buttonStyle(.plain)
                    Text(t("PRÉFÉRENCES", "PREFERENCES"))
                        .font(Theme.mono(12, .bold)).tracking(2)
                        .foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)

                groupTitle(t("Raccourcis principaux", "Core shortcuts"))
                ForEach(BindableAction.allCases.filter { $0.isCoreRebindable }) { action in
                    RebindRow(action: action)
                }

                groupTitle(t("Espacement", "Gutter"))
                gapControl

                groupTitle(t("Démarrage", "Startup"))
                Toggle(isOn: Binding(
                    get: { state.launchAtLogin },
                    set: { state.setLaunchAtLogin($0) })) {
                    Text(t("Lancer au démarrage de session", "Launch at login"))
                        .font(Theme.rounded(12, .medium))
                        .foregroundStyle(Theme.ink)
                }
                .toggleStyle(.switch)
                .tint(Theme.accent)
                .padding(.horizontal, 14).padding(.vertical, 6)

                Button {
                    state.resetBindings()
                } label: {
                    Label(t("Rétablir les raccourcis par défaut", "Reset shortcuts to defaults"),
                          systemImage: "arrow.counterclockwise")
                        .font(Theme.mono(10.5, .medium))
                        .foregroundStyle(Theme.inkDim)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 4)

                Text(t("Les coins, tiers et « presque plein » gardent leurs raccourcis par défaut (visibles dans le menu).",
                        "Corners, thirds and “almost maximize” keep their default shortcuts (shown in the menu)."))
                    .font(Theme.mono(8.5))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 14).padding(.bottom, 12)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var gapControl: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(t("Marge entre fenêtres", "Space between windows"))
                    .font(Theme.rounded(12, .medium)).foregroundStyle(Theme.ink)
                Spacer()
                Text("\(Int(state.manager.gap)) px")
                    .font(Theme.mono(10.5, .semibold)).foregroundStyle(Theme.accentDim)
            }
            Slider(value: Binding(
                get: { Double(state.manager.gap) },
                set: { state.manager.gap = CGFloat($0) }),
                   in: 0...24, step: 2)
            .tint(Theme.accent)
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
    }

    private func groupTitle(_ s: String) -> some View {
        Text(s.uppercased())
            .font(Theme.mono(8.5, .semibold)).tracking(1.5)
            .foregroundStyle(Theme.inkFaint)
            .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
    }
}

/// One rebindable verb with a live capture field. Click "Modifier", press the
/// new chord, and it's registered immediately.
struct RebindRow: View {
    @EnvironmentObject var state: AppState
    let action: BindableAction
    @State private var capturing = false

    var body: some View {
        HStack(spacing: 10) {
            SnapGlyph(action: action.snap, size: 22)
            Text(action.label)
                .font(Theme.rounded(12, .medium))
                .foregroundStyle(Theme.ink)
            Spacer()
            if capturing {
                KeyCaptureField { combo in
                    state.rebind(action, to: combo)
                    capturing = false
                }
                .frame(width: 96, height: 24)
            } else {
                Button {
                    capturing = true
                } label: {
                    Text(state.bindings[action]?.display ?? "—")
                        .font(Theme.mono(11, .semibold))
                        .foregroundStyle(Theme.ink)
                        .frame(minWidth: 56)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.paperRaised))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.gridLineBold, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
    }
}

/// An NSView-backed first-responder that captures the next modified key press
/// and reports it as a `KeyCombo`. Requires at least one modifier so we never
/// register a bare letter that would swallow normal typing.
struct KeyCaptureField: NSViewRepresentable {
    var onCapture: (KeyCombo) -> Void

    func makeNSView(context: Context) -> CaptureView {
        let v = CaptureView()
        v.onCapture = onCapture
        return v
    }
    func updateNSView(_ nsView: CaptureView, context: Context) {
        nsView.onCapture = onCapture
    }

    final class CaptureView: NSView {
        var onCapture: ((KeyCombo) -> Void)?
        override var acceptsFirstResponder: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            DispatchQueue.main.async { [weak self] in
                self?.window?.makeFirstResponder(self)
            }
        }

        override func draw(_ dirtyRect: NSRect) {
            let bg = NSColor(calibratedRed: 0.435, green: 0.706, blue: 1.0, alpha: 0.16)
            bg.setFill()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 5, yRadius: 5)
            path.fill()
            NSColor(calibratedRed: 0.435, green: 0.706, blue: 1.0, alpha: 0.9).setStroke()
            path.lineWidth = 1
            path.stroke()
            let label = t("Appuie…", "Press…")
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor(calibratedRed: 0.435, green: 0.706, blue: 1.0, alpha: 1)
            ]
            let s = NSAttributedString(string: label, attributes: attrs)
            let size = s.size()
            s.draw(at: NSPoint(x: (bounds.width - size.width) / 2,
                               y: (bounds.height - size.height) / 2))
        }

        override func keyDown(with event: NSEvent) {
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            // Ignore pure modifier presses and require at least one modifier.
            guard !mods.isEmpty else { NSSound.beep(); return }
            let combo = KeyCombo(keyCode: UInt32(event.keyCode), modifiers: mods)
            onCapture?(combo)
        }
    }
}
