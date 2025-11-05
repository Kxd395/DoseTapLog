# Critical Red Flags v3 - Production Foot-Guns

**Date:** November 4, 2025  
**Status:** 🔴 NEW BLOCKERS IDENTIFIED - Previous "fixes" incomplete  
**Reviewer:** User (Ruthless Pass #3)  
**Priority:** CRITICAL - Will bite in production

---

## 🚨 NEW RED FLAGS (Not Previously Covered)

### 1. Anchor Corruption / Reset Detection **[CRITICAL]**

**Problem:** Anchors can become invalid:
- User wipes Health data → anchor points to non-existent samples
- Device restore → anchor from different store
- New watch paired → historical data re-appears with "new" anchor

**Impact:** 🔴 **SILENT DATA LOSS OR DUPLICATION** - anchor jumps backwards/forwards unpredictably

**Solution - Anchor Monotonicity + Store Fingerprint:**

```swift
struct AnchorMetadata: Codable {
    let typeId: String
    let anchorBase64: String
    let anchorVersion: Int
    let lastSeenEndDate: String // ISO8601 watermark
    let storeFingerprint: String // Device + store identifier
    
    func validate(newSamples: [HKSample], storeID: String) -> ValidationResult {
        guard storeID == storeFingerprint else {
            return .storeReset // Different store → full replay needed
        }
        
        if let newest = newSamples.max(by: { $0.endDate < $1.endDate }),
           let watermark = ISO8601DateFormatter().date(from: lastSeenEndDate),
           newest.endDate < watermark.addingTimeInterval(-7 * 86400) {
            // Anchor jumped backwards >7 days
            return .anchorReset
        }
        
        return .valid
    }
}

enum ValidationResult {
    case valid
    case anchorReset // Fall back to time-range replay
    case storeReset  // Re-export everything
}

func getStoreFingerprint() -> String {
    let deviceID = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    let storeID = healthStore.identifier?.uuidString ?? "default"
    return SHA256.hash(data: Data("\(deviceID):\(storeID)".utf8)).hex
}
```

**Test Case:**
```swift
// 1. Export with anchor A, watermark = 2025-11-04
// 2. User wipes Health data
// 3. Re-export returns samples from 2024-10-01
// 4. Validator detects: newest.endDate < watermark - 7d
// 5. Trigger full time-range replay (discard anchor A)
```

---

### 2. Concurrent Exporters (BG Task + Foreground Tap) **[CRITICAL]**

**Problem:** User taps "Export Now" while BGTask is running → two processes write to same manifest/anchors

**Impact:** 🔴 **DATA CORRUPTION** - interleaved manifests, anchor race conditions

**Solution - Process-Wide File Lock:**

```swift
import Foundation

final class ExportLock {
    private let lockFile: URL
    private var fileHandle: FileHandle?
    
    init(exportDirectory: URL) {
        self.lockFile = exportDirectory.appendingPathComponent(".export.lock")
    }
    
    func acquire(timeout: TimeInterval = 5.0) throws -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            // Create lock file if doesn't exist
            if !FileManager.default.fileExists(atPath: lockFile.path) {
                FileManager.default.createFile(atPath: lockFile.path, contents: nil)
            }
            
            // Try to acquire exclusive lock
            guard let handle = FileHandle(forWritingAtPath: lockFile.path) else {
                throw NSError(domain: "ExportLock", code: 1, 
                             userInfo: [NSLocalizedDescriptionKey: "Cannot open lock file"])
            }
            
            let fd = handle.fileDescriptor
            let result = flock(fd, LOCK_EX | LOCK_NB) // Non-blocking exclusive lock
            
            if result == 0 {
                // Lock acquired
                self.fileHandle = handle
                try handle.write(contentsOf: Data("Export in progress\n".utf8))
                return true
            } else if errno == EWOULDBLOCK {
                // Lock held by another process
                try? handle.close()
                Thread.sleep(forTimeInterval: 0.1)
                continue
            } else {
                try? handle.close()
                throw NSError(domain: "ExportLock", code: 2, 
                             userInfo: [NSLocalizedDescriptionKey: "flock failed: \(errno)"])
            }
        }
        
        return false // Timeout
    }
    
    func release() {
        guard let handle = fileHandle else { return }
        flock(handle.fileDescriptor, LOCK_UN)
        try? handle.close()
        fileHandle = nil
    }
    
    deinit {
        release()
    }
}

// Usage:
let lock = ExportLock(exportDirectory: exportsDir)

guard try lock.acquire(timeout: 5.0) else {
    throw NSError(domain: "HealthExportBridge", code: 10,
                 userInfo: [NSLocalizedDescriptionKey: "Export already in progress"])
}
defer { lock.release() }

// ... perform export ...
```

---

### 3. Device-Locked Data Visibility **[CRITICAL]**

**Problem:** HealthKit data protected until first unlock. BGTask fires before unlock → under-export but advance anchors anyway.

**Impact:** 🔴 **SILENT DATA LOSS** - missing data from locked device

**Solution - Protected Data Guard:**

```swift
extension HealthExportBridge {
    
    func canAccessProtectedData() -> Bool {
        return UIApplication.shared.isProtectedDataAvailable
    }
    
    func exportWithProtectedDataGuard() async throws -> URL {
        // Gate 1: Check if protected data available
        guard canAccessProtectedData() else {
            // Mark as pending, schedule retry after unlock
            NotificationCenter.default.addObserver(
                forName: UIApplication.protectedDataDidBecomeAvailableNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task {
                    try? await self?.exportIncrementalTwoPhase()
                }
            }
            
            throw NSError(domain: "HealthExportBridge", code: 11,
                         userInfo: [NSLocalizedDescriptionKey: "Device locked - export deferred until unlock"])
        }
        
        // Gate 2: Dry-run sample count check
        let dryRunCounts = try await countSamplesPerType()
        
        // Sanity check: if counts suspiciously low, retry after unlock
        for (typeId, count) in dryRunCounts {
            let lastCount = UserDefaults.standard.integer(forKey: "last_export_count_\(typeId)")
            if lastCount > 0 && count < lastCount * 0.5 {
                // >50% drop → likely locked data issue
                print("⚠️ Sample count dropped \(lastCount) → \(count) for \(typeId) - deferring")
                throw NSError(domain: "HealthExportBridge", code: 12,
                             userInfo: [NSLocalizedDescriptionKey: "Suspicious low count - device may be locked"])
            }
        }
        
        // Proceed with export
        let result = try await exportIncrementalTwoPhase()
        
        // Update last known counts
        for (typeId, count) in dryRunCounts {
            UserDefaults.standard.set(count, forKey: "last_export_count_\(typeId)")
        }
        
        return result
    }
    
    private func countSamplesPerType() async throws -> [String: Int] {
        var counts: [String: Int] = [:]
        
        for (sampleType, typeId) in healthKitTypes {
            let anchor = anchorStore.loadAnchor(for: typeId)
            let predicate = anchor == nil 
                ? HKQuery.predicateForSamples(withStart: Date().addingTimeInterval(-14 * 86400), end: nil)
                : nil
            
            let count = try await withCheckedThrowingContinuation { continuation in
                let query = HKAnchoredObjectQuery(
                    type: sampleType,
                    predicate: predicate,
                    anchor: anchor,
                    limit: HKObjectQueryNoLimit
                ) { query, addedSamples, deletedSamples, newAnchor, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: (addedSamples?.count ?? 0))
                    }
                }
                healthStore.execute(query)
            }
            
            counts[typeId] = count
        }
        
        return counts
    }
}
```

---

### 4. iCloud Coordination Networks/Timeouts **[HIGH]**

**Problem:** NSFileCoordinator helps, but no retry logic or offline queue

**Impact:** 🟠 **EXPORT FAILURES** - flaky networks cause data loss

**Solution - Exponential Backoff + Offline Queue:**

```swift
struct ExportRetryPolicy {
    var maxRetries: Int = 3
    var baseDelay: TimeInterval = 1.0
    var maxDelay: TimeInterval = 30.0
    
    func delay(for attempt: Int) -> TimeInterval {
        let exponential = baseDelay * pow(2.0, Double(attempt))
        return min(exponential, maxDelay)
    }
}

extension HealthExportBridge {
    
    func exportWithRetry(policy: ExportRetryPolicy = .init()) async throws -> URL {
        var lastError: Error?
        
        for attempt in 0..<policy.maxRetries {
            do {
                return try await exportIncrementalTwoPhase()
            } catch {
                lastError = error
                
                // Check if retryable
                if !isRetryable(error) {
                    throw error
                }
                
                let delay = policy.delay(for: attempt)
                print("⚠️ Export failed (attempt \(attempt+1)/\(policy.maxRetries)) - retrying in \(delay)s: \(error)")
                
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        
        // All retries exhausted → queue for offline processing
        try queueForOfflineExport()
        throw lastError ?? NSError(domain: "HealthExportBridge", code: 13,
                                   userInfo: [NSLocalizedDescriptionKey: "Export failed after retries"])
    }
    
    private func isRetryable(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Network errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorNotConnectedToInternet:
                return true
            default:
                return false
            }
        }
        
        // iCloud coordination errors
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileWriteNoPermissionError,
                 NSFileWriteOutOfSpaceError:
                return false // Not retryable
            default:
                return true
            }
        }
        
        return false
    }
    
    private func queueForOfflineExport() throws {
        let queueFile = exportsDirectory.appendingPathComponent(".offline_queue.json")
        
        var queue: [[String: Any]] = []
        if let data = try? Data(contentsOf: queueFile),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            queue = json
        }
        
        queue.append([
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "retry_count": 0,
            "status": "pending"
        ])
        
        let data = try JSONSerialization.data(withJSONObject: queue, options: .prettyPrinted)
        try data.write(to: queueFile, options: .atomic)
    }
}
```

---

### 5. Cross-Source Dedupe (HK Live + Apple XML Import) **[HIGH]**

**Problem:** User imports Apple Health XML → samples appear in both live HK and XML → double-counted

**Impact:** 🟠 **INFLATED METRICS** - 2x counts for imported data

**Solution - Global Uniqueness Index:**

```javascript
// In normalize.js

const globalIndex = new Map(); // (source, hk_uuid) → record

for (const rec of lines) {
    const key = `${rec.source}:${rec.hk_uuid || rec.sha256}`;
    
    if (globalIndex.has(key)) {
        const existing = globalIndex.get(key);
        
        // Conflict resolution: prefer live HealthKit over XML
        if (rec.source === 'healthkit' && existing.source === 'apple_health_xml') {
            globalIndex.set(key, rec); // Replace XML with live
            console.log(`Dedupe: Replaced XML record with live HK for ${key}`);
        } else if (rec.source === 'apple_health_xml' && existing.source === 'healthkit') {
            // Skip XML duplicate (already have live)
            console.log(`Dedupe: Skipping XML duplicate for ${key}`);
            continue;
        } else {
            // Same source → use SHA-256 dedupe
            if (rec.sha256 === existing.sha256) {
                continue; // Exact duplicate
            } else {
                console.warn(`Dedupe conflict: Different SHA-256 for same key ${key}`);
            }
        }
    } else {
        globalIndex.set(key, rec);
    }
    
    // Accumulate into per-night aggregates
    accumulateRecord(rec);
}
```

---

### 6. JS Timezone Math is Wrong **[CRITICAL]**

**Problem:** `new Date(localStr)` parses in system timezone, not target timezone

**Impact:** 🔴 **PARITY FAILURES** - Swift/JS produce different service_day_keys

**Solution - Use date-fns-tz:**

```javascript
const { zonedTimeToUtc, utcToZonedTime, format } = require('date-fns-tz');

function serviceDayKeyMaxOverlap(startUTC, endUTC, cutoffHourLocal, tzName) {
    const start = new Date(startUTC);
    const end = new Date(endUTC);
    
    // Convert to target timezone
    const startZoned = utcToZonedTime(start, tzName);
    const endZoned = utcToZonedTime(end, tzName);
    
    // Find candidate service days
    const candidates = [];
    
    let candidateDate = new Date(startZoned);
    candidateDate.setHours(0, 0, 0, 0);
    
    for (let i = 0; i < 3; i++) {
        // Service day boundary in target timezone
        const serviceDayStart = new Date(candidateDate);
        serviceDayStart.setHours(cutoffHourLocal, 0, 0, 0);
        
        const serviceDayEnd = new Date(candidateDate);
        serviceDayEnd.setDate(serviceDayEnd.getDate() + 1);
        serviceDayEnd.setHours(cutoffHourLocal, 0, 0, 0);
        
        // Convert boundaries back to UTC for comparison
        const serviceDayStartUTC = zonedTimeToUtc(serviceDayStart, tzName);
        const serviceDayEndUTC = zonedTimeToUtc(serviceDayEnd, tzName);
        
        // Compute overlap
        const overlapStart = new Date(Math.max(start.getTime(), serviceDayStartUTC.getTime()));
        const overlapEnd = new Date(Math.min(end.getTime(), serviceDayEndUTC.getTime()));
        const overlap = Math.max(0, overlapEnd - overlapStart);
        
        if (overlap > 0) {
            candidates.push({
                day: format(candidateDate, 'yyyy-MM-dd', { timeZone: tzName }),
                overlap: overlap
            });
        }
        
        candidateDate.setDate(candidateDate.getDate() + 1);
        
        if (candidateDate > endZoned) break;
    }
    
    // Max overlap; ties → earlier day
    candidates.sort((a, b) => {
        if (Math.abs(b.overlap - a.overlap) < 10) {
            return a.day.localeCompare(b.day); // Earlier wins
        }
        return b.overlap - a.overlap;
    });
    
    return candidates[0]?.day || format(startZoned, 'yyyy-MM-dd', { timeZone: tzName });
}

module.exports = { serviceDayKeyMaxOverlap };
```

**Package Update:**
```bash
npm install date-fns date-fns-tz --save
```

---

### 7. Huge HR Series → Memory Blow-Ups **[HIGH]**

**Problem:** Materializing `_raw.hr` array with 18,000+ samples per night → OOM on normalization

**Impact:** 🟠 **CRASHES** - normalizer dies on big nights

**Solution - Online Aggregates + Reservoir Sampling:**

```javascript
// In normalize.js

class OnlineStats {
    constructor(maxReservoir = 1000) {
        this.count = 0;
        this.sum = 0;
        this.sumSq = 0;
        this.reservoir = [];
        this.maxReservoir = maxReservoir;
    }
    
    add(value) {
        this.count++;
        this.sum += value;
        this.sumSq += value * value;
        
        // Reservoir sampling (maintain representative sample)
        if (this.reservoir.length < this.maxReservoir) {
            this.reservoir.push(value);
        } else {
            const k = Math.floor(Math.random() * this.count);
            if (k < this.maxReservoir) {
                this.reservoir[k] = value;
            }
        }
    }
    
    mean() {
        return this.count > 0 ? this.sum / this.count : 0;
    }
    
    stddev() {
        if (this.count < 2) return 0;
        const variance = (this.sumSq / this.count) - Math.pow(this.mean(), 2);
        return Math.sqrt(Math.max(0, variance));
    }
    
    percentile(p) {
        if (this.reservoir.length === 0) return 0;
        const sorted = this.reservoir.slice().sort((a, b) => a - b);
        const idx = Math.floor(sorted.length * p);
        return sorted[idx];
    }
}

// Replace _raw arrays with OnlineStats
const perNight = {};

for (const rec of lines) {
    const night = perNight[rec.service_day_key] || { stats: {} };
    
    if (!night.stats[rec.record_type]) {
        night.stats[rec.record_type] = new OnlineStats();
    }
    
    night.stats[rec.record_type].add(rec.value);
    
    // Only keep _raw if DEBUG flag set
    if (process.env.DEBUG_RAW === '1') {
        night._raw = night._raw || {};
        night._raw[rec.record_type] = night._raw[rec.record_type] || [];
        night._raw[rec.record_type].push(rec);
    }
    
    perNight[rec.service_day_key] = night;
}

// Compute features from stats
for (const [nightKey, night] of Object.entries(perNight)) {
    if (night.stats.hr) {
        night.hrMeanBpm = night.stats.hr.mean();
        night.hrStddevBpm = night.stats.hr.stddev();
        night.hrP10Bpm = night.stats.hr.percentile(0.1);
        night.hrP90Bpm = night.stats.hr.percentile(0.9);
    }
    
    if (night.stats.hrv) {
        night.hrvSdnnMsP50 = night.stats.hrv.percentile(0.5);
        night.hrvSdnnMsP75 = night.stats.hrv.percentile(0.75);
    }
}
```

---

### 8. Manifest Integrity / Tamper Detection **[HIGH]**

**Problem:** Partial uploads or corruption → manifest says "ok" but data is bad

**Impact:** 🟠 **SILENT CORRUPTION** - bad data propagates downstream

**Solution - SHA-256 + HMAC:**

```swift
import CryptoKit

extension HealthExportBridge {
    
    func createManifestWithIntegrity(
        fileURL: URL,
        checkpoints: [AnchorCheckpoint]
    ) throws -> ExportManifest {
        
        // 1. SHA-256 of compressed blob
        let blobData = try Data(contentsOf: fileURL)
        let blobSHA256 = SHA256.hash(data: blobData).hex
        
        // 2. Create manifest (without HMAC yet)
        var manifest = ExportManifest(
            schemaVersion: "2.0",
            exporterVersion: "2.1.0",
            cutoffHourLocal: cutoffHourLocal,
            tzName: TimeZone.current.identifier,
            status: .pending,
            anchorCheckpoints: checkpoints,
            files: [
                ExportManifest.FileInfo(
                    path: fileURL.lastPathComponent,
                    sha256: blobSHA256,
                    sizeBytes: blobData.count
                )
            ],
            startedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        // 3. SHA-256 of manifest JSON (before HMAC)
        let manifestJSON = try JSONEncoder().encode(manifest)
        let manifestSHA256 = SHA256.hash(data: manifestJSON).hex
        
        // 4. HMAC of (blob_sha256 + manifest_sha256)
        let hmacKey = try getHMACKey()
        let hmacInput = Data("\(blobSHA256):\(manifestSHA256)".utf8)
        let hmac = HMAC<SHA256>.authenticationCode(for: hmacInput, using: hmacKey)
        
        manifest.blobSHA256 = blobSHA256
        manifest.manifestSHA256 = manifestSHA256
        manifest.hmacSHA256 = Data(hmac).hex
        
        return manifest
    }
    
    private func getHMACKey() throws -> SymmetricKey {
        let keyName = "health_export_hmac_key"
        
        if let keyData = try? KeychainHelper.load(forKey: keyName) {
            return SymmetricKey(data: keyData)
        }
        
        // Generate new key
        let key = SymmetricKey(size: .bits256)
        try KeychainHelper.save(key.withUnsafeBytes { Data($0) }, forKey: keyName)
        return key
    }
}

// In agent (normalize.js)
const crypto = require('crypto');

function verifyManifestIntegrity(manifest, fileData) {
    // 1. Verify blob SHA-256
    const blobSHA256 = crypto.createHash('sha256').update(fileData).digest('hex');
    if (blobSHA256 !== manifest.files[0].sha256) {
        throw new Error(`Blob checksum mismatch: expected ${manifest.files[0].sha256}, got ${blobSHA256}`);
    }
    
    // 2. Verify manifest SHA-256
    const manifestCopy = { ...manifest };
    delete manifestCopy.hmacSHA256;
    const manifestJSON = JSON.stringify(manifestCopy);
    const manifestSHA256 = crypto.createHash('sha256').update(manifestJSON).digest('hex');
    
    if (manifestSHA256 !== manifest.manifestSHA256) {
        throw new Error(`Manifest checksum mismatch`);
    }
    
    // 3. Verify HMAC (if key available)
    const hmacKey = loadHMACKey(); // From secure storage
    if (hmacKey) {
        const hmacInput = `${blobSHA256}:${manifestSHA256}`;
        const hmac = crypto.createHmac('sha256', hmacKey).update(hmacInput).digest('hex');
        
        if (hmac !== manifest.hmacSHA256) {
            throw new Error(`HMAC verification failed - manifest tampered`);
        }
    }
    
    return true;
}
```

---

### 9. HealthKit Deletions Before First Anchor **[MEDIUM]**

**Problem:** Tombstones only arrive after anchoring starts. First run misses retro deletions.

**Impact:** 🟡 **STALE DATA** - deleted samples linger in first export

**Solution - Backward Look-Back on Subsequent Runs:**

```swift
extension HealthExportBridge {
    
    func queryWithBackwardLookBack(
        type: HKSampleType,
        typeId: String
    ) async throws -> QueryResult {
        
        let anchor = anchorStore.loadAnchor(for: typeId)
        
        // First run: no anchor → use 14-day time range
        if anchor == nil {
            return try await queryTimeRange(type: type, typeId: typeId, days: 14)
        }
        
        // Subsequent runs: anchored query + 7-day backward look-back
        let anchorResult = try await queryAnchored(type: type, typeId: typeId)
        
        // Also query 7 days before anchor watermark to catch retro deletions
        if let watermark = anchorStore.loadWatermark(for: typeId) {
            let lookBackStart = watermark.addingTimeInterval(-7 * 86400)
            let lookBackResult = try await queryTimeRange(
                type: type,
                typeId: typeId,
                start: lookBackStart,
                end: watermark
            )
            
            // Merge results (dedupe by HK UUID)
            var merged = anchorResult
            for sample in lookBackResult.addedRecords {
                if !merged.addedRecords.contains(where: { $0.hkUUID == sample.hkUUID }) {
                    merged.addedRecords.append(sample)
                }
            }
            
            return merged
        }
        
        return anchorResult
    }
}
```

---

### 10. Cutoff/Locale Edge Cases **[LOW]**

**Problem:** Non-Gregorian calendars (Islamic, Hebrew) or 24h locales break date math

**Impact:** 🟢 **EDGE CASES** - rare but catastrophic for affected users

**Solution - Force Proleptic Gregorian:**

```swift
extension ServiceDayCalculator {
    
    static func serviceDayKey(
        start: Date,
        end: Date,
        cutoffHourLocal: Int,
        tz: TimeZone
    ) -> String {
        
        // Force Gregorian calendar (ignore user's calendar preference)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        
        // ... rest of logic ...
    }
}
```

---

### 11. Background Energy Budget **[MEDIUM]**

**Problem:** Export + compression spikes energy → iOS kills BGTask

**Impact:** 🟡 **INCOMPLETE EXPORTS** - large exports never finish

**Solution - Time/Size Budgets + Chunking:**

```swift
struct ExportBudget {
    var maxDurationSeconds: TimeInterval = 25.0
    var maxBytesPerRun: Int = 25 * 1024 * 1024 // 25 MB
    var maxSamplesPerType: Int = 50_000
}

extension HealthExportBridge {
    
    func exportWithBudget(budget: ExportBudget = .init()) async throws -> URL {
        let startTime = Date()
        var totalBytes = 0
        var chunks: [URL] = []
        
        for (sampleType, typeId) in healthKitTypes {
            // Check time budget
            if Date().timeIntervalSince(startTime) > budget.maxDurationSeconds {
                print("⏱ Time budget exhausted - resuming in next run")
                break
            }
            
            // Check size budget
            if totalBytes > budget.maxBytesPerRun {
                print("💾 Size budget exhausted - resuming in next run")
                break
            }
            
            // Query with limit
            let result = try await queryAnchored(
                type: sampleType,
                typeId: typeId,
                limit: budget.maxSamplesPerType
            )
            
            // Write chunk
            let chunkFile = try await writeChunk(result, typeId: typeId)
            chunks.append(chunkFile)
            
            let chunkSize = try FileManager.default.attributesOfItem(atPath: chunkFile.path)[.size] as! Int
            totalBytes += chunkSize
            
            // If chunk hit limit, don't advance anchor (resume later)
            if result.recordCount >= budget.maxSamplesPerType {
                print("📦 Chunk limit reached for \(typeId) - will resume")
                continue
            } else {
                // Full export → safe to advance anchor
                anchorStore.saveAnchor(result.newAnchor, for: typeId)
            }
        }
        
        // Merge chunks into final file
        return try mergeChunks(chunks)
    }
}
```

---

## 🔧 FIXES TO EXISTING "DONE" COMPONENTS

### Two-Phase Commit → Add Manifest WAL

**Problem:** Recovery doesn't know **what** to replay (which types, how many records)

**Fix:**

```swift
struct ExportManifest: Codable {
    // ... existing fields ...
    
    var wal: WriteAheadLog?
    
    struct WriteAheadLog: Codable {
        let pendingTypes: [String] // Types not yet exported
        let completedTypes: [String] // Types successfully exported
        let failedTypes: [String: String] // typeId → error message
        let totalRecordCount: Int
        let exportedRecordCount: Int
    }
}

// During export:
manifest.wal = WriteAheadLog(
    pendingTypes: ["hr", "hrv", "sleep", "spo2", "respiratory_rate", "step"],
    completedTypes: [],
    failedTypes: [:],
    totalRecordCount: 0,
    exportedRecordCount: 0
)

// After each type:
manifest.wal?.completedTypes.append(typeId)
manifest.wal?.pendingTypes.removeAll { $0 == typeId }
manifest.wal?.exportedRecordCount += recordCount

// On recovery:
if let wal = manifest.wal {
    // Resume only pending types
    for typeId in wal.pendingTypes {
        try await queryAndWrite(typeId)
    }
}
```

**Also:** Persist anchors in **Keychain (this device only)**, not UserDefaults:

```swift
final class HKAnchorStore {
    func saveAnchor(_ anchor: HKQueryAnchor?, for typeId: String) {
        guard let anchor = anchor,
              let data = try? anchor.encoded() else { return }
        
        try? KeychainHelper.save(data, forKey: "hk_anchor_\(typeId)")
    }
    
    func loadAnchor(for typeId: String) -> HKQueryAnchor? {
        guard let data = try? KeychainHelper.load(forKey: "hk_anchor_\(typeId)"),
              let anchor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data) else {
            return nil
        }
        return anchor
    }
}
```

---

### Service-Day Max-Overlap → Add Assignment Method Metadata

**Fix:**

```swift
var record = HealthRecord(...)
record.metadata = [
    "assignment_method": "max_overlap_v2",
    "assignment_version": "2.0"
]
```

**Rebucket Tool:**

```javascript
// scripts/rebucket-health-export.js
#!/usr/bin/env node

const fs = require('fs');
const { serviceDayKeyMaxOverlap } = require('../src/util/serviceDayMaxOverlap');

const inputFile = process.argv[2];
const newCutoff = parseInt(process.argv[3]);

const lines = fs.readFileSync(inputFile, 'utf8').split('\n').filter(Boolean);
const records = lines.map(JSON.parse);

for (const rec of records) {
    // Only rebucket if using old assignment method
    if (rec.metadata?.assignment_method !== 'max_overlap_v2') {
        rec.service_day_key = serviceDayKeyMaxOverlap(
            rec.start_utc,
            rec.end_utc,
            newCutoff,
            rec.tz_name
        );
        rec.cutoff_hour_local = newCutoff;
        rec.metadata = rec.metadata || {};
        rec.metadata.assignment_method = 'max_overlap_v2';
        rec.metadata.assignment_version = '2.0';
        rec.metadata.rebucketed_at = new Date().toISOString();
    }
}

fs.writeFileSync('health_rebucketed.jsonl', records.map(JSON.stringify).join('\n'));
console.log(`✅ Rebucketed ${records.length} records to cutoff=${newCutoff}`);
```

---

### Compression → Enforce Single Format via Flag

**Fix:**

```swift
enum CompressionFormat: String {
    case gzip
    case none
}

func compress(_ file: URL, format: CompressionFormat) throws -> URL {
    switch format {
    case .gzip:
        let dest = file.appendingPathExtension("gz")
        let input = try Data(contentsOf: file)
        let compressed = try (input as NSData).compressed(using: .zlib)
        try compressed.write(to: dest, options: .atomic)
        try FileManager.default.removeItem(at: file)
        return dest
        
    case .none:
        return file
    }
}
```

**CI Check:**

```yaml
# .github/workflows/export-validation.yml
- name: Verify compression format
  run: |
    for file in exports/*.gz; do
      # Verify gzip magic bytes
      if ! file "$file" | grep -q "gzip"; then
        echo "❌ File $file has .gz extension but is not gzip"
        exit 1
      fi
    done
```

---

### Steps Totals → Document Partial Day Exclusion

**Fix:**

```swift
/// Export step totals using HKStatisticsCollection.
/// **Important:** Partial days (e.g., "today" before cutoff) are **excluded**
/// unless explicitly requested via `includePartialDays: true`.
func exportStepTotals(
    from startDate: Date,
    to endDate: Date,
    cutoffHourLocal: Int,
    tz: TimeZone,
    includePartialDays: Bool = false
) async throws -> [HealthRecord] {
    
    // Align anchor date to cutoff hour exactly
    var calendar = Calendar.current
    calendar.timeZone = tz
    
    var components = calendar.dateComponents([.year, .month, .day], from: startDate)
    components.hour = cutoffHourLocal
    components.minute = 0
    components.second = 0
    let anchorDate = calendar.date(from: components)!
    
    // ... HKStatisticsCollectionQuery ...
    
    collection?.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
        // Exclude partial days unless requested
        if !includePartialDays {
            let isToday = calendar.isDateInToday(stats.startDate)
            let beforeCutoff = calendar.component(.hour, from: Date()) < cutoffHourLocal
            if isToday && beforeCutoff {
                return // Skip today before cutoff
            }
        }
        
        // ... rest of logic ...
    }
}
```

---

### Encryption → Use CryptoKit HKDF + Key Versioning

**Fix:**

```swift
import CryptoKit

func deriveKey(from passphrase: String, salt: Data, version: Int) -> SymmetricKey {
    let passphraseData = Data(passphrase.utf8)
    
    switch version {
    case 1:
        // Legacy PBKDF2 (for migration)
        var key = SHA256.hash(data: passphraseData + salt)
        for _ in 0..<100_000 {
            key = SHA256.hash(data: Data(key) + salt)
        }
        return SymmetricKey(data: key)
        
    case 2:
        // Modern HKDF
        let inputKey = SymmetricKey(data: passphraseData)
        let derived = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: inputKey,
            salt: salt,
            info: Data("health_export_v2".utf8),
            outputByteCount: 32
        )
        return derived
        
    default:
        fatalError("Unsupported key version: \(version)")
    }
}

// In manifest:
struct EncryptionMetadata: Codable {
    let keyVersion: Int
    let algorithm: String // "AES-GCM"
    let saltBase64: String
}

manifest.encryptionMetadata = EncryptionMetadata(
    keyVersion: 2,
    algorithm: "AES-GCM",
    saltBase64: salt.base64EncodedString()
)
```

**Re-Encrypt Action:**

```swift
func reEncryptExport(from oldPassphrase: String, to newPassphrase: String) async throws {
    let files = try FileManager.default.contentsOfDirectory(
        at: exportsDirectory,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "enc" }
    
    for file in files {
        // Decrypt with old key
        let encrypted = try Data(contentsOf: file)
        let oldKey = deriveKey(from: oldPassphrase, salt: oldSalt, version: 1)
        let plaintext = try decrypt(encrypted, key: oldKey)
        
        // Re-encrypt with new key
        let newSalt = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        let newKey = deriveKey(from: newPassphrase, salt: newSalt, version: 2)
        let reEncrypted = try encrypt(plaintext, key: newKey)
        
        try reEncrypted.write(to: file, options: .atomic)
    }
}
```

---

### Nap Detection → Blacklist Dose Windows

**Fix:**

```swift
func detectNap(
    sample: HKCategorySample,
    cutoffHourLocal: Int,
    context: NapDetectionContext
) -> (isNap: Bool, confidence: Double, ruleVersion: String) {
    
    // ... existing guards ...
    
    // Guard 4: Blacklist ±45 min around dose times
    if let doseLog = context.doseLog {
        for dose in [doseLog.dose1UTC, doseLog.dose2UTC].compactMap({ $0 }) {
            let doseStart = dose.addingTimeInterval(-45 * 60)
            let doseEnd = dose.addingTimeInterval(45 * 60)
            
            if sample.startDate < doseEnd && sample.endDate > doseStart {
                return (false, 0.8, "v2") // Likely micro-wake, not nap
            }
        }
    }
    
    // Guard 5: Night shift workers (low confidence)
    if let schedule = context.weeklySchedule {
        let weekday = Calendar.current.component(.weekday, from: sample.startDate)
        if schedule.days[weekday].isNightShift {
            return (true, 0.5, "v2") // Daytime sleep for night shift = lower confidence
        }
    }
    
    return (true, 0.9, "v2")
}
```

---

## 📋 UPDATED NO-SHIP-UNLESS GATES

### P0 (Must Ship) - 12 Gates

- [ ] **Two-phase anchor** with WAL + recovery; anchors in Keychain after checksum OK
- [ ] **Anchor reset detector** (store fingerprint + watermark sanity check)
- [ ] **Concurrent export lock** (file lock + reentrancy guard)
- [ ] **Device-locked guard** prevents premature anchor advancement
- [ ] **Deletion cascade** recomputes 7-day/14-day windows; tests prove deltas
- [ ] **Gzip everywhere**; extension matches; CI content-type check
- [ ] **HKStatisticsCollection** for steps with cutoff-aligned anchor; partial days excluded
- [ ] **Encryption UX**: HKDF, key version, rotation, RAM wipe, strength meter, risk ACK
- [ ] **HK UUID + sourceRevision** emitted; cross-source dedupe validated
- [ ] **start_tz/end_tz** and offsets emitted; Node uses date-fns-tz
- [ ] **Join invariant enforced**; rebucket tool available and tested
- [ ] **Strict schemas** + integrity HMAC verified pre-ingest

### P1 (Should Ship) - 6 Gates

- [ ] **Exponential backoff retry** + offline queue for network failures
- [ ] **Online aggregates** (no _raw materialization); DEBUG_RAW flag gates full arrays
- [ ] **Manifest WAL** tracks pending/completed/failed types
- [ ] **Assignment method metadata** in records; rebucket tool respects versions
- [ ] **Nap detection v2** with dose window blacklist, shift work confidence
- [ ] **Energy budgets**: time/size limits; chunked exports resume via manifest

---

## 🧪 CRITICAL TESTS STILL MISSING

1. **Anchor reset & replay**: Wipe Health → exporter detects → full time-range replay
2. **Device-locked export**: BGTask before unlock → defers → replays after unlock
3. **TZ parity (100 cases)**: Swift vs date-fns-tz across 6 timezones → 100% match
4. **Chunked resume**: 2 GB HR → multi-file export → crash → resumes next chunk
5. **Cross-source dedupe**: HK UUID in XML + live → only one survives
6. **Integrity**: Corrupt .gz → checksum mismatch → anchors NOT advanced

---

**Status:** 🔴 CRITICAL - Previous "fixes" incomplete, new blockers identified  
**Remaining:** ~20-25 hours to production-solid (was 13h, now expanded)  
**Priority:** Implement anchor reset detection, concurrent locks, device-locked guards, JS timezone fix

