//
//  EarlyDoseSheetView.swift
//  DoseTrack
//
//  Confirmation modal for early Dose 2 with override logging
//  Presents when user attempts Dose 2 before window with early policy enabled
//

import SwiftUI

struct EarlyDoseSheetView: View {
    @Binding var isPresented: Bool
    let minutesEarly: Int
    let dose2Grams: Double
    let requireReason: Bool
    let timePriorOptions: [Int] // e.g., [5, 10, 15, 20, 30]
    let onConfirm: (_ reason: String, _ timePriorMin: Int) -> Void
    
    @State private var selectedReason: EarlyReason = .couldNotSleep
    @State private var selectedTimePrior: Int = 10
    @State private var customReason: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                            .font(.system(size: 48))
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Dose 2 Early")
                                .font(.headline)
                            Text("You're logging \(minutesEarly) min before the window opens")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Dose Details") {
                    LabeledContent("Amount", value: "\(String(format: "%.2f", dose2Grams))g")
                    LabeledContent("Early by", value: "\(minutesEarly) min")
                }
                
                if requireReason {
                    Section("Reason (Required)") {
                        Picker("Reason", selection: $selectedReason) {
                            ForEach(EarlyReason.allCases, id: \.self) { reason in
                                Text(reason.displayName).tag(reason)
                            }
                        }
                        .pickerStyle(.inline)
                        
                        if selectedReason == .other {
                            TextField("Describe reason", text: $customReason)
                                .textInputAutocapitalization(.sentences)
                        }
                    }
                }
                
                Section("Log Time") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Log dose as taken:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Time Prior", selection: $selectedTimePrior) {
                            ForEach(timePriorOptions, id: \.self) { minutes in
                                Text("\(minutes) min ago").tag(minutes)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                
                Section {
                    VStack(spacing: 8) {
                        Text("This will log an early dose override with your reason and timing adjustment.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Text("Your clinician may review override events during follow-up.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Early Dose Confirmation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        confirmEarlyDose()
                    }
                    .disabled(!canConfirm)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private var canConfirm: Bool {
        if requireReason {
            if selectedReason == .other {
                return !customReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return true
        }
        return true
    }
    
    // MARK: - Actions
    
    private func confirmEarlyDose() {
        let reasonText: String
        if selectedReason == .other {
            reasonText = customReason.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            reasonText = selectedReason.rawValue
        }
        
        onConfirm(reasonText, selectedTimePrior)
        isPresented = false
    }
}

// MARK: - Supporting Types

enum EarlyReason: String, CaseIterable, Codable, Identifiable {
    case couldNotSleep = "Could not sleep again"
    case shiftSchedule = "Shift schedule"
    case forgotEarlier = "Forgot earlier dose"
    case other = "Other"
    
    var id: String { rawValue }
    
    var displayName: String {
        rawValue
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var isPresented = true
    
    return Color.clear
        .sheet(isPresented: $isPresented) {
            EarlyDoseSheetView(
                isPresented: $isPresented,
                minutesEarly: 25,
                dose2Grams: 3.25,
                requireReason: true,
                timePriorOptions: [5, 10, 15, 20, 30],
                onConfirm: { reason, timePrior in
                    print("Confirmed: \(reason), \(timePrior) min ago")
                }
            )
        }
}

#Preview("No Reason Required") {
    @Previewable @State var isPresented = true
    
    return Color.clear
        .sheet(isPresented: $isPresented) {
            EarlyDoseSheetView(
                isPresented: $isPresented,
                minutesEarly: 15,
                dose2Grams: 3.0,
                requireReason: false,
                timePriorOptions: [5, 10, 15],
                onConfirm: { reason, timePrior in
                    print("Confirmed: \(reason), \(timePrior) min ago")
                }
            )
        }
}
