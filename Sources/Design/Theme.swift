import SwiftUI

/// L'Équerre's visual identity: a draughtsman's blueprint. Indigo graph-paper
/// grid lines on near-black paper, precise mono-ish type, a single luminous
/// accent. Everything reads like a set of architectural drawings — which is
/// exactly what a window manager is: plans for where the windows go.
enum Theme {
    /// Deep blueprint paper.
    static let paper       = Color(red: 0.071, green: 0.086, blue: 0.137)   // #121623
    static let paperRaised = Color(red: 0.102, green: 0.122, blue: 0.184)   // #1A1F2F
    static let paperSunken = Color(red: 0.055, green: 0.067, blue: 0.110)   // #0E111C

    /// Indigo grid ink, in two weights.
    static let gridLine    = Color(red: 0.290, green: 0.345, blue: 0.560).opacity(0.22)
    static let gridLineBold = Color(red: 0.345, green: 0.412, blue: 0.660).opacity(0.40)

    /// The luminous draughting accent — a cyan-leaning indigo, like a backlit
    /// set square.
    static let accent      = Color(red: 0.435, green: 0.706, blue: 1.0)      // #6FB4FF
    static let accentDim   = Color(red: 0.435, green: 0.706, blue: 1.0).opacity(0.65)

    /// A warm secondary used for saved layouts, so they read apart from the
    /// cool grid actions.
    static let brass       = Color(red: 0.918, green: 0.745, blue: 0.482)    // #EABE7B

    static let ink         = Color(red: 0.882, green: 0.910, blue: 0.973)    // #E1E8F8
    static let inkDim      = Color(red: 0.580, green: 0.635, blue: 0.760)    // #94A2C2
    static let inkFaint    = Color(red: 0.400, green: 0.451, blue: 0.580)    // #667394

    static let danger      = Color(red: 0.953, green: 0.498, blue: 0.498)

    /// A monospaced face for the blueprint type. Falls back gracefully.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

/// A faint graph-paper grid drawn behind the popover content.
struct BlueprintGrid: View {
    var cell: CGFloat = 16
    var body: some View {
        Canvas { ctx, size in
            var minor = Path()
            var x: CGFloat = 0
            while x <= size.width { minor.move(to: CGPoint(x: x, y: 0)); minor.addLine(to: CGPoint(x: x, y: size.height)); x += cell }
            var y: CGFloat = 0
            while y <= size.height { minor.move(to: CGPoint(x: 0, y: y)); minor.addLine(to: CGPoint(x: size.width, y: y)); y += cell }
            ctx.stroke(minor, with: .color(Theme.gridLine), lineWidth: 0.5)

            var bold = Path()
            x = 0
            while x <= size.width { bold.move(to: CGPoint(x: x, y: 0)); bold.addLine(to: CGPoint(x: x, y: size.height)); x += cell * 4 }
            y = 0
            while y <= size.height { bold.move(to: CGPoint(x: 0, y: y)); bold.addLine(to: CGPoint(x: size.width, y: y)); y += cell * 4 }
            ctx.stroke(bold, with: .color(Theme.gridLineBold), lineWidth: 0.6)
        }
        .allowsHitTesting(false)
    }
}
