import Foundation

/// The `x-equerre://` URL contract — L'Équerre's remote control.
///
/// Sibling Atelier apps (notably **La Régie**, the cue console) can't drive
/// windows themselves: positioning needs the Accessibility API, which L'Équerre
/// already owns. So instead of duplicating that engine, they fire a URL and let
/// L'Équerre do the placing. One scheme, one verb today:
///
///     x-equerre://apply?name=Montage
///
/// re-applies the saved disposition named "Montage". The parsing lives here, as
/// a pure value-in / value-out function, so it is unit-tested without AppKit,
/// windows, or the Accessibility permission.
enum BridgeCommand: Equatable {
    /// Re-apply the named disposition (case-insensitive match in `LayoutStore`).
    case apply(name: String)
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
        default:
            return nil
        }
    }
}
