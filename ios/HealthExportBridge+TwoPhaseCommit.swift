// HealthExportBridge+TwoPhaseCommit.swift
// Two-phase commit with crash recovery for anchored HealthKit exports

import Foundation
import HealthKit

// MARK: - Anchor Checkpoint (Phase 1 State)

/// Captures old/new anchor state before committing to persistent storage
struct AnchorCheckpoint: Codable {
    let typeId: String
    let oldTokenBase64: String?
    let newTokenBase64: String?
    let recordCount: Int
    let addedCount: Int
    let deletedCount: Int
    
    init(
        typeId: String,
        oldAnchor: HKQueryAnchor?,
        newAnchor: HKQueryAnchor?,
        recordCount: Int,
        addedCount: Int,
        deletedCount: Int
    ) {
        self.typeId = typeId
        self.oldTokenBase64 = oldAnchor.flatMap { try? $0.encoded().base64EncodedString() }
        self.newTokenBase64 = newAnchor.flatMap { try? $0.encoded().base64EncodedString() }
        self.recordCount = recordCount
        self.addedCount = addedCount
        self.deletedCount = deletedCount
    }
    
    func oldAnchor() -> HKQueryAnchor? {
        guard let base64 = oldTokenBase64,
              let data = Data(base64Encoded: base64) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
    
    func newAnchor() -> HKQueryAnchor? {
        guard let base64 = newTokenBase64,
              let data = Data(base64Encoded: base64) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }
}

extension HKQueryAnchor {
    func encoded() throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: self, requiringSecureCoding: true)
    }
}

// MARK: - Export Manifest with Checkpoints

struct ExportManifest: Codable {
    let schemaVersion: String
    let exporterVersion: String
    let cutoffHourLocal: Int
    let tzName: String
    
    var status: ExportStatus
    var anchorCheckpoints: [AnchorCheckpoint]
    
    let files: [FileInfo]
    let startedAt: String
    var finishedAt: String?
    var error: String?
    
    struct FileInfo: Codable {
        let path: String
        let sha256: String
        let sizeBytes: Int
    }
    
    enum ExportStatus: String, Codable {
        case pending   // Phase 1: File written, anchors NOT committed
        case ok        // Phase 2: Anchors committed, export complete
        case failed    // Error occurred
    }
}

// MARK: - Two-Phase Export Orchestrator

extension HealthExportBridge {
    
    /// Phase 1: Query with OLD anchors, write to temp file, create pending manifest
    func exportIncrementalTwoPhase() async throws -> URL {
        // Step 1: Check for pending exports (crash recovery)
        try await recoverPendingExports()
        
        // Step 2: Query all types with current anchors
        let checkpoints = try await queryAllTypesWithCheckpoints()
        
        // Step 3: Write records to temp file
        let tempFile = try await writeRecordsToTemp(checkpoints)
        
        // Step 4: Create pending manifest
        let manifestURL = try createPendingManifest(
            tempFile: tempFile,
            checkpoints: checkpoints
        )
        
        // Step 5: fsync temp file
        try await fsyncFile(tempFile)
        
        // Step 6: Atomic move to final path
        let finalFile = try await moveToFinal(tempFile)
        
        // Step 7: Update manifest status to "ok"
        try updateManifestStatus(manifestURL, status: .ok)
        
        // Step 8: ONLY NOW commit anchors to persistent storage
        try commitAnchors(checkpoints)
        
        return finalFile
    }
    
    // MARK: - Crash Recovery
    
    /// On app launch, check for pending manifests and recover
    func recoverPendingExports() async throws {
        let manifestFiles = try FileManager.default.contentsOfDirectory(
            at: manifestDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasSuffix("manifest.json") }
        
        for manifestURL in manifestFiles {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(ExportManifest.self, from: data)
            
            if manifest.status == .pending {
                print("⚠️ Found pending export from \(manifest.startedAt) - recovering...")
                
                // Rollback: Restore OLD anchors (do NOT use new anchors from checkpoints)
                for checkpoint in manifest.anchorCheckpoints {
                    if let oldAnchor = checkpoint.oldAnchor() {
                        anchorStore.saveAnchor(oldAnchor, for: checkpoint.typeId)
                        print("  ↩️  Rolled back anchor for \(checkpoint.typeId)")
                    }
                }
                
                // Mark manifest as failed (user can re-export)
                var updated = manifest
                updated.status = .failed
                updated.error = "Recovered after crash - anchors rolled back"
                updated.finishedAt = ISO8601DateFormatter().string(from: Date())
                
                let encoded = try JSONEncoder().encode(updated)
                try encoded.write(to: manifestURL, options: .atomic)
                
                print("✅ Recovery complete - re-export will use old anchors")
            }
        }
    }
    
    // MARK: - Query with Checkpoints
    
    struct QueryResult {
        let typeId: String
        let oldAnchor: HKQueryAnchor?
        let newAnchor: HKQueryAnchor?
        let addedRecords: [HealthRecord]
        let deletedRecords: [HealthRecord]
    }
    
    func queryAllTypesWithCheckpoints() async throws -> [AnchorCheckpoint] {
        let types: [(HKSampleType, String)] = [
            (HKCategoryType(.sleepAnalysis), "sleep"),
            (HKQuantityType(.heartRate), "hr"),
            (HKQuantityType(.heartRateVariabilitySDNN), "hrv"),
            (HKQuantityType(.respiratoryRate), "respiratory_rate"),
            (HKQuantityType(.oxygenSaturation), "spo2"),
            (HKQuantityType(.stepCount), "step")
        ]
        
        var checkpoints: [AnchorCheckpoint] = []
        
        for (sampleType, typeId) in types {
            let result = try await queryAnchored(type: sampleType, typeId: typeId)
            
            let checkpoint = AnchorCheckpoint(
                typeId: typeId,
                oldAnchor: result.oldAnchor,
                newAnchor: result.newAnchor,
                recordCount: result.addedRecords.count + result.deletedRecords.count,
                addedCount: result.addedRecords.count,
                deletedCount: result.deletedRecords.count
            )
            
            checkpoints.append(checkpoint)
            
            // Store records in memory for writing (not persisting anchors yet!)
            pendingRecords[typeId] = (result.addedRecords, result.deletedRecords)
        }
        
        return checkpoints
    }
    
    private var pendingRecords: [String: ([HealthRecord], [HealthRecord])] = [:]
    
    func queryAnchored(
        type: HKSampleType,
        typeId: String
    ) async throws -> QueryResult {
        
        let oldAnchor = anchorStore.loadAnchor(for: typeId)
        
        // Fallback: if no anchor, use 14-day lookback
        let fallbackStart = oldAnchor == nil 
            ? Calendar.current.date(byAdding: .day, value: -14, to: Date())!
            : nil
        
        let predicate = fallbackStart.map { 
            HKQuery.predicateForSamples(withStart: $0, end: nil) 
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: predicate,
                anchor: oldAnchor,
                limit: HKObjectQueryNoLimit
            ) { [weak self] query, addedSamples, deletedSamples, newAnchor, error in
                
                guard let self = self else { return }
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let added = (addedSamples ?? []).compactMap { sample -> HealthRecord? in
                    try? self.makeRecord(from: sample, typeId: typeId, deleted: false)
                }
                
                let deleted = (deletedSamples ?? []).compactMap { sample -> HealthRecord? in
                    try? self.makeRecord(from: sample, typeId: typeId, deleted: true)
                }
                
                let result = QueryResult(
                    typeId: typeId,
                    oldAnchor: oldAnchor,
                    newAnchor: newAnchor,
                    addedRecords: added,
                    deletedRecords: deleted
                )
                
                continuation.resume(returning: result)
            }
            
            healthStore.execute(query)
        }
    }
    
    // MARK: - File I/O with fsync
    
    func writeRecordsToTemp(_ checkpoints: [AnchorCheckpoint]) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let timestamp = Int(Date().timeIntervalSince1970)
        let tempFile = tempDir.appendingPathComponent("healthkit_export_\(timestamp).tmp")
        
        guard let handle = FileHandle(forWritingAtPath: tempFile.path) ?? {
            FileManager.default.createFile(atPath: tempFile.path, contents: nil)
            return FileHandle(forWritingAtPath: tempFile.path)
        }() else {
            throw NSError(domain: "HealthExportBridge", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Cannot create temp file"])
        }
        
        defer { try? handle.close() }
        
        // Write all records (added + deleted)
        for checkpoint in checkpoints {
            guard let (added, deleted) = pendingRecords[checkpoint.typeId] else { continue }
            
            for record in added + deleted {
                let json = try JSONEncoder().encode(record)
                handle.write(json)
                handle.write(Data("\n".utf8))
            }
        }
        
        return tempFile
    }
    
    func fsyncFile(_ url: URL) async throws {
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        try handle.synchronize() // Force fsync
    }
    
    func moveToFinal(_ tempFile: URL) async throws -> URL {
        let finalDir = exportsDirectory
        let finalFile = finalDir.appendingPathComponent(
            tempFile.deletingPathExtension().lastPathComponent + ".jsonl"
        )
        
        // Atomic move (rename on same filesystem)
        try FileManager.default.moveItem(at: tempFile, to: finalFile)
        
        return finalFile
    }
    
    // MARK: - Manifest Management
    
    func createPendingManifest(
        tempFile: URL,
        checkpoints: [AnchorCheckpoint]
    ) throws -> URL {
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let manifestURL = manifestDirectory
            .appendingPathComponent("healthkit_export_\(timestamp)_manifest.json")
        
        let sha256 = try fileSHA256(tempFile)
        let size = try FileManager.default.attributesOfItem(atPath: tempFile.path)[.size] as! Int
        
        let manifest = ExportManifest(
            schemaVersion: "2.0",
            exporterVersion: "2.1.0",
            cutoffHourLocal: cutoffHourLocal,
            tzName: TimeZone.current.identifier,
            status: .pending,
            anchorCheckpoints: checkpoints,
            files: [
                ExportManifest.FileInfo(
                    path: tempFile.lastPathComponent,
                    sha256: sha256,
                    sizeBytes: size
                )
            ],
            startedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
        
        return manifestURL
    }
    
    func updateManifestStatus(_ url: URL, status: ExportManifest.ExportStatus) throws {
        let data = try Data(contentsOf: url)
        var manifest = try JSONDecoder().decode(ExportManifest.self, from: data)
        
        manifest.status = status
        manifest.finishedAt = ISO8601DateFormatter().string(from: Date())
        
        let updated = try JSONEncoder().encode(manifest)
        try updated.write(to: url, options: .atomic)
    }
    
    // MARK: - Anchor Commit (Phase 2 Only!)
    
    func commitAnchors(_ checkpoints: [AnchorCheckpoint]) throws {
        for checkpoint in checkpoints {
            guard let newAnchor = checkpoint.newAnchor() else { continue }
            anchorStore.saveAnchor(newAnchor, for: checkpoint.typeId)
            print("✅ Committed anchor for \(checkpoint.typeId) (\(checkpoint.addedCount) added, \(checkpoint.deletedCount) deleted)")
        }
    }
    
    // MARK: - Helpers
    
    private var exportsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HealthExports")
    }
    
    private var manifestDirectory: URL {
        exportsDirectory.appendingPathComponent("Manifests")
    }
    
    func fileSHA256(_ url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Unit Test Helpers

#if DEBUG
extension HealthExportBridge {
    
    /// Test helper: Simulate crash by NOT committing anchors
    func simulateCrashAfterWrite(_ checkpoints: [AnchorCheckpoint]) async throws -> URL {
        let tempFile = try await writeRecordsToTemp(checkpoints)
        let manifestURL = try createPendingManifest(tempFile: tempFile, checkpoints: checkpoints)
        try await fsyncFile(tempFile)
        let finalFile = try await moveToFinal(tempFile)
        
        // INTENTIONALLY skip:
        // - try updateManifestStatus(manifestURL, status: .ok)
        // - try commitAnchors(checkpoints)
        
        return finalFile // Manifest remains "pending", anchors NOT updated
    }
    
    /// Test helper: Verify recovery restores old anchors
    func verifyRecoveryAnchors(_ expectedOldAnchors: [String: HKQueryAnchor]) throws {
        for (typeId, expected) in expectedOldAnchors {
            let actual = anchorStore.loadAnchor(for: typeId)
            guard let actualData = try? actual?.encoded(),
                  let expectedData = try? expected.encoded(),
                  actualData == expectedData else {
                throw NSError(domain: "Test", code: 1, 
                             userInfo: [NSLocalizedDescriptionKey: "Anchor mismatch for \(typeId)"])
            }
        }
    }
}
#endif
