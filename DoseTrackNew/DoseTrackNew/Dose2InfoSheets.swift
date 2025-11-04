//
//  Dose2InfoSheets.swift
//  DoseTrack
//
//  Info sheets for Dose 2 blocked states and already-logged state
//

import SwiftUI

/// Sheet shown when Dose 2 is blocked (no override allowed)
struct Dose2BlockedSheet: View {
    let reason: String
    let onRemindAtStart: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: DT.lg) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("Dose 2 is locked")
                .font(.title2.bold())
            
            Text(reason)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: DT.md) {
                if let onRemindAtStart {
                    Button("Remind me at window start") {
                        onRemindAtStart()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, DT.sm)
        }
        .padding(DT.xl)
        .presentationDetents([.height(280)])
    }
}

/// Sheet shown when user needs to log Dose 1 first
struct NeedDose1Sheet: View {
    let onLogDose1Now: () -> Void
    let onSetReminder: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: DT.lg) {
            Image(systemName: "1.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
            
            Text("Log Dose 1 first")
                .font(.title2.bold())
            
            Text("Log Dose 1 to start the dosing window.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: DT.md) {
                Button("Log Dose 1 now") {
                    onLogDose1Now()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                
                Button("Set reminder") {
                    onSetReminder()
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, DT.sm)
        }
        .padding(DT.xl)
        .presentationDetents([.height(320)])
    }
}

/// Sheet shown when Dose 2 is already logged
struct Dose2AlreadyLoggedSheet: View {
    let loggedAt: Date
    let onEditTime: () -> Void
    let onUndo: (() -> Void)?
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: DT.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            
            Text("Dose 2 logged")
                .font(.title2.bold())
            
            Text("Logged at \(formatTime(loggedAt))")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: DT.md) {
                Button("Edit time (tonight only)") {
                    onEditTime()
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                if let onUndo {
                    Button("Undo (30s)", role: .destructive) {
                        onUndo()
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, DT.sm)
        }
        .padding(DT.xl)
        .presentationDetents([.height(320)])
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Previews

#Preview("Blocked") {
    Dose2BlockedSheet(
        reason: "Dose 2 must be at least 210 min after Dose 1. You're 38 min early.",
        onRemindAtStart: {}
    )
}

#Preview("Need Dose 1") {
    NeedDose1Sheet(
        onLogDose1Now: {},
        onSetReminder: {}
    )
}

#Preview("Already Logged") {
    Dose2AlreadyLoggedSheet(
        loggedAt: Date(),
        onEditTime: {},
        onUndo: {}
    )
}
