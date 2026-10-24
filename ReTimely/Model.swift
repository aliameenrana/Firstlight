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
    var smartTrack = "Smart1"
    var enabled = true

    init() {}

    var plan: Plan { Plan(hour: hour, minute: minute, days: days, track: smartTrack, active: enabled && smartRise) }
}

struct Plan {
    let hour: Int, minute: Int, days: [Int], track: String, active: Bool

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
    static var smart: [String] { all.filter { $0.hasPrefix("Smart") } }
    static var alarm: [String] { all.filter { !$0.hasPrefix("Smart") } }
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
