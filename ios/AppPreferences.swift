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
    
    // MARK: - Night Plan Defaults
    
    @AppStorage("plan_total_night_grams")
    var totalNightGrams: Double = 6.5
    
    @AppStorage("plan_split_strategy")
    var splitStrategy: String = "50-50"
    
    @AppStorage("plan_rounding_increment")
    var roundingIncrement: Double = 0.25
    
    @AppStorage("dose2_window_start_min")
    var windowStartMin: Int = 150
    
    @AppStorage("dose2_window_end_min")
    var windowEndMin: Int = 240
    
    @AppStorage("allow_tonight_only_edit")
    var allowTonightEdit: Bool = true
    
    // MARK: - Early Dose 2 Policy
    
    @AppStorage("allow_early_dose")
    var allowEarlyDose: Bool = false
    
    @AppStorage("max_early_minutes")
    var maxEarlyMinutes: Int = 15
    
    @AppStorage("early_require_reason")
    var earlyRequireReason: Bool = true
    
    @AppStorage("early_time_prior_defaults")
    var earlyTimePriorDefaults: String = "5,10"
    
    // MARK: - Notifications & Live Activity
    
    @AppStorage("notifications_live_activity_enabled")
    var liveActivityEnabled: Bool = true
    
    @AppStorage("notifications_window_start")
    var notifyWindowStart: Bool = true
    
    @AppStorage("notifications_halfway")
    var notifyHalfway: Bool = false
    
    @AppStorage("notifications_window_end")
    var notifyWindowEnd: Bool = true
    
    @AppStorage("notifications_quiet_start")
    var quietHoursStart: String?
    
    @AppStorage("notifications_quiet_end")
    var quietHoursEnd: String?
    
    @AppStorage("notifications_haptics_enabled")
    var hapticsEnabled: Bool = true
    
    // MARK: - Data Sources
    
    @AppStorage("health_sample_window_min")
    var healthSampleWindowMin: Int = 60
    
    @AppStorage("whoop_proxy_url")
    var whoopProxyURL: String = ""
    
    @AppStorage("whoop_api_key")
    var whoopAPIKey: String = ""
    
    @AppStorage("wake_source_preference")
    var wakeSourcePreference: String = "Health"
    
    // MARK: - Exports
    
    @AppStorage("export_include_timezone")
    var exportIncludeTimezone: Bool = true
    
    @AppStorage("export_filename_pattern")
    var exportFilenamePattern: String = "DoseTrack_yyyyMMdd.csv"
    
    @AppStorage("export_include_notes")
    var exportIncludeNotes: Bool = true
    
    @AppStorage("export_include_event_log")
    var exportIncludeEventLog: Bool = false
    
    @AppStorage("export_default_email")
    var exportDefaultEmail: String = ""
    
    // MARK: - Privacy & Retention
    
    @AppStorage("privacy_require_biometric")
    var requireBiometric: Bool = false
    
    @AppStorage("privacy_mask_widget_doses")
    var maskWidgetDoses: Bool = true
    
    @AppStorage("privacy_retention_days")
    var retentionDays: Int = 365
    
    // MARK: - Debug
    
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
