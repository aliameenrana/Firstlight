import AVFoundation

// Mirrors Timely 1.3's curve: one Smart Rise sound, chosen in settings, fades from silence to a fixed level, then holds until the alarm.
// iOS cannot start audio from a suspended app, so the sound loops at zero volume from the moment the app is
// backgrounded; that keeps the process alive until the window opens.
@MainActor
final class SmartRise {
    static let shared = SmartRise()

    private var plans: [Plan] = []
    private var target: (fire: Date, sound: String)?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var rising = false
    private var sessionReady = false
    // Bumped on every arm so a late session callback cannot start a stale player.
    private var generation = 0

    // Timely mapped a 0...1 level to gain with (10^x - 1) / 9 and divided out the stream volume
    // so the result sounds the same at any system volume.
    static func gain(level: Double, compensate: Bool) -> Float {
        var g = (pow(10, level) - 1) / 9
        let v = Double(AVAudioSession.sharedInstance().outputVolume)
        if compensate && v > 0 && v < 1 { g /= (pow(10, v) - 1) / 9 }
        return Float(min(1, max(0, g)))
    }

    func arm(_ plans: [Plan]) {
        self.plans = plans
        stop()
        target = plans.filter(\.active)
            .compactMap { p in p.nextFire().map { (fire: $0, sound: p.sound) } }
            .min { $0.fire < $1.fire }
        guard target != nil, let url = Bundle.main.url(forResource: UserDefaults.standard.string(forKey: SmartRiseKey.sound) ?? "Smart1", withExtension: "caf") else { return }
        generation += 1
        let current = generation
        withSession { [weak self] in
            guard let self, current == self.generation else { return }
            self.player = try? AVAudioPlayer(contentsOf: url)
            self.player?.numberOfLoops = -1
            self.player?.volume = 0
            self.player?.play()
            self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        }
    }

    // setActive can block for tens of milliseconds, so it runs once, off the main thread.
    private func withSession(_ body: @escaping @MainActor () -> Void) {
        if sessionReady { body(); return }
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, options: [.mixWithOthers])
            try? session.setActive(true)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    SmartRise.shared.sessionReady = true
                    body()
                }
            }
        }
    }

    private func tick() {
        guard let target, let player else { return }
        let s = UserDefaults.standard
        let lead = s.double(forKey: SmartRiseKey.lead) * 60
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
        let peak = s.double(forKey: SmartRiseKey.level)
        let level = min(peak, (lead - left) / max(1, s.double(forKey: SmartRiseKey.rise)) * peak)
        player.volume = Self.gain(level: level, compensate: s.bool(forKey: SmartRiseKey.compensate))
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
