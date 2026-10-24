import AlarmKit
import SwiftUI

struct AlarmMeta: AlarmMetadata {}

struct AlarmSpec: Equatable, Sendable {
    let id: UUID, hour: Int, minute: Int, days: [Int], label: String, sound: String
}

@MainActor
enum Scheduler {
    private static let weekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]
    private static var last: [AlarmSpec]?
    private static var pending: Task<Void, Never>?

    // Several syncs fire per app switch. Identical requests are skipped, and runs are chained so one run's
    // cancel-all can never delete what an overlapping run just scheduled.
    static func sync(_ alarms: [WakeAlarm]) {
        let specs = alarms.filter(\.enabled).map {
            AlarmSpec(id: $0.id, hour: $0.hour, minute: $0.minute, days: $0.days, label: $0.label, sound: $0.sound)
        }
        guard specs != last else { return }
        last = specs
        let previous = pending
        pending = Task {
            await previous?.value
            await apply(specs)
        }
    }

    private static func apply(_ specs: [AlarmSpec]) async {
        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined { _ = try? await manager.requestAuthorization() }
        for existing in (try? manager.alarms) ?? [] { try? manager.cancel(id: existing.id) }
        for a in specs {
            let time = Alarm.Schedule.Relative.Time(hour: a.hour, minute: a.minute)
            let repeats: Alarm.Schedule.Relative.Recurrence = a.days.isEmpty ? .never : .weekly(a.days.map { weekdays[$0 - 1] })
            let alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: a.label.isEmpty ? "ReTimely" : a.label),
                stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "sun.max"))
            let attributes = AlarmAttributes<AlarmMeta>(presentation: AlarmPresentation(alert: alert), tintColor: .cyan)
            let config = AlarmManager.AlarmConfiguration<AlarmMeta>(
                schedule: .relative(.init(time: time, repeats: repeats)),
                attributes: attributes,
                sound: .named("\(a.sound).caf"))
            _ = try? await manager.schedule(id: a.id, configuration: config)
        }
    }
}
