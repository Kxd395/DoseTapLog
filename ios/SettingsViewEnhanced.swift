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
    @Bindable var prefs = AppPreferences.shared
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Section 1: Night Plan Defaults
                Section("Night plan defaults") {
                    Picker("Total night (g)", selection: $prefs.totalNightGrams) {
                        ForEach([3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,8.5,9.0], id: \.self) { g in
                            Text(String(format: "%.1f g", g)).tag(g)
                        }
                    }
                    
                    Picker("Split", selection: $prefs.splitStrategy) {
                        Text("50/50").tag("50/50")
                        Text("60/40").tag("60/40")
                        Text("40/60").tag("40/60")
                    }
                    
                    Picker("Rounding step", selection: $prefs.roundingStepG) {
                        Text("0.25 g").tag(0.25)
                        Text("0.5 g").tag(0.5)
                    }
                    
                    Toggle("Allow editing tonight's plan", isOn: $prefs.allowTonightEdit)
                    
                    // Live preview
                    let (d1, d2) = prefs.calculateDoses()
                    HStack {
                        Text("Tonight's plan")
                        Spacer()
                        Text(String(format: "%.2fg + %.2fg", d1, d2))
                            .foregroundStyle(.secondary)
                    }
                    
                    if prefs.planViolatesSafety {
                        Label("Plan violates safety guardrails", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                
                // MARK: - Section 2: Dose 2 Window
                Section("Dose 2 window") {
                    Stepper(value: $prefs.windowStartMin, in: 120...300, step: 5) {
                        Text("Window starts at \(prefs.formatMinutes(prefs.windowStartMin))")
                    }
                    
                    Stepper(value: $prefs.windowEndMin, in: 150...360, step: 5) {
                        Text("Window ends at \(prefs.formatMinutes(prefs.windowEndMin))")
                    }
                    
                    let duration = prefs.windowEndMin - prefs.windowStartMin
                    HStack {
                        Text("Window duration")
                        Spacer()
                        Text(prefs.formatMinutes(duration))
                            .foregroundStyle(.secondary)
                    }
                }
                
                // MARK: - Section 3: Early Dose 2 Policy
                Section("Early dose 2 policy") {
                    Toggle("Allow early Dose 2", isOn: $prefs.allowEarlyDose)
                    
                    if prefs.allowEarlyDose {
                        Stepper(value: $prefs.maxEarlyMinutes, in: 0...60, step: 5) {
                            Text("Max early: \(prefs.maxEarlyMinutes) minutes")
                        }
                        
                        Toggle("Require reason for early dose", isOn: $prefs.requireEarlyReason)
                        
                        NavigationLink("Quick time-prior buttons") {
                            EarlyDoseQuickChoicesView()
                        }
                    }
                }
                
                // MARK: - Section 3b: Late Dose 2 Policy
                Section("Late dose 2 policy") {
                    Toggle("Allow late Dose 2", isOn: $prefs.allowLateDose)
                    
                    if prefs.allowLateDose {
                        Stepper(value: $prefs.maxLateMinutes, in: 0...90, step: 5) {
                            Text("Max late: \(prefs.maxLateMinutes) minutes")
                        }
                        
                        Toggle("Require reason for late dose", isOn: $prefs.lateRequireReason)
                    }
                } footer: {
                    if prefs.allowLateDose {
                        Text("Late doses are logged after the dosing window closes. Maximum recommended: 30-60 minutes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // MARK: - Section 4: Alarm Ladder
                Section("Alarm ladder") {
                    Picker("Alarm style", selection: $prefs.alarmStyleRaw) {
                        ForEach(NightAlarmPlan.AlarmStyle.allCases, id: \.self) { style in
                            Text(style.description).tag(style.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    // Show consent warning for Strong style
                    if prefs.alarmStyle == .strong && !prefs.strongAlarmConsent {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Strong style requires consent")
                                .font(.caption)
                        }
                        
                        Toggle("I consent to hard repeating alarms", isOn: $prefs.strongAlarmConsent)
                            .font(.caption)
                    }
                    
                    Stepper(value: $prefs.alarmBudgetPerNight, in: 1...5) {
                        Text("Alarm budget: \(prefs.alarmBudgetPerNight) per night")
                    }
                    
                    Stepper(value: $prefs.lateGraceMinutes, in: 0...30, step: 5) {
                        Text("Late grace period: \(prefs.lateGraceMinutes) min")
                    }
                    
                    if prefs.alarmStyle != .quiet {
                        Stepper(value: $prefs.preWindowLeadMinutes, in: 0...60, step: 5) {
                            if prefs.preWindowLeadMinutes == 0 {
                                Text("Pre-window nudge: Off")
                            } else {
                                Text("Pre-window nudge: \(prefs.preWindowLeadMinutes) min before")
                            }
                        }
                    }
                    
                    if prefs.alarmStyle == .strong {
                        Divider()
                        
                        Toggle("Hard repeats after grace", isOn: $prefs.hardAfterEndEnabled)
                        
                        if prefs.hardAfterEndEnabled {
                            Stepper(value: $prefs.hardRepeatMinutes, in: 5...30, step: 5) {
                                Text("Hard repeat interval: \(prefs.hardRepeatMinutes) min")
                            }
                            
                            Stepper(value: $prefs.hardMaxRepeats, in: 1...3) {
                                Text("Max hard repeats: \(prefs.hardMaxRepeats)")
                            }
                        }
                    }
                    
                    Picker("Focus mode policy", selection: $prefs.respectDNDRaw) {
                        ForEach(AppPreferences.DNDPolicy.allCases, id: \.self) { policy in
                            Text(policy.description).tag(policy.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if prefs.respectDND == .timeSensitive && !prefs.timeSensitiveConsent {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Time Sensitive requires system permission")
                                .font(.caption)
                        }
                        
                        Toggle("I consent to Time Sensitive notifications", isOn: $prefs.timeSensitiveConsent)
                            .font(.caption)
                    }
                    
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alarm ladder prevents alarm fatigue with budget-limited alerts.")
                        
                        if prefs.alarmStyle == .quiet {
                            Text("Quiet: 1 alert at window open only.")
                        } else if prefs.alarmStyle == .normal {
                            Text("Normal: Up to 3 alerts (open, closing, end).")
                        } else if prefs.alarmStyle == .strong {
                            Text("Strong: Up to 5 alerts including hard repeats after grace. Requires consent.")
                        }
                        
                        if prefs.respectDND == .timeSensitive {
                            Text("Time Sensitive interruption breaks through most Focus modes but requires system permission.")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                
                // MARK: - Section 5: Notifications & Live Activity
                Section("Notifications and Live Activity") {
                    Toggle("Enable Live Activity", isOn: $prefs.liveActivityEnabled)
                    
                    Toggle("Notify at window start", isOn: $prefs.notifyAtStart)
                    Toggle("Notify at halfway point", isOn: $prefs.notifyAtHalf)
                    Toggle("Notify at window end", isOn: $prefs.notifyAtEnd)
                    
                    Stepper(value: $prefs.quietHoursStart, in: 0...23) {
                        Text("Quiet hours start: \(prefs.quietHoursStart):00")
                    }
                    
                    Stepper(value: $prefs.quietHoursEnd, in: 0...23) {
                        Text("Quiet hours end: \(prefs.quietHoursEnd):00")
                    }
                    
                    Toggle("Haptic feedback", isOn: $prefs.hapticsEnabled)
                }
                
                // MARK: - Section 6: Data Sources
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
                    
                    Stepper(value: $prefs.healthSampleWindowMin, in: 60...300, step: 15) {
                        Text("Health sample window: \(prefs.healthSampleWindowMin) min")
                    }
                    
                    TextField("WHOOP proxy URL", text: $prefs.whoopProxyURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    SecureField("WHOOP API key", text: $prefs.whoopAPIKey)
                    
                    Button("Test WHOOP connection") {
                        // TODO: Call WHOOP proxy endpoint
                    }
                    .disabled(prefs.whoopProxyURL.isEmpty)
                    
                    Picker("Prefer wake source", selection: $prefs.wakeSourcePreference) {
                        Text("HealthKit").tag("health")
                        Text("Manual entry").tag("manual")
                    }
                }
                
                // MARK: - Section 6: Exports
                Section("Exports") {
                    Toggle("Include timezone in CSV", isOn: $prefs.exportIncludeTimezone)
                    
                    TextField("Filename pattern", text: $prefs.exportFilenamePattern)
                        .textInputAutocapitalization(.never)
                    
                    Text("Available tokens: {nightKey}, {date}, {timezone}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Toggle("Include notes column", isOn: $prefs.exportIncludeNotes)
                    Toggle("Include raw event log", isOn: $prefs.exportIncludeEventLog)
                    
                    TextField("Default share email", text: $prefs.exportDefaultEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }
                
                // MARK: - Section 7: Privacy & Retention
                Section("Privacy and retention") {
                    Toggle("Require Face ID to open", isOn: $prefs.requireBiometric)
                    
                    Toggle("Mask doses on widgets", isOn: $prefs.maskWidgetDoses)
                    
                    Stepper(value: $prefs.retentionDays, in: 30...3650, step: 30) {
                        Text("Keep data for \(prefs.retentionDays) days")
                    }
                    
                    Button("Purge old data now", role: .destructive) {
                        showPurgeConfirm = true
                    }
                    .confirmationDialog("Purge old data?", isPresented: $showPurgeConfirm) {
                        Button("Delete data older than \(prefs.retentionDays) days", role: .destructive) {
                            // TODO: Call DoseLogController.purgeOldData()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete night records older than \(prefs.retentionDays) days.")
                    }
                }
                
                // MARK: - Section 7.5: Reset Night
                Section {
                    Toggle("Allow Hard Reset", isOn: $prefs.resetAllowHard)
                    
                    Toggle("Require Face ID for Hard Reset", isOn: $prefs.resetRequireBiometricHard)
                        .disabled(!prefs.resetAllowHard)
                    
                    Toggle("Reason required", isOn: $prefs.resetReasonRequired)
                    
                    Stepper(value: $prefs.resetUndoWindowSec, in: 10...120, step: 10) {
                        Text("Undo window: \(prefs.resetUndoWindowSec) seconds")
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
                    Toggle("Show nightKey and offsets", isOn: $prefs.showInternals)
                    
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
        let buttons = prefs.defaultEarlyButtons
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
        prefs.earlyTimePriorDefaults = sorted.map(String.init).joined(separator: ",")
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

extension AppPreferencesEnhanced {
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
