import AVFoundation
import MediaPlayer
import UserNotifications
import UIKit

// Mirrors Timely 1.3's curve: one Smart Rise sound, chosen in settings, fades from silence to a fixed level, then holds until the alarm.
// iOS cannot start audio from a suspended app, so the sound loops at zero volume from the moment the app is
// backgrounded; that keeps the process alive until the window opens. A force-quit kills the process and ends this.
@MainActor
final class SmartRise {
    static let shared = SmartRise()

    private var plans: [Plan] = []
    private var target: Date?
    private var player: AVAudioPlayer?
    private var timer: Timer?
    private var rising = false
    private var sessionReady = false
    // Bumped on every arm so a late session callback cannot start a stale player.
    private var generation = 0
    private var armedKey: String?
    private(set) var muted = false
    private var stoppedFor: Date?

    private init() {
        // A call or Siri stops the player; resume once the interruption ends so Smart Rise is not silently lost.
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            DispatchQueue.global(qos: .userInitiated).async {
                try? AVAudioSession.sharedInstance().setActive(true)
                DispatchQueue.main.async { MainActor.assumeIsolated { _ = SmartRise.shared.player?.play() } }
            }
        }
        // The lock screen player shows only play/pause, which mutes. Stopping is done from the notification.
        let commands = MPRemoteCommandCenter.shared()
        for command in [commands.togglePlayPauseCommand, commands.playCommand, commands.pauseCommand] {
            command.addTarget { _ in MainActor.assumeIsolated { SmartRise.shared.toggleMute() }; return .success }
        }
        commands.nextTrackCommand.isEnabled = false
        commands.previousTrackCommand.isEnabled = false
        commands.changePlaybackPositionCommand.isEnabled = false
    }

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
        let next = plans.filter(\.active).compactMap { $0.nextFire() }.min()
        let sound = UserDefaults.standard.string(forKey: SmartRiseKey.sound) ?? "Smartnight5"
        let key = next.map { "\($0.timeIntervalSince1970)|\(sound)" }
        // Arm runs on every app switch; restarting an unchanged, playing session would only cost work and reset the fade.
        if key != nil, key == armedKey, player?.isPlaying == true || stoppedFor == next { return }
        armedKey = key
        stop()
        target = next
        guard let next, stoppedFor != next, let url = Bundle.main.url(forResource: sound, withExtension: "caf") else { return }
        generation += 1
        let current = generation
        withSession(mixing: true) { [weak self] in
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

    func toggleMute() {
        guard rising else { return }
        muted.toggle()
        if muted { player?.volume = 0 }
        showPlaying()
    }

    func stopTonight() {
        stoppedFor = target
        stop()
    }

    // setActive can block for tens of milliseconds, so it runs off the main thread. While waiting silently the
    // session mixes with other audio; once audible it takes over so the lock screen shows it as now playing.
    private func withSession(mixing: Bool, _ body: @escaping @MainActor () -> Void) {
        if sessionReady && mixing { body(); return }
        DispatchQueue.global(qos: .userInitiated).async {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, options: mixing ? [.mixWithOthers] : [])
            try? session.setActive(true)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    SmartRise.shared.sessionReady = mixing
                    body()
                }
            }
        }
    }

    private func tick() {
        guard let target, let player else { return }
        let s = UserDefaults.standard
        let lead = s.double(forKey: SmartRiseKey.lead) * 60
        let left = target.timeIntervalSinceNow
        guard left <= lead else { return }
        if !rising {
            rising = true
            muted = false
            player.currentTime = 0
            withSession(mixing: false) { SmartRise.shared.showPlaying() }
        }
        if left <= 0 {
            timer?.invalidate()
            player.setVolume(0, fadeDuration: 3)
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { [weak self] in
                guard let self else { return }
                self.armedKey = nil
                self.arm(self.plans)
            }
            return
        }
        guard !muted else { return }
        let peak = s.double(forKey: SmartRiseKey.level)
        let level = min(peak, (lead - left) / max(1, s.double(forKey: SmartRiseKey.rise)) * peak)
        player.volume = Self.gain(level: level)
    }

    private func showPlaying() {
        guard let target else { return }
        let time = target.formatted(date: .omitted, time: .shortened)
        // The progress bar spans the Smart Rise window, so its remaining time counts down to the alarm.
        // The rate stays 1 while muted so the countdown keeps moving; the title shows the mute state.
        let lead = UserDefaults.standard.double(forKey: SmartRiseKey.lead) * 60
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: muted ? "Smart Rise · muted" : "Smart Rise",
            MPMediaItemPropertyArtist: "Alarm at \(time)",
            MPMediaItemPropertyPlaybackDuration: lead,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(0, lead - target.timeIntervalSinceNow),
            MPNowPlayingInfoPropertyPlaybackRate: 1.0,
        ]
        if let art = UIImage(named: "Artwork") {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: art.size) { _ in art }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        let content = UNMutableNotificationContent()
        content.title = muted ? "Smart Rise is muted" : "Smart Rise is playing"
        content.body = "Alarm at \(time)"
        content.categoryIdentifier = muted ? SmartRiseNotice.mutedCategory : SmartRiseNotice.category
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: SmartRiseNotice.id, content: content, trigger: nil))
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        if rising {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [SmartRiseNotice.id])
        }
        rising = false
    }
}

final class SmartRiseNotice: NSObject, UNUserNotificationCenterDelegate {
    static let shared = SmartRiseNotice()
    static let id = "smartRise"
    static let category = "smartRise"
    static let mutedCategory = "smartRiseMuted"

    func register() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let stop = UNNotificationAction(identifier: "stop", title: "Stop", options: [.destructive])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: Self.category, actions: [UNNotificationAction(identifier: "mute", title: "Mute"), stop], intentIdentifiers: []),
            UNNotificationCategory(identifier: Self.mutedCategory, actions: [UNNotificationAction(identifier: "unmute", title: "Unmute"), stop], intentIdentifiers: []),
        ])
        center.requestAuthorization(options: [.alert]) { _, _ in }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let action = response.actionIdentifier
        await MainActor.run {
            switch action {
            case "mute", "unmute": SmartRise.shared.toggleMute()
            case "stop": SmartRise.shared.stopTonight()
            default: break
            }
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list]
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
