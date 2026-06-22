import Foundation
import Carbon.HIToolbox
import AppKit

/// The set of actions a user can rebind from Preferences. We expose the four
/// directional chains, maximize and center as the "core" rebindable verbs (the
/// rest follow sensible fixed defaults). Each has a stable string key used for
/// persistence and for `HotkeyManager` registration.
enum BindableAction: String, CaseIterable, Identifiable {
    case cycleLeft, cycleRight, cycleUp, cycleDown
    case maximize, center, almostMaximize
    case leftThird, centerThird, rightThird
    case leftTwoThirds, rightTwoThirds
    case topLeft, topRight, bottomLeft, bottomRight

    var id: String { rawValue }

    /// The snap action this binding triggers.
    var snap: SnapAction {
        switch self {
        case .cycleLeft:      return .cycleLeft
        case .cycleRight:     return .cycleRight
        case .cycleUp:        return .cycleUp
        case .cycleDown:      return .cycleDown
        case .maximize:       return .maximize
        case .center:         return .center
        case .almostMaximize: return .almostMaximize
        case .leftThird:      return .leftThird
        case .centerThird:    return .centerThird
        case .rightThird:     return .rightThird
        case .leftTwoThirds:  return .leftTwoThirds
        case .rightTwoThirds: return .rightTwoThirds
        case .topLeft:        return .topLeft
        case .topRight:       return .topRight
        case .bottomLeft:     return .bottomLeft
        case .bottomRight:    return .bottomRight
        }
    }

    var label: String {
        switch self {
        case .cycleLeft:      return t("Moitié gauche",  "Left half")
        case .cycleRight:     return t("Moitié droite",  "Right half")
        case .cycleUp:        return t("Moitié haut",    "Top half")
        case .cycleDown:      return t("Moitié bas",     "Bottom half")
        case .maximize:       return t("Plein écran",    "Maximize")
        case .center:         return t("Centrer",        "Center")
        case .almostMaximize: return t("Presque plein",  "Almost maximize")
        case .leftThird:      return t("Tiers gauche",   "Left third")
        case .centerThird:    return t("Tiers centre",   "Center third")
        case .rightThird:     return t("Tiers droit",    "Right third")
        case .leftTwoThirds:  return t("Deux tiers gauche", "Left two-thirds")
        case .rightTwoThirds: return t("Deux tiers droit",  "Right two-thirds")
        case .topLeft:        return t("Coin haut-gauche",   "Top-left")
        case .topRight:       return t("Coin haut-droit",    "Top-right")
        case .bottomLeft:     return t("Coin bas-gauche",    "Bottom-left")
        case .bottomRight:    return t("Coin bas-droit",     "Bottom-right")
        }
    }

    /// Whether this action appears in the compact "rebind a few core hotkeys"
    /// Preferences list (the rest are shown read-only in the menu).
    var isCoreRebindable: Bool {
        switch self {
        case .cycleLeft, .cycleRight, .cycleUp, .cycleDown, .maximize, .center:
            return true
        default:
            return false
        }
    }

    /// Factory-default combo. ⌃⌥ as the base chord (the Rectangle convention,
    /// out of the way of app shortcuts), arrows for halves, U/I/J/K wouldn't be
    /// mnemonic so we use letters that map to the screen geometry.
    var defaultCombo: KeyCombo {
        let ctrlOpt: NSEvent.ModifierFlags = [.control, .option]
        switch self {
        case .cycleLeft:      return KeyCombo(keyCode: UInt32(kVK_LeftArrow),  modifiers: ctrlOpt)
        case .cycleRight:     return KeyCombo(keyCode: UInt32(kVK_RightArrow), modifiers: ctrlOpt)
        case .cycleUp:        return KeyCombo(keyCode: UInt32(kVK_UpArrow),    modifiers: ctrlOpt)
        case .cycleDown:      return KeyCombo(keyCode: UInt32(kVK_DownArrow),  modifiers: ctrlOpt)
        case .maximize:       return KeyCombo(keyCode: UInt32(kVK_Return),     modifiers: ctrlOpt)
        case .center:         return KeyCombo(keyCode: UInt32(kVK_ANSI_C),     modifiers: ctrlOpt)
        case .almostMaximize: return KeyCombo(keyCode: UInt32(kVK_ANSI_A),     modifiers: ctrlOpt)
        case .leftThird:      return KeyCombo(keyCode: UInt32(kVK_ANSI_J),     modifiers: ctrlOpt)
        case .centerThird:    return KeyCombo(keyCode: UInt32(kVK_ANSI_K),     modifiers: ctrlOpt)
        case .rightThird:     return KeyCombo(keyCode: UInt32(kVK_ANSI_L),     modifiers: ctrlOpt)
        // ⌃⌥⇧ + arrow — the half-arrow plus Shift, mnemonic for "wider".
        case .leftTwoThirds:  return KeyCombo(keyCode: UInt32(kVK_LeftArrow),  modifiers: [.control, .option, .shift])
        case .rightTwoThirds: return KeyCombo(keyCode: UInt32(kVK_RightArrow), modifiers: [.control, .option, .shift])
        case .topLeft:        return KeyCombo(keyCode: UInt32(kVK_ANSI_U),     modifiers: ctrlOpt)
        case .topRight:       return KeyCombo(keyCode: UInt32(kVK_ANSI_I),     modifiers: ctrlOpt)
        case .bottomLeft:     return KeyCombo(keyCode: UInt32(kVK_ANSI_N),     modifiers: ctrlOpt)
        case .bottomRight:    return KeyCombo(keyCode: UInt32(kVK_ANSI_M),     modifiers: ctrlOpt)
        }
    }
}
