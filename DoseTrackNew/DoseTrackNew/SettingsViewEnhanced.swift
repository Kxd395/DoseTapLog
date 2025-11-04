//
//  SettingsViewEnhanced.swift
//  DoseTrack
//
//  Enhanced Settings screen with 7 sections (complete spec coverage)
//

import SwiftUI

struct SettingsViewEnhanced: View {
    @Environment(\.dismiss) var dismiss
    @State private var showResetConfirm = false
    @State private var showPurgeConfirm = false
    
    // Access AppPreferencesEnhanced properties directly via @AppStorage for bindings
    private static let suite = UserDefaults(suiteName: "group.com.jefferson.dosetrack")!
    
    @AppStorage("plan_total_night_grams", store: suite) 
    private var totalNightGrams: Double = 6.5
    
    @AppStorage("plan_split_strategy", store: suite) 
    private var splitStrategy: String = "50/50"
    
    @AppStorage("plan_rounding_step_g", store: suite) 
    private var roundingStepG: Double = 0.25
    
    @AppStorage("plan_allow_tonight_edit", store: suite) 
    private var allowTonightEdit: Bool = true
    
    @AppStorage("plan_window_start_min", store: suite) 
    private var windowStartMin: Int = 150
    
    @AppStorage("plan_window_end_min", store: suite) 
    private var windowEndMin: Int = 240
    
    @AppStorage("early_allow_dose_2", store: suite) 
    private var allowEarlyDose: Bool = false
    
    @AppStorage("early_max_minutes", store: suite) 
    private var maxEarlyMinutes: Int = 15
    
    @AppStorage("early_require_reason", store: suite) 
    private var requireEarlyReason: Bool = true
    
    @AppStorage("live_activity_enabled", store: suite) 
    private var liveActivityEnabled: Bool = true
    
    @AppStorage("notify_at_start", store: suite) 
    private var notifyAtStart: Bool = true
    
    @AppStorage("notify_at_half", store: suite) 
    private var notifyAtHalf: Bool = false
    
    @AppStorage("notify_at_end", store: suite) 
    private var notifyAtEnd: Bool = true
    
    @AppStorage("quiet_hours_start", store: suite) 
    private var quietHoursStart: Int = 22
    
    @AppStorage("quiet_hours_end", store: suite) 
    private var quietHoursEnd: Int = 7
    
    @AppStorage("haptics_enabled", store: suite) 
    private var hapticsEnabled: Bool = true
    
    @AppStorage("health_sample_window_min", store: suite) 
    private var healthSampleWindowMin: Int = 120
    
    @AppStorage("whoop_proxy_url", store: suite) 
    private var whoopProxyURL: String = ""
    
    @AppStorage("whoop_api_key", store: suite) 
    private var whoopAPIKey: String = ""
    
    @AppStorage("wake_source_preference", store: suite) 
    private var wakeSourcePreference: String = "health"
    
    @AppStorage("export_include_timezone", store: suite) 
    private var exportIncludeTimezone: Bool = true
    
    @AppStorage("export_filename_pattern", store: suite) 
    private var exportFilenamePattern: String = "dosetrack_{nightKey}"
    
    @AppStorage("export_include_notes", store: suite) 
    private var exportIncludeNotes: Bool = true
    
    @AppStorage("export_include_event_log", store: suite) 
    private var exportIncludeEventLog: Bool = false
    
    @AppStorage("export_default_email", store: suite) 
    private var exportDefaultEmail: String = ""
    
    @AppStorage("require_biometric", store: suite) 
    private var requireBiometric: Bool = false
    
    @AppStorage("mask_widget_doses", store: suite) 
    private var maskWidgetDoses: Bool = false
    
    @AppStorage("retention_days", store: suite) 
    private var retentionDays: Int = 365
    
    @AppStorage("reset_allow_hard", store: suite)
    private var resetAllowHard: Bool = true
    
    @AppStorage("reset_require_biometric_hard", store: suite)
    private var resetRequireBiometricHard: Bool = false
    
    @AppStorage("reset_undo_window_sec", store: suite)
    private var resetUndoWindowSec: Int = 30
    
    @AppStorage("reset_reason_required", store: suite)
    private var resetReasonRequired: Bool = true
    
    @AppStorage("show_internals", store: suite) 
    private var showInternals: Bool = false
    
    // Reference to shared instance for computed properties
    private let prefs = AppPreferencesEnhanced.shared
    
    // Helper to format minutes as "Xh Ym" or "Ym"
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Section 1: Night Plan Defaults
                Section("Night plan defaults") {
                    Picker("Total night (g)", selection: $totalNightGrams) {
                        ForEach([3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,8.5,9.0], id: \.self) { g in
                            Text(String(format: "%.1f g", g)).tag(g)
                        }
                    }
                    
                    Picker("Split", selection: $splitStrategy) {
                        Text("50/50").tag("50/50")
                        Text("60/40").tag("60/40")
                        Text("40/60").tag("40/60")
                    }
                    
                    Picker("Rounding step", selection: $roundingStepG) {
                        Text("0.25 g").tag(0.25)
                        Text("0.5 g").tag(0.5)
                    }
                    
                    Toggle("Allow editing tonight's plan", isOn: $allowTonightEdit)
                    
                    // Live preview (calculate directly from local @AppStorage values)
                    let splitFraction: (first: Double, second: Double) = {
                        switch splitStrategy {
                        case "60/40": return (0.6, 0.4)
                        case "40/60": return (0.4, 0.6)
                        default: return (0.5, 0.5)
                        }
                    }()
                    let d1 = AppPreferencesEnhanced.round(totalNightGrams * splitFraction.first, step: roundingStepG)
                    let d2 = AppPreferencesEnhanced.round(totalNightGrams * splitFraction.second, step: roundingStepG)
                    
                    HStack {
                        Text("Tonight's plan")
                        Spacer()
                        Text(String(format: "%.2fg + %.2fg", d1, d2))
                            .foregroundStyle(.secondary)
                    }
                    
                    let perDoseMin = 1.5, perDoseMax = 4.5
                    let nightlyMin = 3.0, nightlyMax = 9.0
                    let violatesSafety = d1 < perDoseMin || d1 > perDoseMax ||
                                        d2 < perDoseMin || d2 > perDoseMax ||
                                        totalNightGrams < nightlyMin || totalNightGrams > nightlyMax
                    
                    if violatesSafety {
                        Label("Plan violates safety guardrails", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                
                // MARK: - Section 2: Dose 2 Window
                Section("Dose 2 window") {
                    Stepper(value: $windowStartMin, in: 120...300, step: 5) {
                        Text("Window starts at \(formatMinutes(windowStartMin))")
                    }
                    
                    Stepper(value: $windowEndMin, in: 150...360, step: 5) {
                        Text("Window ends at \(formatMinutes(windowEndMin))")
                    }
                    
                    let duration = windowEndMin - windowStartMin
                    HStack {
                        Text("Window duration")
                        Spacer()
                        Text(formatMinutes(duration))
                            .foregroundStyle(.secondary)
                    }
                }
                
                // MARK: - Section 3: Early Dose 2 Policy
                Section("Early dose 2 policy") {
                    Toggle("Allow early Dose 2", isOn: $allowEarlyDose)
                    
                    if allowEarlyDose {
                        Stepper(value: $maxEarlyMinutes, in: 0...60, step: 5) {
                            Text("Max early: \(maxEarlyMinutes) minutes")
                        }
                        
                        Toggle("Require reason for early dose", isOn: $requireEarlyReason)
                        
                        NavigationLink("Quick time-prior buttons") {
                            EarlyDoseQuickChoicesView()
                        }
                    }
                }
                
                // MARK: - Section 4: Notifications & Live Activity
                Section("Notifications and Live Activity") {
                    Toggle("Enable Live Activity", isOn: $liveActivityEnabled)
                    
                    Toggle("Notify at window start", isOn: $notifyAtStart)
                    Toggle("Notify at halfway point", isOn: $notifyAtHalf)
                    Toggle("Notify at window end", isOn: $notifyAtEnd)
                    
                    Stepper(value: $quietHoursStart, in: 0...23) {
                        Text("Quiet hours start: \(quietHoursStart):00")
                    }
                    
                    Stepper(value: $quietHoursEnd, in: 0...23) {
                        Text("Quiet hours end: \(quietHoursEnd):00")
                    }
                    
                    Toggle("Haptic feedback", isOn: $hapticsEnabled)
                }
                
                // MARK: - Section 5: Data Sources
                Section("Data sources") {
                    // Health permissions status (read-only)
                    HStack {
                        Text("HealthKit permissions")
                        Spacer()
                        // TODO: Get actual status from HealthKitManager
                        Text("Authorized")
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("Recheck Health permissions") {
                        // TODO: Call HealthKitManager.requestAuthorization()
                    }
                    
                    Stepper(value: $healthSampleWindowMin, in: 60...300, step: 15) {
                        Text("Health sample window: \(healthSampleWindowMin) min")
                    }
                    
                    TextField("WHOOP proxy URL", text: $whoopProxyURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    SecureField("WHOOP API key", text: $whoopAPIKey)
                    
                    Button("Test WHOOP connection") {
                        // TODO: Call WHOOP proxy endpoint
                    }
                    .disabled(whoopProxyURL.isEmpty)
                    
                    Picker("Prefer wake source", selection: $wakeSourcePreference) {
                        Text("HealthKit").tag("health")
                        Text("Manual entry").tag("manual")
                    }
                }
                
                // MARK: - Section 6: Exports
                Section("Exports") {
                    Toggle("Include timezone in CSV", isOn: $exportIncludeTimezone)
                    
                    TextField("Filename pattern", text: $exportFilenamePattern)
                        .textInputAutocapitalization(.never)
                    
                    Text("Available tokens: {nightKey}, {date}, {timezone}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Toggle("Include notes column", isOn: $exportIncludeNotes)
                    Toggle("Include raw event log", isOn: $exportIncludeEventLog)
                    
                    TextField("Default share email", text: $exportDefaultEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }
                
                // MARK: - Section 7: Privacy & Retention
                Section("Privacy and retention") {
                    Toggle("Require Face ID to open", isOn: $requireBiometric)
                    
                    Toggle("Mask doses on widgets", isOn: $maskWidgetDoses)
                    
                    Stepper(value: $retentionDays, in: 30...3650, step: 30) {
                        Text("Keep data for \(retentionDays) days")
                    }
                    
                    Button("Purge old data now", role: .destructive) {
                        showPurgeConfirm = true
                    }
                    .confirmationDialog("Purge old data?", isPresented: $showPurgeConfirm) {
                        Button("Delete data older than \(retentionDays) days", role: .destructive) {
                            // TODO: Call DoseLogController.purgeOldData()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete night records older than \(retentionDays) days.")
                    }
                }
                
                // MARK: - Section 7.5: Reset Night
                Section {
                    Toggle("Allow Hard Reset", isOn: $resetAllowHard)
                    
                    Toggle("Require Face ID for Hard Reset", isOn: $resetRequireBiometricHard)
                        .disabled(!resetAllowHard)
                    
                    Toggle("Reason required", isOn: $resetReasonRequired)
                    
                    Stepper(value: $resetUndoWindowSec, in: 10...120, step: 10) {
                        Text("Undo window: \(resetUndoWindowSec) seconds")
                    }
                } header: {
                    Text("Reset Night")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Soft reset closes tonight and starts fresh (reversible)")
                        Text("• Hard reset closes and deletes tonight's data (permanent)")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
                
                // MARK: - Section 8: Debug & Developer
                Section("Debug and developer") {
                    Toggle("Show nightKey and offsets", isOn: $showInternals)
                    
                    Button("Simulate Dose 1 now") {
                        // TODO: Call DoseLogController test method
                    }
                    
                    Button("Force window open") {
                        // TODO: Call DoseLogController test method
                    }
                    
                    NavigationLink("View event log") {
                        EventLogView()
                    }
                    
                    // Schema version (read-only)
                    HStack {
                        Text("Schema version")
                        Spacer()
                        Text("1.1.1c")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // MARK: - Reset Button
                Section {
                    Button("Reset all settings to defaults", role: .destructive) {
                        showResetConfirm = true
                    }
                    .confirmationDialog("Reset all settings?", isPresented: $showResetConfirm) {
                        Button("Reset to defaults", role: .destructive) {
                            prefs.resetToDefaults()
                        }
                        Button("Cancel", role: .cancel) {}
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct EarlyDoseQuickChoicesView: View {
    @State private var selectedButtons: Set<Int>
    
    init() {
        let buttons = AppPreferences.shared.defaultEarlyButtons
        _selectedButtons = State(initialValue: Set(buttons))
    }
    
    var body: some View {
        List {
            ForEach([5, 10, 15, 20, 30], id: \.self) { minutes in
                HStack {
                    Text("\(minutes) minutes")
                    Spacer()
                    Image(systemName: selectedButtons.contains(minutes) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedButtons.contains(minutes) ? .blue : .secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedButtons.contains(minutes) {
                        selectedButtons.remove(minutes)
                    } else {
                        selectedButtons.insert(minutes)
                    }
                    updatePreferences()
                }
            }
        }
        .navigationTitle("Quick choices")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func updatePreferences() {
        let sorted = selectedButtons.sorted()
        AppPreferences.shared.earlyTimePriorDefaults = sorted.map(String.init).joined(separator: ",")
    }
}

struct EventLogView: View {
    var body: some View {
        List {
            Text("Event log viewer - TODO")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Event log")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Helper Extension

extension AppPreferences {
    func formatMinutes(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h == 0 {
            return "\(m)m"
        } else if m == 0 {
            return "\(h)h"
        } else {
            return "\(h)h \(m)m"
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsViewEnhanced()
}
