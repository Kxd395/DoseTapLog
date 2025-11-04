//
//  Dose2Gate.swift
//  DoseTrack
//
//  Dose 2 override gate logic with early/late policy enforcement
//

import Foundation

/// Gate states for Dose 2 button
enum Dose2Gate {
    case needDose1
    case ready                      // within window
    case tooEarly(minutes: Int)
    case tooLate(minutes: Int)
    case alreadyLogged
    case noWakeGuard(minutesUntilWake: Int)  // NEW: Too close to morning wake
}

/// Alarm style for Dose 2 soft-wake notifications
enum Dose2AlarmStyle: String, CaseIterable {
    case off = "off"
    case banner = "banner"          // Silent notification only
    case soft = "soft"              // Time-sensitive, respects quiet hours
    case strong = "strong"          // Loops until acknowledged
    
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .banner: return "Banner Only"
        case .soft: return "Soft"
        case .strong: return "Strong"
        }
    }
}

/// Policy configuration for Dose 2 timing
struct Dose2Policy {
    let startMin: Int
    let endMin: Int
    let allowEarly: Bool
    let maxEarlyMin: Int
    let allowLate: Bool
    let maxLateMin: Int
    
    // NEW: No-Wake Guard settings
    let workdayNoWakeBufferMin: Int
    let offdayNoWakeBufferMin: Int
    let allowGuardOverride: Bool
    
    /// Create policy from AppPreferencesEnhanced
    static func from(_ prefs: AppPreferencesEnhanced) -> Dose2Policy {
        return Dose2Policy(
            startMin: prefs.windowStartMin,
            endMin: prefs.windowEndMin,
            allowEarly: prefs.allowEarlyDose,
            maxEarlyMin: prefs.maxEarlyMinutes,
            allowLate: prefs.allowLateDose,
            maxLateMin: prefs.maxLateMinutes,
            workdayNoWakeBufferMin: prefs.workdayNoWakeBufferMin,
            offdayNoWakeBufferMin: prefs.offdayNoWakeBufferMin,
            allowGuardOverride: prefs.allowGuardOverride
        )
    }
}

/// Override data for audit trail
struct Dose2Override {
    let kind: OverrideKind
    let minutes: Int                    // positive minutes early/late
    let reason: String
    let timePriorChoiceMin: Int?        // 0 for "Now", or 5/10 etc.
    let policyVersion: String           // e.g., "1.1.2"
    let source: OverrideSource
    
    enum OverrideKind: String {
        case early = "early"
        case late = "late"
        case guard = "guard"            // NEW: Override from no-wake guard
    }
    
    enum OverrideSource: String {
        case inApp = "in_app"
        case notification = "notification"
        case watch = "watch"
    }
}

/// Evaluate Dose 2 gate state
func evaluateDose2Gate(
    now: Date,
    dose1At: Date?,
    dose2At: Date?,
    policy: Dose2Policy,
    plannedFinalWake: Date?,
    isWorkday: Bool
) -> Dose2Gate {
    if dose2At != nil { return .alreadyLogged }
    guard let dose1 = dose1At else { return .needDose1 }
    
    // GUARD CHECK FIRST: Too close to morning wake?
    if let wake = plannedFinalWake {
        let minutesUntilWake = Int(wake.timeIntervalSince(now) / 60.0)
        let guardBuffer = isWorkday ? policy.workdayNoWakeBufferMin : policy.offdayNoWakeBufferMin
        
        if minutesUntilWake <= guardBuffer && minutesUntilWake > 0 {
            return .noWakeGuard(minutesUntilWake: minutesUntilWake)
        }
    }
    
    // STANDARD WINDOW MATH
    let elapsedMin = Int(now.timeIntervalSince(dose1) / 60.0)
    
    // Too early
    if elapsedMin < policy.startMin {
        let early = policy.startMin - elapsedMin
        return .tooEarly(minutes: early)
    }
    
    // Too late
    if elapsedMin > policy.endMin {
        let late = elapsedMin - policy.endMin
        return .tooLate(minutes: late)
    }
    
    // Ready!
    return .ready
}

/// Check if override is allowed given gate state and policy
func isOverrideAllowed(gate: Dose2Gate, policy: Dose2Policy) -> Bool {
    switch gate {
    case .tooEarly(let minutes):
        return policy.allowEarly && minutes <= policy.maxEarlyMin
    case .tooLate(let minutes):
        return policy.allowLate && minutes <= policy.maxLateMin
    case .noWakeGuard:
        return policy.allowGuardOverride
    default:
        return false
    }
}

/// Accessibility hint for Dose 2 button
func dose2AccessibilityHint(gate: Dose2Gate) -> String {
    switch gate {
    case .needDose1:
        return "Locked: Log Dose 1 first"
    case .ready:
        return "Ready now"
    case .tooEarly(let m):
        return "Locked: wait \(m) minutes"
    case .tooLate(let m):
        return "Late by \(m) minutes"
    case .alreadyLogged:
        return "Already logged"
    case .noWakeGuard(let m):
        return "Guard: \(m) minutes to wake"
    }
}
