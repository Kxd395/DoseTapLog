import SwiftUI

struct EarlyDoseSheet: View {
    @Binding var minutes: Int
    @Binding var reason: EarlyReason
    let allowed: ClosedRange<Int>
    let quickChoices: [Int]
    let requireReason: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Why early") {
                    Picker("Reason", selection: $reason) {
                        ForEach(EarlyReason.allCases) { r in Text(r.rawValue).tag(r) }
                    }.disabled(!requireReason)
                }
                Section("How early") {
                    HStack { ForEach(quickChoices, id: \.self) { m in Button("\(m)m") { minutes = m }.buttonStyle(.bordered) } }
                    Stepper(value: $minutes, in: allowed, step: 1) { Text("Early by \(minutes) minutes") }
                }
                Section {
                    Button("Confirm early Dose 2") { onConfirm() }.buttonStyle(.borderedProminent)
                    Button("Cancel", role: .cancel) { onCancel() }
                }
            }.navigationTitle("Dose 2 early")
        }
    }
}

// NOTE: SettingsView has been replaced by SettingsViewEnhanced.swift
// The old SettingsView code has been removed as it used outdated AppPreferences properties
