import SwiftUI

struct TodayLogView: View {
    @StateObject private var vm = TodayViewModel(controller: RealDoseLogController())
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    GroupBox {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Tonight plan").font(.title3).bold()
                                Text("Dose 1: \(vm.prefs.planDose1G.formatG)")
                                Text("Window: \(vm.windowStartMinutes) to \(vm.windowEndMinutes) min after Dose 1")
                                    .foregroundStyle(.secondary).font(.footnote)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Dose 2: \(vm.prefs.planDose2G.formatG)")
                                Spacer().frame(height: 4)
                            }
                        }
                    }
                    SafetyBanner(nightTotalG: vm.prefs.totalNightG, planDose1G: vm.prefs.planDose1G, planDose2G: vm.prefs.planDose2G)
                    StatusChips(healthOK: true, whoopOK: true, wakeSource: "manual", onChangeWakeSource: {}, onCheckHealth: {}, onCheckWhoop: {})
                    Text(nightContextLine).font(.footnote).foregroundStyle(.secondary)
                    TimelineView(.periodic(from: Date(), by: 30)) { _ in
                        CountdownRing(progress: vm.ringProgress, status: vm.ringStatus, reasonText: vm.dose2ReasonText)
                    }
                    VStack(spacing: 10) {
                        Text("Primary Actions").font(.footnote).foregroundStyle(.secondary)
                        HStack {
                            Button("In bed now", action: vm.logInBedNow).buttonStyle(.bordered)
                            Button("Dose 1 now", action: vm.logDose1Now).buttonStyle(.borderedProminent)
                        }
                        HStack {
                            Button("Dose 2 now", action: vm.tryLogDose2).buttonStyle(.borderedProminent).disabled(!vm.dose2Enabled)
                            Button("Final wake", action: vm.logFinalWake).buttonStyle(.bordered)
                        }
                        Text("Events").font(.footnote).foregroundStyle(.secondary)
                        HStack {
                            Button("Alarm wake", action: vm.logAlarmWake).buttonStyle(.bordered)
                            Button("Bathroom", action: vm.logBathroom).buttonStyle(.bordered)
                        }
                        HStack {
                            Button("Undo last", action: vm.undoLast).buttonStyle(.bordered)
                            Button("Edit plan") { showSettings = true }.buttonStyle(.bordered)
                        }
                    }
                    EventStrip(events: vm.lastEvents, onUndo: vm.undoLast)
                }.padding(16)
            }
            .navigationTitle("DoseTrack")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showSettings = true } label: { Image(systemName: "gearshape") } } }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $vm.showEarlyDoseSheet) {
                EarlyDoseSheet(minutes: $vm.earlyMinutesRequested, reason: $vm.earlyReason, allowed: 0...vm.prefs.maxEarlyMinutes, quickChoices: vm.prefs.defaultEarlyButtons, requireReason: vm.prefs.requireEarlyReason, onConfirm: vm.confirmEarlyDose2, onCancel: { vm.showEarlyDoseSheet = false })
            }
            .onAppear(perform: vm.onAppear)
        }
    }
    private var nightContextLine: String {
        let df = DateFormatter(); df.dateFormat = "EEE, MMM d"; let today = df.string(from: Date())
        let tzMin = TimeZone.current.secondsFromGMT() / 60; let sign = tzMin >= 0 ? "+" : "-"; let absMin = abs(tzMin)
        let tzStr = String(format: "UTC%@$%02d:%02d".replacingOccurrences(of: "@", with: sign), "", absMin / 60, absMin % 60)
        let key = vm.nightKey ?? "Key unknown"
        return "\(today) • \(tzStr) • \(key)"
    }
}

// Replace with your real controller. Stub for compilation.
final class RealDoseLogController: DoseLogControllering {
    private var open: (nightKey: String, dose1TimeUTC: Date?, dose2TimeUTC: Date?, finalWakeTimeUTC: Date?, timezoneOffsetMinutes: Int)? = (nightKey: nil, dose1TimeUTC: nil, dose2TimeUTC: nil, finalWakeTimeUTC: nil, timezoneOffsetMinutes: TimeZone.current.secondsFromGMT()/60)
    private var events: [LoggedEvent] = []
    func consumePendingFromWidget() {}
    func fetchOpenNight() -> (nightKey: String, dose1TimeUTC: Date?, dose2TimeUTC: Date?, finalWakeTimeUTC: Date?, timezoneOffsetMinutes: Int)? { open }
    func fetchRecentEvents(limit: Int) -> [LoggedEvent] { Array(events.suffix(limit)).reversed() }
    func mintNightKeyIfNeeded() { if open?.nightKey == nil { open?.nightKey = Self.makeNightKey(); log(kind: .inBed, detail: "") } }
    func logInBedNow() { mintNightKeyIfNeeded(); log(kind: .inBed, detail: "") }
    func logDose1Now(grams: Double) { mintNightKeyIfNeeded(); open?.dose1TimeUTC = Date(); log(kind: .dose1, detail: String(format: "%.2f g", grams)) }
    func logDose2Now(grams: Double, overrideEarlyMinutes: Int?, overrideReason: String?) {
        open?.dose2TimeUTC = Date(); var d = String(format: "%.2f g", grams); if let m = overrideEarlyMinutes { d += " • early \(m)m" }; log(kind: .dose2, detail: d)
    }
    func logFinalWakeNow(provenance: String) { open?.finalWakeTimeUTC = Date(); log(kind: .finalWake, detail: provenance) }
    func logAlarmWakeNow() { log(kind: .alarmWake, detail: "") }
    func logBathroomNow() { log(kind: .bathroom, detail: "") }
    func undoLastEvent() { _ = events.popLast() }
    func startLiveActivityIfEnabled(prefs: AppPreferences, dose1UTC: Date, windowStartMin: Int, windowEndMin: Int) {}
    func endLiveActivity() {}
    private func log(kind: LoggedEvent.Kind, detail: String) { events.append(LoggedEvent(kind: kind, timestampUTC: Date(), detail: detail)) }
    private static func makeNightKey() -> String { let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; df.timeZone = TimeZone(secondsFromGMT: 0); return df.string(from: Date()) }
}
