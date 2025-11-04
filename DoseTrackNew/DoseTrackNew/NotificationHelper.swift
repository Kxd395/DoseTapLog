//
//  NotificationHelper.swift
//  DoseTrack
//
//  Notification scheduling for Dose 2 window reminders
//

import Foundation
import UserNotifications

@MainActor
class NotificationHelper {
    static let shared = NotificationHelper()
    
    private let center = UNUserNotificationCenter.current()
    
    // Notification identifiers
    private let windowStartId = "dose2.window.start"
    
    /// Request notification permission if not already granted
    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("❌ Notification permission error: \(error)")
            return false
        }
    }
    
    /// Check current notification permission status
    func checkPermission() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    /// Schedule notification for Dose 2 window start
    /// - Parameter windowStartTime: The time when the window opens
    /// - Returns: Success status
    @discardableResult
    func scheduleWindowStartReminder(at windowStartTime: Date) async -> Bool {
        // Check permission first
        guard await checkPermission() else {
            print("⚠️ Notification permission not granted")
            return false
        }
        
        // Cancel any existing window start notification
        center.removePendingNotificationRequests(withIdentifiers: [windowStartId])
        
        // Don't schedule if time is in the past
        guard windowStartTime > Date() else {
            print("⚠️ Window start time is in the past, not scheduling")
            return false
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Dose 2 Window Open"
        content.body = "Your Dose 2 window is now open. Tap to log your dose."
        content.sound = .default
        content.categoryIdentifier = "DOSE2_WINDOW"
        content.badge = 1
        
        // Add custom data
        content.userInfo = [
            "type": "dose2_window_start",
            "scheduled_at": Date().timeIntervalSince1970,
            "window_start": windowStartTime.timeIntervalSince1970
        ]
        
        // Create trigger
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: windowStartTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Create request
        let request = UNNotificationRequest(identifier: windowStartId, content: content, trigger: trigger)
        
        // Schedule
        do {
            try await center.add(request)
            print("✅ Scheduled Dose 2 window reminder for \(windowStartTime)")
            return true
        } catch {
            print("❌ Failed to schedule notification: \(error)")
            return false
        }
    }
    
    /// Cancel the Dose 2 window start reminder
    func cancelWindowStartReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [windowStartId])
        print("🗑️ Cancelled Dose 2 window start reminder")
    }
    
    /// Get all pending notifications (for debugging)
    func getPendingNotifications() async -> [UNNotificationRequest] {
        return await center.pendingNotificationRequests()
    }
}
