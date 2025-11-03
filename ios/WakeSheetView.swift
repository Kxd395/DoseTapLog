//
//  WakeSheetView.swift
//  DoseTrack
//
//  Sheet for logging wake events with full context
//

import SwiftUI

struct WakeSheetView: View {
    @Binding var isPresented: Bool
    @State private var reason: WakeReason = .natural
    @State private var isFinal: Bool = false
    @State private var wasAlarmInterrupted: Bool = false
    @State private var note: String = ""
    @State private var time: Date = Date()
    
    let allowTimeEditMinutes: Int
    let onConfirm: (_ reason: WakeReason, _ isFinal: Bool, _ wasAlarmInterrupted: Bool, _ time: Date, _ note: String?) -> Void
    let showSeconds: Bool
    
    init(isPresented: Binding<Bool>,
         isFinalPreset: Bool = false,
         allowTimeEditMinutes: Int = 15,
         showSeconds: Bool = false,
         onConfirm: @escaping (_ reason: WakeReason, _ isFinal: Bool, _ wasAlarmInterrupted: Bool, _ time: Date, _ note: String?) -> Void) {
        self._isPresented = isPresented
        self.allowTimeEditMinutes = allowTimeEditMinutes
        self.showSeconds = showSeconds
        self.onConfirm = onConfirm
        self._isFinal = State(initialValue: isFinalPreset)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Reason") {
                    Picker("Type", selection: $reason) {
                        ForEach(WakeReason.allCases) { r in
                            Label(r.label, systemImage: r.iconName).tag(r)
                        }
                    }
                }
                
                Section("Details") {
                    Toggle("Final wake", isOn: $isFinal)
                    
                    if reason == .alarm {
                        Toggle("Alarm interrupted", isOn: $wasAlarmInterrupted)
                    }
                    
                    DatePicker("Time", selection: $time, displayedComponents: [.hourAndMinute, .date])
                        .environment(\.locale, .current)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .onAppear { clampEditableWindow() }
                    
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section {
                    Button {
                        onConfirm(reason, isFinal, wasAlarmInterrupted, time, note.isEmpty ? nil : note)
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: reason.iconName)
                            Text(isFinal ? "Log final wake" : "Log wake now")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("Wake now")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
            }
        }
    }
    
    private func clampEditableWindow() {
        // Clamp to last N minutes to avoid backdating errors
        let minT = Date().addingTimeInterval(-Double(allowTimeEditMinutes) * 60)
        if time < minT { time = minT }
    }
}

// MARK: - Preview
#Preview("Wake Sheet - Regular") {
    WakeSheetView(
        isPresented: .constant(true),
        onConfirm: { reason, isFinal, interrupted, time, note in
            print("Logged: \(reason.label), final: \(isFinal)")
        }
    )
}

#Preview("Wake Sheet - Final Preset") {
    WakeSheetView(
        isPresented: .constant(true),
        isFinalPreset: true,
        onConfirm: { reason, isFinal, interrupted, time, note in
            print("Logged: \(reason.label), final: \(isFinal)")
        }
    )
}
