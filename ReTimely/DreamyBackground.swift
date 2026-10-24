import SwiftUI

struct DreamyBackground: View {
    private static let start = Date()

    var body: some View {
        TimelineView(.animation) { context in
            let t = Float(context.date.timeIntervalSince(Self.start))
            let p = Palette.at(context.date)
            GeometryReader { geo in
                Rectangle()
                    .colorEffect(ShaderLibrary.dreamy(
                        .float2(geo.size), .float(t),
                        .color(p[0]), .color(p[1]), .color(p[2]), .color(p[3])))
            }
        }
        .ignoresSafeArea()
    }
}

// Colors drift with the time of day: deep night, golden dawn, aqua day, violet dusk.
enum Palette {
    typealias RGB = SIMD3<Double>
    private static let night: [RGB] = [[0.05, 0.07, 0.26], [0.42, 0.20, 0.72], [0.08, 0.42, 0.70], [0.01, 0.01, 0.08]]
    private static let dawn: [RGB] = [[0.98, 0.84, 0.16], [1.00, 0.55, 0.18], [0.95, 0.35, 0.45], [0.68, 0.10, 0.08]]
    private static let day: [RGB] = [[0.08, 0.86, 0.86], [0.14, 0.55, 0.96], [0.36, 0.88, 0.78], [0.04, 0.14, 0.56]]
    private static let dusk: [RGB] = [[0.58, 0.26, 0.78], [0.96, 0.42, 0.46], [0.30, 0.20, 0.72], [0.10, 0.04, 0.30]]
    private static let keys: [(Double, [RGB])] = [(0, night), (5, night), (7, dawn), (10, day), (16, day), (19, dusk), (21.5, night), (24, night)]

    static func at(_ date: Date) -> [Color] {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60
        let i = keys.lastIndex { $0.0 <= h } ?? 0
        let (h0, a) = keys[i], (h1, b) = keys[min(i + 1, keys.count - 1)]
        let f = h1 > h0 ? (h - h0) / (h1 - h0) : 0
        let s = f * f * (3 - 2 * f)
        return zip(a, b).map { x, y in
            let m = x + (y - x) * s
            return Color(red: m.x, green: m.y, blue: m.z)
        }
    }
}
