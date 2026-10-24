import AVFoundation

// iOS cannot start audio from a suspended app, so the melody loops at zero volume from the
// moment the app is backgrounded; that keeps the process alive until the 30-minute window opens.
@MainActor
final class SmartRise {
    static let shared = SmartRise()
    static let lead: TimeInterval = 30 * 60
    // Fractions of the system media volume; the melody should stay at the edge of hearing.
    static let floor: Float = 0.003
    static let peak: Float = 0.08

    private var plans: [Plan] = []
    private var target: (fire: Date, track: String)?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var rising = false

    func arm(_ plans: [Plan]) {
        self.plans = plans
        stop()
        target = plans.filter(\.active)
            .compactMap { p in p.nextFire().map { (fire: $0, track: p.track) } }
            .min { $0.fire < $1.fire }
        guard let target, let url = Bundle.main.url(forResource: target.track, withExtension: "caf") else { return }
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
        let left = target.fire.timeIntervalSinceNow
        guard left <= Self.lead else { return }
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
        let progress = Float(1 - left / Self.lead)
        player.volume = Self.floor + (Self.peak - Self.floor) * progress * progress
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

    static func play(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "caf") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = name.hasPrefix("Smart") ? SmartRise.peak : 0.5
        player?.play()
    }

    static func stop() { player?.stop() }
}
