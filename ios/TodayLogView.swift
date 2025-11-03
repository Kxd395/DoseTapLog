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
                        
                        // Override Banner (if armed for early/late)
                        if let message = vm.bannerMessage {
                            HStack {
                                Image(systemName: bannerIcon(for: vm.bannerStyle))
                                    .foregroundStyle(bannerColor(for: vm.bannerStyle))
                                Text(message)
                                    .font(.footnote)
                                Spacer()
                            }
                            .padding(8)
                            .background(bannerColor(for: vm.bannerStyle).opacity(0.1))
                            .cornerRadius(8)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        HStack {
                            Button("Dose 2 now") {
                                vm.tryLogDose2Tapped()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!vm.evaluateDose2Gate().enabled)
                            .onLongPressGesture {
                                vm.longPressDose2()
                            }
                            
                            Button("Final wake", action: vm.logFinalWake).buttonStyle(.bordered)
                        }
                        
                        // Helper text for Dose 2
                        let gate = vm.evaluateDose2Gate()
                        if !gate.enabled {
                            Text(gate.reason)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Events").font(.footnote).foregroundStyle(.secondary)
                        HStack {
                            Button("Alarm wake") {
                                vm.showAlarmWakeSheet()
                            }
                            .buttonStyle(.bordered)
                            
                            Button("Bathroom") {
                                vm.showBathroomWakeSheet()
                            }
                            .buttonStyle(.bordered)
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
                                Text("Undo within \(AppPreferencesEnhanced.shared.resetUndoWindowSec) seconds")
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
                EarlyDoseSheetView(
                    isPresented: $vm.showEarlyDoseSheet,
                    minutesEarly: vm.evaluateDose2Gate().minutesOffset,
                    dose2Grams: vm.prefs.planDose2G,
                    requireReason: AppPreferences.shared.earlyRequireReason,
                    timePriorOptions: AppPreferences.shared.earlyTimePriorOptions,
                    onConfirm: { reason, timePrior in
                        vm.confirmEarlyDose2(reason: reason, timePriorMin: timePrior)
                    }
                )
            }
            .sheet(isPresented: $vm.showLateDoseSheet) {
                LateDoseSheetView(
                    isPresented: $vm.showLateDoseSheet,
                    dose2Grams: vm.prefs.planDose2G,
                    minutesAfterWindow: vm.evaluateDose2Gate().minutesOffset,
                    requireReason: AppPreferences.shared.lateRequireReason,
                    quickChoices: [5, 10, 15, 20, 30],
                    maxLateMinutes: AppPreferences.shared.maxLateMinutes,
                    onConfirm: { reason, minutesLate in
                        vm.confirmLateDose2(reason: reason)
                    }
                )
            }
            .sheet(isPresented: $vm.showResetSheet) {
                ResetNightSheet(
                    requireBiometric: AppPreferencesEnhanced.shared.resetRequireBiometricHard,
                    allowHardReset: AppPreferencesEnhanced.shared.resetAllowHard,
                    reasonRequired: AppPreferencesEnhanced.shared.resetReasonRequired,
                    hasFinalWake: vm.finalWakeTimeUTC != nil
                ) { mode, reason in
                    vm.performResetNight(mode: mode, reason: reason)
                    vm.showResetSheet = false
                }
            }
            .sheet(isPresented: $vm.showWakeSheet) {
                WakeSheetView(
                    isPresented: $vm.showWakeSheet,
                    isFinalPreset: vm.wakeSheetType == .finalWake,
                    onConfirm: { reason, isFinal, wasInterrupted, time, note in
                        vm.logWakeNow(
                            reason: reason,
                            isFinal: isFinal,
                            wasAlarmInterrupted: wasInterrupted,
                            overrideTime: time,
                            note: note?.isEmpty == false ? note : nil
                        )
                    }
                )
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
        let tzStr = String(format: "UTC%@%02d:%02d", sign, absMin / 60, absMin % 60)
        let key = vm.nightKey ?? "Key unknown"
        return "\(today) • \(tzStr) • \(key)"
    }
    
    // MARK: - Banner Helpers
    
    private func bannerIcon(for style: TodayViewModel.BannerStyle) -> String {
        switch style {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        }
    }
    
    private func bannerColor(for style: TodayViewModel.BannerStyle) -> Color {
        switch style {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .success: return .green
        }
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

