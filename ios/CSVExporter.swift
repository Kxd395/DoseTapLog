import Foundation
import SwiftData
import UIKit

enum CSVExporter {
    static func exportAll(context: ModelContext) throws -> URL {
        let items = try context.fetch(FetchDescriptor<DoseLog>(sortBy: [.init(\.nightStartUTC, order: .forward)]))
        let header = DoseLog.csvHeader()
        let rows = items.map { $0.csvRow() }
        let csv = ([header] + rows).joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dosetrack_export_\(UUID().uuidString).csv")
        try csv.data(using: .utf8)?.write(to: url)
        return url
    }
}
