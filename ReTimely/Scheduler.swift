import AlarmKit
import SwiftUI

struct AlarmMeta: AlarmMetadata {}

enum Scheduler {
    private static let weekdays: [Locale.Weekday] = [.sunday, .monday, .tuesday, .wednesday, .thursday, .friday, .saturday]

    static func sync(_ alarms: [WakeAlarm]) async {
        let manager = AlarmManager.shared
        if manager.authorizationState == .notDetermined { _ = try? await manager.requestAuthorization() }
        for existing in (try? manager.alarms) ?? [] { try? manager.cancel(id: existing.id) }
        for a in alarms where a.enabled {
            let time = Alarm.Schedule.Relative.Time(hour: a.hour, minute: a.minute)
            let repeats: Alarm.Schedule.Relative.Recurrence = a.days.isEmpty ? .never : .weekly(a.days.map { weekdays[$0 - 1] })
            let alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: a.label.isEmpty ? "ReTimely" : a.label),
                stopButton: AlarmButton(text: "Stop", textColor: .white, systemImageName: "stop.fill"),
                secondaryButton: AlarmButton(text: "Open", textColor: .white, systemImageName: "sun.max"),
                secondaryButtonBehavior: .custom)
            let attributes = AlarmAttributes<AlarmMeta>(presentation: AlarmPresentation(alert: alert), tintColor: .cyan)
            let config = AlarmManager.AlarmConfiguration<AlarmMeta>(
                schedule: .relative(.init(time: time, repeats: repeats)),
                attributes: attributes,
                secondaryIntent: OpenRingingIntent(alarmID: a.id, sound: a.sound),
                sound: .named("\(a.sound).caf"))
            _ = try? await manager.schedule(id: a.id, configuration: config)
        }
    }
}
