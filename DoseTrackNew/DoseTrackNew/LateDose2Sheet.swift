//
//  LateDose2Sheet.swift
//  DoseTrack
//
//  Late Dose 2 override sheet with reason picker
//

import SwiftUI

struct LateDose2Sheet: View {
    let minutesLate: Int
    let policy: Dose2Policy
    let onConfirm: (Dose2Override) -> Void
    let onLogMissed: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason: Dose2LateReason = .other
    @State private var customReason: String = ""
    
    private let prefs = AppPreferencesEnhanced.shared
    
    var body: some View {
        NavigationStack {
            Form {
                // Warning chip
                Section {
                    HStack(spacing: DT.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Window ended \(minutesLate) min ago")
                                .font(.callout.weight(.semibold))
                            Text("Policy: up to \(policy.maxLateMin) min late")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, DT.xs)
                }
                
                // Reason (if required)
                if prefs.lateRequireReason {
                    Section("Reason") {
                        Picker("Why are you dosing late?", selection: $selectedReason) {
                            ForEach(Dose2LateReason.allCases, id: \.self) { reason in
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
                
                // Actions
                Section {
                    Button("Confirm late override") {
                        confirmOverride()
                    }
                    .disabled(!canConfirm)
                    .foregroundStyle(.orange)
                    
                    Button("Log as missed dose") {
                        onLogMissed()
                        dismiss()
                    }
                }
            }
            .navigationTitle("Late Dose 2")
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
        if prefs.lateRequireReason {
            if selectedReason == .other {
                return !customReason.trimmingCharacters(in: .whitespaces).isEmpty
            }
        }
        return true
    }
    
    private func confirmOverride() {
        let reason = selectedReason == .other ? customReason : selectedReason.displayName
        let override = Dose2Override(
            kind: .late,
            minutes: minutesLate,
            reason: reason,
            timePriorChoiceMin: nil,  // Late overrides are immediate
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

enum Dose2LateReason: String, CaseIterable {
    case wokeUp = "woke_up"
    case forgotAlarm = "forgot_alarm"
    case workSchedule = "work_schedule"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .wokeUp: return "Woke up naturally"
        case .forgotAlarm: return "Forgot/snoozed alarm"
        case .workSchedule: return "Work schedule"
        case .other: return "Other..."
        }
    }
}

#Preview {
    LateDose2Sheet(
        minutesLate: 12,
        policy: Dose2Policy(startMin: 210, endMin: 245, allowEarly: true, maxEarlyMin: 45, allowLate: true, maxLateMin: 30),
        onConfirm: { _ in },
        onLogMissed: { }
    )
}
