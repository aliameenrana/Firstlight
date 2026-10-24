import SwiftUI

enum Settings {
    static let leadMinutes = "smartRiseLead"
    static let level = "smartRiseLevel"
    static let riseSeconds = "smartRiseSeconds"
    static let compensate = "smartRiseCompensate"
    static let glass = "glassStyle"
    static let bubbleOpacity = "bubbleOpacity"
    static let aurora = "aurora"
    static let gooey = "gooey"
    static let pop = "popBubbles"
    static let flee = "fleeBubbles"

    // Smart Rise defaults are Timely 1.3's own constants.
    static func register() {
        UserDefaults.standard.register(defaults: [
            leadMinutes: 30.0, level: 0.25, riseSeconds: 75.0, compensate: true,
            glass: GlassStyle.fake.rawValue, bubbleOpacity: 0.8, aurora: 1.0,
            gooey: false, pop: true, flee: true,
        ])
    }
}

enum GlassStyle: String, CaseIterable {
    case fake = "Frosted (fastest)"
    case material = "Blurred material"
    case liquid = "Liquid Glass"
}

struct Frost<S: Shape>: ViewModifier {
    @AppStorage(Settings.glass) private var style = GlassStyle.fake
    let shape: S
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        let edge = LinearGradient(colors: [.white.opacity(0.5), .white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        switch style {
        case .liquid:
            content.glassEffect(interactive ? .clear.interactive() : .clear, in: shape)
        case .material:
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(edge, lineWidth: 0.75))
        case .fake:
            content
                .background(shape.fill(LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .overlay(shape.stroke(edge, lineWidth: 1))
        }
    }
}

extension View {
    func frost<S: Shape>(_ shape: S, interactive: Bool = false) -> some View {
        modifier(Frost(shape: shape, interactive: interactive))
    }
}

@MainActor @Observable
final class Touch {
    static let shared = Touch()
    var point: CGPoint = .zero
    var active = false
    var pop: (point: CGPoint, time: Date)?
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Settings.leadMinutes) private var lead = 30.0
    @AppStorage(Settings.level) private var level = 0.25
    @AppStorage(Settings.riseSeconds) private var rise = 75.0
    @AppStorage(Settings.compensate) private var compensate = true
    @AppStorage(Settings.glass) private var glass = GlassStyle.fake
    @AppStorage(Settings.bubbleOpacity) private var bubbleOpacity = 0.8
    @AppStorage(Settings.aurora) private var aurora = 1.0
    @AppStorage(Settings.gooey) private var gooey = false
    @AppStorage(Settings.pop) private var pop = true
    @AppStorage(Settings.flee) private var flee = true
    @State private var previewSound = "Smart1"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper("Starts \(Int(lead)) min before", value: $lead, in: 5...60, step: 5)
                    VStack(alignment: .leading) {
                        let g = (pow(10, level) - 1) / 9
                        Text("Level \(level, format: .number.precision(.fractionLength(2))) · \(g * 100, format: .number.precision(.fractionLength(1)))% · \(20 * log10(g), format: .number.precision(.fractionLength(0))) dB")
                        Slider(value: $level, in: 0.05...0.6)
                    }
                    Stepper("Fades in over \(Int(rise)) s", value: $rise, in: 15...900, step: 15)
                    Toggle("Same loudness at any volume", isOn: $compensate)
                    Picker("Preview sound", selection: $previewSound) {
                        ForEach(Sounds.all, id: \.self) { Text(Sounds.title($0)) }
                    }
                    Button("Play at this level") { Preview.play(previewSound, volume: SmartRise.gain(level: level, compensate: compensate)) }
                } header: {
                    Text("Smart Rise")
                } footer: {
                    Text("Timely's values: level 0.25 (8.6% amplitude, about −21 dB), reached after 75 s and held until the alarm.")
                }
                Section("Look") {
                    Picker("Panels", selection: $glass) {
                        ForEach(GlassStyle.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    labeled("Bubble opacity", $bubbleOpacity, 0...1.5)
                    labeled("Northern lights", $aurora, 0...2)
                    Toggle("Gooey bubbles", isOn: $gooey)
                }
                Section {
                    Toggle("Pop bubbles on tap", isOn: $pop)
                    Toggle("Bubbles move away from finger", isOn: $flee)
                } header: {
                    Text("Interaction")
                }
                Section {
                    Button("Restore defaults") {
                        for key in [Settings.leadMinutes, Settings.level, Settings.riseSeconds, Settings.compensate, Settings.glass,
                                    Settings.bubbleOpacity, Settings.aurora, Settings.gooey, Settings.pop, Settings.flee] {
                            UserDefaults.standard.removeObject(forKey: key)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { Preview.stop(); dismiss() } }
        }
    }

    private func labeled(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            Text("\(title) \(Int(value.wrappedValue * 100))%")
            Slider(value: value, in: range)
        }
    }
}
