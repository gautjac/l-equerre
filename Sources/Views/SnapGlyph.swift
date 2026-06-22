import SwiftUI

/// A tiny blueprint thumbnail of a snap zone: the screen as a thin indigo
/// rectangle with the target region drawn as a filled accent block. Reads
/// instantly as "this is where the window goes."
struct SnapGlyph: View {
    let action: SnapAction
    var size: CGFloat = 26

    /// The fraction the glyph illustrates. Cycle verbs show their first ring
    /// position (the half), `center` shows a centred block.
    private var fraction: FractionRect {
        if let f = action.fraction { return f }
        if let ring = Cycles.ring(for: action) { return ring[0] }
        // center
        return FractionRect(0.28, 0.28, 0.44, 0.44)
    }

    var body: some View {
        let w = size * 1.45
        let h = size
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .stroke(Theme.gridLineBold, lineWidth: 1)
                .background(RoundedRectangle(cornerRadius: 3).fill(Theme.paperSunken))
            GeometryReader { geo in
                let f = fraction
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Theme.accent.opacity(0.92))
                    .frame(width: max(3, geo.size.width * f.w - 2),
                           height: max(3, geo.size.height * f.h - 2))
                    .position(x: geo.size.width * (f.x + f.w / 2),
                              y: geo.size.height * (f.y + f.h / 2))
            }
            .padding(2)
        }
        .frame(width: w, height: h)
    }
}
