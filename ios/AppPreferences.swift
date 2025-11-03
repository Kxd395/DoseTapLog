//
//  AppPreferences.swift
//  DoseTrack
//
//  Single source of truth for all user settings using @AppStorage
//  Aligned with .specify/memory/spec.md Settings Panel specification
//

import SwiftUI
import Observation

@Observable
final class AppPreferences {
    
    // MARK: - Supporting Types
    
    /// Do Not Disturb / Focus mode policy
    enum DNDPolicy: String, Codable, CaseIterable {
        case off = "off"                    // Always interrupt
        case timeSensitive = "timeSensitive" // Use Time Sensitive interruption
        case ask = "ask"                    // Ask user on first alarm
        
        var description: String {
            switch self {
            case .off: return "Always notify (ignore Focus)"
            case .timeSensitive: return "Time Sensitive (requires permission)"
            case .ask: return "Ask me"
            }
        }
    }
    
    // MARK: - Night Plan Defaults
    
    @ObservationIgnored
    @AppStorage("plan_total_night_grams")
    var totalNightGrams: Double = 6.5
    
    @ObservationIgnored
    @AppStorage("plan_split_strategy")
    var splitStrategy: String = "50-50"
    
    @ObservationIgnored
    @AppStorage("plan_rounding_increment")
    var roundingIncrement: Double = 0.25
    
    @ObservationIgnored
    @AppStorage("dose2_window_start_min")
    var windowStartMin: Int = 150
    
    @ObservationIgnored
    @AppStorage("dose2_window_end_min")
    var windowEndMin: Int = 240
    
    @ObservationIgnored
    @AppStorage("allow_tonight_only_edit")
    var allowTonightEdit: Bool = true
    
    // MARK: - Early Dose 2 Policy
    
    @ObservationIgnored
    @AppStorage("allow_early_dose")
    var allowEarlyDose: Bool = false
    
    @ObservationIgnored
    @AppStorage("max_early_minutes")
    var maxEarlyMinutes: Int = 15
    
    @ObservationIgnored
    @AppStorage("early_require_reason")
    var earlyRequireReason: Bool = true
    
    @ObservationIgnored
    @AppStorage("early_time_prior_defaults")
    var earlyTimePriorDefaults: String = "5,10"
    
    // MARK: - Late Dose 2 Policy
    
    @ObservationIgnored
    @AppStorage("allow_late_dose")
    var allowLateDose: Bool = false
    
    @ObservationIgnored
    @AppStorage("max_late_minutes")
    var maxLateMinutes: Int = 30
    
    @ObservationIgnored
    @AppStorage("late_require_reason")
    var lateRequireReason: Bool = true
    
    @ObservationIgnored
    @AppStorage("late_grace_minutes")
    var lateGraceMinutes: Int = 15
    
    // MARK: - Alarm Ladder Policy
    
    @ObservationIgnored
    @AppStorage("alarm_style")
    var alarmStyleRaw: String = NightAlarmPlan.AlarmStyle.normal.rawValue
    
    /// Alarm style with type safety
    var alarmStyle: NightAlarmPlan.AlarmStyle {
        get { NightAlarmPlan.AlarmStyle(rawValue: alarmStyleRaw) ?? .normal }
        set { alarmStyleRaw = newValue.rawValue }
    }
    
    @ObservationIgnored
    @AppStorage("alarm_budget_per_night")
    var alarmBudgetPerNight: Int = 3
    
    @ObservationIgnored
    @AppStorage("pre_window_lead_minutes")
    var preWindowLeadMinutes: Int = 0  // 0 = disabled
    
    @ObservationIgnored
    @AppStorage("hard_after_end_enabled")
    var hardAfterEndEnabled: Bool = false
    
    @ObservationIgnored
    @AppStorage("hard_repeat_minutes")
    var hardRepeatMinutes: Int = 15
    
    @ObservationIgnored
    @AppStorage("hard_max_repeats")
    var hardMaxRepeats: Int = 3
    
    @ObservationIgnored
    @AppStorage("respect_dnd")
    var respectDNDRaw: String = DNDPolicy.timeSensitive.rawValue
    
    /// DND policy with type safety
    var respectDND: DNDPolicy {
        get { DNDPolicy(rawValue: respectDNDRaw) ?? .timeSensitive }
        set { respectDNDRaw = newValue.rawValue }
    }
    
    @ObservationIgnored
    @AppStorage("notifications_time_sensitive_consent")
    var timeSensitiveConsent: Bool = false
    
    @ObservationIgnored
    @AppStorage("strong_alarm_consent")
    var strongAlarmConsent: Bool = false
    
    // MARK: - Notifications & Live Activity
    
    @ObservationIgnored
    @AppStorage("notifications_live_activity_enabled")
    var liveActivityEnabled: Bool = true
    
    @ObservationIgnored
    @AppStorage("notifications_window_start")
    var notifyWindowStart: Bool = true
    
    /// Alias for compatibility
    var notifyAtStart: Bool {
        get { notifyWindowStart }
        set { notifyWindowStart = newValue }
    }
    
    @ObservationIgnored
    @AppStorage("notifications_halfway")
    var notifyHalfway: Bool = false
    
    /// Alias for compatibility
    var notifyAtHalf: Bool {
        get { notifyHalfway }
        set { notifyHalfway = newValue }
    }
    
    @ObservationIgnored
    @AppStorage("notifications_window_end")
    var notifyWindowEnd: Bool = true
    
    /// Alias for compatibility
    var notifyAtEnd: Bool {
        get { notifyWindowEnd }
        set { notifyWindowEnd = newValue }
    }
    
    @ObservationIgnored
    @AppStorage("notifications_quiet_start")
    var quietHoursStart: String?
    
    @ObservationIgnored
    @AppStorage("notifications_quiet_end")
    var quietHoursEnd: String?
    
    @ObservationIgnored
    @AppStorage("notifications_haptics_enabled")
    var hapticsEnabled: Bool = true
    
    /// Computed property for window duration
    var windowStartMinutes: Int {
        get { windowStartMin }
        set { windowStartMin = newValue }
    }
    
    var windowEndMinutes: Int {
        get { windowEndMin }
        set { windowEndMin = newValue }
    }
    
    // MARK: - Data Sources
    
    @ObservationIgnored
    @AppStorage("health_sample_window_min")
    var healthSampleWindowMin: Int = 60
    
    @ObservationIgnored
    @AppStorage("whoop_proxy_url")
    var whoopProxyURL: String = ""
    
    @ObservationIgnored
    @AppStorage("whoop_api_key")
    var whoopAPIKey: String = ""
    
    @ObservationIgnored
    @AppStorage("wake_source_preference")
    var wakeSourcePreference: String = "Health"
    
    // MARK: - Exports
    
    @ObservationIgnored
    @AppStorage("export_include_timezone")
    var exportIncludeTimezone: Bool = true
    
    @ObservationIgnored
    @AppStorage("export_filename_pattern")
    var exportFilenamePattern: String = "DoseTrack_yyyyMMdd.csv"
    
    @ObservationIgnored
    @AppStorage("export_include_notes")
    var exportIncludeNotes: Bool = true
    
    @ObservationIgnored
    @AppStorage("export_include_event_log")
    var exportIncludeEventLog: Bool = false
    
    @ObservationIgnored
    @AppStorage("export_default_email")
    var exportDefaultEmail: String = ""
    
    // MARK: - Privacy & Retention
    
    @ObservationIgnored
    @AppStorage("privacy_require_biometric")
    var requireBiometric: Bool = false
    
    @ObservationIgnored
    @AppStorage("privacy_mask_widget_doses")
    var maskWidgetDoses: Bool = true
    
    @ObservationIgnored
    @AppStorage("privacy_retention_days")
    var retentionDays: Int = 365
    
    // MARK: - Debug
    
    @ObservationIgnored
    @AppStorage("debug_show_internals")
    var showInternals: Bool = false
    
    // MARK: - Singleton
    
    static let shared = AppPreferences()
    
    // MARK: - Computed Properties
    
    /// Parse early time-prior defaults from comma-separated string
    var earlyTimePriorOptions: [Int] {
        earlyTimePriorDefaults
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
    
    /// Calculate Dose 1 and Dose 2 amounts based on current plan
    func calculateDoses() -> (dose1: Double, dose2: Double) {
        let total = totalNightGrams
        let (d1, d2): (Double, Double)
        
        switch splitStrategy {
        case "50-50":
            d1 = total / 2.0
            d2 = total / 2.0
        case "60-40":
            d1 = total * 0.6
            d2 = total * 0.4
        case "40-60":
            d1 = total * 0.4
            d2 = total * 0.6
        default: // "Custom"
            d1 = total / 2.0
            d2 = total / 2.0
        }
        
        return (roundDose(d1), roundDose(d2))
    }
    
    /// Round dose to configured increment (0.25g or 0.5g)
    private func roundDose(_ value: Double) -> Double {
        let increment = roundingIncrement
        return (value / increment).rounded() * increment
    }
    
    /// Validate current plan against safety guardrails
    var planViolatesSafety: Bool {
        let (d1, d2) = calculateDoses()
        let perDoseMin = 1.5
        let perDoseMax = 4.5
        let nightlyMin = 3.0
        let nightlyMax = 9.0
        
        if d1 < perDoseMin || d1 > perDoseMax { return true }
        if d2 < perDoseMin || d2 > perDoseMax { return true }
        if totalNightGrams < nightlyMin || totalNightGrams > nightlyMax { return true }
        
        return false
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
    static func migrateFromLegacy() {
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
        
        // Clear legacy data
        suite.removeObject(forKey: legacyKey)
    }
}
