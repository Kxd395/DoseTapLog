import Foundation
import SwiftData

/// Exports DoseLog records to JSONL for agent feature computation
final class DoseLogExporter {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Export last N days of dose logs
    func exportLastNDays(_ days: Int = 14) throws -> URL {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        
        let descriptor = FetchDescriptor<DoseLog>(
            predicate: #Predicate { log in
                log.createdAtUTC >= start && log.createdAtUTC <= end
            },
            sortBy: [SortDescriptor(\.nightKey, order: .forward)]
        )
        
        let logs = try modelContext.fetch(descriptor)
        var lines: [String] = []
        let iso = ISO8601DateFormatter()
        
        for log in logs {
            var record: [String: Any] = [
                "night_key": log.nightKey,
                "created_at_utc": iso.string(from: log.createdAtUTC),
                "lifecycle_state": log.currentLifecycleState.rawValue
            ]
            
            // Optional timestamps
            if let bedtime = log.bedtimeUTC {
                record["bedtime_utc"] = iso.string(from: bedtime)
            }
            if let dose1 = log.dose1TimeUTC {
                record["dose1_utc"] = iso.string(from: dose1)
                record["dose1_grams"] = log.dose1Grams ?? NSNull()
            }
            if let dose2 = log.dose2TimeUTC {
                record["dose2_utc"] = iso.string(from: dose2)
                record["dose2_grams"] = log.dose2Grams ?? NSNull()
                record["dose2_is_override"] = log.dose2IsOverride
                record["dose2_override_kind"] = log.dose2OverrideKind ?? NSNull()
                record["dose2_override_minutes"] = log.dose2OverrideMinutes ?? NSNull()
                record["dose2_override_reason"] = log.dose2OverrideReason ?? NSNull()
            }
            if let wake = log.finalWakeUTC {
                record["final_wake_utc"] = iso.string(from: wake)
                record["wake_reason"] = log.wakeReason?.rawValue ?? NSNull()
            }
            
            // Planned doses
            record["plan_dose1_g"] = log.planDose1G ?? NSNull()
            record["plan_dose2_g"] = log.planDose2G ?? NSNull()
            
            // Wake events
            if !log.wakeEvents.isEmpty {
                let wakeEventsJSON = log.wakeEvents.map { event in
                    [
                        "time_utc": iso.string(from: event.timeUTC),
                        "reason": event.reason.rawValue,
                        "source": event.source
                    ]
                }
                record["wake_events"] = wakeEventsJSON
            }
            
            if let data = try? JSONSerialization.data(withJSONObject: record),
               let line = String(data: data, encoding: .utf8) {
                lines.append(line)
            }
        }
        
        return try writeToFile(lines: lines)
    }
    
    private func writeToFile(lines: [String]) throws -> URL {
        let fm = FileManager.default
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // Try iCloud Drive first
        if let ubiq = fm.url(forUbiquityContainerIdentifier: nil) {
            let dir = ubiq.appendingPathComponent("Documents/DoseTrack/exports", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("dosetrack_export_\(timestamp).jsonl")
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        }
        
        // Fallback to local Documents
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("DoseTrack/exports", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("dosetrack_export_\(timestamp).jsonl")
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
