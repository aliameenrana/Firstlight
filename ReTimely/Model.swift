import Foundation
import SwiftData

@Model
final class WakeAlarm {
    var id = UUID()
    var hour = 7
    var minute = 0
    var days: [Int] = []
    var label = ""
    var sound = "Good Morning"
    var smartRise = false
    var enabled = true

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
    // Timely's own names, from its ringtone registry, keyed by the SoundCloud upload's file name.
    private static let names = [
        "dong": "Primus", "summerday": "Summer day", "live": "Live", "angels_harp": "Angels Harp", "wecksong_1": "Lyra",
        "still_dreamin": "Carina", "past_time": "Past time", "hurry": "Hurry", "wake_me_soft": "Atlas", "get_up": "Virgo",
        "good_morning": "Lanx", "glockenspiel_6": "Atria", "vib_7": "Vega", "xylo_3": "Lux", "la_gitar": "Dalia",
        "sunrise1": "Sunrise", "awakening": "Awakening", "keep_it_simple": "Avior", "dream_is_over": "Sky", "to_late": "Spica",
        "belling": "Church", "smart1": "Crescendo", "smart2": "Happy", "smart3": "Playful", "smartnature": "Tribal",
        "smartnight5": "Gentle Night", "smartwater2": "Deep Ocean",
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
    }

    var summary: String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let days = days.isEmpty ? "Once" : days.sorted().map { symbols[$0 - 1] }.joined(separator: " ")
        return [label, days, smartRise ? "Smart Rise" : ""].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

func clockString(_ m: Int) -> String { String(format: "%02d:%02d", m / 60, m % 60) }
