import SwiftUI
import SwiftData

@main
struct DoseTrackApp: App {
    init() {
        // Request notification permission on app launch
        Task {
            await NotificationHelper.shared.requestPermission()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ThreeCardPlanningView()
        }
        .modelContainer(for: [DoseLog.self])
    }
}
