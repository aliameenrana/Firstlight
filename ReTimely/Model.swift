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
