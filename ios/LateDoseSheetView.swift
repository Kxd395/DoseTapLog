import SwiftUI

/// Sheet presented when user wants to log Dose 2 after the window has closed
/// Shows warning header, reason picker, minutes late input with quick choices
struct LateDoseSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Bindings from parent
    @Binding var isPresented: Bool
    
    // Parameters
    let dose2Grams: Double
    let minutesAfterWindow: Int
    let requireReason: Bool
    let quickChoices: [Int]
    let maxLateMinutes: Int
    let onConfirm: (_ reason: String, _ minutesLate: Int) -> Void
    
    // Local state
    @State private var selectedReason: LateDoseReason = .feltSleepy
    @State private var customReason: String = ""
    @State private var minutesLate: Int = 5
    
    var body: some View {
        NavigationStack {
            Form {
                // Warning header
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Late Dose 2 Override")
                                .font(.headline)
                                .bold()
                            
                            Text("You're logging \(minutesAfterWindow) min after the window closed.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    Text("This records what happened for adherence tracking. It does NOT restart the dosing window or Live Activity.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .padding(.vertical, 4)
                }
                .listRowBackground(Color.orange.opacity(0.1))
                
                // Dose details
                Section("Dose Details") {
                    LabeledContent("Amount", value: dose2Grams.formatG)
                    LabeledContent("After window end", value: "\(minutesAfterWindow) min")
                }
                
                // Reason (required or optional)
                Section {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(LateDoseReason.allCases) { reason in
                            Text(reason.displayName).tag(reason)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    if selectedReason == .other {
                        TextField("Describe reason", text: $customReason, axis: .vertical)
                            .lineLimit(2...4)
                    }
                } header: {
                    Text(requireReason ? "Reason (Required)" : "Reason (Optional)")
                } footer: {
                    Text("This will appear in your event log and CSV exports.")
                        .font(.footnote)
                }
                
                // How late
                Section("How Late") {
                    // Quick choices
                    if !quickChoices.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(quickChoices, id: \.self) { minutes in
                                Button(action: {
                                    minutesLate = minutes
                                }) {
                                    Text("\(minutes)m")
                                        .font(.footnote)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            minutesLate == minutes ?
                                            Color.orange : Color.gray.opacity(0.2)
                                        )
                                        .foregroundStyle(
                                            minutesLate == minutes ?
                                            Color.white : Color.primary
                                        )
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    // Stepper
                    Stepper(value: $minutesLate, in: 1...300, step: 5) {
                        Text("Late by \(minutesLate) minutes")
                    }
                    
                    // Warning if exceeds max
                    if maxLateMinutes > 0 && minutesLate > maxLateMinutes {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                            Text("This exceeds your configured max of \(maxLateMinutes) min")
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                // Disclaimer
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What this does", systemImage: "info.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("• Records Dose 2 at the current time")
                        Text("• Marks as 'late override' in database and CSV")
                        Text("• Captures your reason for audit trail")
                        Text("• Does NOT restart Live Activity or window")
                        Text("• Clinicians may review override patterns")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Late Dose 2")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm Late Dose") {
                        confirmLateDose()
                    }
                    .disabled(!canConfirm)
                    .bold()
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var canConfirm: Bool {
        if requireReason {
            if selectedReason == .other {
                return !customReason.trimmingCharacters(in: .whitespaces).isEmpty
            }
            return true
        }
        return true
    }
    
    private func confirmLateDose() {
        let finalReason: String
        if selectedReason == .other {
            finalReason = customReason.trimmingCharacters(in: .whitespaces)
        } else {
            finalReason = selectedReason.displayName
        }
        
        onConfirm(finalReason, minutesLate)
        isPresented = false
        dismiss()
    }
}

// MARK: - Supporting Types

enum LateDoseReason: String, CaseIterable, Identifiable {
    case feltSleepy = "felt_sleepy"
    case forgotEarlier = "forgot_earlier"
    case delayedByActivity = "delayed_by_activity"
    case wakeWindowIssue = "wake_window_issue"
    case other = "other"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .feltSleepy: return "Felt sleepy, took late"
        case .forgotEarlier: return "Forgot to take earlier"
        case .delayedByActivity: return "Delayed by activity/event"
        case .wakeWindowIssue: return "Wake time tracking issue"
        case .other: return "Other (describe)"
        }
    }
}

// MARK: - Preview

#Preview("Late Dose Sheet") {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        
        var body: some View {
            Text("Preview Container")
                .sheet(isPresented: $isPresented) {
                    LateDoseSheetView(
                        isPresented: $isPresented,
                        dose2Grams: 3.25,
                        minutesAfterWindow: 22,
                        requireReason: true,
                        quickChoices: [5, 10, 15, 30],
                        maxLateMinutes: 120,
                        onConfirm: { reason, minutes in
                            print("Confirmed: \(reason), \(minutes) min late")
                        }
                    )
                }
        }
    }
    
    return PreviewWrapper()
}

#Preview("No Max Limit") {
    struct PreviewWrapper: View {
        @State private var isPresented = true
        
        var body: some View {
            Text("Preview Container")
                .sheet(isPresented: $isPresented) {
                    LateDoseSheetView(
                        isPresented: $isPresented,
                        dose2Grams: 3.5,
                        minutesAfterWindow: 45,
                        requireReason: false,
                        quickChoices: [5, 10, 20, 30, 60],
                        maxLateMinutes: 0, // Unlimited
                        onConfirm: { reason, minutes in
                            print("Confirmed: \(reason), \(minutes) min late")
                        }
                    )
                }
        }
    }
    
    return PreviewWrapper()
}
