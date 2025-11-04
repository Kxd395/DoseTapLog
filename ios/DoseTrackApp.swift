import SwiftUI
import SwiftData
import BackgroundTasks

@main
struct DoseTrackApp: App {
    
    init() {
        // Register background tasks
        registerBackgroundTasks()
        
        // Request notification permission
        Task {
            await NotificationHelper.shared.requestPermission()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ThreeCardPlanningView()
        }
        .modelContainer(for: [DoseLog.self])
        .backgroundTask(.appRefresh("com.dosetrack.cutoff.rollover")) { task in
            await handleCutoffRollover(task: task as! BGAppRefreshTask)
        }
    }
    
    // MARK: - Background Task Registration
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.dosetrack.cutoff.rollover",
            using: nil
        ) { task in
            Task {
                await self.handleCutoffRollover(task: task as! BGAppRefreshTask)
            }
        }
        
        // Schedule first cutoff check
        scheduleCutoffRolloverTask()
    }
    
    /// Schedule background task to run at next cutoff (±15 min)
    private func scheduleCutoffRolloverTask() {
        let prefs = AppPreferencesEnhanced.shared
        let nextCutoff = NightServiceDay.nextCutoff(cutoffHour: prefs.cutoffHourLocal)
        
        // Schedule ±15 min window around cutoff
        let request = BGAppRefreshTaskRequest(identifier: "com.dosetrack.cutoff.rollover")
        request.earliestBeginDate = nextCutoff.addingTimeInterval(-15 * 60)  // 15 min before
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Scheduled cutoff rollover task for \(nextCutoff)")
        } catch {
            print("❌ Failed to schedule cutoff rollover: \(error)")
        }
    }
    
    /// Handle cutoff rollover in background
    @MainActor
    private func handleCutoffRollover(task: BGAppRefreshTask) async {
        // Set up expiration handler
        task.expirationHandler = {
            print("⏱️ Cutoff rollover task expired")
        }
        
        // Create model context
        let container = try! ModelContainer(for: DoseLog.self)
        let context = ModelContext(container)
        
        // Run turnover logic
        let controller = NightTurnoverController(
            modelContext: context,
            preferences: AppPreferencesEnhanced.shared
        )
        
        let changesMade = controller.handleCutoffCrossing()
        
        if changesMade {
            print("✅ Background cutoff rollover: changes saved")
        } else {
            print("ℹ️ Background cutoff rollover: no changes needed")
        }
        
        // Schedule next occurrence
        scheduleCutoffRolloverTask()
        
        // Mark task complete
        task.setTaskCompleted(success: true)
    }
}
