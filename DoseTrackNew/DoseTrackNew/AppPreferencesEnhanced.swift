//
//  AppPreferencesEnhanced.swift
//  DoseTrack
//
//  Enhanced AppPreferences combining @Observable with App Group persistence
//  Backward compatible with review bundle's Codable struct
//

import SwiftUI

/// AppPreferences: Single source of truth for all user preferences.
/// Uses @AppStorage with App Group UserDefaults for automatic persistence and widget/extension access.
/// Note: @AppStorage already provides SwiftUI reactivity, so @Observable is not needed (and causes conflicts)
final class AppPreferencesEnhanced {
    static let shared = AppPreferencesEnhanced()
    private static let suite = UserDefaults(suiteName: "group.com.jefferson.dosetrack")!
    private static let legacyKey = "AppPreferences.v1"
    
    // MARK: - Night Plan Defaults
    
    @AppStorage("plan_total_night_grams", store: suite) 
    var totalNightGrams: Double = 6.5
    
    @AppStorage("plan_split_strategy", store: suite) 
    var splitStrategy: String = "50/50" // "50/50", "60/40", "40/60"
    
    @AppStorage("plan_rounding_step_g", store: suite) 
    var roundingStepG: Double = 0.25
    
    @AppStorage("plan_window_start_min", store: suite) 
    var windowStartMin: Int = 150
    
    @AppStorage("plan_window_end_min", store: suite) 
    var windowEndMin: Int = 240
    
    @AppStorage("plan_allow_tonight_edit", store: suite) 
    var allowTonightEdit: Bool = true
    
    // MARK: - Service-Day Cutoff & Planning Horizon
    
    @AppStorage("service_cutoff_hour_local", store: suite)
    var cutoffHourLocal: Int = 12 // Noon cutoff by default
    
    @AppStorage("show_seconds", store: suite)
    var showSeconds: Bool = false // Show seconds in time pickers and event log
    
    @AppStorage("weekly_schedule_json", store: suite)
    var weeklyScheduleJSON: String = "" // Encoded WeeklyScheduleProfile
    
    @AppStorage("max_shift_per_night_min", store: suite)
    var maxShiftPerNightMin: Int = 30 // Max bedtime shift to maintain circadian rhythm
    
    @AppStorage("time_zone_lock", store: suite)
    var timeZoneLock: String = "local" // "local", "home", "ask"
    
    @AppStorage("home_time_zone", store: suite)
    var homeTimeZone: String = TimeZone.current.identifier
    
    @AppStorage("last_known_time_zone", store: suite)
    var lastKnownTimeZone: String = TimeZone.current.identifier
    
    // MARK: - Early Dose 2 Policy
    
    @AppStorage("early_allow_dose_2", store: suite) 
    var allowEarlyDose: Bool = false
    
    @AppStorage("early_max_minutes", store: suite) 
    var maxEarlyMinutes: Int = 15
    
    @AppStorage("early_require_reason", store: suite) 
    var requireEarlyReason: Bool = true
    
    @AppStorage("early_time_prior_defaults", store: suite) 
    var earlyTimePriorDefaults: String = "5,10" // Comma-separated list
    
    // MARK: - Late Dose 2 Override Policy
    
    @AppStorage("late_dose_allow", store: suite)
    var allowLateDose: Bool = true
    
    @AppStorage("late_dose_require_reason", store: suite)
    var lateRequireReason: Bool = true
    
    @AppStorage("late_dose_max_minutes", store: suite)
    var maxLateMinutes: Int = 120
    
    @AppStorage("late_dose_quick_choices", store: suite)
    var lateQuickChoicesCSV: String = "5,10,15,30"
    
    // MARK: - Notifications & Live Activity
    
    @AppStorage("alarm_style_raw", store: suite)
    var alarmStyleRaw: String = "normal" // "off", "quiet", "normal", "strong"
    
    var alarmStyle: NightAlarmPlan.AlarmStyle {
        get { NightAlarmPlan.AlarmStyle(rawValue: alarmStyleRaw) ?? .normal }
        set { alarmStyleRaw = newValue.rawValue }
    }
    
    @AppStorage("live_activity_enabled", store: suite) 
    var liveActivityEnabled: Bool = true
    
    @AppStorage("notify_at_start", store: suite) 
    var notifyAtStart: Bool = true
    
    @AppStorage("notify_at_half", store: suite) 
    var notifyAtHalf: Bool = false
    
    @AppStorage("notify_at_end", store: suite) 
    var notifyAtEnd: Bool = true
    
    @AppStorage("quiet_hours_start", store: suite) 
    var quietHoursStart: Int = 22 // 10 PM
    
    @AppStorage("quiet_hours_end", store: suite) 
    var quietHoursEnd: Int = 7 // 7 AM
    
    @AppStorage("haptics_enabled", store: suite) 
    var hapticsEnabled: Bool = true
    
    // MARK: - Data Sources
    
    @AppStorage("health_sample_window_min", store: suite) 
    var healthSampleWindowMin: Int = 120
    
    @AppStorage("whoop_proxy_url", store: suite) 
    var whoopProxyURL: String = ""
    
    @AppStorage("whoop_api_key", store: suite) 
    var whoopAPIKey: String = ""
    
    @AppStorage("wake_source_preference", store: suite) 
    var wakeSourcePreference: String = "health" // "health", "manual"
    
    // MARK: - Exports
    
    @AppStorage("export_include_timezone", store: suite) 
    var exportIncludeTimezone: Bool = true
    
    @AppStorage("export_filename_pattern", store: suite) 
    var exportFilenamePattern: String = "dosetrack_{nightKey}"
    
    @AppStorage("export_include_notes", store: suite) 
    var exportIncludeNotes: Bool = true
    
    @AppStorage("export_include_event_log", store: suite) 
    var exportIncludeEventLog: Bool = false
    
    @AppStorage("export_default_email", store: suite) 
    var exportDefaultEmail: String = ""
    
    // MARK: - Privacy & Retention
    
    @AppStorage("require_biometric", store: suite) 
    var requireBiometric: Bool = false
    
    @AppStorage("mask_widget_doses", store: suite) 
    var maskWidgetDoses: Bool = false
    
    @AppStorage("retention_days", store: suite) 
    var retentionDays: Int = 365
    
    // MARK: - Reset Night
    
    @AppStorage("reset_allow_hard", store: suite)
    var resetAllowHard: Bool = true
    
    @AppStorage("reset_require_biometric_hard", store: suite)
    var resetRequireBiometricHard: Bool = false
    
    @AppStorage("reset_undo_window_sec", store: suite)
    var resetUndoWindowSec: Int = 30
    
    @AppStorage("reset_reason_required", store: suite)
    var resetReasonRequired: Bool = true
    
    // MARK: - Debug & Developer
    
    @AppStorage("show_internals", store: suite) 
    var showInternals: Bool = false
    
    // MARK: - Computed Properties (for backward compatibility with review bundle)
    
    /// Planned Dose 1 amount (first dose of the night)
    var planDose1G: Double {
        Self.round(totalNightGrams * splitFraction.first, step: roundingStepG)
    }
    
    /// Planned Dose 2 amount (second dose of the night)
    var planDose2G: Double {
        Self.round(totalNightGrams * splitFraction.second, step: roundingStepG)
    }
    
    /// Early dose button values parsed from comma-separated string
    var defaultEarlyButtons: [Int] {
        earlyTimePriorDefaults.split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
    
    /// Weekly schedule profile (decoded from JSON)
    var weeklySchedule: WeeklyScheduleProfile {
        get {
            guard !weeklyScheduleJSON.isEmpty,
                  let data = weeklyScheduleJSON.data(using: .utf8),
                  let profile = try? JSONDecoder().decode(WeeklyScheduleProfile.self, from: data) else {
                return .default
            }
            return profile
        }
        set {
            if let data = try? JSONEncoder().encode(newValue),
               let json = String(data: data, encoding: .utf8) {
                weeklyScheduleJSON = json
            }
        }
    }
    
    /// Timezone policy enum
    var timeZonePolicy: WeeklyScheduleProfile.TimeZonePolicy {
        get {
            WeeklyScheduleProfile.TimeZonePolicy(rawValue: timeZoneLock) ?? .local
        }
        set {
            timeZoneLock = newValue.rawValue
        }
    }
    
    /// Split fractions for dose calculations
    private var splitFraction: (first: Double, second: Double) {
        switch splitStrategy {
        case "60/40": return (0.6, 0.4)
        case "40/60": return (0.4, 0.6)
        default: return (0.5, 0.5) // "50/50"
        }
    }
    
    // MARK: - Helpers
    
    /// Round value to nearest step
    static func round(_ value: Double, step: Double) -> Double {
        (value / step).rounded() * step
    }
    
    /// Calculate planned dose amounts based on total and split strategy
    func calculateDoses() -> (dose1: Double, dose2: Double) {
        return (planDose1G, planDose2G)
    }
    
    /// Check if planned dose amounts violate safety guardrails
    var planViolatesSafety: Bool {
        let (d1, d2) = calculateDoses()
        let perDoseMin = 1.5, perDoseMax = 4.5
        let nightlyMin = 3.0, nightlyMax = 9.0
        
        return d1 < perDoseMin || d1 > perDoseMax ||
               d2 < perDoseMin || d2 > perDoseMax ||
               totalNightGrams < nightlyMin || totalNightGrams > nightlyMax
    }
    
    /// Available options for early dose time prior picker
    var earlyTimePriorOptions: [Int] {
        Array(stride(from: 5, through: 30, by: 5))
    }
    
    /// Reset all preferences to default values
    func resetToDefaults() {
        totalNightGrams = 6.5
        splitStrategy = "50/50"
        roundingStepG = 0.25
        windowStartMin = 150
        windowEndMin = 240
        allowTonightEdit = true
        
        allowEarlyDose = false
        maxEarlyMinutes = 15
        requireEarlyReason = true
        earlyTimePriorDefaults = "5,10"
        
        liveActivityEnabled = true
        notifyAtStart = true
        notifyAtHalf = false
        notifyAtEnd = true
        quietHoursStart = 22
        quietHoursEnd = 7
        hapticsEnabled = true
        
        healthSampleWindowMin = 120
        whoopProxyURL = ""
        whoopAPIKey = ""
        wakeSourcePreference = "health"
        
        exportIncludeTimezone = true
        exportFilenamePattern = "dosetrack_{nightKey}"
        exportIncludeNotes = true
        exportIncludeEventLog = false
        exportDefaultEmail = ""
        
        requireBiometric = false
        maskWidgetDoses = false
        retentionDays = 365
        
        showInternals = false
    }
    
    // MARK: - Migration from Legacy Codable Version
    
    /// Migrate from review bundle's Codable struct if present
    static func migrateFromLegacyIfNeeded() {
        struct LegacyPreferences: Codable {
            var totalNightG: Double?
            var split: String?
            var roundingStepG: Double?
            var windowStartMin: Int?
            var windowEndMin: Int?
            var allowEarlyDose: Bool?
            var maxEarlyMinutes: Int?
            var requireEarlyReason: Bool?
            var defaultEarlyButtons: [Int]?
            var liveActivityEnabled: Bool?
            var notifyAtStart: Bool?
            var notifyAtHalf: Bool?
            var notifyAtEnd: Bool?
        }
        
        guard let data = suite.data(forKey: legacyKey),
              let legacy = try? JSONDecoder().decode(LegacyPreferences.self, from: data) else {
            return
        }
        
        print("📦 Migrating from legacy AppPreferences Codable struct...")
        
        // Migrate values to @AppStorage
        let prefs = shared
        if let val = legacy.totalNightG { prefs.totalNightGrams = val }
        if let val = legacy.roundingStepG { prefs.roundingStepG = val }
        if let val = legacy.windowStartMin { prefs.windowStartMin = val }
        if let val = legacy.windowEndMin { prefs.windowEndMin = val }
        if let val = legacy.allowEarlyDose { prefs.allowEarlyDose = val }
        if let val = legacy.maxEarlyMinutes { prefs.maxEarlyMinutes = val }
        if let val = legacy.requireEarlyReason { prefs.requireEarlyReason = val }
        if let buttons = legacy.defaultEarlyButtons {
            prefs.earlyTimePriorDefaults = buttons.map(String.init).joined(separator: ",")
        }
        if let val = legacy.liveActivityEnabled { prefs.liveActivityEnabled = val }
        if let val = legacy.notifyAtStart { prefs.notifyAtStart = val }
        if let val = legacy.notifyAtHalf { prefs.notifyAtHalf = val }
        if let val = legacy.notifyAtEnd { prefs.notifyAtEnd = val }
        
        // Convert split enum to string
        if let split = legacy.split {
            switch split {
            case "sixtyForty": prefs.splitStrategy = "60/40"
            case "fortySixty": prefs.splitStrategy = "40/60"
            default: prefs.splitStrategy = "50/50"
            }
        }
        
        // Clear legacy data (commented out for safety - user can delete manually)
        // suite.removeObject(forKey: legacyKey)
        
        print("✅ Migration complete")
    }
    
    // MARK: - Codable Compatibility (for review bundle's TodayViewModel)
    
    /// Create a lightweight struct compatible with review bundle's AppPreferences protocol
    func toLegacyStruct() -> LegacyAppPreferences {
        LegacyAppPreferences(
            totalNightG: totalNightGrams,
            split: splitToEnum(),
            roundingStepG: roundingStepG,
            windowStartMin: windowStartMin,
            windowEndMin: windowEndMin,
            allowEarlyDose: allowEarlyDose,
            maxEarlyMinutes: maxEarlyMinutes,
            requireEarlyReason: requireEarlyReason,
            defaultEarlyButtons: defaultEarlyButtons,
            liveActivityEnabled: liveActivityEnabled,
            notifyAtStart: notifyAtStart,
            notifyAtHalf: notifyAtHalf,
            notifyAtEnd: notifyAtEnd,
            allowLateDose: allowLateDose,
            maxLateMinutes: maxLateMinutes,
            lateRequireReason: lateRequireReason
        )
    }
    
    private func splitToEnum() -> LegacyAppPreferences.Split {
        switch splitStrategy {
        case "60/40": return .sixtyForty
        case "40/60": return .fortySixty
        default: return .fiftyFifty
        }
    }
}

// MARK: - Legacy Compatibility Struct

/// Lightweight struct compatible with review bundle's TodayViewModel
struct LegacyAppPreferences: Codable, Equatable {
    var totalNightG: Double
    var split: Split
    var roundingStepG: Double
    var windowStartMin: Int
    var windowEndMin: Int
    var allowEarlyDose: Bool
    var maxEarlyMinutes: Int
    var requireEarlyReason: Bool
    var defaultEarlyButtons: [Int]
    var liveActivityEnabled: Bool
    var notifyAtStart: Bool
    var notifyAtHalf: Bool
    var notifyAtEnd: Bool
    var allowLateDose: Bool
    var maxLateMinutes: Int
    var lateRequireReason: Bool
    
    var planDose1G: Double {
        AppPreferencesEnhanced.round(totalNightG * split.firstFraction, step: roundingStepG)
    }
    
    var planDose2G: Double {
        AppPreferencesEnhanced.round(totalNightG * split.secondFraction, step: roundingStepG)
    }
    
    enum Split: String, Codable, CaseIterable {
        case fiftyFifty
        case sixtyForty
        case fortySixty
        case custom
        
        var firstFraction: Double {
            switch self {
            case .fiftyFifty: return 0.5
            case .sixtyForty: return 0.6
            case .fortySixty: return 0.4
            case .custom: return 0.5
            }
        }
        
        var secondFraction: Double {
            1.0 - firstFraction
        }
    }
}
