import SwiftUI

enum Theme: String, CaseIterable {
    case auto, amber, ocean, teal, magenta, forest, violet, custom

    static let key = "theme"
    static let customKey = "customColors"
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

    func colors(at date: Date, custom: String) -> [Color] {
        rgb(at: date, custom: custom).map { Color(red: $0.x, green: $0.y, blue: $0.z) }
    }

    static func parse(_ s: String) -> [Palette.RGB] {
        let parts = s.split(separator: ";").map { $0.split(separator: ",").compactMap { Double($0) } }
        guard parts.count == 3, parts.allSatisfy({ $0.count == 3 }) else { return parse(defaultCustom) }
        return parts.map { Palette.RGB($0[0], $0[1], $0[2]) }
    }
}

struct ThemeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Theme.key) private var theme = Theme.auto
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
            SmartRiseSettings()
        }
        .padding(.vertical, 24)
        }
        .foregroundStyle(.white)
        .presentationDetents([.large])
        .presentationBackground(.black.opacity(0.55))
    }

    private func swatch(_ t: Theme) -> some View {
        let c = t.colors(at: .now, custom: custom)
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
    static let compensate = "smartRiseCompensate"
    static let sound = "smartRiseSound"

    // Defaults are Timely 1.3's own constants.
    static func register() {
        UserDefaults.standard.register(defaults: [lead: 30.0, level: 0.25, rise: 75.0, compensate: true, sound: "Smartnight5"])
    }
}

struct SmartRiseSettings: View {
    @AppStorage(SmartRiseKey.lead) private var lead = 30.0
    @AppStorage(SmartRiseKey.level) private var level = 0.25
    @AppStorage(SmartRiseKey.rise) private var rise = 75.0
    @AppStorage(SmartRiseKey.compensate) private var compensate = true
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
            Toggle("Same loudness at any volume", isOn: $compensate)
            HStack {
                Picker("Sound", selection: $sound) {
                    ForEach(Sounds.all, id: \.self) { Text(Sounds.title($0)) }
                }
                Spacer()
                Button("Play at this level") { Preview.play(sound, volume: SmartRise.gain(level: level, compensate: compensate)) }
            }
            Button("Restore Timely's values") {
                for key in [SmartRiseKey.lead, SmartRiseKey.level, SmartRiseKey.rise, SmartRiseKey.compensate, SmartRiseKey.sound] {
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
