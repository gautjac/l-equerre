import Foundation
import Carbon.HIToolbox
import AppKit

/// A hardware-key + modifier combination, stored by virtual key code so it is
/// layout-stable (the same physical key regardless of QWERTY/AZERTY). Carries
/// helpers to render itself as the familiar ⌃⌥⇧⌘ glyph string and to bridge to
/// Carbon's modifier mask for `RegisterEventHotKey`.
struct KeyCombo: Codable, Equatable, Hashable {
    /// Carbon virtual key code (e.g. `kVK_LeftArrow`).
    var keyCode: UInt32
    /// Cocoa modifier flags (`.command`, `.option`, …) stored as their raw
    /// `UInt`, so the struct stays `Codable`.
    var modifierRawValue: UInt

    var modifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: modifierRawValue) }
        set { modifierRawValue = newValue.rawValue }
    }

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifierRawValue = modifiers.rawValue
    }

    /// Translate the Cocoa modifier flags to the Carbon modifier mask that
    /// `RegisterEventHotKey` expects.
    var carbonModifiers: UInt32 {
        var m: UInt32 = 0
        if modifiers.contains(.command) { m |= UInt32(cmdKey) }
        if modifiers.contains(.option)  { m |= UInt32(optionKey) }
        if modifiers.contains(.control) { m |= UInt32(controlKey) }
        if modifiers.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }

    /// The conventional glyph string, e.g. "⌃⌥←".
    var display: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        s += KeyCombo.keyName(for: keyCode)
        return s
    }

    /// Human-readable name for a virtual key code (the glyph or letter on the
    /// key cap). Covers the keys L'Équerre binds plus the full alphanumerics.
    static func keyName(for code: UInt32) -> String {
        switch Int(code) {
        case kVK_LeftArrow:  return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow:    return "↑"
        case kVK_DownArrow:  return "↓"
        case kVK_Return:     return "↩"
        case kVK_ANSI_KeypadEnter: return "⌤"
        case kVK_Space:      return "␣"
        case kVK_Escape:     return "⎋"
        case kVK_Delete:     return "⌫"
        case kVK_Tab:        return "⇥"
        default:
            if let s = KeyCombo.letterCodes.first(where: { $0.value == Int(code) })?.key {
                return s
            }
            return "?"
        }
    }

    /// Map of single uppercase letters / digits to their ANSI virtual key
    /// codes, used both for display and for the rebinding UI's key capture.
    static let letterCodes: [String: Int] = [
        "A": kVK_ANSI_A, "B": kVK_ANSI_B, "C": kVK_ANSI_C, "D": kVK_ANSI_D,
        "E": kVK_ANSI_E, "F": kVK_ANSI_F, "G": kVK_ANSI_G, "H": kVK_ANSI_H,
        "I": kVK_ANSI_I, "J": kVK_ANSI_J, "K": kVK_ANSI_K, "L": kVK_ANSI_L,
        "M": kVK_ANSI_M, "N": kVK_ANSI_N, "O": kVK_ANSI_O, "P": kVK_ANSI_P,
        "Q": kVK_ANSI_Q, "R": kVK_ANSI_R, "S": kVK_ANSI_S, "T": kVK_ANSI_T,
        "U": kVK_ANSI_U, "V": kVK_ANSI_V, "W": kVK_ANSI_W, "X": kVK_ANSI_X,
        "Y": kVK_ANSI_Y, "Z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
        "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
        "8": kVK_ANSI_8, "9": kVK_ANSI_9,
    ]
}
