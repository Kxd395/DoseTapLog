import SwiftUI

struct EarlyDoseSheet: View {
    @Binding var minutes: Int
    @Binding var reason: EarlyReason
    let allowed: ClosedRange<Int>
    let quickChoices: [Int]
    let requireReason: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Why early") {
                    Picker("Reason", selection: $reason) {
                        ForEach(EarlyReason.allCases) { r in Text(r.rawValue).tag(r) }
                    }.disabled(!requireReason)
                }
                Section("How early") {
                    HStack { ForEach(quickChoices, id: \.self) { m in Button("\(m)m") { minutes = m }.buttonStyle(.bordered) } }
                    Stepper(value: $minutes, in: allowed, step: 1) { Text("Early by \(minutes) minutes") }
                }
                Section {
                    Button("Confirm early Dose 2") { onConfirm() }.buttonStyle(.borderedProminent)
                    Button("Cancel", role: .cancel) { onCancel() }
                }
            }.navigationTitle("Dose 2 early")
        }
    }
}

struct SettingsView: View {
    @State var prefs = AppPreferences.load()
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Night plan defaults") {
                    Picker("Total night (g)", selection: $prefs.totalNightG) {
                        ForEach([3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5,7.0,7.5,8.0,8.5,9.0], id: \.self) { g in Text(String(format: "%.1f g", g)).tag(g) }
                    }
                    Picker("Split", selection: $prefs.split) {
                        Text("50 50").tag(AppPreferences.Split.fiftyFifty)
                        Text("60 40").tag(AppPreferences.Split.sixtyForty)
                        Text("40 60").tag(AppPreferences.Split.fortySixty)
                        Text("Custom").tag(AppPreferences.Split.custom)
                    }
                    Picker("Rounding step", selection: $prefs.roundingStepG) {
                        Text("0.25 g").tag(0.25); Text("0.5 g").tag(0.5)
                    }
                }
                Section("Dose 2 window") {
                    Stepper("Start \(prefs.windowStartMin) min", value: $prefs.windowStartMin, in: 120...300, step: 5)
                    Stepper("End \(prefs.windowEndMin) min", value: $prefs.windowEndMin, in: 150...360, step: 5)
                }
                Section("Early dose policy") {
                    Toggle("Allow early dose", isOn: $prefs.allowEarlyDose)
                    Stepper("Max early \(prefs.maxEarlyMinutes) min", value: $prefs.maxEarlyMinutes, in: 0...30)
                    Toggle("Require reason", isOn: $prefs.requireEarlyReason)
                    NavigationLink("Default quick choices") {
                        List {
                            ForEach([5,10,15,20,30], id: \.self) { m in
                                HStack {
                                    Text("\(m) minutes"); Spacer()
                                    let selected = prefs.defaultEarlyButtons.contains(m)
                                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                }.contentShape(Rectangle()).onTapGesture {
                                    if let i = prefs.defaultEarlyButtons.firstIndex(of: m) { prefs.defaultEarlyButtons.remove(at: i) } else { prefs.defaultEarlyButtons.append(m) }
                                }
                            }
                        }.navigationTitle("Quick choices")
                    }
                }
                Section("Notifications and Live Activity") {
                    Toggle("Live Activity for Dose 2", isOn: $prefs.liveActivityEnabled)
                    Toggle("Notify at window start", isOn: $prefs.notifyAtStart)
                    Toggle("Notify at halfway", isOn: $prefs.notifyAtHalf)
                    Toggle("Notify at window end", isOn: $prefs.notifyAtEnd)
                }
            }.navigationTitle("Settings").toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Save") { prefs.save(); dismiss() } }
            }
        }
    }
}
