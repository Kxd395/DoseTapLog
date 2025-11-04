import SwiftUI
import SwiftData

@main
struct DoseTrackApp: App {
    var body: some Scene {
        WindowGroup {
            ThreeCardPlanningView()
        }
        .modelContainer(for: [DoseLog.self])
    }
}
