import Foundation

/// Service-day cutoff system for deterministic night rollover.
/// Replaces midnight-based boundaries with a configurable cutoff (default noon).
/// NightKey = the service-day date of the evening the night starts.
///
/// Key principle: Any session that begins after cutoff belongs to that date.
/// Example: With noon cutoff, 11 PM on Nov 3 → nightKey "2025-11-03"
///          2 AM on Nov 4 (before noon) → still nightKey "2025-11-03"
enum NightServiceDay {
    
    /// Calculate the service-day cutoff time for a given date
    /// - Parameters:
    ///   - date: Reference date
    ///   - cutoffHour: Hour of day for cutoff (default 12 = noon)
    ///   - timeZone: Local timezone
    /// - Returns: Cutoff timestamp (YYYY-MM-DD HH:00:00)
    static func serviceCutoff(for date: Date, cutoffHour: Int = 12, in timeZone: TimeZone = .current) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = cutoffHour
        components.minute = 0
        components.second = 0
        components.nanosecond = 0
        
        return calendar.date(from: components) ?? date
    }
    
    /// Generate nightKey for a given timestamp using service-day rules
    /// - Parameters:
    ///   - timestamp: The time to calculate nightKey for
    ///   - cutoffHour: Hour of day for cutoff (default 12 = noon)
    ///   - timeZone: Local timezone
    /// - Returns: NightKey in YYYY-MM-DD format
    ///
    /// Logic:
    /// - If timestamp < cutoff → use yesterday's date (still part of previous night)
    /// - If timestamp >= cutoff → use today's date (new night starting this evening)
    static func nightKey(for timestamp: Date, cutoffHour: Int = 12, in timeZone: TimeZone = .current) -> String {
        let cutoff = serviceCutoff(for: timestamp, cutoffHour: cutoffHour, in: timeZone)
        
        // If before cutoff, this timestamp belongs to yesterday's service day
        let serviceDay: Date
        if timestamp < cutoff {
            serviceDay = timestamp.addingTimeInterval(-86400) // 24 hours earlier
        } else {
            serviceDay = timestamp
        }
        
        return formatYYYYMMDD(serviceDay, in: timeZone)
    }
    
    /// Get the nightKey for "tonight" (the current service day)
    /// - Parameters:
    ///   - cutoffHour: Hour of day for cutoff
    ///   - timeZone: Local timezone
    /// - Returns: Tonight's nightKey
    static func tonightKey(cutoffHour: Int = 12, in timeZone: TimeZone = .current) -> String {
        nightKey(for: Date(), cutoffHour: cutoffHour, in: timeZone)
    }
    
    /// Get the nightKey for "last night" (previous service day)
    static func lastNightKey(cutoffHour: Int = 12, in timeZone: TimeZone = .current) -> String {
        let yesterday = Date().addingTimeInterval(-86400)
        return nightKey(for: yesterday, cutoffHour: cutoffHour, in: timeZone)
    }
    
    /// Get the nightKey for "tomorrow" (next service day)
    static func tomorrowKey(cutoffHour: Int = 12, in timeZone: TimeZone = .current) -> String {
        let tomorrow = Date().addingTimeInterval(86400)
        return nightKey(for: tomorrow, cutoffHour: cutoffHour, in: timeZone)
    }
    
    /// Check if we've crossed the cutoff since a given timestamp
    /// - Parameters:
    ///   - since: Previous timestamp
    ///   - cutoffHour: Hour of day for cutoff
    ///   - timeZone: Local timezone
    /// - Returns: True if cutoff has been crossed
    static func hasCrossedCutoff(since: Date, cutoffHour: Int = 12, in timeZone: TimeZone = .current) -> Bool {
        let previousKey = nightKey(for: since, cutoffHour: cutoffHour, in: timeZone)
        let currentKey = nightKey(for: Date(), cutoffHour: cutoffHour, in: timeZone)
        return previousKey != currentKey
    }
    
    /// Get the next cutoff time from now
    /// - Parameters:
    ///   - cutoffHour: Hour of day for cutoff
    ///   - timeZone: Local timezone
    /// - Returns: Next cutoff timestamp
    static func nextCutoff(cutoffHour: Int = 12, in timeZone: TimeZone = .current) -> Date {
        let todayCutoff = serviceCutoff(for: Date(), cutoffHour: cutoffHour, in: timeZone)
        
        // If we're past today's cutoff, return tomorrow's cutoff
        if Date() >= todayCutoff {
            return todayCutoff.addingTimeInterval(86400)
        } else {
            return todayCutoff
        }
    }
    
    /// Format a date as YYYY-MM-DD in the given timezone
    private static func formatYYYYMMDD(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
}

// MARK: - Night Lifecycle States

/// Deterministic state machine for night progression
enum NightLifecycleState: String, Codable, CaseIterable {
    /// Planned but not started (no events logged yet)
    case planned = "planned"
    
    /// In bed logged, waiting for Dose 1
    case armed = "armed"
    
    /// Dose 1 logged, before window opens
    case active = "active"
    
    /// Dose 2 window is open
    case windowOpen = "window_open"
    
    /// Dose 2 window has closed
    case windowClosed = "window_closed"
    
    /// Waiting for final wake
    case awaitWake = "await_wake"
    
    /// Night is complete (Final Wake logged or auto-closed at cutoff)
    case closed = "closed"
    
    /// Night was abandoned/reset
    case abandoned = "abandoned"
    
    var displayName: String {
        switch self {
        case .planned: return "Planned"
        case .armed: return "Armed"
        case .active: return "Active"
        case .windowOpen: return "Window Open"
        case .windowClosed: return "Window Closed"
        case .awaitWake: return "Awaiting Wake"
        case .closed: return "Closed"
        case .abandoned: return "Abandoned"
        }
    }
    
    var color: String {
        switch self {
        case .planned: return "gray"
        case .armed: return "blue"
        case .active: return "green"
        case .windowOpen: return "orange"
        case .windowClosed: return "red"
        case .awaitWake: return "purple"
        case .closed: return "gray"
        case .abandoned: return "gray"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .planned, .abandoned, .closed:
            return false
        default:
            return true
        }
    }
}

// MARK: - Planning Horizon

/// Which card in the 3-card planning view
enum PlanningHorizon: String, CaseIterable {
    case lastNight = "last_night"
    case tonight = "tonight"
    case tomorrow = "tomorrow"
    
    var displayName: String {
        switch self {
        case .lastNight: return "Last Night"
        case .tonight: return "Tonight"
        case .tomorrow: return "Tomorrow"
        }
    }
    
    /// Get the nightKey for this horizon
    func nightKey(cutoffHour: Int = 12, in timeZone: TimeZone = .current) -> String {
        switch self {
        case .lastNight:
            return NightServiceDay.lastNightKey(cutoffHour: cutoffHour, in: timeZone)
        case .tonight:
            return NightServiceDay.tonightKey(cutoffHour: cutoffHour, in: timeZone)
        case .tomorrow:
            return NightServiceDay.tomorrowKey(cutoffHour: cutoffHour, in: timeZone)
        }
    }
}
