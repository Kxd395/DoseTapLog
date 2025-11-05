//
//  WindowState.swift
//  DoseTrack - Robust Dose 2 Window State Machine
//
//  Single source of truth for dosing window state.
//  All UI enables, notification schedules, and override gates derive from this.
//

import Foundation

/// Dose 2 window state - the only source of truth for timing decisions
enum WindowState: Equatable {
    /// No Dose 1 logged yet
    case noDose1
    
    /// Waiting for window to open (before startMin elapsed)
    case waiting(start: Date)
    
    /// Window is open (between startMin and endMin)
    case open(start: Date, end: Date)
    
    /// Grace period after window end (late allowed without critical severity)
    case grace(end: Date, graceEnd: Date)
    
    /// Window closed (beyond grace period)
    case closed(end: Date)
    
    /// Pure function - no side effects, easy to test
    /// - Parameters:
    ///   - now: Current time
    ///   - dose1: Dose 1 timestamp (nil if not logged)
    ///   - startMin: Window start offset from Dose 1 (e.g., 150)
    ///   - endMin: Window end offset from Dose 1 (e.g., 210)
    ///   - lateGraceMin: Grace period after end (default 15)
    ///   - calendar: Calendar for date math (injected for DST testing)
    /// - Returns: Current window state
    static func compute(
        now: Date,
        dose1: Date?,
        startMin: Int,
        endMin: Int,
        lateGraceMin: Int = 15,
        calendar: Calendar = .current
    ) -> WindowState {
        guard let dose1 = dose1 else {
            return .noDose1
        }
        
        // Compute window boundaries using Calendar to handle DST
        guard let windowStart = calendar.date(byAdding: .minute, value: startMin, to: dose1),
              let windowEnd = calendar.date(byAdding: .minute, value: endMin, to: dose1),
              let graceEnd = calendar.date(byAdding: .minute, value: lateGraceMin, to: windowEnd) else {
            // Calendar math failed - treat as closed
            return .closed(end: dose1.addingTimeInterval(TimeInterval(endMin * 60)))
        }
        
        if now < windowStart {
            return .waiting(start: windowStart)
        } else if now <= windowEnd {
            return .open(start: windowStart, end: windowEnd)
        } else if now <= graceEnd {
            return .grace(end: windowEnd, graceEnd: graceEnd)
        } else {
            return .closed(end: windowEnd)
        }
    }
    
    /// Human-readable description for UI and logging
    var description: String {
        switch self {
        case .noDose1:
            return "No Dose 1 logged"
        case .waiting(let start):
            return "Window opens at \(start.formatted(date: .omitted, time: .shortened))"
        case .open(_, let end):
            return "Window open until \(end.formatted(date: .omitted, time: .shortened))"
        case .grace(let end, _):
            return "Late grace period (ended \(end.formatted(date: .omitted, time: .shortened)))"
        case .closed(let end):
            return "Window closed at \(end.formatted(date: .omitted, time: .shortened))"
        }
    }
    
    /// Can Dose 2 be logged right now without override?
    var canLogImmediately: Bool {
        switch self {
        case .open:
            return true
        default:
            return false
        }
    }
    
    /// Minutes until window opens (nil if already open or past)
    var minutesUntilOpen: Int? {
        switch self {
        case .waiting(let start):
            return Int(start.timeIntervalSinceNow / 60)
        default:
            return nil
        }
    }
    
    /// Minutes since window ended (nil if not yet ended)
    var minutesPastEnd: Int? {
        switch self {
        case .grace(let end, _), .closed(let end):
            return Int(-end.timeIntervalSinceNow / 60)
        default:
            return nil
        }
    }
    
    /// Minutes before window starts (negative if early)
    /// Used for early override calculations
    func minutesBeforeStart(now: Date) -> Int? {
        switch self {
        case .waiting(let start):
            return Int(start.timeIntervalSince(now) / 60)
        default:
            return nil
        }
    }
}

// MARK: - Override Policy Gates

extension WindowState {
    /// Override severity level based on timing
    enum OverrideSeverity {
        case normal      // Within policy limits (early or late grace)
        case critical    // Beyond grace, requires double confirm
    }
    
    /// Gate for early Dose 2 attempts
    /// - Parameters:
    ///   - now: Current time
    ///   - maxEarlyMin: Policy limit (e.g., 60)
    /// - Returns: nil if not early, severity if early
    func earlyOverrideGate(now: Date, maxEarlyMin: Int) -> OverrideSeverity? {
        guard case .waiting(let start) = self else {
            return nil
        }
        
        let minutesEarly = Int(start.timeIntervalSince(now) / 60)
        if minutesEarly <= maxEarlyMin {
            return .normal
        } else {
            return .critical  // Too early, requires escalated confirm
        }
    }
    
    /// Gate for late Dose 2 attempts
    /// - Parameters:
    ///   - now: Current time
    ///   - maxLateMin: Policy limit (e.g., 30)
    /// - Returns: nil if not late, severity if late
    func lateOverrideGate(now: Date, maxLateMin: Int) -> OverrideSeverity? {
        switch self {
        case .grace(let end, _):
            // In grace period - normal severity
            return .normal
        case .closed(let end):
            let minutesLate = Int(now.timeIntervalSince(end) / 60)
            if minutesLate <= maxLateMin {
                return .normal
            } else {
                return .critical  // Very late, requires escalated confirm
            }
        default:
            return nil
        }
    }
}

// MARK: - Time Zone Handling

extension WindowState {
    /// Detect if time zone has changed since Dose 1
    /// - Parameters:
    ///   - dose1TimeZone: Time zone when Dose 1 was logged
    ///   - currentTimeZone: Current device time zone
    /// - Returns: true if rebase is needed
    static func needsRebase(dose1TimeZone: TimeZone, currentTimeZone: TimeZone) -> Bool {
        dose1TimeZone != currentTimeZone
    }
    
    /// Calculate rebase info for UI display
    /// - Parameters:
    ///   - dose1: Original Dose 1 time
    ///   - startMin: Window start offset
    ///   - endMin: Window end offset
    ///   - oldZone: Original time zone
    ///   - newZone: Current time zone
    /// - Returns: Description of old vs new window times
    static func rebaseInfo(
        dose1: Date,
        startMin: Int,
        endMin: Int,
        oldZone: TimeZone,
        newZone: TimeZone
    ) -> String {
        var oldCalendar = Calendar.current
        oldCalendar.timeZone = oldZone
        
        var newCalendar = Calendar.current
        newCalendar.timeZone = newZone
        
        guard let oldStart = oldCalendar.date(byAdding: .minute, value: startMin, to: dose1),
              let oldEnd = oldCalendar.date(byAdding: .minute, value: endMin, to: dose1),
              let newStart = newCalendar.date(byAdding: .minute, value: startMin, to: dose1),
              let newEnd = newCalendar.date(byAdding: .minute, value: endMin, to: dose1) else {
            return "Time zone changed. Review window timing."
        }
        
        let oldFormatter = DateFormatter()
        oldFormatter.timeZone = oldZone
        oldFormatter.timeStyle = .short
        
        let newFormatter = DateFormatter()
        newFormatter.timeZone = newZone
        newFormatter.timeStyle = .short
        
        return """
        Old window: \(oldFormatter.string(from: oldStart))–\(oldFormatter.string(from: oldEnd)) (\(oldZone.abbreviation() ?? ""))
        New window: \(newFormatter.string(from: newStart))–\(newFormatter.string(from: newEnd)) (\(newZone.abbreviation() ?? ""))
        """
    }
}
