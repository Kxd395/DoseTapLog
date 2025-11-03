import SwiftUI
import SwiftData

let sharedContainer: ModelContainer = {
    let schema = Schema([DoseLog.self])
    return try! ModelContainer(for: schema)
}()

@main
struct DoseTrackApp: App {
    var body: some Scene {
        WindowGroup {
            TodayLogView()
                .modelContainer(sharedContainer)
        }
    }
}
