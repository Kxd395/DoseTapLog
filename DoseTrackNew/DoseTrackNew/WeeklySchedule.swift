import Foundation

/// Weekly schedule template for planning "typical" sleep cycles
/// Supports per-day-of-week target times with circadian stability constraints
struct WeeklyScheduleProfile: Codable, Equatable {
    
    /// Single day's schedule
    struct DaySchedule: Codable, Equatable {
        /// Target bedtime (Dose 1 time) as "HH:mm" in 24h format
        var targetBedtime: String
        
        /// Target wake time as "HH:mm"
        var targetWake: String
        
        /// Profile type for this day
        var profileType: ProfileType
        
        enum ProfileType: String, Codable, CaseIterable {
            case workday
            case offDay = "off_day"
            case travel
            
            var displayName: String {
                switch self {
                case .workday: return "Workday"
                case .offDay: return "Off Day"
                case .travel: return "Travel"
                }
            }
        }
    }
    
    /// Schedule for each day of week (0 = Sunday, 6 = Saturday)
    var days: [DaySchedule]
    
    /// Maximum shift allowed per night (minutes) to maintain circadian stability
    var maxShiftPerNightMin: Int
    
    /// Timezone policy
    var timeZonePolicy: TimeZonePolicy
    
    /// Home timezone identifier (for "home" or "ask" policy)
    var homeTimeZone: String
    
    enum TimeZonePolicy: String, Codable, CaseIterable {
        case local      // Always use device's current timezone
        case home       // Always use home timezone (rebase when traveling)
        case ask        // Prompt user when timezone changes
        
        var displayName: String {
            switch self {
            case .local: return "Local Time"
            case .home: return "Home Time"
            case .ask: return "Ask Me"
            }
        }
    }
    
    /// Default workweek schedule (10:30 PM bedtime, 6:30 AM wake)
    static let `default` = WeeklyScheduleProfile(
        days: [
            // Sunday (off day)
            DaySchedule(targetBedtime: "23:00", targetWake: "07:30", profileType: .offDay),
            // Monday-Friday (workdays)
            DaySchedule(targetBedtime: "22:30", targetWake: "06:30", profileType: .workday),
            DaySchedule(targetBedtime: "22:30", targetWake: "06:30", profileType: .workday),
            DaySchedule(targetBedtime: "22:30", targetWake: "06:30", profileType: .workday),
            DaySchedule(targetBedtime: "22:30", targetWake: "06:30", profileType: .workday),
            DaySchedule(targetBedtime: "22:30", targetWake: "06:30", profileType: .workday),
            // Saturday (off day)
            DaySchedule(targetBedtime: "23:30", targetWake: "08:00", profileType: .offDay)
        ],
        maxShiftPerNightMin: 30,
        timeZonePolicy: .local,
        homeTimeZone: TimeZone.current.identifier
    )
    
    /// Get schedule for a specific date
    func schedule(for date: Date, in timeZone: TimeZone = .current) -> DaySchedule {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let weekday = calendar.component(.weekday, from: date) - 1 // 0-based
        return days[weekday]
    }
    
    /// Get suggested Dose 1 time for tonight
    /// - Parameters:
    ///   - date: Reference date (usually today)
    ///   - cutoffHour: Service-day cutoff hour
    ///   - timeZone: Timezone to use
    /// - Returns: Suggested Dose 1 timestamp
    func suggestedDose1Time(for date: Date = Date(), cutoffHour: Int = 12, in timeZone: TimeZone = .current) -> Date {
        // Get tonight's service day
        let nightKey = NightServiceDay.nightKey(for: date, cutoffHour: cutoffHour, in: timeZone)
        
        // Parse nightKey to get the evening date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        guard let serviceDate = formatter.date(from: nightKey) else { return date }
        
        // Get schedule for that day
        let schedule = self.schedule(for: serviceDate, in: timeZone)
        
        // Parse target bedtime
        let timeComponents = schedule.targetBedtime.split(separator: ":")
        guard timeComponents.count == 2,
              let hour = Int(timeComponents[0]),
              let minute = Int(timeComponents[1]) else {
            return date
        }
        
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        
        var components = calendar.dateComponents([.year, .month, .day], from: serviceDate)
        components.hour = hour
        components.minute = minute
        components.second = 0
        
        return calendar.date(from: components) ?? date
    }
    
    /// Apply max shift constraint to a proposed bedtime
    /// - Parameters:
    ///   - proposed: Proposed bedtime
    ///   - previous: Previous night's bedtime (or nil if first night)
    /// - Returns: Constrained bedtime (within maxShift of previous)
    func constrainShift(proposed: Date, previous: Date?) -> Date {
        guard let previous = previous else { return proposed }
        
        let maxShiftSeconds = TimeInterval(maxShiftPerNightMin * 60)
        let actualShift = proposed.timeIntervalSince(previous)
        
        // If shift is within limits, allow it
        if abs(actualShift) <= maxShiftSeconds {
            return proposed
        }
        
        // Constrain to max shift in the direction of the proposal
        if actualShift > 0 {
            return previous.addingTimeInterval(maxShiftSeconds)
        } else {
            return previous.addingTimeInterval(-maxShiftSeconds)
        }
    }
}

// MARK: - Timezone Rebase Support

/// Timezone change detection and rebase prompt
struct TimeZoneChange {
    let previousTimeZone: TimeZone
    let currentTimeZone: TimeZone
    let hoursShift: Int
    
    var description: String {
        let direction = hoursShift > 0 ? "east" : "west"
        return "Time zone changed \(abs(hoursShift))h \(direction)"
    }
    
    var shouldPromptRebase: Bool {
        // Prompt if shift is 1+ hours
        abs(hoursShift) >= 1
    }
    
    init(from previous: TimeZone, to current: TimeZone) {
        self.previousTimeZone = previous
        self.currentTimeZone = current
        
        let prevOffset = previous.secondsFromGMT() / 3600
        let currOffset = current.secondsFromGMT() / 3600
        self.hoursShift = currOffset - prevOffset
    }
}

/// Rebase action when timezone changes
enum RebaseAction: String, CaseIterable {
    case local      // Recompute plan in local time
    case keepHome   // Keep home time (don't adjust)
    case manual     // Let me adjust manually
    
    var displayName: String {
        switch self {
        case .local: return "Use Local Time"
        case .keepHome: return "Keep Home Time"
        case .manual: return "Adjust Manually"
        }
    }
    
    var description: String {
        switch self {
        case .local: return "Recompute tonight's plan using local timezone"
        case .keepHome: return "Keep original plan times (home timezone)"
        case .manual: return "I'll adjust the plan myself"
        }
    }
}
