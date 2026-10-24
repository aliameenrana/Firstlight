import Foundation
import SwiftData

@Model
final class WakeAlarm {
    var id = UUID()
    var hour = 7
    var minute = 0
    var days: [Int] = []
    var label = ""
    var sound = "Past Time"
    var smartRise = false
    var enabled = true
    // When a one-time alarm is due. AlarmKit forgets it after it rings, so the app disables it once this passes.
    var onceFireDate: Date?

    init() {}

    var plan: Plan { Plan(hour: hour, minute: minute, days: days, sound: sound, active: enabled && smartRise) }
}

struct Plan {
    let hour: Int, minute: Int, days: [Int], sound: String, active: Bool

    func nextFire(after now: Date = .now) -> Date? {
        let cal = Calendar.current
        let weekdays: [Int?] = days.isEmpty ? [nil] : days
        return weekdays.compactMap {
            cal.nextDate(after: now, matching: DateComponents(hour: hour, minute: minute, weekday: $0), matchingPolicy: .nextTime)
        }.min()
    }
}

enum Sounds {
    static let all: [String] = (Bundle.main.urls(forResourcesWithExtension: "caf", subdirectory: nil) ?? [])
        .map { $0.deletingPathExtension().lastPathComponent }.sorted()
    // Display names, keyed by the SoundCloud upload's file name.
    private static let names = [
        "dong": "Lanternbell", "summerday": "Midsummer", "live": "Kindling", "angels_harp": "Halo", "wecksong_1": "Daybreak",
        "still_dreamin": "Halflight", "past_time": "Firstlight", "hurry": "Sunburst", "wake_me_soft": "Softwake", "get_up": "Morning Star",
        "good_morning": "Golden Hour", "glockenspiel_6": "Glimmer", "vib_7": "Starling", "xylo_3": "Dewdrop", "la_gitar": "Ember",
        "sunrise1": "Sunward", "awakening": "Skyglow", "keep_it_simple": "Clear Sky", "dream_is_over": "Moonset", "to_late": "Rushlight",
        "belling": "Matins", "smart1": "Riselight", "smart2": "Paleglow", "smart3": "Driftlight", "smartnature": "Northglow",
        "smartnight5": "Nightfade", "smartwater2": "Tidelight",
    ]

    static func title(_ file: String) -> String {
        names[file.lowercased().replacingOccurrences(of: " ", with: "_")] ?? file
    }
}

extension WakeAlarm {
    var minutes: Int { hour * 60 + minute }

    func setMinutes(_ m: Int) {
        hour = m / 60
        minute = m % 60
        onceFireDate = nil
    }

    var summary: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let days = days.isEmpty ? "Once" : days.sorted().map { symbols[$0 - 1] }.joined(separator: " ")
        return [label, days, smartRise ? "Smart Rise" : ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

func clockString(_ m: Int) -> String { String(format: "%02d:%02d", m / 60, m % 60) }
