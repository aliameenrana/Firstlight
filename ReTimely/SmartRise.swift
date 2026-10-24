import AVFoundation

// Mirrors Timely 1.3: the alarm's own sound fades from silence to a fixed level, then holds until the alarm.
// iOS cannot start audio from a suspended app, so the sound loops at zero volume from the moment the app is
// backgrounded; that keeps the process alive until the window opens.
@MainActor
final class SmartRise {
    static let shared = SmartRise()
    static let lead: TimeInterval = 30 * 60
    static let level = 0.25
    static let riseSeconds = 75.0

    private var plans: [Plan] = []
    private var target: (fire: Date, sound: String)?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var rising = false

    // Timely mapped a 0...1 level to gain with (10^x - 1) / 9 and divided out the stream volume
    // so the result sounds the same at any system volume.
    static func gain(level: Double) -> Float {
        var g = (pow(10, level) - 1) / 9
        let v = Double(AVAudioSession.sharedInstance().outputVolume)
        if v > 0 && v < 1 { g /= (pow(10, v) - 1) / 9 }
        return Float(min(1, max(0, g)))
    }

    func arm(_ plans: [Plan]) {
        self.plans = plans
        stop()
        target = plans.filter(\.active)
            .compactMap { p in p.nextFire().map { (fire: $0, sound: p.sound) } }
            .min { $0.fire < $1.fire }
        guard let target, let url = Bundle.main.url(forResource: target.sound, withExtension: "caf") else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, options: [.mixWithOthers])
        try? session.setActive(true)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.numberOfLoops = -1
        player?.volume = 0
        player?.play()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func tick() {
        guard let target, let player else { return }
        let lead = Self.lead
        let left = target.fire.timeIntervalSinceNow
        guard left <= lead else { return }
        if !rising {
            rising = true
            player.currentTime = 0
        }
        if left <= 0 {
            timer?.invalidate()
            player.setVolume(0, fadeDuration: 3)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                guard let self else { return }
                self.arm(self.plans)
            }
            return
        }
        let level = min(Self.level, (lead - left) / Self.riseSeconds * Self.level)
        player.volume = Self.gain(level: level)
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        rising = false
    }
}

@MainActor
enum Preview {
    private static var player: AVAudioPlayer?

    static func play(_ name: String, volume: Float = 0.5) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = volume
        player?.play()
    }

    static func stop() { player?.stop() }
}
