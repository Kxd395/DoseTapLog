//
//  GuardNoWakeSheet.swift
//  DoseTrack
//
//  Hard No-Wake Guard sheet when Dose 2 too close to morning wake
//

import SwiftUI

struct GuardNoWakeSheet: View {
    let minutesUntilWake: Int
    let isWorkday: Bool
    let allowOverride: Bool
    let onProceed: (String) -> Void        // Proceed anyway with reason
    let onSnooze: (Int) -> Void            // Snooze for N minutes
    let onClose: () -> Void                // Cancel
    
    @State private var reason: String = ""
    @FocusState private var reasonFieldFocused: Bool
    
    private var snoozeOptions: [Int] {
        AppPreferencesEnhanced.shared.dose2SnoozeOptionsCSV
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    
                    Text("Hard no-wake is on")
                        .font(.title2.bold())
                    
                    Text("It's too close to your wake time\(isWorkday ? " for work" : "")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
                
                // Warning message
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Wake in \(minutesUntilWake) minutes")
                            .font(.headline)
                    }
                    
                    Text("Proceeding may reduce sleep before \(isWorkday ? "work" : "your wake time") and hurt tomorrow's schedule.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                // Reason field (if override allowed)
                if allowOverride {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reason (required to proceed)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        
                        TextField("Why are you taking Dose 2 now?", text: $reason, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                            .focused($reasonFieldFocused)
                    }
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    // Proceed anyway (destructive, requires reason)
                    if allowOverride {
                        Button(action: {
                            guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                                reasonFieldFocused = true
                                return
                            }
                            onProceed(reason)
                        }) {
                            Text("Proceed anyway")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red.opacity(reason.isEmpty ? 0.3 : 1.0))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .disabled(reason.isEmpty)
                    }
                    
                    // Snooze options
                    HStack(spacing: 12) {
                        ForEach(snoozeOptions.prefix(3), id: \.self) { minutes in
                            Button(action: {
                                onSnooze(minutes)
                            }) {
                                VStack(spacing: 4) {
                                    Text("Snooze")
                                        .font(.caption)
                                    Text("\(minutes)m")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                            }
                        }
                    }
                    
                    // Close
                    Button(action: onClose) {
                        Text("Close")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                    }
                }
            }
            .padding()
            .navigationTitle("Dose 2 Guard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onClose()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview

#Preview {
    GuardNoWakeSheet(
        minutesUntilWake: 105,
        isWorkday: true,
        allowOverride: true,
        onProceed: { reason in
            print("Proceed with reason: \(reason)")
        },
        onSnooze: { minutes in
            print("Snooze \(minutes) minutes")
        },
        onClose: {
            print("Close")
        }
    )
}
