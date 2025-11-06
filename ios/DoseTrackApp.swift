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
        .modelContainer(for: [DoseLog.self, NightFeatures.self])
        .backgroundTask(.appRefresh("com.dosetrack.cutoff.rollover")) { task in
            await handleCutoffRollover(task: task as! BGAppRefreshTask)
        }
        .onOpenURL { url in
            handleOpenURL(url)
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
        let container = try! ModelContainer(for: DoseLog.self, NightFeatures.self)
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
    
    // MARK: - URL Handling (OAuth Callbacks)
    
    /// Handle OAuth redirect URLs
    private func handleOpenURL(_ url: URL) {
        guard url.scheme == "dosetrack" else { return }
        
        // Handle WHOOP OAuth callback
        if url.host == "oauth" && url.pathComponents.contains("whoop") {
            handleWhoopOAuthCallback(url)
        }
    }
    
    /// Process WHOOP OAuth callback
    private func handleWhoopOAuthCallback(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            print("❌ WHOOP OAuth: No authorization code in callback")
            // Post notification for UI to show error
            NotificationCenter.default.post(name: .whoopConnectionFailed, object: nil)
            return
        }
        
        print("✅ WHOOP OAuth: Received authorization code")
        
        Task {
            do {
                // Exchange code for session
                let session = try await WhoopAPIClient.shared.exchangeCode(code)
                
                await MainActor.run {
                    // Store session ID
                    UserDefaults.standard.set(session.sessionId, forKey: "whoop_session_id")
                    UserDefaults.standard.set(session.whoopUserId, forKey: "whoop_user_id")
                    UserDefaults.standard.set(session.expiresAt.timeIntervalSince1970, forKey: "whoop_expires_at")
                    
                    print("✅ WHOOP OAuth: Session created (expires: \(session.expiresAt))")
                    
                    // Notify UI
                    NotificationCenter.default.post(
                        name: .whoopConnected,
                        object: nil,
                        userInfo: ["session": session]
                    )
                }
            } catch {
                print("❌ WHOOP OAuth: Failed to exchange code - \(error.localizedDescription)")
                
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .whoopConnectionFailed,
                        object: nil,
                        userInfo: ["error": error]
                    )
                }
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when WHOOP connection succeeds
    static let whoopConnected = Notification.Name("WhoopConnected")
    
    /// Posted when WHOOP connection fails
    static let whoopConnectionFailed = Notification.Name("WhoopConnectionFailed")
}
