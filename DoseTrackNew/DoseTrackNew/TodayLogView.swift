import SwiftUI
import SwiftData

struct TodayLogView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vm: TodayViewModel
    @State private var showSettings = false
    
    init() {
        // Initialize with a placeholder - will be updated in .onAppear
        _vm = StateObject(wrappedValue: TodayViewModel(controller: StubController()))
    }
    
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
                    
                    // Helper banner when window expired and session stuck
                    if vm.nightKey != nil && vm.dose1TimeUTC != nil && vm.dose2TimeUTC == nil && vm.finalWakeTimeUTC == nil {
                        // Check if window expired
                        if let d1 = vm.dose1TimeUTC, Date().timeIntervalSince(d1) / 60.0 > Double(vm.windowEndMinutes) {
                            GroupBox {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundStyle(.orange)
                                        Text("Window Expired")
                                            .font(.headline)
                                            .bold()
                                    }
                                    Text("The Dose 2 window has closed. You can either log a missed dose or reset this night to start fresh.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 12) {
                                        Button {
                                            vm.presentResetNight()
                                        } label: {
                                            Label("Reset Night", systemImage: "arrow.counterclockwise")
                                                .font(.footnote)
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(.orange)
                                        
                                        Button("Log Missed Dose") {
                                            // TODO: Implement missed dose logging
                                        }
                                        .buttonStyle(.bordered)
                                        .font(.footnote)
                                    }
                                }
                            }
                            .backgroundStyle(.orange.opacity(0.1))
                        }
                    }
                    
                    VStack(spacing: 10) {
                        Text("Primary Actions").font(.footnote).foregroundStyle(.secondary)
                        HStack {
                            Button("In bed now", action: vm.logInBedNow).buttonStyle(.bordered)
                            Button("Dose 1 now") { vm.logDose1Now(grams: vm.prefs.planDose1G) }.buttonStyle(.borderedProminent)
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
                        
                        // SAFETY: Reset Night button - always show when session exists
                        if vm.nightKey != nil {
                            HStack {
                                Spacer()
                                Button(role: .destructive) {
                                    vm.presentResetNight()
                                } label: {
                                    Label("Reset Night", systemImage: "arrow.counterclockwise")
                                        .font(.footnote)
                                        .bold()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                    }
                    
                    // Undo Reset Banner (shows after soft reset)
                    if vm.showUndoResetBanner {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Night Reset").font(.headline).bold()
                                Text("Undo within \(AppPreferences.shared.resetUndoWindowSec) seconds")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Undo") {
                                vm.undoResetNight()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    EventStrip(events: vm.lastEvents, onUndo: vm.undoLast)
                }.padding(16)
            }
            .navigationTitle("DoseTrack")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showSettings = true } label: { Image(systemName: "gearshape") } } }
            .sheet(isPresented: $showSettings) { SettingsViewEnhanced() }
            .sheet(isPresented: $vm.showEarlyDoseSheet) {
                EarlyDoseSheet(minutes: $vm.earlyMinutesRequested, reason: $vm.earlyReason, allowed: 0...vm.prefs.maxEarlyMinutes, quickChoices: vm.prefs.defaultEarlyButtons, requireReason: vm.prefs.requireEarlyReason, onConfirm: vm.confirmEarlyDose2, onCancel: { vm.showEarlyDoseSheet = false })
            }
            .sheet(isPresented: $vm.showResetSheet) {
                ResetNightSheet(
                    requireBiometric: AppPreferences.shared.resetRequireBiometricHard,
                    allowHardReset: AppPreferences.shared.resetAllowHard,
                    reasonRequired: AppPreferences.shared.resetReasonRequired,
                    hasFinalWake: vm.finalWakeTimeUTC != nil
                ) { mode, reason in
                    vm.performResetNight(mode: mode, reason: reason)
                    vm.showResetSheet = false
                }
            }
            .onAppear {
                // Initialize controller with modelContext on first appear
                if vm.controller is StubController {
                    let realController = DoseLogController(modelContext)
                    vm.updateController(realController)
                }
                vm.onAppear()
            }
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

// Stub controller for initialization (replaced on first .onAppear)
final class StubController: DoseLogControllering {
    func consumePendingFromWidget() {}
    func fetchOpenNight() -> (nightKey: String, dose1TimeUTC: Date?, dose2TimeUTC: Date?, finalWakeTimeUTC: Date?, timezoneOffsetMinutes: Int)? { nil }
    func fetchRecentEvents(limit: Int) -> [LoggedEvent] { [] }
    func mintNightKeyIfNeeded() {}
    func logInBedNow() {}
    func logDose1Now(grams: Double) {}
    func logDose2Now(grams: Double, overrideEarlyMinutes: Int?, overrideReason: String?) {}
    func logDose2Now(grams: Double, overrideKind: String?, overrideMinutes: Int?, overrideReason: String?) {}
    func logFinalWakeNow(provenance: String) {}
    func logAlarmWakeNow() {}
    func logBathroomNow() {}
    func undoLastEvent() {}
    func resetCurrentNight(archive: Bool) {}
    func resetNight(mode: ResetMode, reason: String, resetBatchId: String) {}
    func undoResetNight(resetBatchId: String) {}
    func cancelDose2Notifications() {}
    func startLiveActivityIfEnabled(prefs: LegacyAppPreferences, dose1UTC: Date, windowStartMin: Int, windowEndMin: Int) {}
    func endLiveActivity() {}
}

