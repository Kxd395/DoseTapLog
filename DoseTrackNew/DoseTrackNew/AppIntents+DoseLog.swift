import AppIntents
import Foundation
struct LogDose1Intent: AppIntent {
    static var title: LocalizedStringResource = "Log Dose 1"
    @Parameter(title: "Grams", default: 0.0) var grams: Double
    func perform() async throws -> some IntentResult {
        AppGroupStore.writePending(.init(kind: .dose1Now, grams: grams, timestamp: Date()))
        return .result(value: "Dose 1 logged request queued")
    }
}
struct LogDose2Intent: AppIntent {
    static var title: LocalizedStringResource = "Log Dose 2"
    @Parameter(title: "Grams", default: 0.0) var grams: Double
    func perform() async throws -> some IntentResult {
        AppGroupStore.writePending(.init(kind: .dose2Now, grams: grams, timestamp: Date()))
        return .result(value: "Dose 2 logged request queued")
    }
}
