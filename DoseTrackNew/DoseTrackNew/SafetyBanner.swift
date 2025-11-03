import SwiftUI

struct SafetyBanner: View {
    let perDoseMinG: Double = 1.5
    let perDoseMaxG: Double = 4.5
    let nightTotalG: Double
    let planDose1G: Double
    let planDose2G: Double
    
    var planWithinBounds: Bool {
        planDose1G >= perDoseMinG && planDose1G <= perDoseMaxG &&
        planDose2G >= perDoseMinG && planDose2G <= perDoseMaxG &&
        nightTotalG >= 3.0 && nightTotalG <= 9.0
    }
    var body: some View {
        HStack(spacing: 12) {
            Label("Per dose \(perDoseMinG.formatG) to \(perDoseMaxG.formatG)", systemImage: planWithinBounds ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(planWithinBounds ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                .clipShape(Capsule())
            Text("Night total \(nightTotalG.formatG)")
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Color.gray.opacity(0.12)).clipShape(Capsule())
        }.font(.callout)
    }
}
extension Double { var formatG: String { String(format: "%.2f g", self) } }

struct StatusChips: View {
    let healthOK: Bool; let whoopOK: Bool; let wakeSource: String
    let onChangeWakeSource: () -> Void; let onCheckHealth: () -> Void; let onCheckWhoop: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Button(action: onCheckHealth) { Text(healthOK ? "Health OK" : "Health denied") }.chipStyle(ok: healthOK)
            Button(action: onCheckWhoop) { Text(whoopOK ? "WHOOP OK" : "WHOOP offline") }.chipStyle(ok: whoopOK)
            Button(action: onChangeWakeSource) { Text("Wake: \(wakeSource)") }.chipNeutral()
        }.font(.callout)
    }
}
extension Button {
    func chipStyle(ok: Bool) -> some View {
        self.padding(.horizontal, 10).padding(.vertical, 8).background(ok ? Color.green.opacity(0.15) : Color.orange.opacity(0.18)).clipShape(Capsule())
    }
    func chipNeutral() -> some View {
        self.padding(.horizontal, 10).padding(.vertical, 8).background(Color.gray.opacity(0.12)).clipShape(Capsule())
    }
}

struct CountdownRing: View {
    enum Status { case idle, waiting, open, expired }
    let progress: Double; let status: Status; let reasonText: String
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().stroke(Color.gray.opacity(0.18), lineWidth: 14)
                Circle().trim(from: 0, to: max(0, min(1, progress)))
                    .stroke(statusColor, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90)).animation(.easeInOut(duration: 0.6), value: progress)
                Text(centerText).font(.title3).bold()
            }.frame(width: 160, height: 160)
            Text(reasonText).font(.footnote).foregroundStyle(.secondary)
        }.padding(.vertical, 6)
    }
    private var statusColor: Color { switch status { case .idle: return .gray; case .waiting: return .gray; case .open: return .blue; case .expired: return .red } }
    private var centerText: String { switch status { case .idle: return "Ready"; case .waiting: return "Waiting"; case .open: return "Open"; case .expired: return "Expired" } }
}

struct EventStrip: View {
    let events: [LoggedEvent]; let onUndo: () -> Void; @State private var canUndo = true
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent events").font(.subheadline).foregroundStyle(.secondary)
            ForEach(events) { e in
                HStack {
                    Text(symbol(for: e.kind)); Text(label(for: e)).bold(); Spacer(); Text(relTime(e.timestampUTC)).foregroundStyle(.secondary)
                }.font(.callout)
            }
            if canUndo {
                Button("Undo last", action: { onUndo(); canUndo = false; DispatchQueue.main.asyncAfter(deadline: .now() + 60) { canUndo = true } })
                    .buttonStyle(.borderedProminent).disabled(events.isEmpty)
            }
        }.padding(12).background(Color.gray.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: 14))
    }
    private func symbol(for k: LoggedEvent.Kind) -> String { switch k { case .inBed: "🛏️"; case .dose1: "💊1"; case .dose2: "💊2"; case .bathroom: "🚻"; case .alarmWake: "⏰"; case .finalWake: "🌅" } }
    private func label(for e: LoggedEvent) -> String { switch e.kind { case .dose1, .dose2: return "\(e.kind == .dose1 ? "Dose 1" : "Dose 2") \(e.detail)"; default: return title(for: e.kind) } }
    private func title(for k: LoggedEvent.Kind) -> String { switch k { case .inBed: "In bed"; case .dose1: "Dose 1"; case .dose2: "Dose 2"; case .bathroom: "Bathroom"; case .alarmWake: "Alarm wake"; case .finalWake: "Final wake" } }
    private func relTime(_ d: Date) -> String { let m = Int(Date().timeIntervalSince(d) / 60); if m < 1 { return "now" }; if m < 60 { return "\(m)m ago" }; return "\(m/60)h \(m%60)m ago" }
}
