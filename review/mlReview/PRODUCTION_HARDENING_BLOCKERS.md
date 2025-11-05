# Health Export v2 - Production Hardening Blockers

**Date:** November 4, 2025  
**Status:** 🔴 CRITICAL GAPS IDENTIFIED - NOT PRODUCTION READY  
**Reviewer:** User (Hyper-Critical Pass #2)  
**Agent Status:** Implementing surgical fixes

---

## 🚨 BLOCKERS HIDING IN PLAIN SIGHT

### 1. Anchor Commit/Rollback Semantics **[CRITICAL]**

**Problem:** Current implementation updates anchors immediately after query, before file is written. Crash between query and file write = silent data loss.

**Root Cause:** No two-phase commit discipline.

**Impact:** 🔴 **SILENT DATA LOSS** - records queried but never exported, next run skips them forever.

**Solution - Two-Phase Commit:**

```swift
// PHASE 1: Query with OLD anchors → write to temp
struct AnchorCheckpoint: Codable {
    var typeId: String
    var oldToken: Data?
    var newToken: Data?
    var recordCount: Int
}

// PHASE 2: After successful fsync + manifest write → commit anchors
func commitAnchors(_ checkpoints: [AnchorCheckpoint]) {
    for cp in checkpoints {
        anchorStore.saveAnchor(HKQueryAnchor(fromData: cp.newToken!), for: cp.typeId)
    }
}

// RECOVERY: On app launch, check for pending manifests
func recoverPendingExports() {
    let manifests = loadManifests(status: "pending")
    for manifest in manifests {
        // Re-run export with OLD anchors (don't use pending new anchors)
        // Manifest has stashed old tokens for recovery
        let checkpoints = manifest.anchor_checkpoints
        for cp in checkpoints {
            anchorStore.saveAnchor(HKQueryAnchor(fromData: cp.oldToken!), for: cp.typeId)
        }
        // Re-export will use old anchors, produce identical records + new anchor
    }
}
```

**Test Case:**
```swift
// 1. Export 100 HR records → anchor saved as "A"
// 2. Add 50 new HR records
// 3. Start export → query returns 50 records, new anchor "B"
// 4. SIMULATE CRASH before fsync
// 5. App relaunches → finds pending manifest
// 6. Recovers with anchor "A" (not "B")
// 7. Re-export → produces same 50 records, saves anchor "B"
// 8. Verify: no duplicates, no losses
```

---

### 2. Deletion Tombstones → Downstream Incomplete **[CRITICAL]**

**Problem:** iOS emits `{deleted:true}`, but normalizer doesn't:
- Remove deleted records from aggregates
- Recompute rolling windows (7-day HRV, resp rate)
- Invalidate dependent features

**Root Cause:** No DAG/invalidation step in feature computation.

**Impact:** 🔴 **STALE FEATURES** - deletions leave ghost data in statistics.

**Solution - Invalidation Cascade:**

```javascript
// In normalize.js
const impactedNights = new Set();
const deletedRecords = [];

for (const rec of lines) {
    if (rec.deleted) {
        impactedNights.add(rec.service_day_key);
        deletedRecords.push(rec.sha256);
        
        // Remove from raw data structures
        const night = perNight[rec.service_day_key];
        if (night && night._raw[rec.record_type]) {
            night._raw[rec.record_type] = night._raw[rec.record_type]
                .filter(r => r.sha256 !== rec.sha256);
        }
    } else {
        // Normal accumulation
        accumulateRecord(rec);
    }
}

// Recompute rolling windows for impacted nights + 6 days forward
for (const nightKey of impactedNights) {
    const impactedRange = getDateRange(nightKey, 7); // [N … N+6]
    for (const rangeNight of impactedRange) {
        recomputeRollingStats(rangeNight); // HRV 7-day median, etc.
    }
}

function recomputeRollingStats(nightKey) {
    const window = get7DayWindow(nightKey);
    const allHRV = window.flatMap(n => n._raw.hrv || []).map(r => r.value);
    
    perNight[nightKey].hrvSdnnMsP50_7day = median(allHRV);
    perNight[nightKey].hrvSdnnMsP75_7day = percentile(allHRV, 0.75);
    // ... respiratory, step totals, etc.
}
```

**Test Case:**
```javascript
// 1. Export night 2025-11-01 with 10 HRV samples
// 2. Compute 7-day HRV median for nights [11-01 … 11-07]
// 3. Delete 3 HRV samples from 11-01 → tombstones emitted
// 4. Re-normalize → impacted = [11-01 … 11-07]
// 5. Verify: HRV median changes for all 7 nights
// 6. Verify: deleted SHA-256s not in aggregates
```

---

### 3. Service-Day Rule Ambiguous for Long Spans **[CRITICAL]**

**Problem:** Current rule "use start timestamp" mis-buckets sleep crossing midnight.

**Example:**
- Sleep: 23:30 Nov 3 → 06:30 Nov 4
- Cutoff: 12:00 local
- Start-based rule → service_day_key = 2025-11-03 ✅
- BUT: 2 hours pre-cutoff (23:30-00:00), 6.5 hours post-cutoff (00:00-06:30)
- Max overlap → should be 2025-11-04 (6.5h > 2h)

**Root Cause:** No deterministic "max temporal overlap" rule.

**Impact:** 🔴 **MIS-BUCKETING** - nights split across wrong service days, join failures.

**Solution - Max Overlap Rule v2:**

```swift
/// Assign sample to service day with maximum temporal overlap.
/// Ties → choose earlier day (stability).
func serviceDayKeyMaxOverlap(
    start: Date, 
    end: Date, 
    cutoffHourLocal: Int, 
    tz: TimeZone
) -> String {
    var calendar = Calendar.current
    calendar.timeZone = tz
    
    // Compute midnight-aligned service days that span [start, end]
    let startLocal = start.toLocalDate(tz: tz)
    let endLocal = end.toLocalDate(tz: tz)
    
    // Candidate service days: up to 2 days (or 3 if sample >24h)
    var candidates: [(day: String, overlap: TimeInterval)] = []
    
    var candidateDate = calendar.startOfDay(for: startLocal)
    while candidateDate <= endLocal {
        // Service day boundaries in UTC
        let serviceDayStart = serviceDayBoundary(date: candidateDate, cutoff: cutoffHourLocal, tz: tz)
        let serviceDayEnd = serviceDayBoundary(date: calendar.date(byAdding: .day, value: 1, to: candidateDate)!, 
                                               cutoff: cutoffHourLocal, tz: tz)
        
        // Compute overlap
        let overlapStart = max(start, serviceDayStart)
        let overlapEnd = min(end, serviceDayEnd)
        let overlap = max(0, overlapEnd.timeIntervalSince(overlapStart))
        
        if overlap > 0 {
            let key = serviceDayFormatter.string(from: candidateDate)
            candidates.append((day: key, overlap: overlap))
        }
        
        candidateDate = calendar.date(byAdding: .day, value: 1, to: candidateDate)!
    }
    
    // Pick max overlap; ties → earlier day
    let winner = candidates.max { a, b in
        if a.overlap == b.overlap {
            return a.day > b.day // Earlier day wins ties
        }
        return a.overlap < b.overlap
    }
    
    return winner?.day ?? serviceDayFormatter.string(from: startLocal)
}

func serviceDayBoundary(date: Date, cutoff: Int, tz: TimeZone) -> Date {
    var calendar = Calendar.current
    calendar.timeZone = tz
    
    var components = calendar.dateComponents([.year, .month, .day], from: date)
    components.hour = cutoff
    components.minute = 0
    components.second = 0
    
    return calendar.date(from: components)!
}
```

**JavaScript Equivalent:**

```javascript
function serviceDayKeyMaxOverlap(startUTC, endUTC, cutoffHourLocal, tzName) {
    const start = new Date(startUTC);
    const end = new Date(endUTC);
    
    // Format dates in local tz
    const fmt = new Intl.DateTimeFormat('en-US', {
        timeZone: tzName,
        year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit'
    });
    
    // Find candidate service days
    const candidates = [];
    let candidateDate = new Date(start);
    candidateDate.setUTCHours(0, 0, 0, 0);
    
    while (candidateDate <= end) {
        const serviceDayStart = getServiceDayBoundary(candidateDate, cutoffHourLocal, tzName);
        const serviceDayEnd = getServiceDayBoundary(
            new Date(candidateDate.getTime() + 86400000), 
            cutoffHourLocal, 
            tzName
        );
        
        const overlapStart = new Date(Math.max(start.getTime(), serviceDayStart.getTime()));
        const overlapEnd = new Date(Math.min(end.getTime(), serviceDayEnd.getTime()));
        const overlap = Math.max(0, overlapEnd - overlapStart);
        
        if (overlap > 0) {
            const key = candidateDate.toISOString().slice(0, 10);
            candidates.push({ day: key, overlap });
        }
        
        candidateDate = new Date(candidateDate.getTime() + 86400000);
    }
    
    // Max overlap; ties → earlier day
    candidates.sort((a, b) => {
        if (b.overlap === a.overlap) return a.day.localeCompare(b.day); // Earlier wins
        return b.overlap - a.overlap;
    });
    
    return candidates[0]?.day || start.toISOString().slice(0, 10);
}

function getServiceDayBoundary(date, cutoffHour, tzName) {
    const parts = new Intl.DateTimeFormat('en-US', {
        timeZone: tzName,
        year: 'numeric', month: '2-digit', day: '2-digit'
    }).formatToParts(date);
    
    const year = parts.find(p => p.type === 'year').value;
    const month = parts.find(p => p.type === 'month').value;
    const day = parts.find(p => p.type === 'day').value;
    
    // Construct local time at cutoff hour
    const localStr = `${year}-${month}-${day}T${String(cutoffHour).padStart(2, '0')}:00:00`;
    
    // Parse as UTC offset (tricky - use moment-timezone or date-fns-tz in prod)
    return new Date(localStr); // SIMPLIFIED - needs proper tz conversion
}
```

**Test Cases:**
```swift
// Case 1: Normal sleep (majority post-cutoff)
assert(serviceDayKeyMaxOverlap(
    start: "2025-11-03T23:30:00-05:00", // 23:30 EST
    end:   "2025-11-04T06:30:00-05:00", // 06:30 EST
    cutoff: 12,
    tz: "America/New_York"
) == "2025-11-04") // 6.5h post-cutoff > 0.5h pre-cutoff

// Case 2: Early bedtime (majority pre-cutoff)
assert(serviceDayKeyMaxOverlap(
    start: "2025-11-03T21:00:00-05:00", // 21:00 EST
    end:   "2025-11-04T04:00:00-05:00", // 04:00 EST
    cutoff: 12,
    tz: "America/New_York"
) == "2025-11-03") // 3h pre-cutoff < 4h post-cutoff → WAIT, recalc
// Actually: 3h pre + 4h post = 7h total, 4h in Nov 4 → "2025-11-04"

// Case 3: DST boundary (spring forward)
assert(serviceDayKeyMaxOverlap(
    start: "2025-03-09T06:30:00Z", // 01:30 EST
    end:   "2025-03-09T12:45:00Z", // 08:45 EDT (DST happened at 07:00Z = 02:00→03:00 local)
    cutoff: 12,
    tz: "America/New_York"
) == "2025-03-09") // All within March 9 service day
```

---

### 4. Compression Format Mismatch **[BLOCKER]**

**Problem:** Code says "gzip", implements LZFSE, writes ".gz" extension.

**Impact:** 🔴 **INTEROP FAILURE** - agent can't decompress, silent corruption.

**Solution - Pick One:**

**Option A: Use LZFSE (Apple-optimized, faster)**
```swift
import Compression

func compressLZFSE(_ source: URL) throws -> URL {
    let dest = source.appendingPathExtension("lzfse")
    let input = try Data(contentsOf: source)
    let compressed = try (input as NSData).compressed(using: .lzfse)
    try compressed.write(to: dest, options: .atomic)
    try FileManager.default.removeItem(at: source)
    return dest
}
```

**Agent Update:**
```javascript
const lzfse = require('lzfse'); // or spawn lzfse CLI

function decompressLZFSE(file) {
    if (file.endsWith('.lzfse')) {
        const compressed = fs.readFileSync(file);
        const decompressed = lzfse.decode(compressed);
        return decompressed.toString('utf8');
    }
    return fs.readFileSync(file, 'utf8');
}
```

**Option B: Use Gzip (universal, smaller npm footprint)**
```swift
import Compression

func compressGzip(_ source: URL) throws -> URL {
    let dest = source.appendingPathExtension("gz")
    let input = try Data(contentsOf: source)
    let compressed = try (input as NSData).compressed(using: .zlib) // gzip-compatible
    try compressed.write(to: dest, options: .atomic)
    try FileManager.default.removeItem(at: source)
    return dest
}
```

**Agent Update:**
```javascript
const zlib = require('zlib');

function decompressGzip(file) {
    if (file.endsWith('.gz')) {
        const compressed = fs.readFileSync(file);
        const decompressed = zlib.gunzipSync(compressed);
        return decompressed.toString('utf8');
    }
    return fs.readFileSync(file, 'utf8');
}
```

**Recommendation:** **Gzip** - universal, agent has zlib built-in, no external deps.

---

### 5. Nap Detection Heuristic - False Positives **[HIGH]**

**Problem:** "Daytime & <2h" mislabels:
- Short awakenings inside night sleep
- Travel across timezones (shifted schedule)
- Shift work (night-shift workers sleep during day)

**Root Cause:** No context-aware guards.

**Impact:** 🟠 **DATA QUALITY** - wrong nap flags, skewed features.

**Solution - Context-Aware Nap Detection:**

```swift
struct NapDetectionContext {
    var plannedServiceNight: (start: Date, end: Date)?
    var weeklySchedule: WeeklySchedule?
    var recentTravelDetected: Bool
}

func detectNap(
    sample: HKCategorySample, 
    cutoffHourLocal: Int,
    context: NapDetectionContext
) -> (isNap: Bool, confidence: Double, ruleVersion: String) {
    
    let duration = sample.endDate.timeIntervalSince(sample.startDate)
    let hour = Calendar.current.component(.hour, from: sample.startDate)
    
    // Rule 1: Duration check
    guard duration < 7200 else { // <2h
        return (false, 1.0, "v2")
    }
    
    // Rule 2: Daytime window (cutoff → 22:00)
    let isDaytime = hour >= cutoffHourLocal && hour < 22
    guard isDaytime else {
        return (false, 1.0, "v2")
    }
    
    // Guard 1: Overlaps planned service night by >15 min
    if let planned = context.plannedServiceNight {
        let overlap = sample.endDate > planned.start && sample.startDate < planned.end
        if overlap {
            let overlapDuration = min(sample.endDate, planned.end)
                .timeIntervalSince(max(sample.startDate, planned.start))
            if overlapDuration > 900 { // >15 min
                return (false, 0.6, "v2") // Likely awakening, not nap
            }
        }
    }
    
    // Guard 2: Weekly schedule "off-day" or "travel"
    if let schedule = context.weeklySchedule {
        let weekday = Calendar.current.component(.weekday, from: sample.startDate)
        if schedule.days[weekday].isOffDay || schedule.days[weekday].isTravelDay {
            return (true, 0.7, "v2") // Lower confidence on off-days
        }
    }
    
    // Guard 3: Recent travel (timezone shift)
    if context.recentTravelDetected {
        return (true, 0.5, "v2") // Very low confidence
    }
    
    // Default: daytime short sleep = nap
    return (true, 0.9, "v2")
}
```

**Metadata Schema:**
```json
{
  "record_type": "sleep",
  "metadata": {
    "stage": "asleep",
    "nap_derived": true,
    "nap_rule_version": "v2",
    "nap_confidence": 0.9
  }
}
```

---

### 6. Steps Are Not Simply Additive **[CRITICAL]**

**Problem:** HealthKit step samples can overlap (watch + phone both counting). Summing raw values = double-counting.

**Root Cause:** No de-overlap or statistics-based aggregation.

**Impact:** 🔴 **INFLATED COUNTS** - step totals 2-3x reality.

**Solution - Use HKStatisticsCollection:**

```swift
func exportStepTotals(
    from startDate: Date,
    to endDate: Date,
    cutoffHourLocal: Int,
    tz: TimeZone
) async throws -> [HealthRecord] {
    
    let stepsType = HKQuantityType(.stepCount)
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
    
    // Anchor date aligned to cutoff hour
    var calendar = Calendar.current
    calendar.timeZone = tz
    var components = calendar.dateComponents([.year, .month, .day], from: startDate)
    components.hour = cutoffHourLocal
    let anchorDate = calendar.date(from: components)!
    
    let query = HKStatisticsCollectionQuery(
        quantityType: stepsType,
        quantitySamplePredicate: predicate,
        options: .cumulativeSum,
        anchorDate: anchorDate,
        intervalComponents: DateComponents(day: 1)
    )
    
    return try await withCheckedThrowingContinuation { continuation in
        query.initialResultsHandler = { _, collection, error in
            if let error = error {
                continuation.resume(throwing: error)
                return
            }
            
            var records: [HealthRecord] = []
            collection?.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                if let sum = stats.sumQuantity() {
                    let count = sum.doubleValue(for: .count())
                    
                    // Map to service day
                    let serviceDay = serviceDayKeyMaxOverlap(
                        start: stats.startDate,
                        end: stats.endDate,
                        cutoffHourLocal: cutoffHourLocal,
                        tz: tz
                    )
                    
                    let record = HealthRecord(
                        source: "healthkit",
                        recordType: "step",
                        startUTC: stats.startDate.iso8601,
                        endUTC: stats.endDate.iso8601,
                        serviceDayKey: serviceDay,
                        value: count,
                        unit: "count",
                        // ... other fields
                    )
                    records.append(record)
                }
            }
            
            continuation.resume(returning: records)
        }
        
        healthStore.execute(query)
    }
}
```

**Result:** One aggregated record per service day, no overlaps.

---

### 7. Encryption UX Missing Critical Rails **[BLOCKER]**

**Problem:** AES-GCM code exists, but no:
- Key derivation (raw passphrase → key is weak)
- Passphrase strength enforcement
- Rotation/versioning
- RAM cleanup

**Root Cause:** Crypto primitives without key management UX.

**Impact:** 🔴 **DATA LOSS RISK** - weak passwords, forgotten passphrases, no recovery.

**Solution - Production Key Management:**

```swift
import CryptoKit

struct EncryptionConfig: Codable {
    var enabled: Bool
    var keyVersion: Int
    var pbkdf2Salt: Data
    var pbkdf2Iterations: Int
}

func deriveKey(from passphrase: String, config: EncryptionConfig) -> SymmetricKey {
    let passphraseData = Data(passphrase.utf8)
    let derived = SHA256.hash(data: passphraseData + config.pbkdf2Salt)
    
    // PBKDF2 (use CommonCrypto or CryptoKit equivalent)
    var key = derived
    for _ in 0..<config.pbkdf2Iterations {
        key = SHA256.hash(data: Data(key) + config.pbkdf2Salt)
    }
    
    return SymmetricKey(data: key)
}

func encryptFile(_ source: URL, passphrase: String, config: EncryptionConfig) throws -> URL {
    let key = deriveKey(from: passphrase, config: config)
    defer { 
        // Wipe key from RAM
        withUnsafeMutableBytes(of: &key) { ptr in
            ptr.baseAddress?.initialize(repeating: 0, count: ptr.count)
        }
    }
    
    let plaintext = try Data(contentsOf: source)
    let nonce = AES.GCM.Nonce()
    let sealed = try AES.GCM.seal(plaintext, using: key, nonce: nonce)
    
    let dest = source.appendingPathExtension("enc")
    let combined = nonce.dataRepresentation + sealed.ciphertext + sealed.tag
    try combined.write(to: dest, options: .atomic)
    
    // Delete plaintext (don't leave unencrypted copy)
    try FileManager.default.removeItem(at: source)
    
    return dest
}
```

**Settings UI:**
```swift
struct EncryptionSettingsView: View {
    @State private var passphrase = ""
    @State private var passphraseStrength: Double = 0.0
    @State private var confirmedRisk = false
    
    var body: some View {
        Section {
            SecureField("Passphrase (12+ characters)", text: $passphrase)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onChange(of: passphrase) { old, new in
                    passphraseStrength = calculateStrength(new)
                }
            
            ProgressView(value: passphraseStrength)
                .tint(passphraseStrength < 0.5 ? .red : passphraseStrength < 0.8 ? .orange : .green)
            
            Text("Strength: \(strengthLabel)")
                .font(.caption)
                .foregroundColor(passphraseStrength < 0.5 ? .red : .secondary)
            
            Toggle("I understand I cannot recover data if I forget this passphrase", isOn: $confirmedRisk)
            
            Button("Enable Encryption") {
                let salt = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
                let config = EncryptionConfig(
                    enabled: true,
                    keyVersion: 1,
                    pbkdf2Salt: salt,
                    pbkdf2Iterations: 100_000
                )
                try? KeychainHelper.save(passphrase, forKey: "health_export_passphrase_v1")
                try? KeychainHelper.saveJSON(config, forKey: "health_export_encryption_config")
            }
            .disabled(passphraseStrength < 0.8 || !confirmedRisk)
            
        } header: {
            Text("Encryption")
        } footer: {
            if !confirmedRisk {
                Text("⚠️ Exports will be unencrypted. Health data is sensitive.")
                    .foregroundColor(.orange)
            } else {
                Text("✅ Exports will be encrypted with AES-256-GCM. Keep your passphrase safe.")
                    .foregroundColor(.green)
            }
        }
    }
    
    var strengthLabel: String {
        if passphraseStrength < 0.3 { return "Weak" }
        if passphraseStrength < 0.6 { return "Fair" }
        if passphraseStrength < 0.8 { return "Good" }
        return "Strong"
    }
    
    func calculateStrength(_ password: String) -> Double {
        var strength = 0.0
        if password.count >= 12 { strength += 0.3 }
        if password.count >= 16 { strength += 0.2 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { strength += 0.15 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { strength += 0.15 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { strength += 0.1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*")) != nil { strength += 0.1 }
        return min(strength, 1.0)
    }
}
```

---

## 🔍 HIGH-IMPACT SPEC/QUALITY GAPS

### 8. Record Identity → Include HK UUID **[HIGH]**

**Problem:** SHA-256 is for dedupe, tombstones need canonical ID.

**Solution:**
```swift
struct HealthRecord {
    var sha256: String // Dedupe hash
    var hk_uuid: String? // HealthKit sample UUID (for tombstones)
    var hk_source_revision: String? // HKSourceRevision (version tracking)
}

// In makeRecord:
record.hk_uuid = sample.uuid.uuidString
if let sourceRev = sample.sourceRevision {
    record.hk_source_revision = "\(sourceRev.source.bundleIdentifier):\(sourceRev.version)"
}
```

**Tombstone Reference:**
```json
{
  "deleted": true,
  "sha256": "abc123...",
  "hk_uuid": "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
  "deleted_at": "2025-11-04T14:30:00Z"
}
```

---

### 9. Offsets + Timezones Across Travel **[HIGH]**

**Problem:** Single `tz_name` wrong for travel nights (NYC → Denver mid-sleep).

**Solution:**
```swift
struct HealthRecord {
    var start_tz: String // "America/New_York"
    var end_tz: String // "America/Denver"
    var start_offset_min: Int // -300 (EST)
    var end_offset_min: Int // -420 (MST)
}

// In makeRecord:
record.start_tz = TimeZone.current.identifier(for: sample.startDate)
record.end_tz = TimeZone.current.identifier(for: sample.endDate)
```

---

### 10. Cutoff Governance → Hard Invariant **[CRITICAL]**

**Problem:** Cutoff can change, breaking joins.

**Solution - Enforce at Join:**
```javascript
// In join step
for (const doseNight of doseLog) {
    const healthNight = healthExports.find(h => h.service_day_key === doseNight.night_key);
    
    if (!healthNight) {
        throw new Error(`CUTOFF MISMATCH: No health data for night ${doseNight.night_key}. ` +
                       `DoseLog cutoff may differ from health export cutoff. ` +
                       `Run rebucket tool: npm run rebucket --cutoff=${doseNight.cutoff}`);
    }
    
    // Also check cutoff hour consistency
    if (healthNight.cutoff_hour_local !== doseNight.cutoff_hour_local) {
        throw new Error(`CUTOFF INCONSISTENCY: DoseLog=${doseNight.cutoff_hour_local}, ` +
                       `Health=${healthNight.cutoff_hour_local} for night ${doseNight.night_key}`);
    }
}
```

**Rebucket Tool:**
```bash
#!/usr/bin/env node
// scripts/rebucket-health-export.js

const oldCutoff = parseInt(process.argv[2]);
const newCutoff = parseInt(process.argv[3]);

for (const record of healthRecords) {
    const newServiceDay = serviceDayKeyMaxOverlap(
        record.start_utc,
        record.end_utc,
        newCutoff,
        record.tz_name
    );
    
    record.service_day_key = newServiceDay;
    record.cutoff_hour_local = newCutoff;
}

fs.writeFileSync('health_rebucketed.jsonl', healthRecords.map(JSON.stringify).join('\n'));
```

---

### 11. Feature Robustness → Outlier Clipping **[HIGH]**

```javascript
function computeRobustStats(night) {
    // HRV: median + P75 (already planned)
    const hrvValues = (night._raw.hrv || [])
        .map(r => r.value)
        .filter(v => v >= 5 && v <= 300) // Clip outliers
        .sort((a, b) => a - b);
    
    night.hrvSdnnMsP50 = median(hrvValues);
    night.hrvSdnnMsP75 = percentile(hrvValues, 0.75);
    
    // HR: clip to plausible range
    const hrValues = (night._raw.hr || [])
        .map(r => r.value)
        .filter(v => v >= 35 && v <= 220);
    night.hrMeanBpm = mean(hrValues);
    night.hrP10Bpm = percentile(hrValues, 0.1);
    night.hrP90Bpm = percentile(hrValues, 0.9);
    
    // Respiratory: clip + median
    const respValues = (night._raw.respiratory_rate || [])
        .map(r => r.value)
        .filter(v => v >= 8 && v <= 30);
    night.respiratoryRateP50 = median(respValues);
}
```

---

### 12. Manifests → Add Anchoring Metadata **[HIGH]**

```json
{
  "schema_version": "2.0",
  "exporter_version": "2.1.0",
  "per_type_stats": {
    "hr": {
      "added": 18320,
      "deleted": 5,
      "new_anchor_base64": "YnBsaXN0M...",
      "old_anchor_base64": "eHl6YWJj..."
    },
    "sleep": {
      "added": 42,
      "deleted": 0,
      "new_anchor_base64": "cXdlcnR5..."
    }
  },
  "files": [
    {
      "path": "healthkit_export_1730764800.jsonl.gz",
      "sha256": "a1b2c3d4...",
      "size_bytes": 245678
    }
  ],
  "status": "ok"
}
```

---

## 🧪 TESTS I EXPECT BEFORE "GREEN"

### Test 1: Two-Phase Anchor Recovery

```swift
func testTwoPhaseAnchorRecovery() async throws {
    // 1. Export 100 HR records → anchor saved as "A"
    let export1 = try await bridge.exportIncremental()
    let anchorA = anchorStore.loadAnchor(for: "hr")
    
    // 2. Add 50 new HR records to HealthKit
    try await addMockHRSamples(count: 50)
    
    // 3. Start export → query returns 50 records, new anchor "B"
    let checkpoints = try await bridge.queryAllTypesWithCheckpoints()
    XCTAssertEqual(checkpoints.first(where: { $0.typeId == "hr" })?.recordCount, 50)
    
    // 4. SIMULATE CRASH before fsync
    // (Don't call commitAnchors)
    
    // 5. App relaunches → finds pending manifest
    let recovered = try bridge.recoverPendingExports()
    
    // 6. Verify: anchor still "A" (not "B")
    let anchorAfterRecovery = anchorStore.loadAnchor(for: "hr")
    XCTAssertEqual(anchorA, anchorAfterRecovery)
    
    // 7. Re-export → produces same 50 records, saves anchor "B"
    let export2 = try await bridge.exportIncremental()
    XCTAssertEqual(export2.manifest.per_type_stats["hr"]?.added, 50)
    
    // 8. Verify: no duplicates in combined exports
    let allRecords = loadAllRecords([export1, export2])
    let uniqueSHA256 = Set(allRecords.map(\.sha256))
    XCTAssertEqual(allRecords.count, 150) // 100 + 50
    XCTAssertEqual(uniqueSHA256.count, 150) // All unique
}
```

---

### Test 2: Service-Day Max Overlap Rule

```swift
func testServiceDayMaxOverlap() {
    // Case 1: Majority post-cutoff
    let key1 = serviceDayKeyMaxOverlap(
        start: iso8601("2025-11-03T23:30:00-05:00"),
        end:   iso8601("2025-11-04T06:30:00-05:00"),
        cutoffHourLocal: 12,
        tz: TimeZone(identifier: "America/New_York")!
    )
    XCTAssertEqual(key1, "2025-11-04") // 6.5h post > 0.5h pre
    
    // Case 2: DST spring forward
    let key2 = serviceDayKeyMaxOverlap(
        start: iso8601("2025-03-09T06:30:00Z"), // 01:30 EST
        end:   iso8601("2025-03-09T12:45:00Z"), // 08:45 EDT
        cutoffHourLocal: 12,
        tz: TimeZone(identifier: "America/New_York")!
    )
    XCTAssertEqual(key2, "2025-03-09")
    
    // Case 3: Travel night (NYC → Denver)
    // NOT YET TESTABLE - needs start_tz/end_tz support
}
```

---

### Test 3: Android/XML Parity

```javascript
test('Service day parity across sources', () => {
    const startUTC = '2025-11-03T04:30:00Z'; // 23:30 EST
    const endUTC = '2025-11-04T11:30:00Z';   // 06:30 EST
    const cutoff = 12;
    const tz = 'America/New_York';
    
    // iOS export
    const iosKey = '2025-11-04'; // From HealthExportBridge
    
    // Android source
    const androidKey = serviceDayKeyMaxOverlap(startUTC, endUTC, cutoff, tz);
    
    // Apple XML source
    const xmlKey = serviceDayKeyMaxOverlap(startUTC, endUTC, cutoff, tz);
    
    expect(androidKey).toBe(iosKey);
    expect(xmlKey).toBe(iosKey);
});
```

---

### Test 4: Tombstone Cascade

```javascript
test('Deletion tombstone invalidates rolling stats', () => {
    // 1. Export nights [11-01 … 11-07] with HRV data
    const nights = generateNights(7, { hrv: 10 }); // 10 samples per night
    const features1 = normalize(nights);
    
    const hrv7dayBefore = features1['2025-11-07'].hrvSdnnMsP50_7day;
    
    // 2. Delete 5 HRV samples from 11-01
    const deletions = nights
        .filter(r => r.service_day_key === '2025-11-01' && r.record_type === 'hrv')
        .slice(0, 5)
        .map(r => ({ ...r, deleted: true }));
    
    // 3. Re-normalize with tombstones
    const features2 = normalize([...nights, ...deletions]);
    
    const hrv7dayAfter = features2['2025-11-07'].hrvSdnnMsP50_7day;
    
    // 4. Verify: 7-day HRV changed (removed 5 samples from window)
    expect(hrv7dayAfter).not.toBe(hrv7dayBefore);
    
    // 5. Verify: deleted SHA-256s not in aggregates
    const nov01HRV = features2['2025-11-01']._raw.hrv || [];
    expect(nov01HRV.length).toBe(5); // 10 - 5 deleted
});
```

---

### Test 5: Compression Interop

```bash
# Swift exports .gz
swift run DoseTrackExporter --compress=gzip

# Agent reads .gz
node agent/normalize.js --source=ios

# Verify: records match uncompressed export
diff <(zcat export.jsonl.gz) export_uncompressed.jsonl
```

---

## 🚫 NO-SHIP-UNLESS GATES (Enforced)

**Critical (P0 - MUST SHIP):**

1. ✅ Two-phase anchor commit with recovery implemented & tested
2. ✅ Tombstones remove prior contributions and rolling windows recompute
3. ✅ Service-day max-overlap rule implemented identically in iOS + agent; parity tests pass
4. ✅ Compression format consistent (gzip or lzfse) + extension matches + verified in CI
5. ✅ Steps totals from HKStatisticsCollection (de-overlapped)
6. ✅ Encryption UX shippable: PBKDF2, key rotation, RAM wipe, strength meter, risk acknowledgment
7. ✅ Manifests contain per-type counts, anchor tokens (base64), blob SHA-256
8. ✅ Join invariant (night_key == service_day_key) enforced with hard failure + documented rebucket tool

**High Priority (P1 - SHOULD SHIP):**

9. ✅ HK UUID + source revision in records (tombstone traceability)
10. ✅ Dual timezones (start_tz, end_tz) for travel nights
11. ✅ Nap detection v2 with context guards (planned night, schedule, travel)
12. ✅ Robust stats with outlier clipping (HR 35-220, resp 8-30, HRV 5-300)

---

## 🎯 SURGICAL FIXES PRIORITY

**Phase 1 (Immediate - 6-8h):**
- Two-phase anchor state machine
- Service-day max-overlap (Swift + JS)
- Compression format pick + consistency
- Steps via HKStatisticsCollection
- Encryption PBKDF2 + Settings UI

**Phase 2 (Next - 4-6h):**
- Tombstone cascade in normalizer
- Join invariant enforcement
- Manifests with per-type metadata
- HK UUID + source revision

**Phase 3 (Polish - 3-4h):**
- Nap detection v2 guards
- Dual timezone support
- Robust stats outlier clipping
- Rebucket tool CLI

---

**Total Estimate:** 13-18 hours to production-solid  
**Status:** 🔴 CRITICAL BLOCKERS IDENTIFIED - Agent implementing surgical fixes now

