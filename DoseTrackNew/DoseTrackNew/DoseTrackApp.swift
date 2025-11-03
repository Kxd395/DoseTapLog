import SwiftUI
import SwiftData

@main
struct DoseTrackApp: App {
    var body: some Scene {
        WindowGroup {
            TodayLogView()
        }
        .modelContainer(for: [DoseLog.self])
    }
}
