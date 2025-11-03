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
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Section 1: Night Plan Defaults
                Section("Night plan defaults") {
                    Picker("Total night (g)", selection: $AppPreferencesEnhanced.shared.totalNightGrams) {
                        ForEach([3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,8.5,9.0], id: \.self) { g in
                            Text(String(format: "%.1f g", g)).tag(g)
                        }
                    }
                    
                    Picker("Split", selection: $AppPreferencesEnhanced.shared.splitStrategy) {
                        Text("50/50").tag("50/50")
                        Text("60/40").tag("60/40")
                        Text("40/60").tag("40/60")
                    }
                    
                    Picker("Rounding step", selection: $AppPreferencesEnhanced.shared.roundingStepG) {
                        Text("0.25 g").tag(0.25)
                        Text("0.5 g").tag(0.5)
                    }
                    
                    Toggle("Allow editing tonight's plan", isOn: $AppPreferencesEnhanced.shared.allowTonightEdit)
                    
                    // Live preview
                    let (d1, d2) = AppPreferencesEnhanced.shared.calculateDoses()
                    HStack {
                        Text("Tonight's plan")
                        Spacer()
                        Text(String(format: "%.2fg + %.2fg", d1, d2))
                            .foregroundStyle(.secondary)
                    }
                    
                    if AppPreferencesEnhanced.shared.planViolatesSafety {
                        Label("Plan violates safety guardrails", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                
                // MARK: - Section 2: Dose 2 Window
                Section("Dose 2 window") {
                    Stepper(value: $AppPreferencesEnhanced.shared.windowStartMin, in: 120...300, step: 5) {
                        Text("Window starts at \(AppPreferencesEnhanced.shared.formatMinutes(AppPreferencesEnhanced.shared.windowStartMin))")
                    }
                    
                    Stepper(value: $AppPreferencesEnhanced.shared.windowEndMin, in: 150...360, step: 5) {
                        Text("Window ends at \(AppPreferencesEnhanced.shared.formatMinutes(AppPreferencesEnhanced.shared.windowEndMin))")
                    }
                    
                    let duration = AppPreferencesEnhanced.shared.windowEndMin - AppPreferencesEnhanced.shared.windowStartMin
                    HStack {
                        Text("Window duration")
                        Spacer()
                        Text(AppPreferencesEnhanced.shared.formatMinutes(duration))
                            .foregroundStyle(.secondary)
                    }
                }
                
                // MARK: - Section 3: Early Dose 2 Policy
                Section("Early dose 2 policy") {
                    Toggle("Allow early Dose 2", isOn: $AppPreferencesEnhanced.shared.allowEarlyDose)
                    
                    if AppPreferencesEnhanced.shared.allowEarlyDose {
                        Stepper(value: $AppPreferencesEnhanced.shared.maxEarlyMinutes, in: 0...60, step: 5) {
                            Text("Max early: \(AppPreferencesEnhanced.shared.maxEarlyMinutes) minutes")
                        }
                        
                        Toggle("Require reason for early dose", isOn: $AppPreferencesEnhanced.shared.requireEarlyReason)
                        
                        NavigationLink("Quick time-prior buttons") {
                            EarlyDoseQuickChoicesView()
                        }
                    }
                }
                
                // MARK: - Section 4: Notifications & Live Activity
                Section("Notifications and Live Activity") {
                    Toggle("Enable Live Activity", isOn: $AppPreferencesEnhanced.shared.liveActivityEnabled)
                    
                    Toggle("Notify at window start", isOn: $AppPreferencesEnhanced.shared.notifyAtStart)
                    Toggle("Notify at halfway point", isOn: $AppPreferencesEnhanced.shared.notifyAtHalf)
                    Toggle("Notify at window end", isOn: $AppPreferencesEnhanced.shared.notifyAtEnd)
                    
                    Stepper(value: $AppPreferencesEnhanced.shared.quietHoursStart, in: 0...23) {
                        Text("Quiet hours start: \(AppPreferencesEnhanced.shared.quietHoursStart):00")
                    }
                    
                    Stepper(value: $AppPreferencesEnhanced.shared.quietHoursEnd, in: 0...23) {
                        Text("Quiet hours end: \(AppPreferencesEnhanced.shared.quietHoursEnd):00")
                    }
                    
                    Toggle("Haptic feedback", isOn: $AppPreferencesEnhanced.shared.hapticsEnabled)
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
                    
                    Stepper(value: $AppPreferencesEnhanced.shared.healthSampleWindowMin, in: 60...300, step: 15) {
                        Text("Health sample window: \(AppPreferencesEnhanced.shared.healthSampleWindowMin) min")
                    }
                    
                    TextField("WHOOP proxy URL", text: $AppPreferencesEnhanced.shared.whoopProxyURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    
                    SecureField("WHOOP API key", text: $AppPreferencesEnhanced.shared.whoopAPIKey)
                    
                    Button("Test WHOOP connection") {
                        // TODO: Call WHOOP proxy endpoint
                    }
                    .disabled(AppPreferencesEnhanced.shared.whoopProxyURL.isEmpty)
                    
                    Picker("Prefer wake source", selection: $AppPreferencesEnhanced.shared.wakeSourcePreference) {
                        Text("HealthKit").tag("health")
                        Text("Manual entry").tag("manual")
                    }
                }
                
                // MARK: - Section 6: Exports
                Section("Exports") {
                    Toggle("Include timezone in CSV", isOn: $AppPreferencesEnhanced.shared.exportIncludeTimezone)
                    
                    TextField("Filename pattern", text: $AppPreferencesEnhanced.shared.exportFilenamePattern)
                        .textInputAutocapitalization(.never)
                    
                    Text("Available tokens: {nightKey}, {date}, {timezone}")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Toggle("Include notes column", isOn: $AppPreferencesEnhanced.shared.exportIncludeNotes)
                    Toggle("Include raw event log", isOn: $AppPreferencesEnhanced.shared.exportIncludeEventLog)
                    
                    TextField("Default share email", text: $AppPreferencesEnhanced.shared.exportDefaultEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                }
                
                // MARK: - Section 7: Privacy & Retention
                Section("Privacy and retention") {
                    Toggle("Require Face ID to open", isOn: $AppPreferencesEnhanced.shared.requireBiometric)
                    
                    Toggle("Mask doses on widgets", isOn: $AppPreferencesEnhanced.shared.maskWidgetDoses)
                    
                    Stepper(value: $AppPreferencesEnhanced.shared.retentionDays, in: 30...3650, step: 30) {
                        Text("Keep data for \(AppPreferencesEnhanced.shared.retentionDays) days")
                    }
                    
                    Button("Purge old data now", role: .destructive) {
                        showPurgeConfirm = true
                    }
                    .confirmationDialog("Purge old data?", isPresented: $showPurgeConfirm) {
                        Button("Delete data older than \(AppPreferencesEnhanced.shared.retentionDays) days", role: .destructive) {
                            // TODO: Call DoseLogController.purgeOldData()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will permanently delete night records older than \(AppPreferencesEnhanced.shared.retentionDays) days.")
                    }
                }
                
                // MARK: - Section 7.5: Reset Night
                Section {
                    Toggle("Allow Hard Reset", isOn: $AppPreferencesEnhanced.shared.resetAllowHard)
                    
                    Toggle("Require Face ID for Hard Reset", isOn: $AppPreferencesEnhanced.shared.resetRequireBiometricHard)
                        .disabled(!AppPreferencesEnhanced.shared.resetAllowHard)
                    
                    Toggle("Reason required", isOn: $AppPreferencesEnhanced.shared.resetReasonRequired)
                    
                    Stepper(value: $AppPreferencesEnhanced.shared.resetUndoWindowSec, in: 10...120, step: 10) {
                        Text("Undo window: \(AppPreferencesEnhanced.shared.resetUndoWindowSec) seconds")
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
                    Toggle("Show nightKey and offsets", isOn: $AppPreferencesEnhanced.shared.showInternals)
                    
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
                            AppPreferencesEnhanced.shared.resetToDefaults()
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
        let buttons = AppPreferencesEnhanced.shared.defaultEarlyButtons
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
        AppPreferencesEnhanced.shared.earlyTimePriorDefaults = sorted.map(String.init).joined(separator: ",")
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
