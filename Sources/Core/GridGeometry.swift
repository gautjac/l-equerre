import Foundation
import CoreGraphics

/// A rectangle expressed as fractions of the screen's *visible* frame
/// (0…1 on each axis), independent of any particular monitor's pixel size.
/// `x`/`y` are the top-left origin in a top-left coordinate space (y grows
/// downward), which is how a window's frame reads to a human looking at a
/// screen. `GridGeometry` converts this to AppKit's bottom-left space when it
/// actually places a window.
struct FractionRect: Equatable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init(_ x: Double, _ y: Double, _ w: Double, _ h: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h
    }

    /// An invisible 12-column / 12-row grid the way Lasso thinks about space.
    /// `c0`/`r0` are the starting column/row (0-based), `cs`/`rs` the spans.
    static func cols(_ c0: Int, _ cs: Int, rows r0: Int = 0, _ rs: Int = 12) -> FractionRect {
        FractionRect(Double(c0) / 12.0, Double(r0) / 12.0, Double(cs) / 12.0, Double(rs) / 12.0)
    }
}

/// Every snap action the app can perform. `Action.raw` cases carry an explicit
/// `FractionRect`; the chainable directional verbs are computed by `Cycles`.
enum SnapAction: String, CaseIterable, Codable, Identifiable {
    // Halves
    case leftHalf, rightHalf, topHalf, bottomHalf
    // Thirds (single columns) + two-thirds (horizontal and vertical)
    case leftThird, centerThird, rightThird
    case leftTwoThirds, rightTwoThirds
    case topTwoThirds, bottomTwoThirds
    // Quarters (corners)
    case topLeft, topRight, bottomLeft, bottomRight
    // Whole-screen verbs
    case maximize, almostMaximize, center
    // The chainable directional verbs (cycle through related sizes)
    case cycleLeft, cycleRight, cycleUp, cycleDown

    var id: String { rawValue }
}

/// The fixed (non-cycling) target for a snap action, as a fraction of the
/// visible frame. Returns nil for the directional cycle verbs and for `center`
/// (which preserves size).
extension SnapAction {
    var fraction: FractionRect? {
        switch self {
        case .leftHalf:        return .cols(0, 6)
        case .rightHalf:       return .cols(6, 6)
        case .topHalf:         return .cols(0, 12, rows: 0, 6)
        case .bottomHalf:      return .cols(0, 12, rows: 6, 6)
        case .leftThird:       return .cols(0, 4)
        case .centerThird:     return .cols(4, 4)
        case .rightThird:      return .cols(8, 4)
        case .leftTwoThirds:   return .cols(0, 8)
        case .rightTwoThirds:  return .cols(4, 8)
        case .topTwoThirds:    return .cols(0, 12, rows: 0, 8)
        case .bottomTwoThirds: return .cols(0, 12, rows: 4, 8)
        case .topLeft:         return .cols(0, 6, rows: 0, 6)
        case .topRight:        return .cols(6, 6, rows: 0, 6)
        case .bottomLeft:      return .cols(0, 6, rows: 6, 6)
        case .bottomRight:     return .cols(6, 6, rows: 6, 6)
        case .maximize:        return FractionRect(0, 0, 1, 1)
        case .almostMaximize:  return FractionRect(0.04, 0.04, 0.92, 0.92)
        case .center, .cycleLeft, .cycleRight, .cycleUp, .cycleDown:
            return nil
        }
    }
}

/// Chainable-verb cycles. Pressing the same direction repeatedly walks these
/// rings; the per-window cycle state lives in `WindowManager`.
enum Cycles {
    static let left:  [FractionRect] = [.cols(0, 6), .cols(0, 4), .cols(0, 8)]   // 1/2 → 1/3 → 2/3
    static let right: [FractionRect] = [.cols(6, 6), .cols(8, 4), .cols(4, 8)]   // 1/2 → 1/3 → 2/3
    static let up:    [FractionRect] = [.cols(0, 12, rows: 0, 6),
                                        .cols(0, 12, rows: 0, 4),
                                        .cols(0, 12, rows: 0, 8)]                // 1/2 → 1/3 → 2/3
    static let down:  [FractionRect] = [.cols(0, 12, rows: 6, 6),
                                        .cols(0, 12, rows: 8, 4),
                                        .cols(0, 12, rows: 4, 8)]                // 1/2 → 1/3 → 2/3

    static func ring(for action: SnapAction) -> [FractionRect]? {
        switch action {
        case .cycleLeft:  return left
        case .cycleRight: return right
        case .cycleUp:    return up
        case .cycleDown:  return down
        default:          return nil
        }
    }
}

/// Pure geometry: turns a `FractionRect` against a screen's visible frame into
/// an AppKit window frame (bottom-left origin), and snaps a window's *current*
/// frame to the nearest predefined zone for cycle bookkeeping. Kept free of
/// AppKit window objects so it is fully unit-testable.
enum GridGeometry {
    /// Convert a top-left fractional rect to an AppKit (bottom-left) frame
    /// within `visibleFrame` (which is already in AppKit's global coordinate
    /// space). `gap` insets every side so tiled windows don't touch.
    static func frame(for f: FractionRect, in visibleFrame: CGRect, gap: CGFloat = 0) -> CGRect {
        let vw = visibleFrame.width
        let vh = visibleFrame.height

        // Top-left space within the visible frame.
        var x = visibleFrame.minX + f.x * vw
        var w = f.w * vw
        var h = f.h * vh
        // Convert the top-anchored y to a bottom-anchored AppKit y.
        let topY = f.y * vh
        var y = visibleFrame.minY + (vh - topY - h)

        // Apply the gutter as a uniform inset, but never let a window collapse.
        if gap > 0 {
            x += gap; y += gap
            w = max(120, w - gap * 2)
            h = max(80,  h - gap * 2)
        } else {
            w = max(120, w)
            h = max(80,  h)
        }
        return CGRect(x: x.rounded(), y: y.rounded(), width: w.rounded(), height: h.rounded())
    }

    /// For a `center` action: keep the window's size, recentre it in the
    /// visible frame.
    static func centered(_ size: CGSize, in visibleFrame: CGRect) -> CGRect {
        let w = min(size.width, visibleFrame.width)
        let h = min(size.height, visibleFrame.height)
        let x = visibleFrame.minX + (visibleFrame.width - w) / 2
        let y = visibleFrame.minY + (visibleFrame.height - h) / 2
        return CGRect(x: x.rounded(), y: y.rounded(), width: w.rounded(), height: h.rounded())
    }

    /// How close (0…1, fraction of visible frame) two frames must be on every
    /// edge to count as "already at this zone".
    static func matches(_ frame: CGRect, _ f: FractionRect, in visibleFrame: CGRect, tolerance: CGFloat = 12) -> Bool {
        let target = GridGeometry.frame(for: f, in: visibleFrame)
        return abs(frame.minX - target.minX) <= tolerance &&
               abs(frame.minY - target.minY) <= tolerance &&
               abs(frame.width  - target.width)  <= tolerance &&
               abs(frame.height - target.height) <= tolerance
    }
}
