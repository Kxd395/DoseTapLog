//
//  AlarmOrchestrator.swift
//  DoseTrack - Notification Scheduling Coordinator
//
//  Manages all Dose 2 notification lifecycle with:
//  - Budget tracking
//  - Identifier discipline
//  - Idempotent re-arming
//  - Cancel-by-prefix
//  - Time Sensitive opt-in
//

import Foundation
import UserNotifications
import os.log

/// Protocol for alarm scheduling (mockable for testing)
protocol AlarmOrchestrating {
    /// Arm all alarms for a night based on plan and budget
    func arm(for plan: NightAlarmPlan, style: NightAlarmPlan.AlarmStyle) async throws -> NightAlarmPlan
    
    /// Cancel all alarms for a specific night
    func cancelAll(forNightKey nightKey: String) async
    
    /// Snooze next alarm by N minutes (replaces, doesn't stack)
    func snooze(forNightKey nightKey: String, minutes: Int) async throws
    
    /// Mark alarm as delivered (consumes budget)
    func markDelivered(identifier: String, nightKey: String) async
    
    /// Check if user interacted recently (suppress next alert)
    func recordInteraction(nightKey: String)
    
    /// Get pending notification count for night
    func pendingCount(forNightKey nightKey: String) async -> Int
}

/// Concrete orchestrator implementation
actor AlarmOrchestrator: AlarmOrchestrating {
    private let center: UNUserNotificationCenter
    private let logger = Logger(subsystem: "com.dosetrack", category: "AlarmOrchestrator")
    private let appPreferences: AppPreferences
    
    /// Track last interaction time per night
    private var lastInteractionTime: [String: Date] = [:]
    
    /// Interaction suppression window (5 minutes)
    private let interactionSuppressionWindow: TimeInterval = 5 * 60
    
    init(
        center: UNUserNotificationCenter = .current(),
        preferences: AppPreferences = .shared
    ) {
        self.center = center
        self.appPreferences = preferences
    }
    
    // MARK: - Arming
    
    func arm(for plan: NightAlarmPlan, style: NightAlarmPlan.AlarmStyle) async throws -> NightAlarmPlan {
        logger.info("🔔 Arming alarms for \(plan.nightKey) with style \(style.rawValue)")
        
        // Cancel any existing alarms for this night first (idempotent)
        await cancelAll(forNightKey: plan.nightKey)
        
        // Check notification authorization
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            logger.warning("⚠️ Notifications not authorized")
            throw AlarmError.notAuthorized
        }
        
        // Build schedule based on style
        let schedule = buildSchedule(plan: plan, style: style)
        
        // Schedule notifications
        var identifiers: [String] = []
        var budgetConsumed = 0
        
        for item in schedule {
            // Check budget
            if budgetConsumed >= plan.budgetLimit {
                logger.info("📊 Budget exhausted (\(plan.budgetLimit)), skipping remaining alarms")
                break
            }
            
            let identifier = plan.identifier(for: item.type.identifier)
            let content = buildContent(for: item, nightKey: plan.nightKey, settings: settings)
            
            // Calculate fire date relative to plan times
            let fireDate = item.fireDate(from: plan)
            
            // Skip if fire date is in the past
            if fireDate < Date() {
                logger.info("⏭️ Skipping past alarm: \(item.type.description)")
                continue
            }
            
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fireDate),
                repeats: false
            )
            
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            
            try await center.add(request)
            identifiers.append(identifier)
            budgetConsumed += 1
            
            logger.info("✅ Scheduled \(item.type.description) at \(fireDate.formatted(date: .omitted, time: .shortened))")
            
            // Log telemetry
            logTelemetry(plan.createEvent(type: .scheduled, alarmType: item.type))
        }
        
        // Update plan with actual identifiers and budget
        var updatedPlan = plan
        updatedPlan = NightAlarmPlan(
            nightKey: plan.nightKey,
            dose1: plan.start.addingTimeInterval(-TimeInterval(appPreferences.windowStartMinutes * 60)),
            startMin: appPreferences.windowStartMinutes,
            endMin: appPreferences.windowEndMinutes,
            lateGraceMin: appPreferences.lateGraceMinutes,
            budgetLimit: plan.budgetLimit,
            timeZone: plan.plannedTimeZone
        )
        
        logger.info("📋 Armed \(identifiers.count) alarms, budget: \(budgetConsumed)/\(plan.budgetLimit)")
        return updatedPlan
    }
    
    // MARK: - Cancellation
    
    func cancelAll(forNightKey nightKey: String) async {
        logger.info("🗑️ Canceling all alarms for \(nightKey)")
        
        let pending = await center.pendingNotificationRequests()
        let prefix = "\(nightKey).dose2."
        let toCancel = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        
        if !toCancel.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: toCancel)
            logger.info("❌ Canceled \(toCancel.count) pending alarms")
            
            // Log telemetry
            for id in toCancel {
                if let purpose = extractPurpose(from: id, nightKey: nightKey),
                   let type = NightAlarmPlan.AlarmType(rawValue: purpose) {
                    let plan = NightAlarmPlan(nightKey: nightKey, dose1: Date(), startMin: 150, endMin: 210)
                    logTelemetry(plan.createEvent(type: .canceled, alarmType: type))
                }
            }
        }
        
        // Verify zero pending
        let remaining = await pendingCount(forNightKey: nightKey)
        if remaining > 0 {
            logger.error("⚠️ Failed to cancel all alarms: \(remaining) still pending")
        }
    }
    
    // MARK: - Snooze
    
    func snooze(forNightKey nightKey: String, minutes: Int) async throws {
        logger.info("💤 Snoozing \(nightKey) by \(minutes) minutes")
        
        // Find next pending alarm for this night
        let pending = await center.pendingNotificationRequests()
        let prefix = "\(nightKey).dose2."
        let nightAlarms = pending.filter { $0.identifier.hasPrefix(prefix) }
        
        guard let nextAlarm = nightAlarms.sorted(by: {
            guard let t1 = ($0.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate(),
                  let t2 = ($1.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() else {
                return false
            }
            return t1 < t2
        }).first else {
            logger.warning("⚠️ No pending alarms to snooze")
            return
        }
        
        // Cancel the next alarm
        center.removePendingNotificationRequests(withIdentifiers: [nextAlarm.identifier])
        
        // Reschedule with new fire time
        guard let oldTrigger = nextAlarm.trigger as? UNCalendarNotificationTrigger,
              let oldFireDate = oldTrigger.nextTriggerDate() else {
            logger.error("⚠️ Cannot extract fire date from trigger")
            return
        }
        
        let newFireDate = oldFireDate.addingTimeInterval(TimeInterval(minutes * 60))
        let newTrigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: newFireDate),
            repeats: false
        )
        
        let newRequest = UNNotificationRequest(
            identifier: nextAlarm.identifier,
            content: nextAlarm.content,
            trigger: newTrigger
        )
        
        try await center.add(newRequest)
        logger.info("✅ Snoozed to \(newFireDate.formatted(date: .omitted, time: .shortened))")
        
        // Log telemetry
        if let purpose = extractPurpose(from: nextAlarm.identifier, nightKey: nightKey),
           let type = NightAlarmPlan.AlarmType(rawValue: purpose) {
            let plan = NightAlarmPlan(nightKey: nightKey, dose1: Date(), startMin: 150, endMin: 210)
            logTelemetry(plan.createEvent(type: .snoozed, alarmType: type))
        }
    }
    
    // MARK: - Interaction Tracking
    
    func recordInteraction(nightKey: String) {
        lastInteractionTime[nightKey] = Date()
        logger.info("👆 Recorded interaction for \(nightKey)")
    }
    
    func markDelivered(identifier: String, nightKey: String) {
        logger.info("📨 Alarm delivered: \(identifier)")
        
        // Log telemetry
        if let purpose = extractPurpose(from: identifier, nightKey: nightKey),
           let type = NightAlarmPlan.AlarmType(rawValue: purpose) {
            let plan = NightAlarmPlan(nightKey: nightKey, dose1: Date(), startMin: 150, endMin: 210)
            logTelemetry(plan.createEvent(type: .delivered, alarmType: type))
        }
    }
    
    // MARK: - Utility
    
    func pendingCount(forNightKey nightKey: String) async -> Int {
        let pending = await center.pendingNotificationRequests()
        let prefix = "\(nightKey).dose2."
        return pending.filter { $0.identifier.hasPrefix(prefix) }.count
    }
    
    // MARK: - Private Helpers
    
    private func buildSchedule(plan: NightAlarmPlan, style: NightAlarmPlan.AlarmStyle) -> [ScheduleItem] {
        var items: [ScheduleItem] = []
        
        switch style {
        case .quiet:
            // Only window open
            items.append(ScheduleItem(type: .open, relativeToStart: 0))
            
        case .normal:
            // Open, Closing, End (up to budget 3)
            items.append(ScheduleItem(type: .open, relativeToStart: 0))
            
            // Closing soon (30 min before end)
            let closingOffset = (appPreferences.windowEndMinutes - appPreferences.windowStartMinutes) - 30
            if closingOffset > 0 {
                items.append(ScheduleItem(type: .closing, relativeToStart: closingOffset))
            }
            
            items.append(ScheduleItem(type: .end, relativeToEnd: 0))
            
        case .strong:
            // All normal alerts + hard repeats
            items.append(ScheduleItem(type: .open, relativeToStart: 0))
            
            let closingOffset = (appPreferences.windowEndMinutes - appPreferences.windowStartMinutes) - 30
            if closingOffset > 0 {
                items.append(ScheduleItem(type: .closing, relativeToStart: closingOffset))
            }
            
            items.append(ScheduleItem(type: .end, relativeToEnd: 0))
            
            // Hard repeats after grace period if enabled
            if appPreferences.hardAfterEndEnabled {
                let repeatMin = appPreferences.hardRepeatMinutes
                let maxRepeats = min(appPreferences.hardMaxRepeats, 3)
                
                for i in 1...maxRepeats {
                    let offset = appPreferences.lateGraceMinutes + (repeatMin * i)
                    let type: NightAlarmPlan.AlarmType = i == 1 ? .hard1 : (i == 2 ? .hard2 : .hard3)
                    items.append(ScheduleItem(type: type, relativeToEnd: offset))
                }
            }
        }
        
        // Collapse pre-window and open if within 10 minutes
        if appPreferences.preWindowLeadMinutes > 0 {
            let preOffset = -appPreferences.preWindowLeadMinutes
            if preOffset > -10 {
                // Too close to open, skip pre-window
                logger.info("⏭️ Skipping pre-window (within 10 min of open)")
            } else {
                items.insert(ScheduleItem(type: .preWindow, relativeToStart: preOffset), at: 0)
            }
        }
        
        return items
    }
    
    private func buildContent(
        for item: ScheduleItem,
        nightKey: String,
        settings: UNNotificationSettings
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = item.type.description
        content.body = item.body
        content.sound = item.sound
        content.categoryIdentifier = "DOSE2_ALARM"
        
        // Time Sensitive only if user opted in AND setting is enabled
        if appPreferences.respectDND == .timeSensitive && settings.timeSensitiveSetting == .enabled {
            content.interruptionLevel = .timeSensitive
        } else if appPreferences.respectDND == .off {
            content.interruptionLevel = .active
        } else {
            content.interruptionLevel = .active
        }
        
        // Badge
        content.badge = 1
        
        // User info for tracking
        content.userInfo = [
            "nightKey": nightKey,
            "alarmType": item.type.rawValue
        ]
        
        return content
    }
    
    private func extractPurpose(from identifier: String, nightKey: String) -> String? {
        let prefix = "\(nightKey).dose2."
        guard identifier.hasPrefix(prefix) else { return nil }
        return String(identifier.dropFirst(prefix.count))
    }
    
    private func logTelemetry(_ event: NightAlarmPlan.AlarmEvent) {
        // TODO: Persist to database or analytics service
        logger.debug("📊 Telemetry: \(event.eventType.rawValue) - \(event.alarmType?.rawValue ?? "nil")")
    }
}

// MARK: - Supporting Types

private struct ScheduleItem {
    let type: NightAlarmPlan.AlarmType
    var relativeToStart: Int = 0  // Minutes from window start
    var relativeToEnd: Int = 0    // Minutes from window end
    
    var body: String {
        switch type {
        case .preWindow:
            return "Window opens soon. Prepare for Dose 2."
        case .open:
            return "Dose 2 window is now open."
        case .closing:
            return "Dose 2 window closing in 30 minutes."
        case .end:
            return "Dose 2 window has ended."
        case .hard1, .hard2, .hard3:
            return "You have not logged Dose 2. Window closed."
        }
    }
    
    var sound: UNNotificationSound {
        switch type {
        case .preWindow, .open:
            return .default
        case .closing:
            return .defaultCritical
        case .end:
            return .defaultCritical
        case .hard1, .hard2, .hard3:
            return .defaultCritical
        }
    }
    
    func fireDate(from plan: NightAlarmPlan) -> Date {
        if relativeToStart != 0 {
            return plan.start.addingTimeInterval(TimeInterval(relativeToStart * 60))
        } else {
            return plan.end.addingTimeInterval(TimeInterval(relativeToEnd * 60))
        }
    }
}

enum AlarmError: Error, LocalizedError {
    case notAuthorized
    case invalidPlan
    case schedulingFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Notifications not authorized. Fix in Settings."
        case .invalidPlan:
            return "Invalid alarm plan"
        case .schedulingFailed:
            return "Failed to schedule notification"
        }
    }
}
