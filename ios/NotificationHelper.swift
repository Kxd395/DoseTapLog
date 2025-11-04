//
//  NotificationHelper.swift
//  DoseTrack
//
//  Centralized notification scheduling for Dose 2 Soft-Wake alarms
//

import Foundation
import UserNotifications

/// Helper for scheduling and managing Dose 2 alarms
struct NotificationHelper {
    
    // MARK: - Notification Categories
    
    enum Category: String {
        case dose2Open = "DOSE2_OPEN"
        case dose2Mid = "DOSE2_MID"
        case dose2LastCall = "DOSE2_LASTCALL"
        case dose2Guard = "DOSE2_GUARD"
        
        var identifier: String { rawValue }
    }
    
    enum ActionID: String {
        case logNow = "LOG_NOW"
        case snooze5 = "SNOOZE_5"
        case snooze10 = "SNOOZE_10"
        case snooze15 = "SNOOZE_15"
        
        var identifier: String { rawValue }
    }
    
    // MARK: - Register Categories
    
    static func registerNotificationCategories() {
        let logNow = UNNotificationAction(
            identifier: ActionID.logNow.identifier,
            title: "Log Now",
            options: [.foreground]
        )
        
        let snooze5 = UNNotificationAction(
            identifier: ActionID.snooze5.identifier,
            title: "Snooze 5m",
            options: []
        )
        
        let snooze10 = UNNotificationAction(
            identifier: ActionID.snooze10.identifier,
            title: "Snooze 10m",
            options: []
        )
        
        let snooze15 = UNNotificationAction(
            identifier: ActionID.snooze15.identifier,
            title: "Snooze 15m",
            options: []
        )
        
        // Dose 2 Open category
        let dose2OpenCategory = UNNotificationCategory(
            identifier: Category.dose2Open.identifier,
            actions: [logNow, snooze5],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Dose 2 Mid-window category
        let dose2MidCategory = UNNotificationCategory(
            identifier: Category.dose2Mid.identifier,
            actions: [logNow, snooze10],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Dose 2 Last Call category
        let dose2LastCallCategory = UNNotificationCategory(
            identifier: Category.dose2LastCall.identifier,
            actions: [logNow],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Guard active (informational only)
        let guardCategory = UNNotificationCategory(
            identifier: Category.dose2Guard.identifier,
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([
            dose2OpenCategory,
            dose2MidCategory,
            dose2LastCallCategory,
            guardCategory
        ])
    }
    
    // MARK: - Schedule Dose 2 Alarms
    
    /// Schedule all Dose 2 alarms when Dose 1 is logged
    static func scheduleDose2Alarms(
        dose1Time: Date,
        windowStartMin: Int,
        windowEndMin: Int,
        guardCutoff: Date?,
        style: Dose2AlarmStyle,
        nightKey: String
    ) {
        guard style != .off else {
            print("📵 Dose 2 alarms disabled")
            return
        }
        
        let prefs = AppPreferencesEnhanced.shared
        let center = UNUserNotificationCenter.current()
        
        // Calculate alert times
        let windowOpen = dose1Time.addingTimeInterval(TimeInterval(windowStartMin * 60))
        let windowClose = dose1Time.addingTimeInterval(TimeInterval(windowEndMin * 60))
        let lastCall = windowClose.addingTimeInterval(-10 * 60) // 10 min before close
        let midWindow = dose1Time.addingTimeInterval(TimeInterval(((windowStartMin + windowEndMin) / 2) * 60))
        
        // Determine interruption level
        let interruptionLevel: UNNotificationInterruptionLevel = {
            switch style {
            case .off, .banner:
                return .passive
            case .soft:
                // Check quiet hours unless user opted to break them
                if prefs.breakQuietHoursForDose2 {
                    return .timeSensitive
                }
                let now = Date()
                let hour = Calendar.current.component(.hour, from: now)
                let inQuietHours = (hour >= prefs.quietHoursStart || hour < prefs.quietHoursEnd)
                return inQuietHours ? .passive : .timeSensitive
            case .strong:
                return .timeSensitive
            }
        }()
        
        // 1. Window Open alert
        scheduleNotification(
            id: "dose2_open_\(nightKey)",
            title: "Dose 2 Window Open",
            body: style == .strong ? "🔔 Soft-Wake: Dose 2 window is open. Tap to log now." : "Dose 2 window is open",
            at: windowOpen,
            category: .dose2Open,
            interruptionLevel: interruptionLevel,
            sound: style == .strong ? .defaultCritical : .default
        )
        
        // 2. Mid-window ping (optional)
        if prefs.dose2MidPingEnabled {
            scheduleNotification(
                id: "dose2_mid_\(nightKey)",
                title: "Dose 2 Reminder",
                body: "Window is open. Take Dose 2 when ready.",
                at: midWindow,
                category: .dose2Mid,
                interruptionLevel: interruptionLevel,
                sound: style == .strong ? .defaultCritical : .default
            )
        }
        
        // 3. Last call alert
        scheduleNotification(
            id: "dose2_lastcall_\(nightKey)",
            title: "Dose 2 Window Closing Soon",
            body: "Window closes in 10 minutes",
            at: lastCall,
            category: .dose2LastCall,
            interruptionLevel: .timeSensitive,
            sound: .default
        )
        
        // 4. Schedule cancel task at guard cutoff
        if let cutoff = guardCutoff {
            scheduleCancelTask(id: "dose2_cancel_\(nightKey)", at: cutoff, nightKey: nightKey)
        }
        
        print("✅ Scheduled Dose 2 alarms for \(nightKey): open=\(windowOpen.formatted(date: .omitted, time: .shortened)), lastCall=\(lastCall.formatted(date: .omitted, time: .shortened))")
    }
    
    // MARK: - Individual Notification Scheduling
    
    private static func scheduleNotification(
        id: String,
        title: String,
        body: String,
        at date: Date,
        category: Category,
        interruptionLevel: UNNotificationInterruptionLevel,
        sound: UNNotificationSound
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = category.identifier
        content.interruptionLevel = interruptionLevel
        content.sound = sound
        content.userInfo = [
            "notification_id": id,
            "scheduled_at": ISO8601DateFormatter().string(from: Date()),
            "target_time": ISO8601DateFormatter().string(from: date)
        ]
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule \(id): \(error)")
            } else {
                print("📅 Scheduled \(id) at \(date.formatted(date: .omitted, time: .shortened))")
            }
        }
    }
    
    // MARK: - Cancel Notifications
    
    /// Cancel all Dose 2 notifications for a specific night
    static func cancelDose2Alarms(nightKey: String) {
        let center = UNUserNotificationCenter.current()
        let identifiers = [
            "dose2_open_\(nightKey)",
            "dose2_mid_\(nightKey)",
            "dose2_lastcall_\(nightKey)",
            "dose2_cancel_\(nightKey)"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("🔕 Cancelled Dose 2 alarms for \(nightKey)")
    }
    
    /// Schedule a cancel task to fire at guard cutoff
    static func scheduleCancelTask(id: String, at date: Date, nightKey: String) {
        let content = UNMutableNotificationContent()
        content.title = "No-Wake Guard Active"
        content.body = "Dose 2 alarms cancelled: too close to morning wake"
        content.categoryIdentifier = Category.dose2Guard.identifier
        content.interruptionLevel = .passive
        content.sound = nil
        content.userInfo = [
            "cancel_task": true,
            "night_key": nightKey
        ]
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to schedule cancel task \(id): \(error)")
            } else {
                print("🛡️ Scheduled guard cancel at \(date.formatted(date: .omitted, time: .shortened))")
                // Actually cancel the notifications when this fires
                // This would need to be handled by notification delegate
            }
        }
    }
    
    // MARK: - Query Next Alert
    
    /// Get the next scheduled Dose 2 alert time for display in Bell Chip
    static func getNextDose2Alert(nightKey: String, completion: @escaping (Date?) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let dose2Requests = requests.filter { request in
                request.identifier.hasPrefix("dose2_") && request.identifier.contains(nightKey)
            }
            
            let nextAlert = dose2Requests.compactMap { request -> Date? in
                guard let trigger = request.trigger as? UNCalendarNotificationTrigger,
                      let nextDate = trigger.nextTriggerDate() else {
                    return nil
                }
                return nextDate
            }.min()
            
            DispatchQueue.main.async {
                completion(nextAlert)
            }
        }
    }
}
