import XCTest
import Carbon.HIToolbox
import AppKit
@testable import LEquerre

/// Tests for the binding defaults, key-combo rendering, and layout JSON
/// round-tripping — all pure value types, no AX permission needed.
final class BindingsAndLayoutTests: XCTestCase {

    // MARK: KeyCombo

    func testDefaultCombosUseControlOption() {
        let combo = BindableAction.cycleLeft.defaultCombo
        XCTAssertTrue(combo.modifiers.contains(.control))
        XCTAssertTrue(combo.modifiers.contains(.option))
        XCTAssertEqual(combo.keyCode, UInt32(kVK_LeftArrow))
    }

    func testCarbonModifierMaskBridges() {
        let combo = KeyCombo(keyCode: UInt32(kVK_ANSI_C), modifiers: [.control, .option])
        let mask = combo.carbonModifiers
        XCTAssertEqual(mask & UInt32(controlKey), UInt32(controlKey))
        XCTAssertEqual(mask & UInt32(optionKey), UInt32(optionKey))
        XCTAssertEqual(mask & UInt32(cmdKey), 0)
    }

    func testDisplayGlyphs() {
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_LeftArrow), modifiers: [.control, .option]).display, "⌃⌥←")
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_Return), modifiers: [.control, .option]).display, "⌃⌥↩")
        XCTAssertEqual(KeyCombo(keyCode: UInt32(kVK_ANSI_C), modifiers: [.command]).display, "⌘C")
    }

    func testEveryBindableActionHasAUniqueDefaultCombo() {
        let combos = BindableAction.allCases.map { $0.defaultCombo }
        let set = Set(combos)
        XCTAssertEqual(set.count, combos.count, "Default hotkeys must not collide")
    }

    func testKeyComboCodableRoundTrip() throws {
        let combo = BindableAction.maximize.defaultCombo
        let data = try JSONEncoder().encode(combo)
        let back = try JSONDecoder().decode(KeyCombo.self, from: data)
        XCTAssertEqual(combo, back)
    }

    // MARK: Layout model

    func testWindowSlotRoundTrips() throws {
        let slot = WindowSlot(bundleID: "com.apple.Safari", appName: "Safari",
                              windowTitle: "Atelier", fraction: FractionRect(0, 0, 0.5, 1))
        let data = try JSONEncoder().encode(slot)
        let back = try JSONDecoder().decode(WindowSlot.self, from: data)
        XCTAssertEqual(back.bundleID, "com.apple.Safari")
        XCTAssertEqual(back.fraction, FractionRect(0, 0, 0.5, 1))
    }

    func testNamedLayoutRoundTrips() throws {
        let layout = NamedLayout(name: "Montage", slots: [
            WindowSlot(bundleID: "a", appName: "A", windowTitle: "", fraction: .cols(0, 6)),
            WindowSlot(bundleID: "b", appName: "B", windowTitle: "", fraction: .cols(6, 6)),
        ])
        let data = try JSONEncoder().encode(layout)
        let back = try JSONDecoder().decode(NamedLayout.self, from: data)
        XCTAssertEqual(back.name, "Montage")
        XCTAssertEqual(back.slots.count, 2)
        XCTAssertEqual(back.slots[1].fraction, .cols(6, 6))
    }

    // MARK: Snap action coverage

    func testEverySnapActionEitherHasFractionOrIsSpecial() {
        let special: Set<SnapAction> = [.center, .cycleLeft, .cycleRight, .cycleUp, .cycleDown]
        for action in SnapAction.allCases {
            if special.contains(action) {
                XCTAssertNil(action.fraction)
            } else {
                XCTAssertNotNil(action.fraction, "\(action) should carry a fixed fraction")
            }
        }
    }
}
