//
//  Dose2OverrideSheet.swift
//  DoseTrack
//
//  Decision sheet for early/late Dose 2 overrides
//

import SwiftUI

/// Reusable override decision sheet for Dose 2 early/late scenarios
struct Dose2OverrideSheet: View {
    let title: String
    let subtitle: String
    let reasonRequired: Bool
    let primaryLabel: String
    let secondaryLabel: String?
    let onPrimary: (_ reason: String?) -> Void
    let onSecondary: (() -> Void)?
    let onCancel: () -> Void
    
    @State private var reason: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Label(title, systemImage: "exclamationmark.triangle.fill")
                        .font(.title3.bold())
                        .foregroundStyle(.orange)
                    
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                
                // Reason field
                VStack(alignment: .leading, spacing: 8) {
                    Text(reasonRequired ? "Reason (required)" : "Reason (optional)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                    
                    TextField("Why are you overriding?", text: $reason, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    // Primary action (Log early/late now)
                    Button {
                        onPrimary(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : reason)
                    } label: {
                        Text(primaryLabel)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Palette.primary)
                            .foregroundStyle(.white)
                            .bold()
                            .cornerRadius(12)
                    }
                    .disabled(reasonRequired && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    
                    // Secondary action (Remind me / Mark missed)
                    if let secondaryLabel = secondaryLabel, let onSecondary = onSecondary {
                        Button {
                            onSecondary()
                        } label: {
                            Text(secondaryLabel)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Palette.surfaceHi)
                                .foregroundStyle(Palette.text)
                                .cornerRadius(12)
                        }
                    }
                    
                    // Cancel
                    Button("Cancel", role: .cancel) {
                        onCancel()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Palette.bg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Previews

#Preview("Early Override") {
    Dose2OverrideSheet(
        title: "Dose 2 early",
        subtitle: "You're 15m before the window.",
        reasonRequired: false,
        primaryLabel: "Log early now",
        secondaryLabel: "Remind me at window start",
        onPrimary: { reason in
            print("Primary: \(reason ?? "no reason")")
        },
        onSecondary: {
            print("Secondary: remind")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}

#Preview("Late Override") {
    Dose2OverrideSheet(
        title: "Dose 2 late",
        subtitle: "You're 45m after the window.",
        reasonRequired: true,
        primaryLabel: "Log late now",
        secondaryLabel: "Mark as missed",
        onPrimary: { reason in
            print("Primary: \(reason ?? "no reason")")
        },
        onSecondary: {
            print("Secondary: missed")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
