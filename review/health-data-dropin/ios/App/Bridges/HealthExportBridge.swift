import Foundation
import HealthKit
import UniformTypeIdentifiers

final class HealthExportBridge {
    private let store = HKHealthStore()
    private let types: Set<HKSampleType> = [
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.quantityType(forIdentifier: .respiratoryRate)!
    ]

    func requestAuth() async throws {
        try await store.requestAuthorization(toShare: [], read: types)
    }

    func exportLastNDays(_ days: Int = 14) async throws -> URL {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end)!
        var outLines: [String] = []

        func append(_ obj: [String: Any]) {
            if let data = try? JSONSerialization.data(withJSONObject: obj),
               let s = String(data: data, encoding: .utf8) { outLines.append(s) }
        }

        // Sleep
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let sleepPred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        let sleep = try await withCheckedThrowingContinuation { (c: CheckedContinuation<[HKCategorySample], Error>) in
            let q = HKSampleQuery(sampleType: sleepType, predicate: sleepPred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, err in
                if let err = err { c.resume(throwing: err); return }
                c.resume(returning: samples as? [HKCategorySample] ?? [])
            }
            store.execute(q)
        }
        let iso = ISO8601DateFormatter()
        for s in sleep {
            append([
                "source": "healthkit",
                "record_type": "sleep",
                "start_utc": iso.string(from: s.startDate),
                "end_utc":   iso.string(from: s.endDate),
                "value": NSNull(),
                "metadata": [:]
            ])
        }

        // HR, HRV, Respiratory
        func exportQuantity(_ id: HKQuantityTypeIdentifier, as recType: String, unit: HKUnit) async throws {
            let qt = HKObjectType.quantityType(forIdentifier: id)!
            let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
            let samples = try await withCheckedThrowingContinuation { (c: CheckedContinuation<[HKQuantitySample], Error>) in
                let q = HKSampleQuery(sampleType: qt, predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, err in
                    if let err = err { c.resume(throwing: err); return }
                    c.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
                store.execute(q)
            }
            for s in samples {
                append([
                    "source": "healthkit",
                    "record_type": recType,
                    "start_utc": iso.string(from: s.startDate),
                    "end_utc":   iso.string(from: s.endDate),
                    "value": s.quantity.doubleValue(for: unit),
                    "metadata": [:]
                ])
            }
        }
        try await exportQuantity(.heartRate, as: "hr", unit: HKUnit.count().unitDivided(by: .minute()))
        try await exportQuantity(.heartRateVariabilitySDNN, as: "hrv", unit: HKUnit.secondUnit(with: .milli))
        try await exportQuantity(.respiratoryRate, as: "respiratory_rate", unit: HKUnit.count().unitDivided(by: .minute()))

        // Write to iCloud Drive (Files app): DoseTrack/exports
        let fm = FileManager.default
        guard let ubiq = fm.url(forUbiquityContainerIdentifier: nil) else {
            throw NSError(domain: "HealthExportBridge", code: 1, userInfo: [NSLocalizedDescriptionKey: "iCloud unavailable"])
        }
        let dir = ubiq.appendingPathComponent("Documents/DoseTrack/exports", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let out = dir.appendingPathComponent("healthkit_export_\(Int(Date().timeIntervalSince1970)).json")
        try outLines.joined(separator: "\n").write(to: out, atomically: true, encoding: .utf8)
        return out
    }
}
