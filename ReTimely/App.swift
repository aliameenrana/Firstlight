import SwiftUI
import SwiftData

@main
struct ReTimelyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView().preferredColorScheme(.dark)
        }
        .modelContainer(for: WakeAlarm.self)
    }
}
