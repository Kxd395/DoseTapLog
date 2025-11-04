//
//  TapBehavior.swift
//  DoseTrack
//
//  Tap behavior policies for action buttons (Quick/Confirm/Smart modes)
//  Supports global + per-action overrides for flexible UX
//

import Foundation

/// Night actions that can be logged
enum NightAction: String, CaseIterable, Identifiable {
    case inBed = "in_bed"
    case dose1 = "dose1"
    case dose2 = "dose2"
    case finalWake = "final_wake"
    case alarmWake = "alarm_wake"
    case naturalWake = "natural_wake"
    case bathroom = "bathroom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .inBed: return "In Bed"
        case .dose1: return "Dose 1"
        case .dose2: return "Dose 2"
        case .finalWake: return "Final Wake"
        case .alarmWake: return "Alarm Wake"
        case .naturalWake: return "Natural Wake"
        case .bathroom: return "Bathroom"
        }
    }
    
    var icon: String {
        switch self {
        case .inBed: return "bed.double.fill"
        case .dose1: return "pills.fill"
        case .dose2: return "pills.circle.fill"
        case .finalWake: return "sunrise.fill"
        case .alarmWake: return "alarm.fill"
        case .naturalWake: return "figure.walk"
        case .bathroom: return "toilet.fill"
        }
    }
}

/// Tap behavior mode for action buttons
enum TapBehavior: Equatable, Codable {
    case quickLog                           // Single tap logs now immediately
    case confirmSheet                       // Single tap opens confirmation sheet
    case smart(thresholdSec: Int)          // Smart: recent tap logs now, else opens sheet
    
    var displayName: String {
        switch self {
        case .quickLog:
            return "Quick Log"
        case .confirmSheet:
            return "Confirm Sheet"
        case .smart(let sec):
            return "Smart (\(sec)s)"
        }
    }
    
    var description: String {
        switch self {
        case .quickLog:
            return "Single tap logs immediately"
        case .confirmSheet:
            return "Single tap opens time adjustment sheet"
        case .smart(let sec):
            return "Single tap logs now if within \(sec)s, otherwise opens sheet"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case type
        case thresholdSec
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "quickLog":
            self = .quickLog
        case "confirmSheet":
            self = .confirmSheet
        case "smart":
            let threshold = try container.decode(Int.self, forKey: .thresholdSec)
            self = .smart(thresholdSec: threshold)
        default:
            self = .confirmSheet
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .quickLog:
            try container.encode("quickLog", forKey: .type)
        case .confirmSheet:
            try container.encode("confirmSheet", forKey: .type)
        case .smart(let threshold):
            try container.encode("smart", forKey: .type)
            try container.encode(threshold, forKey: .thresholdSec)
        }
    }
}

/// Tap policy for all actions (global + per-action overrides)
struct TapPolicy: Codable {
    var global: TapBehavior
    var smartThresholdSec: Int              // Default threshold for smart mode
    
    // Per-action overrides (nil = use global)
    var overrideInBed: TapBehavior?
    var overrideDose1: TapBehavior?
    var overrideDose2: TapBehavior?
    var overrideFinalWake: TapBehavior?
    var overrideAlarmWake: TapBehavior?
    var overrideNaturalWake: TapBehavior?
    var overrideBathroom: TapBehavior?
    
    // UI preferences
    var showSeconds: Bool
    var showQuickPresets: Bool
    
    /// Default policy (safe defaults)
    static var defaultPolicy: TapPolicy {
        return TapPolicy(
            global: .smart(thresholdSec: 90),
            smartThresholdSec: 90,
            overrideInBed: .quickLog,           // Quick: log in bed immediately
            overrideDose1: nil,                 // Smart: use global
            overrideDose2: .confirmSheet,       // ALWAYS confirm Dose 2 (gate enforcement)
            overrideFinalWake: .confirmSheet,   // ALWAYS confirm final wake (closes night)
            overrideAlarmWake: nil,             // Smart: use global
            overrideNaturalWake: nil,           // Smart: use global
            overrideBathroom: .quickLog,        // Quick: log bathroom immediately
            showSeconds: true,
            showQuickPresets: true
        )
    }
    
    /// Get effective behavior for an action
    func behavior(for action: NightAction) -> TapBehavior {
        switch action {
        case .inBed:
            return overrideInBed ?? global
        case .dose1:
            return overrideDose1 ?? global
        case .dose2:
            // CRITICAL: Dose 2 ALWAYS uses confirmSheet as minimum (never quickLog)
            // Even if user sets quickLog, we enforce confirmSheet for safety
            return overrideDose2 ?? .confirmSheet
        case .finalWake:
            // CRITICAL: Final wake ALWAYS confirms (closes night)
            return overrideFinalWake ?? .confirmSheet
        case .alarmWake:
            return overrideAlarmWake ?? global
        case .naturalWake:
            return overrideNaturalWake ?? global
        case .bathroom:
            return overrideBathroom ?? global
        }
    }
    
    /// Override for specific action
    mutating func setOverride(_ behavior: TapBehavior?, for action: NightAction) {
        switch action {
        case .inBed:
            overrideInBed = behavior
        case .dose1:
            overrideDose1 = behavior
        case .dose2:
            // CRITICAL: Dose 2 cannot be set to quickLog
            if case .quickLog = behavior {
                overrideDose2 = .confirmSheet
            } else {
                overrideDose2 = behavior
            }
        case .finalWake:
            // CRITICAL: Final wake cannot be set to quickLog
            if case .quickLog = behavior {
                overrideFinalWake = .confirmSheet
            } else {
                overrideFinalWake = behavior
            }
        case .alarmWake:
            overrideAlarmWake = behavior
        case .naturalWake:
            overrideNaturalWake = behavior
        case .bathroom:
            overrideBathroom = behavior
        }
    }
}

/// Timestamp tracking for smart mode
class ActionTimestampTracker: ObservableObject {
    @Published private var timestamps: [NightAction: Date] = [:]
    
    /// Record action timestamp
    func record(_ action: NightAction, at time: Date = Date()) {
        timestamps[action] = time
    }
    
    /// Get last timestamp for action
    func lastTimestamp(for action: NightAction) -> Date? {
        return timestamps[action]
    }
    
    /// Check if action was recent (within threshold)
    func isRecent(_ action: NightAction, now: Date = Date(), threshold: Int) -> Bool {
        guard let last = timestamps[action] else { return false }
        let elapsed = abs(now.timeIntervalSince(last))
        return elapsed <= Double(threshold)
    }
    
    /// Clear all timestamps
    func clear() {
        timestamps.removeAll()
    }
    
    /// Clear timestamp for specific action
    func clear(_ action: NightAction) {
        timestamps.removeValue(forKey: action)
    }
}

extension TapBehavior {
    /// VoiceOver hint for tap behavior
    func voiceOverHint(action: NightAction) -> String {
        switch self {
        case .quickLog:
            return "Double-tap to log \(action.displayName) now. Long-press to set a time."
        case .confirmSheet:
            return "Double-tap to open time picker. Long-press for more options."
        case .smart(let sec):
            return "Double-tap to log \(action.displayName). Long-press to set a time. Smart mode: logs immediately if tapped within \(sec) seconds."
        }
    }
}
