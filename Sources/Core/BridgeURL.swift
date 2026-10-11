import Foundation

/// The `x-equerre://` URL contract — L'Équerre's remote control.
///
/// Sibling Atelier apps (notably **La Régie**, the cue console) can't drive
/// windows themselves: positioning needs the Accessibility API, which L'Équerre
/// already owns. So instead of duplicating that engine, they fire a URL and let
/// L'Équerre do the placing. One scheme, one verb today:
///
///     x-equerre://apply?name=Montage
///     x-equerre://snap?zone=left&app=com.apple.Safari
///
/// re-applies the saved disposition named "Montage", or snaps one app's window to a zone. The parsing lives here, as
/// a pure value-in / value-out function, so it is unit-tested without AppKit,
/// windows, or the Accessibility permission.
enum BridgeCommand: Equatable {
    /// Re-apply the named disposition (case-insensitive match in `LayoutStore`).
    case apply(name: String)
    /// Put one window in a zone. `app` is the target's bundle id: a caller that has just closed its own panel (Le Verbe) can't
    /// count on focus having moved back yet, so it names the app instead of relying on "the focused window".
    case snap(zone: SnapAction, app: String?)
}

enum BridgeURL {
    static let scheme = "x-equerre"

    /// Parse an incoming URL into a command, or `nil` if it isn't a well-formed
    /// `x-equerre://` instruction we understand. Tolerant of case in the scheme
    /// and host (macOS may normalise them); strict about needing a non-empty
    /// `name` for `apply`.
    static func parse(_ url: URL) -> BridgeCommand? {
        guard url.scheme?.lowercased() == scheme else { return nil }

        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        // The "verb" is the host: x-equerre://<verb>?…
        switch (url.host ?? comps?.host)?.lowercased() {
        case "apply":
            guard let raw = comps?.queryItems?
                    .first(where: { $0.name.lowercased() == "name" })?.value else { return nil }
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : .apply(name: name)
        case "snap":
            guard let raw = comps?.queryItems?.first(where: { $0.name.lowercased() == "zone" })?.value,
                  let zone = zone(named: raw) else { return nil }
            let app = comps?.queryItems?.first(where: { $0.name.lowercased() == "app" })?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .snap(zone: zone, app: (app?.isEmpty ?? true) ? nil : app)
        default:
            return nil
        }
    }

    /// Short names for the zones a caller is likely to want, then any `SnapAction` raw value (`topLeft`, `leftThird`…).
    /// The cycling verbs (`cycleLeft`…) and `sideBySide` are not zones: they depend on key presses and on two windows.
    static func zone(named raw: String) -> SnapAction? {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "left", "gauche": return .leftHalf
        case "right", "droite": return .rightHalf
        case "top", "haut": return .topHalf
        case "bottom", "bas": return .bottomHalf
        case "almost", "almostmax", "presque": return .almostMaximize
        case "max", "full", "maximize", "plein": return .maximize
        case "center", "centre": return .center
        default:
            guard let a = SnapAction.allCases.first(where: { $0.rawValue.lowercased() == key }) else { return nil }
            switch a {
            case .cycleLeft, .cycleRight, .cycleUp, .cycleDown, .sideBySide: return nil
            default: return a
            }
        }
    }
}
