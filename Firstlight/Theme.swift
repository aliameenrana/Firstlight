import SwiftUI
import simd

enum Theme: String, CaseIterable {
    case ocean, amber, auto, teal, magenta, forest, violet, custom

    static let key = "theme"
    static let customKey = "customColors"
    static let lavaKey = "lavaLamp"
    static let cycleKey = "hueCycle"
    static let cycleMinutesKey = "hueCycleMinutes"
    static let defaultCustom = "1,0.66,0.08;1,0.88,0.4;0.6,0.06,0.05"

    private var preset: [Palette.RGB]? {
        switch self {
        case .amber: Palette.day
        case .ocean: [[0.04, 0.45, 0.85], [0.20, 0.75, 1.00], [0.25, 0.30, 0.95], [0.02, 0.06, 0.35]]
        case .teal: [[0.10, 0.75, 0.70], [0.35, 0.95, 0.85], [0.05, 0.50, 0.60], [0.02, 0.25, 0.35]]
        case .magenta: [[0.85, 0.10, 0.55], [1.00, 0.35, 0.75], [0.55, 0.10, 0.75], [0.30, 0.03, 0.30]]
        case .forest: [[0.20, 0.65, 0.15], [0.55, 0.90, 0.35], [0.10, 0.45, 0.25], [0.03, 0.20, 0.06]]
        case .violet: Palette.dusk
        case .auto, .custom: nil
        }
    }

    func rgb(at date: Date, custom: String) -> [Palette.RGB] {
        if let preset { return preset }
        if self == .auto { return Palette.at(date) }
        let c = Self.parse(custom)
        return [c[0], c[1], (c[1] + c[2]) / 2, c[2]]
    }

    // Two neighbours of the glow colours and a split complement: lively against the gradient without clashing.
    static func waxColors(_ p: [Palette.RGB]) -> [Color] {
        [HueCycle.rotate(p[1], by: 0.7), HueCycle.rotate(p[2], by: -0.7), HueCycle.rotate(p[1], by: 2.6)]
            .map(Palette.color)
    }

    func palette(at date: Date, custom: String, cycleMinutes: Double? = nil) -> [Palette.RGB] {
        var c = rgb(at: date, custom: custom)
        if let cycleMinutes {
            // Phase comes from the wall clock, so the hue is continuous across launches instead of snapping back.
            let turn = date.timeIntervalSinceReferenceDate / (cycleMinutes * 60)
            c = c.map { HueCycle.rotate($0, by: (turn - turn.rounded(.down)) * 2 * .pi) }
        }
        return c
    }

    static func parse(_ s: String) -> [Palette.RGB] {
        let parts = s.split(separator: ";").map { $0.split(separator: ",").compactMap { Double($0) } }
        guard parts.count == 3, parts.allSatisfy({ $0.count == 3 }) else { return parse(defaultCustom) }
        return parts.map { Palette.RGB($0[0], $0[1], $0[2]) }
    }
}

struct ThemeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Theme.key) private var theme = Theme.ocean
    @AppStorage(Theme.customKey) private var custom = Theme.defaultCustom

    var body: some View {
        ScrollView {
        VStack(spacing: 22) {
            HStack {
                Text("Settings").font(.title2.weight(.light))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 36, height: 36)
                }
                .frost(.circle)
            }
            .padding(.horizontal, 20)
            Text("Theme").font(.title3.weight(.light)).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Theme.allCases.filter { $0 != .custom }, id: \.self) { swatch($0) }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 4)
            }
            Text("Custom").font(.caption).opacity(0.7)
            HStack(spacing: 34) {
                colorDot("Top", 0)
                colorDot("Glow", 1)
                colorDot("Bottom", 2)
            }
            CycleSettings()
            SmartRiseSettings()
        }
        .padding(.vertical, 24)
        }
        .foregroundStyle(.white)
        .presentationDetents([.large])
        .presentationBackground(.black.opacity(0.55))
    }

    private func swatch(_ t: Theme) -> some View {
        let c = t.palette(at: .now, custom: custom).map(Palette.color)
        return Circle()
            .fill(LinearGradient(colors: [c[0], c[1], c[3]], startPoint: .top, endPoint: .bottom))
            .frame(width: 56, height: 56)
            .overlay { if t == .auto { Image(systemName: "clock").font(.footnote) } }
            .overlay(Circle().stroke(.white, lineWidth: theme == t ? 2.5 : 0.5).padding(-4))
            .onTapGesture { theme = t }
    }

    private func colorDot(_ title: String, _ index: Int) -> some View {
        let binding = Binding<Color>(
            get: {
                let c = Theme.parse(custom)[index]
                return Color(red: c.x, green: c.y, blue: c.z)
            },
            set: { color in
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
                var parts = Theme.parse(custom)
                parts[index] = Palette.RGB(Double(r), Double(g), Double(b))
                custom = parts.map { "\($0.x),\($0.y),\($0.z)" }.joined(separator: ";")
                theme = .custom
            })
        return VStack(spacing: 8) {
            ColorPicker(title, selection: binding, supportsOpacity: false)
                .labelsHidden()
                .scaleEffect(1.6)
                .frame(width: 48, height: 48)
            Text(title).font(.caption2).opacity(0.7)
        }
    }
}

// Faked frosted glass: a translucent fill and a lit edge, no backdrop blur, so it costs almost nothing to draw.
struct Frost<S: Shape>: ViewModifier {
    let shape: S

    func body(content: Content) -> some View {
        content
            .background(shape.fill(LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(shape.stroke(LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
    }
}

extension View {
    func frost<S: Shape>(_ shape: S, interactive: Bool = false) -> some View {
        modifier(Frost(shape: shape))
    }
}

@MainActor @Observable
final class Touch {
    static let shared = Touch()
    var pop: (point: CGPoint, time: Date)?
}

enum SmartRiseKey {
    static let lead = "smartRiseLead"
    static let level = "smartRiseLevel"
    static let rise = "smartRiseSeconds"
    static let sound = "smartRiseSound"

    // Defaults are Timely 1.3's own constants.
    static func register() {
        UserDefaults.standard.register(defaults: [lead: 30.0, level: 0.25, rise: 75.0, sound: "Smartnight5"])
    }
}

struct SmartRiseSettings: View {
    @AppStorage(SmartRiseKey.lead) private var lead = 30.0
    @AppStorage(SmartRiseKey.level) private var level = 0.25
    @AppStorage(SmartRiseKey.rise) private var rise = 75.0
    @AppStorage(SmartRiseKey.sound) private var sound = "Smartnight5"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Smart Rise").font(.title3.weight(.light))
            Stepper("Starts \(Int(lead)) min before", value: $lead, in: 5...60, step: 5)
            VStack(alignment: .leading) {
                let g = (pow(10, level) - 1) / 9
                Text("Level \(level, format: .number.precision(.fractionLength(2))) · \(g * 100, format: .number.precision(.fractionLength(1)))% · \(20 * log10(g), format: .number.precision(.fractionLength(0))) dB")
                Slider(value: $level, in: 0.05...0.6)
            }
            Stepper("Fades in over \(Int(rise)) s", value: $rise, in: 15...900, step: 15)
            HStack {
                Picker("Sound", selection: $sound) {
                    ForEach(Sounds.all, id: \.self) { Text(Sounds.title($0)) }
                }
                Spacer()
                Button("Play at this level") { Preview.play(sound, volume: SmartRise.gain(level: level)) }
            }
            Button("Restore Timely's values") {
                for key in [SmartRiseKey.lead, SmartRiseKey.level, SmartRiseKey.rise, SmartRiseKey.sound] {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
            .font(.footnote)
        }
        .tint(.white)
        .padding(20)
        .frost(.rect(cornerRadius: 26))
        .padding(.horizontal, 16)
        .onDisappear { Preview.stop() }
    }
}

// Rotating hue in OKLab keeps perceived lightness fixed, so the cycle never passes through a sudden bright
// yellow or a dark muddy band the way an HSV rotation does, and the four colours keep their relative contrast.
enum HueCycle {
    static func rotate(_ c: Palette.RGB, by angle: Double) -> Palette.RGB {
        let lab = oklab(c)
        let (s, k) = (sin(angle), cos(angle))
        var a = lab.y * k - lab.z * s, b = lab.y * s + lab.z * k
        // Rotated colours can leave sRGB; pulling chroma in keeps hue and lightness instead of clipping a channel.
        for _ in 0..<8 {
            let out = rgb(.init(lab.x, a, b))
            if out.min() >= -0.001 && out.max() <= 1.001 { return simd_clamp(out, .zero, .one) }
            a *= 0.85; b *= 0.85
        }
        return simd_clamp(rgb(.init(lab.x, a, b)), .zero, .one)
    }

    private static func lin(_ v: Double) -> Double { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    private static func gam(_ v: Double) -> Double { v <= 0.0031308 ? v * 12.92 : 1.055 * pow(max(v, 0), 1 / 2.4) - 0.055 }

    private static func oklab(_ c: Palette.RGB) -> Palette.RGB {
        let r = lin(c.x), g = lin(c.y), b = lin(c.z)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return .init(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }

    private static func rgb(_ c: Palette.RGB) -> Palette.RGB {
        let l = pow(c.x + 0.3963377774 * c.y + 0.2158037573 * c.z, 3)
        let m = pow(c.x - 0.1055613458 * c.y - 0.0638541728 * c.z, 3)
        let s = pow(c.x - 0.0894841775 * c.y - 1.2914855480 * c.z, 3)
        return .init(gam(4.0767416621 * l - 3.3077085913 * m + 0.2309300596 * s),
                     gam(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
                     gam(-0.0041960771 * l - 0.7034195420 * m + 1.7076147010 * s))
    }
}

struct CycleSettings: View {
    @AppStorage(Theme.cycleKey) private var on = false
    @AppStorage(Theme.cycleMinutesKey) private var minutes = 10.0
    @AppStorage(Theme.lavaKey) private var lava = false

    var body: some View {
        VStack(spacing: 10) {
            Picker("Floating", selection: $lava) {
                Text("Bubbles").tag(false)
                Text("Lava lamp").tag(true)
            }
            .pickerStyle(.segmented)
            Toggle("Cycle colours", isOn: $on.animation())
            if on {
                Picker("Full cycle", selection: $minutes) {
                    Text("1 min").tag(1.0)
                    Text("10 min").tag(10.0)
                    Text("1 hour").tag(60.0)
                    Text("1 day").tag(1440.0)
                }
                .pickerStyle(.segmented)
                Text("The whole theme turns around the colour wheel, keeping its brightness.")
                    .font(.caption).opacity(0.6).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .frost(.rect(cornerRadius: 26))
        .padding(.horizontal, 20)
    }
}
