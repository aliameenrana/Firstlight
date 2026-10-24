import SwiftUI
import SwiftData

@main
struct ReTimelyApp: App {
    init() { SmartRiseKey.register() }

    var body: some Scene {
        WindowGroup {
            ContentView().preferredColorScheme(.dark)
        }
        .modelContainer(for: WakeAlarm.self)
    }
}
