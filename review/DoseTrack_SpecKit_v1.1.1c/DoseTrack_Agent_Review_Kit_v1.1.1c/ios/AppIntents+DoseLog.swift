import AppIntents
import Foundation
struct LogDose1Intent: AppIntent {
    static var title: LocalizedStringResource = "Log Dose 1"
    @Parameter(title: "Grams", default: 0.0) var grams: Double
    func perform() async throws -> some IntentResult {
        AppGroupStore.writePending(.init(kind: .dose1Now, grams: grams, timestamp: Date()))
        return .result(value: "Dose 1 queued")
    }
}
struct LogDose2Intent: AppIntent {
    static var title: LocalizedStringResource = "Log Dose 2"
    @Parameter(title: "Grams", default: 0.0) var grams: Double
    func perform() async throws -> some IntentResult {
        AppGroupStore.writePending(.init(kind: .dose2Now, grams: grams, timestamp: Date()))
        return .result(value: "Dose 2 queued")
    }
}
final class DoseLogController {
    func logDose1(at: Date, gramsOverride: Double?) {}
    func logDose2(at: Date, gramsOverride: Double?) {}
    func consumePendingFromWidget() {
        if let p = AppGroupStore.consumePending() {
            switch p.kind {
            case .dose1Now: logDose1(at: p.timestamp, gramsOverride: p.grams)
            case .dose2Now: logDose2(at: p.timestamp, gramsOverride: p.grams)
            }
        }
    }
}
