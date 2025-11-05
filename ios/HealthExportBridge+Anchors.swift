import Foundation
import HealthKit
import CryptoKit

/// Anchor-based incremental sync with deletion tracking
final class HKAnchorStore {
    static let shared = HKAnchorStore()
    private let defaults = UserDefaults(suiteName: "group.com.dosetrack.app") ?? .standard
    private let prefix = "hk_anchor_"
    
    func loadAnchor(for typeIdentifier: String) -> HKQueryAnchor? {
        guard let data = defaults.data(forKey: prefix + typeIdentifier) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
    
    func saveAnchor(_ anchor: HKQueryAnchor?, for typeIdentifier: String) {
        guard let anchor = anchor else {
            defaults.removeObject(forKey: prefix + typeIdentifier)
            return
        }
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) {
            defaults.set(data, forKey: prefix + typeIdentifier)
        }
    }
    
    func clearAll() {
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix(prefix) }
        keys.forEach { defaults.removeObject(forKey: $0) }
    }
}

/// Record for canonical hashing
struct HealthRecord {
    let source: String
    let recordType: String
    let startUTC: String
    let endUTC: String
    let serviceDayKey: String
    let startOffsetMin: Int
    let endOffsetMin: Int
    let tzName: String
    let value: Double?
    let unit: String?
    let deviceModel: String?
    let deviceHW: String?
    let deviceSW: String?
    let sourceApp: String?
    let metadata: [String: Any]
    let deleted: Bool
    
    var sha256: String {
        canonicalHash256()
    }
    
    private func canonicalHash256() -> String {
        let roundedVal = value.map { String(format: "%.3f", $0) } ?? "null"
        let components = [
            source,
            recordType,
            startUTC,
            endUTC,
            unit ?? "",
            roundedVal,
            deviceModel ?? "",
            deviceHW ?? "",
            deviceSW ?? "",
            sourceApp ?? "",
            String(startOffsetMin),
            String(endOffsetMin)
        ]
        let canonical = components.joined(separator: "|")
        let hash = SHA256.hash(data: Data(canonical.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    func toJSON(schemaVersion: String, exporterVersion: String, cutoffHourLocal: Int) -> [String: Any] {
        var json: [String: Any] = [
            "schema_version": schemaVersion,
            "exporter_version": exporterVersion,
            "source": source,
            "record_type": recordType,
            "start_utc": startUTC,
            "end_utc": endUTC,
            "service_day_key": serviceDayKey,
            "start_offset_min": startOffsetMin,
            "end_offset_min": endOffsetMin,
            "tz_name": tzName,
            "cutoff_hour_local": cutoffHourLocal,
            "sha256": sha256,
            "deleted": deleted,
            "metadata": metadata
        ]
        
        if let value = value {
            json["value"] = value
        } else {
            json["value"] = NSNull()
        }
        
        if let unit = unit {
            json["unit"] = unit
        }
        
        if let deviceModel = deviceModel {
            json["device_model"] = deviceModel
        }
        
        if let deviceHW = deviceHW {
            json["device_hw"] = deviceHW
        }
        
        if let deviceSW = deviceSW {
            json["device_sw"] = deviceSW
        }
        
        if let sourceApp = sourceApp {
            json["source_app"] = sourceApp
        }
        
        return json
    }
}

/// Export manifest for observability
struct ExportManifest: Codable {
    let schemaVersion: String
    let exporterVersion: String
    let cutoffHourLocal: Int
    let tzName: String
    let anchoredSince: String?
    let counts: [String: Int]
    let files: [String]
    let sha256: String
    let startedAt: String
    let finishedAt: String
    let status: String
    let errors: [String]?
    
    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case exporterVersion = "exporter_version"
        case cutoffHourLocal = "cutoff_hour_local"
        case tzName = "tz_name"
        case anchoredSince = "anchored_since"
        case counts, files, sha256
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case status, errors
    }
}

/// HealthKit → JSONL exporter with anchored queries, deletions, encryption
final class HealthExportBridge {
    private let store = HKHealthStore()
    private let defaults = UserDefaults(suiteName: "group.com.dosetrack.app") ?? .standard
    private let anchorStore = HKAnchorStore.shared
    
    private let schemaVersion = "2.0"
    private let exporterVersion = "2.1.0"
    
    private let types: [(HKSampleType, String, HKUnit?)] = [
        (HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!, "sleep", nil),
        (HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!, "spo2", .percent()),
        (HKObjectType.quantityType(forIdentifier: .respiratoryRate)!, "respiratory_rate", HKUnit.count().unitDivided(by: .minute())),
        (HKObjectType.quantityType(forIdentifier: .heartRate)!, "hr", HKUnit.count().unitDivided(by: .minute())),
        (HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!, "hrv", HKUnit.secondUnit(with: .milli)),
        (HKObjectType.quantityType(forIdentifier: .stepCount)!, "step", .count())
    ]
    
    // MARK: - Public API
    
    func requestAuth() async throws {
        let readTypes = Set(types.map { $0.0 })
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }
    
    /// Anchored incremental export with deletion tracking
    func exportIncremental(
        cutoffHourLocal: Int = 12,
        encrypt: Bool = false,
        passphrase: String? = nil
    ) async throws -> URL {
        let startTime = Date()
        let iso = ISO8601DateFormatter()
        
        var allRecords: [HealthRecord] = []
        var counts: [String: Int] = [:]
        var errors: [String] = []
        
        // Process each type with anchored query
        for (sampleType, recordType, unit) in types {
            do {
                let (records, deletions) = try await queryAnchored(
                    type: sampleType,
                    recordType: recordType,
                    unit: unit,
                    cutoffHourLocal: cutoffHourLocal
                )
                allRecords.append(contentsOf: records)
                allRecords.append(contentsOf: deletions)
                counts[recordType] = records.count
                if !deletions.isEmpty {
                    counts["\(recordType)_deleted"] = deletions.count
                }
            } catch {
                errors.append("\(recordType): \(error.localizedDescription)")
            }
        }
        
        // Write to file (atomic, with optional encryption)
        let url = try await writeRecords(
            allRecords,
            cutoffHourLocal: cutoffHourLocal,
            encrypt: encrypt,
            passphrase: passphrase
        )
        
        // Generate manifest
        let manifest = ExportManifest(
            schemaVersion: schemaVersion,
            exporterVersion: exporterVersion,
            cutoffHourLocal: cutoffHourLocal,
            tzName: TimeZone.current.identifier,
            anchoredSince: defaults.string(forKey: "firstAnchoredExportAt"),
            counts: counts,
            files: [url.lastPathComponent],
            sha256: try fileSHA256(url),
            startedAt: iso.string(from: startTime),
            finishedAt: iso.string(from: Date()),
            status: errors.isEmpty ? "ok" : "partial",
            errors: errors.isEmpty ? nil : errors
        )
        
        try writeManifest(manifest, to: url.deletingLastPathComponent())
        
        // Track first anchored export
        if defaults.string(forKey: "firstAnchoredExportAt") == nil {
            defaults.set(iso.string(from: startTime), forKey: "firstAnchoredExportAt")
        }
        
        return url
    }
    
    // MARK: - Anchored Queries
    
    private func queryAnchored(
        type: HKSampleType,
        recordType: String,
        unit: HKUnit?,
        cutoffHourLocal: Int
    ) async throws -> (records: [HealthRecord], deletions: [HealthRecord]) {
        let anchorKey = "anchor_\(recordType)_v1"
        let anchor = anchorStore.loadAnchor(for: anchorKey)
        
        // Fallback: if no anchor, start from 14 days ago
        let fallbackStart = anchor == nil ? Date().addingTimeInterval(-14 * 86400) : nil
        let predicate = fallbackStart.map { HKQuery.predicateForSamples(withStart: $0, end: Date(), options: []) }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: predicate,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] _, addedSamples, deletedSamples, newAnchor, error in
                guard let self = self else { return }
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let iso = ISO8601DateFormatter()
                var records: [HealthRecord] = []
                var deletions: [HealthRecord] = []
                
                // Process additions
                for sample in addedSamples ?? [] {
                    if let catSample = sample as? HKCategorySample {
                        records.append(self.makeRecord(
                            from: catSample,
                            recordType: recordType,
                            unit: nil,
                            cutoffHourLocal: cutoffHourLocal,
                            iso: iso
                        ))
                    } else if let qtySample = sample as? HKQuantitySample, let unit = unit {
                        records.append(self.makeRecord(
                            from: qtySample,
                            recordType: recordType,
                            unit: unit,
                            cutoffHourLocal: cutoffHourLocal,
                            iso: iso
                        ))
                    }
                }
                
                // Process deletions
                for deletedObject in deletedSamples ?? [] {
                    if let sample = deletedObject as? HKSample {
                        let record = self.makeRecord(
                            from: sample,
                            recordType: recordType,
                            unit: unit,
                            cutoffHourLocal: cutoffHourLocal,
                            iso: iso,
                            deleted: true
                        )
                        deletions.append(record)
                    }
                }
                
                // Save new anchor
                if let newAnchor = newAnchor {
                    self.anchorStore.saveAnchor(newAnchor, for: anchorKey)
                }
                
                continuation.resume(returning: (records, deletions))
            }
            
            store.execute(query)
        }
    }
    
    private func makeRecord(
        from sample: HKSample,
        recordType: String,
        unit: HKUnit?,
        cutoffHourLocal: Int,
        iso: ISO8601DateFormatter,
        deleted: Bool = false
    ) -> HealthRecord {
        let tz = TimeZone.current
        let serviceDayKey = self.serviceDayKey(date: sample.startDate, cutoffHourLocal: cutoffHourLocal, tz: tz)
        let startOffsetMin = tz.secondsFromGMT(for: sample.startDate) / 60
        let endOffsetMin = tz.secondsFromGMT(for: sample.endDate) / 60
        
        var value: Double? = nil
        var unitStr: String? = nil
        
        if let qtySample = sample as? HKQuantitySample, let unit = unit {
            value = qtySample.quantity.doubleValue(for: unit)
            unitStr = unit.unitString
        }
        
        // Device metadata (stable fields only)
        let deviceModel = sample.device?.model
        let deviceHW = sample.device?.hardwareVersion
        let deviceSW = sample.device?.softwareVersion
        let sourceApp = sample.sourceRevision.source.bundleIdentifier
        
        // Category-specific metadata
        var metadata: [String: Any] = [:]
        if let catSample = sample as? HKCategorySample {
            metadata["value_category"] = catSample.value
        }
        
        return HealthRecord(
            source: "healthkit",
            recordType: recordType,
            startUTC: iso.string(from: sample.startDate),
            endUTC: iso.string(from: sample.endDate),
            serviceDayKey: serviceDayKey,
            startOffsetMin: startOffsetMin,
            endOffsetMin: endOffsetMin,
            tzName: tz.identifier,
            value: value,
            unit: unitStr,
            deviceModel: deviceModel,
            deviceHW: deviceHW,
            deviceSW: deviceSW,
            sourceApp: sourceApp,
            metadata: metadata,
            deleted: deleted
        )
    }
    
    // MARK: - File I/O
    
    private func writeRecords(
        _ records: [HealthRecord],
        cutoffHourLocal: Int,
        encrypt: Bool,
        passphrase: String?
    ) async throws -> URL {
        let fm = FileManager.default
        let timestamp = Int(Date().timeIntervalSince1970)
        
        // Determine output directory (iCloud → local fallback)
        let baseDir: URL
        if let ubiq = fm.url(forUbiquityContainerIdentifier: nil) {
            baseDir = ubiq.appendingPathComponent("Documents/DoseTrack/exports", isDirectory: true)
        } else {
            let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            baseDir = docs.appendingPathComponent("DoseTrack/exports", isDirectory: true)
        }
        try fm.createDirectory(at: baseDir, withIntermediateDirectories: true)
        
        // Write to temp file atomically
        let tempFile = baseDir.appendingPathComponent("healthkit_export_\(timestamp).tmp")
        let finalFile = baseDir.appendingPathComponent("healthkit_export_\(timestamp).jsonl\(encrypt ? ".enc" : "")")
        
        // Use FileHandle for streaming (avoid giant strings)
        fm.createFile(atPath: tempFile.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: tempFile) else {
            throw NSError(domain: "HealthExportBridge", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cannot create temp file"])
        }
        
        defer { try? handle.close() }
        
        for record in records {
            let json = record.toJSON(
                schemaVersion: schemaVersion,
                exporterVersion: exporterVersion,
                cutoffHourLocal: cutoffHourLocal
            )
            if let data = try? JSONSerialization.data(withJSONObject: json),
               var line = String(data: data, encoding: .utf8) {
                line.append("\n")
                handle.write(line.data(using: .utf8)!)
            }
        }
        
        try handle.close()
        
        // Encrypt if requested
        if encrypt, let passphrase = passphrase {
            try encryptFile(tempFile, to: finalFile, passphrase: passphrase)
            try fm.removeItem(at: tempFile)
        } else {
            try fm.moveItem(at: tempFile, to: finalFile)
        }
        
        return finalFile
    }
    
    private func encryptFile(_ source: URL, to dest: URL, passphrase: String) throws {
        let plaintext = try Data(contentsOf: source)
        let key = SHA256.hash(data: Data(passphrase.utf8))
        let symmetricKey = SymmetricKey(data: key)
        let sealedBox = try AES.GCM.seal(plaintext, using: symmetricKey)
        try sealedBox.combined!.write(to: dest, options: .atomic)
    }
    
    private func writeManifest(_ manifest: ExportManifest, to dir: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        let manifestFile = dir.appendingPathComponent("manifest_\(Int(Date().timeIntervalSince1970)).json")
        try data.write(to: manifestFile, options: .atomic)
    }
    
    private func fileSHA256(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    // MARK: - Service Day Logic
    
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
}
