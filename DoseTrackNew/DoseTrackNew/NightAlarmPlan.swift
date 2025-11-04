//
//  NightAlarmPlan.swift
//  DoseTrack - Alarm Schedule Container
//
//  Bundles all scheduled notification identifiers for a night.
//  Enables easy cancellation by prefix and idempotent re-arming.
//

import Foundation

/// Complete alarm plan for one night's Dose 2 notifications
struct NightAlarmPlan: Equatable, Codable {
    /// Night key (YYYY-MM-DD format)
    let nightKey: String
    
    /// Window start time (Dose 1 + startMin)
    let start: Date
    
    /// Window end time (Dose 1 + endMin)
    let end: Date
    
    /// Grace period end (end + lateGraceMin)
    let graceEnd: Date
    
    /// All scheduled notification identifiers for this night
    /// Pattern: {nightKey}.dose2.{purpose}
    /// Examples: "2025-11-02.dose2.open", "2025-11-02.dose2.closing", "2025-11-02.dose2.end"
    let identifiers: [String]
    
    /// Alarm budget consumed (how many alerts have fired or will fire)
    var budgetConsumed: Int
    
    /// Alarm budget limit (e.g., 3)
    let budgetLimit: Int
    
    /// Time zone when plan was created (for DST/travel detection)
    let plannedTimeZone: TimeZone
    
    /// Remaining budget
    var budgetRemaining: Int {
        max(0, budgetLimit - budgetConsumed)
    }
    
    /// Has budget been exhausted?
    var budgetExhausted: Bool {
        budgetConsumed >= budgetLimit
    }
    
    /// Initialize with window parameters
    init(
        nightKey: String,
        dose1: Date,
        startMin: Int,
        endMin: Int,
        lateGraceMin: Int = 15,
        budgetLimit: Int = 3,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) {
        self.nightKey = nightKey
        self.budgetLimit = budgetLimit
        self.budgetConsumed = 0
        self.plannedTimeZone = timeZone
        
        // Compute window boundaries with Calendar for DST safety
        var cal = calendar
        cal.timeZone = timeZone
        
        self.start = cal.date(byAdding: .minute, value: startMin, to: dose1) ?? dose1
        self.end = cal.date(byAdding: .minute, value: endMin, to: dose1) ?? dose1
        self.graceEnd = cal.date(byAdding: .minute, value: lateGraceMin, to: self.end) ?? self.end
        
        // Initialize with empty identifiers (populated during arming)
        self.identifiers = []
    }
    
    /// Create identifier for a specific notification type
    /// - Parameter purpose: Notification purpose (e.g., "open", "closing", "end", "hard.1")
    /// - Returns: Fully qualified identifier
    func identifier(for purpose: String) -> String {
        "\(nightKey).dose2.\(purpose)"
    }
    
    /// Check if identifier belongs to this night
    /// - Parameter identifier: Notification identifier
    /// - Returns: true if matches this night's prefix
    func owns(identifier: String) -> Bool {
        identifier.hasPrefix("\(nightKey).dose2.")
    }
    
    /// Extract purpose from identifier
    /// - Parameter identifier: Notification identifier
    /// - Returns: Purpose string if valid, nil otherwise
    func purpose(from identifier: String) -> String? {
        let prefix = "\(nightKey).dose2."
        guard identifier.hasPrefix(prefix) else { return nil }
        return String(identifier.dropFirst(prefix.count))
    }
}

// MARK: - Alarm Types

extension NightAlarmPlan {
    /// Notification purpose types
    enum AlarmType: String, CaseIterable, Codable {
        case preWindow = "pre"       // Optional pre-window nudge
        case open = "open"           // Window opened
        case closing = "closing"     // Window closing soon (last 30 min)
        case end = "end"             // Window ended
        case hard1 = "hard.1"        // Hard alarm repeat 1
        case hard2 = "hard.2"        // Hard alarm repeat 2
        case hard3 = "hard.3"        // Hard alarm repeat 3
        
        var identifier: String { rawValue }
        
        /// Is this a hard alarm repeat?
        var isHardAlarm: Bool {
            rawValue.hasPrefix("hard.")
        }
        
        /// User-facing description
        var description: String {
            switch self {
            case .preWindow: return "Pre-window nudge"
            case .open: return "Window open"
            case .closing: return "Window closing soon"
            case .end: return "Window ended"
            case .hard1: return "Hard alarm (1st repeat)"
            case .hard2: return "Hard alarm (2nd repeat)"
            case .hard3: return "Hard alarm (3rd repeat)"
            }
        }
    }
    
    /// Alarm style preference
    enum AlarmStyle: String, Codable, CaseIterable {
        case quiet = "quiet"         // Minimal alerts
        case normal = "normal"       // Standard ladder
        case strong = "strong"       // Includes hard repeats (requires consent)
        
        var description: String {
            switch self {
            case .quiet: return "Quiet (1 alert)"
            case .normal: return "Normal (up to 3 alerts)"
            case .strong: return "Strong (includes hard repeats)"
            }
        }
        
        /// Budget limit for this style
        var defaultBudget: Int {
            switch self {
            case .quiet: return 1
            case .normal: return 3
            case .strong: return 5
            }
        }
    }
}

// MARK: - Telemetry

extension NightAlarmPlan {
    /// Telemetry event for alarm tracking
    struct AlarmEvent: Codable {
        let nightKey: String
        let timestamp: Date
        let eventType: EventType
        let alarmType: AlarmType?
        let budgetRemaining: Int
        let deviceType: DeviceType
        
        enum EventType: String, Codable {
            case scheduled   // Alarm was scheduled
            case delivered   // Alarm was delivered by system
            case acted       // User tapped notification
            case snoozed     // User snoozed
            case canceled    // Alarm was canceled
            case suppressed  // Alarm was suppressed (budget or interaction)
        }
        
        enum DeviceType: String, Codable {
            case phone
            case watch
            case unknown
        }
    }
    
    /// Create telemetry event
    func createEvent(
        type: AlarmEvent.EventType,
        alarmType: AlarmType?,
        device: AlarmEvent.DeviceType = .phone
    ) -> AlarmEvent {
        AlarmEvent(
            nightKey: nightKey,
            timestamp: Date(),
            eventType: type,
            alarmType: alarmType,
            budgetRemaining: budgetRemaining,
            deviceType: device
        )
    }
}
