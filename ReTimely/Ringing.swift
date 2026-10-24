import AppIntents
import AVFoundation
import SwiftUI

@MainActor @Observable
final class Ringing {
    static let shared = Ringing()
    var alarmID: UUID?
    private var player: AVAudioPlayer?

    func start(_ id: UUID, sound: String) {
        alarmID = id
        guard let url = Bundle.main.url(forResource: sound, withExtension: "caf") else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
        withAnimation(.easeOut(duration: 0.5)) { alarmID = nil }
    }
}

// Runs in the app process when "Open" is tapped on the system alarm alert.
struct OpenRingingIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Open ReTimely"
    static let openAppWhenRun = true

    @Parameter(title: "Alarm") var alarmID: String
    @Parameter(title: "Sound") var sound: String

    init() {}
    init(alarmID: UUID, sound: String) {
        self.alarmID = alarmID.uuidString
        self.sound = sound
    }

    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: alarmID) else { return .result() }
        await Ringing.shared.start(id, sound: sound)
        return .result()
    }
}

struct RingingScreen: View {
    let label: String
    @State private var pulse = false

    var body: some View {
        ZStack {
            DreamyBackground(palette: Palette.ocean)
            VStack(spacing: 10) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(context.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                        .font(.system(size: 96, weight: .ultraLight))
                        .monospacedDigit()
                }
                if !label.isEmpty { Text(label).font(.title3.weight(.light)).opacity(0.85) }
                Spacer()
                Button { Ringing.shared.stop() } label: {
                    Text("STOP")
                        .font(.system(size: 26, weight: .medium))
                        .tracking(2)
                        .frame(width: 190, height: 190)
                        .background(Circle().fill(.white.opacity(0.12)))
                        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1).padding(-18).scaleEffect(pulse ? 1.12 : 1).opacity(pulse ? 0 : 1))
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1).padding(-18))
                }
                .glassEffect(.clear.interactive(), in: .circle)
                Spacer()
            }
            .padding(.top, 80)
            .foregroundStyle(.white)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}
