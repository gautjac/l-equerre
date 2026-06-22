import XCTest
@testable import LEquerre

/// Pure-geometry tests: no AppKit windows, no permissions — just the math that
/// turns fractional grid zones into concrete AppKit frames, the cycle rings,
/// and the AppKit↔Quartz flip. These run on the Mac with no UI.
final class GridGeometryTests: XCTestCase {

    /// A simple 1440×900 visible frame anchored at the origin (AppKit space).
    private let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)

    // MARK: Fractional rects

    func testHalvesCoverTheRightColumns() {
        XCTAssertEqual(SnapAction.leftHalf.fraction, FractionRect(0, 0, 0.5, 1))
        XCTAssertEqual(SnapAction.rightHalf.fraction, FractionRect(0.5, 0, 0.5, 1))
    }

    func testThirdsAndTwoThirds() {
        XCTAssertEqual(SnapAction.leftThird.fraction!.w, 1.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(SnapAction.rightThird.fraction!.x, 2.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(SnapAction.leftTwoThirds.fraction!.w, 2.0 / 3.0, accuracy: 1e-9)
    }

    func testMaximizeIsFullScreen() {
        XCTAssertEqual(SnapAction.maximize.fraction, FractionRect(0, 0, 1, 1))
    }

    // MARK: Frame conversion (top-left fraction → AppKit bottom-left frame)

    func testLeftHalfFrame() {
        let f = GridGeometry.frame(for: .cols(0, 6), in: visible)
        XCTAssertEqual(f, CGRect(x: 0, y: 0, width: 720, height: 900))
    }

    func testRightHalfFrame() {
        let f = GridGeometry.frame(for: .cols(6, 6), in: visible)
        XCTAssertEqual(f.minX, 720)
        XCTAssertEqual(f.width, 720)
    }

    func testTopHalfIsUpperInAppKitSpace() {
        // Top half (top-left space y=0, height 0.5) → AppKit upper half, so its
        // origin.y is at 450 (bottom-left space).
        let f = GridGeometry.frame(for: .cols(0, 12, rows: 0, 6), in: visible)
        XCTAssertEqual(f.minY, 450)
        XCTAssertEqual(f.height, 450)
    }

    func testBottomHalfIsLowerInAppKitSpace() {
        let f = GridGeometry.frame(for: .cols(0, 12, rows: 6, 6), in: visible)
        XCTAssertEqual(f.minY, 0)
        XCTAssertEqual(f.height, 450)
    }

    func testTopLeftCorner() {
        let f = GridGeometry.frame(for: .cols(0, 6, rows: 0, 6), in: visible)
        // Upper-left quarter → AppKit (0, 450, 720, 450).
        XCTAssertEqual(f, CGRect(x: 0, y: 450, width: 720, height: 450))
    }

    func testGapInsetsEverySide() {
        let f = GridGeometry.frame(for: .cols(0, 6), in: visible, gap: 10)
        XCTAssertEqual(f.minX, 10)
        XCTAssertEqual(f.minY, 10)
        XCTAssertEqual(f.width, 720 - 20)
        XCTAssertEqual(f.height, 900 - 20)
    }

    func testFrameRespectsVisibleFrameOffset() {
        // Simulate a screen whose visible frame is inset by the menu bar/Dock.
        let inset = CGRect(x: 0, y: 70, width: 1440, height: 800)
        let f = GridGeometry.frame(for: .cols(0, 12, rows: 0, 6), in: inset)
        // Top half should sit at the top of the *visible* frame.
        XCTAssertEqual(f.maxY, inset.maxY)
    }

    // MARK: Centering preserves size

    func testCenteredKeepsSize() {
        let f = GridGeometry.centered(CGSize(width: 600, height: 400), in: visible)
        XCTAssertEqual(f.width, 600)
        XCTAssertEqual(f.height, 400)
        XCTAssertEqual(f.midX, visible.midX, accuracy: 1)
        XCTAssertEqual(f.midY, visible.midY, accuracy: 1)
    }

    // MARK: Matching / cycle bookkeeping

    func testMatchesRecognisesItsOwnFrame() {
        let f = GridGeometry.frame(for: .cols(0, 6), in: visible)
        XCTAssertTrue(GridGeometry.matches(f, .cols(0, 6), in: visible))
        XCTAssertFalse(GridGeometry.matches(f, .cols(6, 6), in: visible))
    }

    func testMatchesWithinTolerance() {
        var f = GridGeometry.frame(for: .cols(0, 6), in: visible)
        f.origin.x += 8   // small nudge under the 12px tolerance
        XCTAssertTrue(GridGeometry.matches(f, .cols(0, 6), in: visible))
        f.origin.x += 40  // now well outside
        XCTAssertFalse(GridGeometry.matches(f, .cols(0, 6), in: visible))
    }

    // MARK: Cycle rings

    func testLeftCycleRingOrder() {
        // 1/2 → 1/3 → 2/3, then wraps.
        XCTAssertEqual(Cycles.left.count, 3)
        XCTAssertEqual(Cycles.left[0].w, 0.5, accuracy: 1e-9)
        XCTAssertEqual(Cycles.left[1].w, 1.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(Cycles.left[2].w, 2.0 / 3.0, accuracy: 1e-9)
    }

    func testCycleRingsAllLeftAnchored() {
        for f in Cycles.left  { XCTAssertEqual(f.x, 0, accuracy: 1e-9) }
        for f in Cycles.right { XCTAssertEqual(f.x + f.w, 1, accuracy: 1e-9) } // right-anchored
    }

    func testRingLookup() {
        XCTAssertNotNil(Cycles.ring(for: .cycleLeft))
        XCTAssertNil(Cycles.ring(for: .maximize))
    }
}
