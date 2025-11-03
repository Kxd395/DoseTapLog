import WidgetKit
import SwiftUI

struct DoseEntry: TimelineEntry { let date: Date; let title: String }

struct DoseWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DoseEntry { DoseEntry(date: Date(), title: "DoseTrack") }
    func getSnapshot(in context: Context, completion: @escaping (DoseEntry) -> ()) { completion(DoseEntry(date: Date(), title: "DoseTrack")) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> ()) {
        completion(Timeline(entries: [DoseEntry(date: Date(), title: "DoseTrack")], policy: .atEnd))
    }
}

struct DoseWidgetView: View { var entry: DoseWidgetProvider.Entry; var body: some View { Text(entry.title) } }

@main
struct DoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DoseWidget", provider: DoseWidgetProvider()) { entry in DoseWidgetView(entry: entry) }
        .configurationDisplayName("DoseTrack").description("Quick glance")
    }
}
