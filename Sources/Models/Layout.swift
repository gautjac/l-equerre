import Foundation

/// One window's place inside a saved layout: which app it belongs to and the
/// frame it should occupy, stored as a fraction of the screen's visible frame
/// so the layout re-applies sensibly even if the resolution changed since it
/// was captured.
struct WindowSlot: Codable, Equatable, Identifiable {
    var id = UUID()
    /// Bundle identifier of the owning application (e.g. "com.apple.Safari").
    var bundleID: String
    /// Human-readable app name, kept for display in the menu.
    var appName: String
    /// The window title at capture time — best-effort hint for matching when an
    /// app has several windows.
    var windowTitle: String
    /// Frame as a fraction of the visible frame (top-left space, 0…1).
    var fraction: FractionRect

    private enum CodingKeys: String, CodingKey {
        case id, bundleID, appName, windowTitle, fx, fy, fw, fh
    }

    init(id: UUID = UUID(), bundleID: String, appName: String, windowTitle: String, fraction: FractionRect) {
        self.id = id; self.bundleID = bundleID; self.appName = appName
        self.windowTitle = windowTitle; self.fraction = fraction
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        bundleID = try c.decode(String.self, forKey: .bundleID)
        appName = try c.decode(String.self, forKey: .appName)
        windowTitle = (try? c.decode(String.self, forKey: .windowTitle)) ?? ""
        fraction = FractionRect(try c.decode(Double.self, forKey: .fx),
                                try c.decode(Double.self, forKey: .fy),
                                try c.decode(Double.self, forKey: .fw),
                                try c.decode(Double.self, forKey: .fh))
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(bundleID, forKey: .bundleID)
        try c.encode(appName, forKey: .appName)
        try c.encode(windowTitle, forKey: .windowTitle)
        try c.encode(fraction.x, forKey: .fx)
        try c.encode(fraction.y, forKey: .fy)
        try c.encode(fraction.w, forKey: .fw)
        try c.encode(fraction.h, forKey: .fh)
    }
}

/// A named arrangement of windows the user can re-apply with a click. Persisted
/// to Application Support as JSON via `LayoutStore`.
struct NamedLayout: Codable, Equatable, Identifiable {
    var id = UUID()
    var name: String
    var slots: [WindowSlot]
    var createdAt: Date = Date()
}

/// JSON-on-disk store for named layouts, living under Application Support so it
/// survives reinstalls and stays out of the (here, absent) sandbox container.
/// Main-actor isolated — it is only ever reached through `AppState`.
@MainActor
final class LayoutStore {
    static let shared = LayoutStore()

    private let url: URL
    private(set) var layouts: [NamedLayout] = []

    private init() {
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                appropriateFor: nil, create: true))
            ?? fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("LEquerre", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent("layouts.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: url) else { layouts = []; return }
        layouts = (try? JSONDecoder().decode([NamedLayout].self, from: data)) ?? []
    }

    private func persist() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(layouts) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func add(_ layout: NamedLayout) {
        layouts.append(layout)
        persist()
    }

    func remove(_ id: UUID) {
        layouts.removeAll { $0.id == id }
        persist()
    }

    func rename(_ id: UUID, to name: String) {
        guard let i = layouts.firstIndex(where: { $0.id == id }) else { return }
        layouts[i].name = name
        persist()
    }
}
