import SwiftUI

/// First-run explainer shown until Accessibility permission is granted. Clean,
/// honest, and on-brand: explains *why* a window manager needs the permission
/// and gives a one-click path to the right System Settings pane. Polls
/// `state.isTrusted`, so it flips to the main panel automatically.
struct OnboardingView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 9) {
                Image(systemName: "righttriangle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("L'ÉQUERRE")
                        .font(Theme.mono(14, .bold)).tracking(2)
                        .foregroundStyle(Theme.ink)
                    Text(t("le règle-fenêtres", "the window ruler"))
                        .font(Theme.mono(9)).foregroundStyle(Theme.inkFaint)
                }
            }

            Text(t("Permission d'accessibilité requise",
                    "Accessibility permission required"))
                .font(Theme.rounded(14, .semibold))
                .foregroundStyle(Theme.ink)

            Text(t("""
            Pour déplacer et redimensionner les fenêtres des autres applications, \
            macOS exige que tu accordes l'accès « Accessibilité » à L'Équerre. \
            Aucune donnée n'est lue ni transmise — l'app ne fait que poser tes \
            fenêtres sur la grille.
            """, """
            To move and resize other apps' windows, macOS requires you to grant \
            L'Équerre the “Accessibility” permission. Nothing is read or sent — \
            the app only lays your windows onto the grid.
            """))
            .font(Theme.mono(10.5))
            .foregroundStyle(Theme.inkDim)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(2)

            // Numbered steps, blueprint style.
            VStack(alignment: .leading, spacing: 7) {
                step(1, t("Ouvre Réglages Système → Confidentialité et sécurité → Accessibilité",
                          "Open System Settings → Privacy & Security → Accessibility"))
                step(2, t("Active L'Équerre dans la liste",
                          "Enable L'Équerre in the list"))
                step(3, t("Reviens ici — la grille s'ouvre toute seule",
                          "Come back here — the grid opens itself"))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.paperSunken))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.gridLineBold, lineWidth: 1))

            VStack(spacing: 8) {
                Button {
                    state.requestTrust()
                    state.openAccessibilitySettings()
                } label: {
                    HStack {
                        Image(systemName: "lock.open")
                        Text(t("Ouvrir les Réglages d'accessibilité",
                                "Open Accessibility Settings"))
                    }
                    .font(Theme.mono(11.5, .semibold))
                    .foregroundStyle(Theme.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Theme.accent))
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    Circle().fill(Theme.danger).frame(width: 6, height: 6)
                    Text(t("En attente de la permission…", "Waiting for permission…"))
                        .font(Theme.mono(9)).foregroundStyle(Theme.inkFaint)
                }
            }
        }
        .padding(16)
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("\(n)")
                .font(Theme.mono(10, .bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 16, height: 16)
                .background(Circle().stroke(Theme.accent, lineWidth: 1))
            Text(text)
                .font(Theme.mono(10))
                .foregroundStyle(Theme.inkDim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
