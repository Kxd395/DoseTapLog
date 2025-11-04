//
//  EarlyDose2Sheet.swift
//  DoseTrack
//
//  Early Dose 2 override sheet with reason and time-prior picker
//

import SwiftUI

struct EarlyDose2Sheet: View {
    let minutesEarly: Int
    let policy: Dose2Policy
    let onConfirm: (Dose2Override) -> Void
    let onRemindAtStart: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: Dose2EarlyReason = .other
    @State private var customReason: String = ""
    @State private var timePriorMinutes: Int = 0  // 0 = Now
    
    @StateObject private var prefs = AppPreferencesEnhanced.shared
    
    var body: some View {
        NavigationStack {
            Form {
                // Warning chip
                Section {
                    HStack(spacing: DT.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("You're \(minutesEarly) min early")
                                .font(.callout.weight(.semibold))
                            Text("Window opens in \(minutesEarly) min • Policy: up to \(policy.maxEarlyMin) min early")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, DT.xs)
                }
                
                // Reason (if required)
                if prefs.requireEarlyReason {
                    Section("Reason") {
                        Picker("Why are you dosing early?", selection: $selectedReason) {
                            ForEach(Dose2EarlyReason.allCases, id: \.self) { reason in
                                Text(reason.displayName).tag(reason)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        if selectedReason == .other {
                            TextField("Describe reason...", text: $customReason)
                                .textInputAutocapitalization(.sentences)
                        }
                    }
                }
                
                // Time-prior choices
                Section("When?") {
                    Picker("Log dose", selection: $timePriorMinutes) {
                        Text("Now").tag(0)
                        ForEach(prefs.defaultEarlyButtons, id: \.self) { minutes in
                            Text("\(minutes)m from now").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Actions
                Section {
                    Button("Confirm early override") {
                        confirmOverride()
                    }
                    .disabled(!canConfirm)
                    .foregroundStyle(.orange)
                    
                    Button("Remind me at window start") {
                        onRemindAtStart()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Early Dose 2")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var canConfirm: Bool {
        if prefs.requireEarlyReason {
            if selectedReason == .other {
                return !customReason.trimmingCharacters(in: .whitespaces).isEmpty
            }
        }
        return true
    }
    
    private func confirmOverride() {
        let reason = selectedReason == .other ? customReason : selectedReason.displayName
        let override = Dose2Override(
            kind: .early,
            minutes: minutesEarly,
            reason: reason,
            timePriorChoiceMin: timePriorMinutes == 0 ? nil : timePriorMinutes,
            policyVersion: "1.1.2",
            source: .inApp
        )
        
        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()
        
        onConfirm(override)
        dismiss()
    }
}

enum Dose2EarlyReason: String, CaseIterable {
    case fellAsleep = "fell_asleep"
    case workSchedule = "work_schedule"
    case travelTimeZone = "travel_timezone"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .fellAsleep: return "Fell asleep"
        case .workSchedule: return "Work schedule"
        case .travelTimeZone: return "Travel/time zone"
        case .other: return "Other..."
        }
    }
}

#Preview {
    EarlyDose2Sheet(
        minutesEarly: 38,
        policy: Dose2Policy(startMin: 210, endMin: 245, allowEarly: true, maxEarlyMin: 45, allowLate: true, maxLateMin: 30),
        onConfirm: { _ in },
        onRemindAtStart: { }
    )
}
