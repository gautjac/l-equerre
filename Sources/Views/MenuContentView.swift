import SwiftUI
import AppKit

/// The blueprint panel that drops from the menu-bar set square. Sections:
/// header + status, the grid actions (with their shortcuts), saved layouts,
/// and footers for Preferences / Quit. When Accessibility isn't yet granted,
/// the whole panel is replaced by the onboarding explainer.
struct MenuContentView: View {
    @EnvironmentObject var state: AppState
    @State private var showingPrefs = false
    @State private var savingLayout = false
    @State private var newLayoutName = ""

    var body: some View {
        ZStack {
            Theme.paper
            BlueprintGrid()
            content
        }
        .frame(width: 320)
        .frame(maxHeight: 560)
    }

    @ViewBuilder private var content: some View {
        if !state.isTrusted {
            OnboardingView()
        } else if showingPrefs {
            PreferencesView(onClose: { showingPrefs = false })
        } else {
            mainPanel
        }
    }

    private var mainPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                groupTitle(t("Moitiés", "Halves"))
                actionRow(.cycleLeft,  t("Gauche",  "Left"),  state.bindings[.cycleLeft]?.display)
                actionRow(.cycleRight, t("Droite",  "Right"), state.bindings[.cycleRight]?.display)
                actionRow(.cycleUp,    t("Haut",    "Top"),   state.bindings[.cycleUp]?.display)
                actionRow(.cycleDown,  t("Bas",     "Bottom"),state.bindings[.cycleDown]?.display)

                groupTitle(t("Tiers", "Thirds"))
                actionRow(.leftThird,   t("Tiers gauche",  "Left third"),  state.bindings[.leftThird]?.display)
                actionRow(.centerThird, t("Tiers centre",  "Center third"),state.bindings[.centerThird]?.display)
                actionRow(.rightThird,  t("Tiers droit",   "Right third"), state.bindings[.rightThird]?.display)

                groupTitle(t("Coins", "Corners"))
                actionRow(.topLeft,     t("Haut-gauche",   "Top-left"),    state.bindings[.topLeft]?.display)
                actionRow(.topRight,    t("Haut-droit",    "Top-right"),   state.bindings[.topRight]?.display)
                actionRow(.bottomLeft,  t("Bas-gauche",    "Bottom-left"), state.bindings[.bottomLeft]?.display)
                actionRow(.bottomRight, t("Bas-droit",     "Bottom-right"),state.bindings[.bottomRight]?.display)

                groupTitle(t("Écran", "Screen"))
                actionRow(.maximize,       t("Plein écran",   "Maximize"),       state.bindings[.maximize]?.display)
                actionRow(.almostMaximize, t("Presque plein", "Almost maximize"),state.bindings[.almostMaximize]?.display)
                actionRow(.center,         t("Centrer",       "Center"),         state.bindings[.center]?.display)

                layoutsSection
                footer
            }
            .padding(.bottom, 8)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(systemName: "righttriangle")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text("L'ÉQUERRE")
                    .font(Theme.mono(13, .bold))
                    .tracking(2)
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(t("plans de fenêtres", "window plans"))
                    .font(Theme.mono(8.5))
                    .foregroundStyle(Theme.inkFaint)
            }
            if !state.status.isEmpty {
                Text(state.status)
                    .font(Theme.mono(9.5))
                    .foregroundStyle(Theme.accentDim)
                    .lineLimit(1)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .animation(.easeInOut(duration: 0.2), value: state.status)
    }

    private func groupTitle(_ s: String) -> some View {
        Text(s.uppercased())
            .font(Theme.mono(8.5, .semibold))
            .tracking(1.5)
            .foregroundStyle(Theme.inkFaint)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 3)
    }

    // MARK: Action row

    private func actionRow(_ action: SnapAction, _ label: String, _ shortcut: String?) -> some View {
        Button { state.snap(action) } label: {
            HStack(spacing: 10) {
                SnapGlyph(action: action)
                Text(label)
                    .font(Theme.rounded(12.5, .medium))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if let shortcut {
                    Text(shortcut)
                        .font(Theme.mono(11, .medium))
                        .foregroundStyle(Theme.inkDim)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.paperRaised))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
    }

    // MARK: Layouts

    private var layoutsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(t("DISPOSITIONS", "LAYOUTS"))
                    .font(Theme.mono(8.5, .semibold)).tracking(1.5)
                    .foregroundStyle(Theme.inkFaint)
                Spacer()
                Button {
                    withAnimation { savingLayout.toggle() }
                } label: {
                    Image(systemName: savingLayout ? "xmark" : "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.brass)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12).padding(.bottom, 3)

            if savingLayout {
                HStack(spacing: 6) {
                    TextField(t("Nom (ex. Montage)", "Name (e.g. Montage)"), text: $newLayoutName)
                        .textFieldStyle(.plain)
                        .font(Theme.mono(11))
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.paperSunken))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.gridLineBold, lineWidth: 1))
                        .onSubmit(commitLayout)
                    Button(t("Saisir", "Capture"), action: commitLayout)
                        .buttonStyle(.plain)
                        .font(Theme.mono(10.5, .semibold))
                        .foregroundStyle(Theme.paper)
                        .padding(.horizontal, 9).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Theme.brass))
                }
                .padding(.horizontal, 14).padding(.vertical, 4)
            }

            if state.layouts.isEmpty && !savingLayout {
                Text(t("Aucune disposition. + pour saisir l'écran courant.",
                        "No layouts. + to capture the current screen."))
                    .font(Theme.mono(9.5))
                    .foregroundStyle(Theme.inkFaint)
                    .padding(.horizontal, 14).padding(.vertical, 4)
            }

            ForEach(state.layouts) { layout in
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.brass)
                    Button { state.applyLayout(layout) } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(layout.name)
                                .font(Theme.rounded(12.5, .medium))
                                .foregroundStyle(Theme.ink)
                            Text(t("\(layout.slots.count) fenêtres", "\(layout.slots.count) windows"))
                                .font(Theme.mono(8.5))
                                .foregroundStyle(Theme.inkFaint)
                        }
                        Spacer()
                    }
                    .buttonStyle(.plain)
                    Button {
                        state.deleteLayout(layout)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.inkFaint)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 14).padding(.vertical, 4)
            }
        }
    }

    private func commitLayout() {
        state.saveCurrentLayout(named: newLayoutName)
        newLayoutName = ""
        withAnimation { savingLayout = false }
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Theme.gridLineBold).frame(height: 1)
                .padding(.horizontal, 14).padding(.top, 10)
            HStack(spacing: 0) {
                Button {
                    showingPrefs = true
                } label: {
                    Label(t("Préférences", "Preferences"), systemImage: "slider.horizontal.3")
                        .font(Theme.mono(11, .medium))
                        .foregroundStyle(Theme.ink)
                }
                .buttonStyle(RowButtonStyle())
                .padding(.horizontal, 8).padding(.vertical, 6)
                Spacer()
                Button { NSApp.terminate(nil) } label: {
                    Label(t("Quitter", "Quit"), systemImage: "power")
                        .font(Theme.mono(11, .medium))
                        .foregroundStyle(Theme.inkDim)
                }
                .buttonStyle(RowButtonStyle())
                .padding(.horizontal, 8).padding(.vertical, 6)
            }
            .padding(.horizontal, 6)
        }
    }
}

/// A subtle row highlight on hover, matching the blueprint palette.
struct RowButtonStyle: ButtonStyle {
    @State private var hovering = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hovering ? Theme.accent.opacity(0.10) : .clear)
                    .padding(.horizontal, 6)
            )
            .opacity(configuration.isPressed ? 0.6 : 1)
            .onHover { hovering = $0 }
    }
}
