import SwiftUI
import LocalAuthentication

enum ResetMode: String, CaseIterable, Identifiable {
    case soft, hard
    var id: String { rawValue }
    var title: String { self == .soft ? "Soft reset" : "Hard reset" }
    var subtitle: String {
        switch self {
        case .soft: return "Archive tonight and start a fresh night"
        case .hard: return "Close and delete tonight's data (requires confirmation)"
        }
    }
}

struct ResetNightSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var mode: ResetMode = .soft
    @State private var reason: String = ""
    @State private var keyword: String = ""
    let requireBiometric: Bool
    let onConfirm: (_ mode: ResetMode, _ reason: String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode") {
                    Picker("Choose", selection: $mode) {
                        ForEach(ResetMode.allCases) { m in
                            VStack(alignment: .leading) {
                                Text(m.title).bold()
                                Text(m.subtitle).font(.footnote).foregroundStyle(.secondary)
                            }.tag(m)
                        }
                    }
                    .pickerStyle(.inline)
                }
                Section("Reason") {
                    TextField("Why are you resetting?", text: $reason, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }
                if mode == .hard {
                    Section("Confirmation") {
                        Text("Type RESET to confirm").font(.footnote)
                        TextField("Type RESET", text: $keyword)
                    }
                }
                Section {
                    Button(role: .destructive) {
                        handleConfirm()
                    } label: {
                        Label(mode == .soft ? "Soft reset night" : "Hard reset night", systemImage: "arrow.clockwise")
                    }
                    .disabled(!canConfirm)
                    Button("Cancel") { dismiss() }
                }
            }
            .navigationTitle("Reset Night")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var canConfirm: Bool {
        guard !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if mode == .hard {
            return keyword.uppercased() == "RESET"
        }
        return true
    }

    private func handleConfirm() {
        if mode == .hard && requireBiometric {
            var authError: NSError?
            let context = LAContext()
            if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Confirm hard reset") { ok, _ in
                    DispatchQueue.main.async {
                        if ok { onConfirm(mode, reason) }
                    }
                }
                return
            }
        }
        onConfirm(mode, reason)
    }
}
