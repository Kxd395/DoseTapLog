//
//  SettingsViewEnhanced.swift
//  DoseTrack
//
//  Enhanced Settings screen with night turnover configuration
//

import SwiftUI

struct SettingsViewEnhanced: View {
    @Environment(\.dismiss) var dismiss
    @State private var showResetConfirm = false
    
    private var prefs: AppPreferencesEnhanced { AppPreferencesEnhanced.shared }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Service Day Cutoff
                Section {
                    Picker("Cutoff time", selection: Binding(
                        get: { prefs.cutoffHourLocal },
                        set: { prefs.cutoffHourLocal = $0 }
                    )) {
                        ForEach(0...23, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Text("Next cutoff")
                        Spacer()
                        Text(formatNextCutoff())
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text("Service day cutoff")
                        Spacer()
                        Button {
                            // Show info sheet
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                } footer: {
                    Text("Nights automatically close at cutoff. Default noon (12:00). Events after cutoff belong to the next service day.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // MARK: - Night Plan Defaults
                Section {
                    Picker("Total night", selection: Binding(
                        get: { prefs.totalNightGrams },
                        set: { prefs.totalNightGrams = $0 }
                    )) {
                        ForEach([3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,8.5,9.0], id: \.self) { g in
                            Text(String(format: "%.1f g", g)).tag(g)
                        }
                    }
                    
                    Picker("Split", selection: Binding(
                        get: { prefs.splitStrategy },
                        set: { prefs.splitStrategy = $0 }
                    )) {
                        Text("50/50").tag("50/50")
                        Text("60/40").tag("60/40")
                        Text("40/60").tag("40/60")
                    }
                } header: {
                    Text("Night plan defaults")
                }
                
                // MARK: - Dose 2 Window
                Section {
                    Stepper(value: Binding(
                        get: { prefs.windowStartMin },
                        set: { prefs.windowStartMin = $0 }
                    ), in: 120...300, step: 5) {
                        Text("Starts at \(formatMinutes(prefs.windowStartMin))")
                    }
                    
                    Stepper(value: Binding(
                        get: { prefs.windowEndMin },
                        set: { prefs.windowEndMin = $0 }
                    ), in: 150...360, step: 5) {
                        Text("Ends at \(formatMinutes(prefs.windowEndMin))")
                    }
                } header: {
                    Text("Dose 2 window")
                }
                
                // MARK: - Override Policies
                Section {
                    Toggle("Allow early dose", isOn: Binding(
                        get: { prefs.allowEarlyDose },
                        set: { prefs.allowEarlyDose = $0 }
                    ))
                    
                    if prefs.allowEarlyDose {
                        Stepper(value: Binding(
                            get: { prefs.maxEarlyMinutes },
                            set: { prefs.maxEarlyMinutes = $0 }
                        ), in: 5...180, step: 5) {
                            Text("Max early: \(prefs.maxEarlyMinutes) min")
                        }
                    }
                } header: {
                    Text("Early dose policy")
                }
                
                Section {
                    Toggle("Allow late dose", isOn: Binding(
                        get: { prefs.allowLateDose },
                        set: { prefs.allowLateDose = $0 }
                    ))
                    
                    if prefs.allowLateDose {
                        Stepper(value: Binding(
                            get: { prefs.maxLateMinutes },
                            set: { prefs.maxLateMinutes = $0 }
                        ), in: 5...180, step: 5) {
                            Text("Max late: \(prefs.maxLateMinutes) min")
                        }
                    }
                } header: {
                    Text("Late dose policy")
                }
                
                // MARK: - Data Management
                Section {
                    NavigationLink {
                        HealthDataExportView()
                    } label: {
                        Label("Health Data Export", systemImage: "heart.text.square")
                    }
                    
                    NavigationLink {
                        EncryptionSettingsView()
                    } label: {
                        Label("Encryption", systemImage: "lock.shield")
                    }
                    
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Label("Reset all settings", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("Data management")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset Settings?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) {
                    resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will reset all settings to default values. This cannot be undone.")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateFormat = "h:mm a"
        
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }
    
    private func formatNextCutoff() -> String {
        let nextCutoff = NightServiceDay.nextCutoff(cutoffHour: prefs.cutoffHourLocal)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .short
        return formatter.string(from: nextCutoff)
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 && mins > 0 {
            return "\(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(mins)m"
        }
    }
    
    private func resetToDefaults() {
        // Reset to defaults
        prefs.cutoffHourLocal = 12
        prefs.totalNightGrams = 6.5
        prefs.splitStrategy = "50/50"
        prefs.windowStartMin = 150
        prefs.windowEndMin = 240
        prefs.allowEarlyDose = false
        prefs.allowLateDose = false
    }
}

// MARK: - Preview

#Preview {
    SettingsViewEnhanced()
}
