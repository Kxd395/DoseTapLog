import SwiftUI
import LocalAuthentication

enum ResetMode: String, CaseIterable, Identifiable {
    case soft, hard
    var id: String { rawValue }
    var title: String { self == .soft ? "Soft Reset" : "Hard Reset" }
    var subtitle: String {
        switch self {
        case .soft: return "Archive tonight and start fresh (reversible)"
        case .hard: return "Close and delete tonight's data (permanent)"
        }
    }
}

struct ResetNightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode: ResetMode = .soft
    @State private var reason: String = ""
    @State private var keyword: String = ""
    
    let requireBiometric: Bool
    let allowHardReset: Bool
    let reasonRequired: Bool
    let hasFinalWake: Bool
    let onConfirm: (_ mode: ResetMode, _ reason: String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Reset Mode") {
                    Picker("Choose reset type", selection: $mode) {
                        ForEach(ResetMode.allCases) { m in
                            if m == .hard && !allowHardReset { EmptyView() }
                            else {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(m.title).bold()
                                    Text(m.subtitle).font(.footnote).foregroundStyle(.secondary)
                                }
                                .tag(m)
                            }
                        }
                    }
                    .pickerStyle(.inline)
                }
                
                if hasFinalWake && mode == .soft {
                    Section {
                        Label("Soft reset blocked", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("This night already has a Final wake. Only Hard reset is allowed.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Section("Reason\(reasonRequired ? " (required)" : "")") {
                    TextField("Why are you resetting?", text: $reason, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                if mode == .hard {
                    Section("Confirmation") {
                        Text("Type RESET to confirm permanent deletion")
                            .font(.footnote)
                            .foregroundStyle(.red)
                        TextField("Type RESET", text: $keyword)
                            .textInputAutocapitalization(.characters)
                        
                        if requireBiometric {
                            Label("Face ID / Touch ID required", systemImage: "faceid")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        handleConfirm()
                    } label: {
                        Label(
                            mode == .soft ? "Soft Reset Night" : "Hard Reset Night",
                            systemImage: mode == .soft ? "arrow.counterclockwise" : "trash"
                        )
                    }
                    .disabled(!canConfirm)
                    
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Reset Night")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var canConfirm: Bool {
        // Soft reset blocked if Final wake exists
        if hasFinalWake && mode == .soft {
            return false
        }
        
        // Reason required?
        if reasonRequired && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        
        // Hard reset requires keyword
        if mode == .hard {
            return keyword.uppercased() == "RESET"
        }
        
        return true
    }

    private func handleConfirm() {
        if mode == .hard && requireBiometric {
            authenticateAndConfirm()
        } else {
            onConfirm(mode, reason)
            dismiss()
        }
    }
    
    private func authenticateAndConfirm() {
        var authError: NSError?
        let context = LAContext()
        
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Confirm hard reset deletion"
            ) { success, error in
                DispatchQueue.main.async {
                    if success {
                        onConfirm(mode, reason)
                        dismiss()
                    } else {
                        // Authentication failed - user cancelled or error
                        // Could show alert here if needed
                    }
                }
            }
        } else {
            // Biometric not available - fallback to just confirming
            onConfirm(mode, reason)
            dismiss()
        }
    }
}

#Preview {
    ResetNightSheet(
        requireBiometric: true,
        allowHardReset: true,
        reasonRequired: true,
        hasFinalWake: false
    ) { mode, reason in
        print("Reset: \(mode.rawValue), reason: \(reason)")
    }
}
