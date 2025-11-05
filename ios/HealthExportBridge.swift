import Foundation
import HealthKit
import CryptoKit

/// HealthKit → JSONL exporter with service-day bucketing, incremental sync, and dedupe
final class HealthExportBridge {
    private let store = HKHealthStore()
    private let defaults = UserDefaults(suiteName: "group.com.dosetrack.app") ?? .standard
    
    private let types: Set<HKSampleType> = [
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
        HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .stepCount)!
    ]
    
    // MARK: - Public API
    
    func requestAuth() async throws {
        try await store.requestAuthorization(toShare: [], read: types)
    }
    
    /// Exports new records since last export (incremental) with service-day bucketing
    func exportIncremental(cutoffHourLocal: Int = 12) async throws -> URL {
        let lastExport = defaults.object(forKey: "lastHealthExportAt") as? Date
        let start = lastExport?.addingTimeInterval(1) ?? Date().addingTimeInterval(-14 * 86400)
        let end = Date()
        
        let url = try await exportRange(start: start, end: end, cutoffHourLocal: cutoffHourLocal)
        defaults.set(end, forKey: "lastHealthExportAt")
        return url
    }
    
    /// Exports full date range (for testing or initial setup)
    func exportRange(start: Date, end: Date, cutoffHourLocal: Int = 12) async throws -> URL {
        var outLines: [String] = []
        let iso = ISO8601DateFormatter()
        
        // Helper: Build record with service-day metadata
        func makeRecord(
            recordType: String,
            startDate: Date,
            endDate: Date,
            value: Double?,
            unit: String?,
            device: String?,
            sourceApp: String?,
            metadata: [String: Any] = [:]
        ) -> [String: Any] {
            let serviceDayKey = self.serviceDayKey(date: startDate, cutoffHourLocal: cutoffHourLocal)
            let localOffsetMin = TimeZone.current.secondsFromGMT(for: startDate) / 60
            let tzName = TimeZone.current.identifier
            let recordID = "\(recordType)_\(iso.string(from: startDate))_\(iso.string(from: endDate))"
            let sha1 = Self.sha1(string: recordID)
            
            var record: [String: Any] = [
                "source": "healthkit",
                "record_type": recordType,
                "start_utc": iso.string(from: startDate),
                "end_utc": iso.string(from: endDate),
                "service_day_key": serviceDayKey,
                "local_offset_min": localOffsetMin,
                "tz_name": tzName,
                "record_id": recordID,
                "sha1": sha1,
                "metadata": metadata
            ]
            
            if let value = value {
                record["value"] = value
            } else {
                record["value"] = NSNull()
            }
            
            if let unit = unit {
                record["unit"] = unit
            }
            
            if let device = device {
                record["device"] = device
            }
            
            if let sourceApp = sourceApp {
                record["source_app"] = sourceApp
            }
            
            return record
        }
        
        func append(_ record: [String: Any]) {
            if let data = try? JSONSerialization.data(withJSONObject: record),
               let line = String(data: data, encoding: .utf8) {
                outLines.append(line)
            }
        }
        
        // Export Sleep (including naps)
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sleepPred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let sleepSamples = try await querySamples(type: sleepType, predicate: sleepPred) as [HKCategorySample]
        
        for s in sleepSamples {
            let isNap = (s.endDate.timeIntervalSince(s.startDate) < 3600) // < 1h = nap
            let recType = isNap ? "nap" : "sleep"
            let device = s.device?.name
            let sourceApp = s.sourceRevision.source.bundleIdentifier
            
            append(makeRecord(
                recordType: recType,
                startDate: s.startDate,
                endDate: s.endDate,
                value: nil,
                unit: nil,
                device: device,
                sourceApp: sourceApp,
                metadata: ["value_category": s.value] // .inBed, .asleepCore, etc.
            ))
        }
        
        // Export Quantities
        try await exportQuantity(.oxygenSaturation, as: "spo2", unit: .percent(), start: start, end: end, append: append, makeRecord: makeRecord)
        try await exportQuantity(.respiratoryRate, as: "respiratory_rate", unit: HKUnit.count().unitDivided(by: .minute()), start: start, end: end, append: append, makeRecord: makeRecord)
        try await exportQuantity(.heartRate, as: "hr", unit: HKUnit.count().unitDivided(by: .minute()), start: start, end: end, append: append, makeRecord: makeRecord)
        try await exportQuantity(.heartRateVariabilitySDNN, as: "hrv", unit: HKUnit.secondUnit(with: .milli), start: start, end: end, append: append, makeRecord: makeRecord)
        try await exportQuantity(.stepCount, as: "step", unit: .count(), start: start, end: end, append: append, makeRecord: makeRecord)
        
        // Write to output (iCloud Drive with local fallback)
        let url = try writeToFile(lines: outLines)
        return url
    }
    
    // MARK: - Private Helpers
    
    private func exportQuantity(
        _ id: HKQuantityTypeIdentifier,
        as recordType: String,
        unit: HKUnit,
        start: Date,
        end: Date,
        append: ([String: Any]) -> Void,
        makeRecord: (String, Date, Date, Double?, String?, String?, String?, [String: Any]) -> [String: Any]
    ) async throws {
        let qt = HKObjectType.quantityType(forIdentifier: id)!
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let samples = try await querySamples(type: qt, predicate: pred) as [HKQuantitySample]
        
        for s in samples {
            let value = s.quantity.doubleValue(for: unit)
            let device = s.device?.name
            let sourceApp = s.sourceRevision.source.bundleIdentifier
            let unitStr = unit.unitString
            
            append(makeRecord(
                recordType,
                s.startDate,
                s.endDate,
                value,
                unitStr,
                device,
                sourceApp,
                [:]
            ))
        }
    }
    
    private func querySamples<T: HKSample>(type: HKSampleType, predicate: NSPredicate) async throws -> [T] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[T], Error>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [T] ?? [])
                }
            }
            store.execute(query)
        }
    }
    
    private func writeToFile(lines: [String]) throws -> URL {
        let fm = FileManager.default
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // Try iCloud Drive first
        if let ubiq = fm.url(forUbiquityContainerIdentifier: nil) {
            let dir = ubiq.appendingPathComponent("Documents/DoseTrack/exports", isDirectory: true)
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            let url = dir.appendingPathComponent("healthkit_export_\(timestamp).jsonl")
            try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            return url
        }
        
        // Fallback to local Documents
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("DoseTrack/exports", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("healthkit_export_\(timestamp).jsonl")
        try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    // MARK: - Service Day Logic
    
    /// Compute service-day key (YYYY-MM-DD) based on cutoff hour
    /// - Parameter date: Timestamp to bucket
    /// - Parameter cutoffHourLocal: Hour of day (0-23) for service-day rollover (default 12 = noon)
    /// - Returns: "YYYY-MM-DD" string in local timezone
    func serviceDayKey(date: Date, cutoffHourLocal: Int = 12, tz: TimeZone = .current) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        
        let components = cal.dateComponents([.year, .month, .day, .hour], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day,
              let hour = components.hour else {
            fatalError("Invalid date components")
        }
        
        // If before cutoff, use previous day
        let serviceDay: DateComponents
        if hour < cutoffHourLocal {
            let base = cal.date(from: DateComponents(year: year, month: month, day: day))!
            let prevDay = cal.date(byAdding: .day, value: -1, to: base)!
            let prevComponents = cal.dateComponents([.year, .month, .day], from: prevDay)
            serviceDay = prevComponents
        } else {
            serviceDay = DateComponents(year: year, month: month, day: day)
        }
        
        return String(format: "%04d-%02d-%02d", serviceDay.year!, serviceDay.month!, serviceDay.day!)
    }
    
    private static func sha1(string: String) -> String {
        let data = Data(string.utf8)
        let hash = Insecure.SHA1.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
