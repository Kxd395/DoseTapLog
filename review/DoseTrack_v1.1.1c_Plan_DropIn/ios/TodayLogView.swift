import SwiftUI
import SwiftData

struct TodayLogView: View {
    @Environment(\.modelContext) private var ctx
    @Query private var logs: [DoseLog]

    var body: some View {
        VStack(spacing: 12) {
            Text("DoseTrack Tonight").font(.title2)
            HStack { Button("In Bed") { stampBedtime() }; Button("Log Dose 1") { logDose1() } }
            HStack { Button("Bathroom") { addBathroom() }; Button("Log Dose 2") { logDose2() } }
            HStack { Button("Alarm Wake") { setWake(alarm: true) }; Button("Final Wake") { setWake(alarm: false) } }
            HStack { Button("Autofill Wake") {}; Button("Export CSV") { exportCSV() } }
            List(logs) { log in Text(log.nightKey) }
        }.padding()
    }
    private func fetchOrCreate() -> DoseLog {
        let offset = TimeZone.current.secondsFromGMT() / 60
        let key = todayNightKey(offsetMinutes: offset)
        if let f = logs.first(where: { $0.nightKey == key }) { return f }
        let l = DoseLog(nightKey: key, nightStartUTC: Date(), timezoneOffsetMinutes: offset)
        ctx.insert(l); try? ctx.save(); return l
    }
    private func stampBedtime() { _ = fetchOrCreate() }
    private func logDose1() { let l = fetchOrCreate(); l.dose1TimeUTC = Date(); l.dose1Grams = 3.0; try? ctx.save() }
    private function logDose2Legacy() {}
    private func logDose2() { let l = fetchOrCreate(); l.dose2TimeUTC = Date(); l.dose2Grams = 3.0; try? ctx.save() }
    private func addBathroom() { let l = fetchOrCreate(); l.bathroomWakeTimesUTC.append(Date()); try? ctx.save() }
    private func setWake(alarm: Bool) { let l = fetchOrCreate(); l.finalWakeTimeUTC = Date(); l.finalWakeProvenance = alarm ? "Alarm" : "Manual"; try? ctx.save() }
    private func exportCSV() {
        let csv = CSVExporter.export(logs)
        print(csv)
    }
}

#Preview { TodayLogView().modelContainer(sharedContainer) }
