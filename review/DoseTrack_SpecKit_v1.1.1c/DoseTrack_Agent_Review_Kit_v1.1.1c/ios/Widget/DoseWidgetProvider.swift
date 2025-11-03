import WidgetKit
import SwiftUI
struct DoseEntry: TimelineEntry {
    let date: Date
    let title: String
    let d1g: Double
    let d2g: Double
    let d1Time: Date
    let winStart: Date
    let winEnd: Date
}
struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DoseEntry { previewEntry() }
    func getSnapshot(in context: Context, completion: @escaping (DoseEntry) -> ()) { completion(previewEntry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> ()) {
        var comps = DateComponents(); comps.hour = Config.defaultBedtimeHour; comps.minute = Config.defaultBedtimeMinute
        let cal = Calendar(identifier: .gregorian)
        let bedtime = cal.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) ?? Date()
        let plan = NightPlanRecommender.makePlan(totalNightG: Config.defaultTotalGrams, preferredSplitFirstPct: 50, historyDose2ToWakeMinAvg: nil, recoveryScore0to100: nil)
        let d1Time = bedtime
        let winStart = d1Time.addingTimeInterval(Double(plan.windowStartMinAfterDose1) * 60.0)
        let winEnd = d1Time.addingTimeInterval(Double(plan.windowEndMinAfterDose1) * 60.0)
        let entry = DoseEntry(date: Date(), title: "Tonight plan", d1g: plan.dose1DisplayG, d2g: plan.dose2DisplayG, d1Time: d1Time, winStart: winStart, winEnd: winEnd)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(1800))))
    }
    private func previewEntry() -> DoseEntry {
        let now = Date()
        return DoseEntry(date: now, title: "Tonight plan", d1g: 3.25, d2g: 3.25, d1Time: now, winStart: now.addingTimeInterval(150*60), winEnd: now.addingTimeInterval(240*60))
    }
}
struct DoseWidgetEntryView: View {
    var entry: Provider.Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.title).font(.headline)
            Text(String(format: "Dose 1: %.2f g", entry.d1g)).font(.subheadline)
            Text(String(format: "Dose 2: %.2f g", entry.d2g)).font(.subheadline)
            Text("Window: \(entry.winStart.formatted(date: .omitted, time: .shortened)) to \(entry.winEnd.formatted(date: .omitted, time: .shortened))").font(.caption)
        }.padding()
    }
}
@main
struct DoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DoseWidget", provider: Provider()) { entry in
            DoseWidgetEntryView(entry: entry)
        }.configurationDisplayName("DoseTrack")
         .description("Tonight plan with one-tap intents.")
    }
}
