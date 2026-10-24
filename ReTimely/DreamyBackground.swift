import SwiftUI

struct DreamyBackground: View {
    private static let start = Date()
    @AppStorage(Settings.bubbleOpacity) private var bubbleOpacity = 0.8
    @AppStorage(Settings.aurora) private var aurora = 1.0
    @AppStorage(Settings.gooey) private var gooey = false
    private let touch = Touch.shared

    var body: some View {
        // The motion is slow; 30 fps is indistinguishable from 120 and quarters the GPU work on ProMotion.
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            let t = Float(context.date.timeIntervalSince(Self.start))
            let p = Palette.at(context.date)
            GeometryReader { geo in
                Rectangle()
                    .colorEffect(ShaderLibrary.dreamy(
                        .float2(geo.size), .float(t),
                        .color(p[0]), .color(p[1]), .color(p[2]), .color(p[3]),
                        .float4(Float(touch.point.x / geo.size.width), Float(touch.point.y / geo.size.height), touch.active ? 1 : 0, 0),
                        .float4(Float((touch.pop?.point.x ?? 0) / geo.size.width), Float((touch.pop?.point.y ?? 0) / geo.size.height),
                                touch.pop.map { Float($0.time.timeIntervalSince(Self.start)) } ?? -100, 0),
                        .float(Float(bubbleOpacity)), .float(Float(aurora)), .float(gooey ? 1 : 0)))
            }
        }
        .ignoresSafeArea()
    }
}

// Colors drift with the time of day: deep blue night, rose dawn, amber day, violet dusk.
enum Palette {
    typealias RGB = SIMD3<Double>
    private static let night: [RGB] = [[0.02, 0.30, 0.50], [0.10, 0.80, 0.80], [0.40, 0.30, 0.90], [0.01, 0.04, 0.22]]
    private static let dawn: [RGB] = [[0.98, 0.70, 0.36], [1.00, 0.86, 0.55], [0.92, 0.40, 0.56], [0.45, 0.12, 0.36]]
    private static let day: [RGB] = [[1.00, 0.66, 0.08], [1.00, 0.88, 0.40], [0.98, 0.32, 0.18], [0.60, 0.06, 0.05]]
    private static let dusk: [RGB] = [[0.62, 0.22, 0.70], [1.00, 0.48, 0.52], [0.25, 0.32, 0.88], [0.08, 0.04, 0.28]]
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
