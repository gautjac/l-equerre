import Foundation
import Carbon.HIToolbox
import AppKit

/// A hand-rolled Carbon global-hotkey wrapper — no SPM network dependency. Each
/// registered combo gets a unique `EventHotKeyID`; a single application-level
/// Carbon event handler dispatches `kEventHotKeyPressed` back to the matching
/// Swift closure on the main thread.
///
/// Carbon's `RegisterEventHotKey` is still the supported, low-latency way to
/// claim a system-wide hotkey on macOS (NSEvent global monitors can't swallow
/// the event, and the newer APIs are sandbox-only). This is the same mechanism
/// Rectangle uses.
///
/// Main-actor isolated: every entry point (registration from `AppState`, and the
/// Carbon callback, which re-dispatches to the main queue) runs on the main
/// thread, so all mutable state is touched single-threaded.
@MainActor
final class HotkeyManager {
    static let shared = HotkeyManager()

    /// Bumped per registration so each hotkey has a stable, unique id.
    private var nextID: UInt32 = 1
    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [UInt32: EventHotKeyRef] = [:]
    /// The id we handed out for a given logical action, so we can replace it
    /// when the user rebinds.
    private var idForAction: [String: UInt32] = [:]
    private var eventHandler: EventHandlerRef?

    /// The four-char signature that namespaces our hotkey ids.
    private let signature: OSType = {
        // 'EQRE'
        let chars: [UInt8] = Array("EQRE".utf8)
        return (OSType(chars[0]) << 24) | (OSType(chars[1]) << 16) | (OSType(chars[2]) << 8) | OSType(chars[3])
    }()

    private init() { installEventHandler() }

    private func installEventHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData -> OSStatus in
            guard let event, let userData else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            guard status == noErr else { return status }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            let firedID = hotKeyID.id
            DispatchQueue.main.async { MainActor.assumeIsolated { manager.fire(id: firedID) } }
            return noErr
        }, 1, &spec, userData, &eventHandler)
    }

    private func fire(id: UInt32) {
        handlers[id]?()
    }

    /// (Re)bind a logical action to a combo. A nil combo unbinds it. Returns
    /// false if the combo couldn't be registered (e.g. already owned by another
    /// app), leaving the action unbound.
    @discardableResult
    func bind(action: String, to combo: KeyCombo?, handler: @escaping () -> Void) -> Bool {
        // Tear down any previous registration for this action.
        if let oldID = idForAction[action] {
            if let ref = refs[oldID] { UnregisterEventHotKey(ref) }
            refs[oldID] = nil
            handlers[oldID] = nil
            idForAction[action] = nil
        }
        guard let combo else { return true }

        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: signature, id: id)
        let status = RegisterEventHotKey(combo.keyCode,
                                         combo.carbonModifiers,
                                         hotKeyID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &ref)
        guard status == noErr, let ref else { return false }
        refs[id] = ref
        handlers[id] = handler
        idForAction[action] = id
        return true
    }

    /// Remove every registration (used on teardown / before a full rebind).
    func unbindAll() {
        for ref in refs.values { UnregisterEventHotKey(ref) }
        refs.removeAll()
        handlers.removeAll()
        idForAction.removeAll()
    }
}
