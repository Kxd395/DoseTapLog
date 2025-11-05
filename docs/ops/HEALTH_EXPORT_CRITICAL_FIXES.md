# Health Export v2 - Critical Fixes & "No Ship Unless" Gates

**Date:** November 4, 2025  
**Status:** ⚠️ BLOCKERS IDENTIFIED - P0 Implementation Incomplete  
**Priority:** CRITICAL - Production Readiness

---

## 🚨 RED FLAGS (Blockers - Must Fix Before Ship)

### 1. ✅ Incremental Export → Anchored Queries **[FIXED]**

**Problem:** Single `lastExportAt` timestamp misses:
- Late HealthKit backfills (watch syncs days later)
- Record corrections/edits
- Deletions (no tombstones)

**Solution Implemented:**
- `HealthExportBridge+Anchors.swift` (475 lines)
- `HKAnchoredObjectQuery` per type with persistent anchor tokens
- Handles `deletedObjects` → emits deletion tombstones (`deleted: true`)
- Falls back to 14-day time-range if no anchor exists

**Test Coverage Required:**
```swift
// Test: Anchor round-trip
- Export with no anchor → saves anchor_hr_v1
- Add 10 HR samples
- Export again → only 10 new records (dedupe via SHA-256)
- Delete 2 HR samples in HealthKit
- Export again → 2 deletion tombstones emitted
```

---

### 2. ✅ DST/Offset → Dual Offsets **[FIXED]**

**Problem:** Single `local_offset_min` fails when sample straddles DST boundary:
- Sleep starts 01:30 EST (offset -300)
- DST occurs at 02:00 → 03:00 EDT
- Sleep ends 08:45 EDT (offset -240)
- Duration calc with single offset = wrong

**Solution Implemented:**
- `start_offset_min`: Offset at `startDate`
- `end_offset_min`: Offset at `endDate`
- Both emitted in every record

**Schema Updated:**
```json
{
  "start_offset_min": -300,
  "end_offset_min": -240,
  "tz_name": "America/New_York"
}
```

**Test Coverage Required:**
```swift
// DST Spring Forward (2025-03-09 02:00 → 03:00)
let preDST = ISO8601DateFormatter().date(from: "2025-03-09T06:59:00Z")! // 01:59 EST
let postDST = ISO8601DateFormatter().date(from: "2025-03-09T07:01:00Z")! // 03:01 EDT
// start_offset_min: -300, end_offset_min: -240
```

---

### 3. ⚠️ "Nap" Derivation **[NEEDS IMPLEMENTATION]**

**Problem:** HealthKit has NO `nap` category - only `.sleepAnalysis` with stages

**Solution Required:**
```swift
// Nap detection logic (add to makeRecord)
func isNap(sample: HKCategorySample, cutoffHourLocal: Int) -> Bool {
    let duration = sample.endDate.timeIntervalSince(sample.startDate)
    let hour = Calendar.current.component(.hour, from: sample.startDate)
    
    // Rule v1: Daytime sleep < 2h outside service night
    let isDaytime = hour >= cutoffHourLocal && hour < 22
    let isShort = duration < 7200 // < 2 hours
    
    return isDaytime && isShort
}

// Emit metadata
if isNap(sample: catSample, cutoffHourLocal: cutoffHourLocal) {
    metadata["nap_derived"] = true
    metadata["nap_rule_version"] = "v1"
    // record_type stays "sleep", use metadata to filter
}
```

**Test Cases:**
- 14:00-15:30 (1.5h) → nap_derived=true
- 01:00-08:00 (7h) → nap_derived=false (night sleep)
- 23:00-23:45 (45m) → nap_derived=false (evening, too short)

---

### 4. ✅ SHA-1 → SHA-256 Canonical Hashing **[FIXED]**

**Problem:** SHA-1 collision-prone; hash input undefined (precision issues)

**Solution Implemented:**
```swift
// HealthRecord.canonicalHash256()
let canonical = [
    source, recordType, startUTC, endUTC,
    unit ?? "", 
    String(format: "%.3f", value ?? 0), // 3 decimal precision
    deviceModel ?? "", deviceHW ?? "", deviceSW ?? "",
    sourceApp ?? "",
    String(startOffsetMin), String(endOffsetMin)
].joined(separator: "|")

SHA256.hash(data: canonical.utf8) → 64-char hex
```

**Dedup Logic:**
- Hash computed on **unfuzzed** values (before anonymization)
- 3-decimal rounding prevents float precision drift
- Stable tuple order ensures consistency

---

### 5. ⚠️ Deletions → Tombstones **[PARTIAL - NEEDS NORMALIZER]**

**Problem:** Dedupe skips duplicates but never removes deleted records downstream

**iOS Solution Implemented:**
- `deletedObjects` from `HKAnchoredObjectQuery` → `{deleted: true}` records

**Agent Solution Required:**
```javascript
// In normalize.js
for (const rec of lines) {
  if (rec.deleted) {
    // Remove from perNight aggregates
    const existing = perNight[rec.service_day_key]?._raw[rec.record_type];
    if (existing) {
      const idx = existing.findIndex(r => r.sha256 === rec.sha256);
      if (idx >= 0) existing.splice(idx, 1);
    }
    // Optionally emit deletion audit trail
    deletions.push({ sha256: rec.sha256, deleted_at: Date.now() });
  } else {
    // Normal accumulation
  }
}
```

---

### 6. ⚠️ Service-Day Bucketing → Universal **[NEEDS ANDROID/XML]**

**Problem:** iOS exports `service_day_key`, but Android/XML sources don't

**Solution Required:**
```javascript
// In agent sources/healthconnect_json.js
function computeServiceDayKey(startUTC, cutoffHourLocal, tzName) {
    const date = new Date(startUTC);
    // Convert to local time in tzName
    const localDate = new Intl.DateTimeFormat('en-US', {
        timeZone: tzName,
        year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit'
    }).formatToParts(date);
    
    const year = localDate.find(p => p.type === 'year').value;
    const month = localDate.find(p => p.type === 'month').value;
    const day = localDate.find(p => p.type === 'day').value;
    const hour = parseInt(localDate.find(p => p.type === 'hour').value);
    
    // Apply cutoff logic
    if (hour < cutoffHourLocal) {
        // Subtract 1 day
        const prevDay = new Date(date);
        prevDay.setDate(prevDay.getDate() - 1);
        return prevDay.toISOString().slice(0, 10);
    }
    
    return `${year}-${month}-${day}`;
}
```

**Test:** iOS, Android, Apple XML all produce same `service_day_key` for same timestamp

---

### 7. ⚠️ Encryption At Rest **[NEEDS SETTINGS UI]**

**iOS Implementation:** ✅ `encryptFile()` with AES-GCM + passphrase SHA-256

**Missing:**
- Settings UI toggle: "Encrypt exports"
- Keychain passphrase storage (NOT synced)
- Passphrase prompt on first export
- "Unencrypted" warning dialog

**Settings UI Required:**
```swift
Section {
    Toggle("Encrypt exports", isOn: $encryptExports)
    
    if encryptExports {
        SecureField("Passphrase", text: $passphrase)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
        
        Button("Save to Keychain") {
            KeychainHelper.save(passphrase, forKey: "health_export_passphrase")
        }
    }
} footer: {
    if !encryptExports {
        Text("⚠️ Exports will be unencrypted. Health data is sensitive.")
            .foregroundColor(.orange)
    }
}
```

---

### 8. ✅ Unit Semantics → Explicit Enums **[FIXED]**

**Problem:** `spo2` value: 97 or 0.97? `hrvScore` ambiguous name

**Solution Implemented:**
```json
{
  "record_type": "spo2",
  "value": 97.0,
  "unit": "pct",  // Enum: "count/min", "ms", "pct", "count", "bpm"
  "description": "SpO2 0-100 percentage"
}

{
  "record_type": "hrv",
  "value": 45.3,
  "unit": "ms",
  "description": "HRV SDNN in milliseconds"
}
```

**Normalizer Update Required:**
```javascript
// Rename hrvScore → hrvSdnnMsP50
night.hrvSdnnMsP50 = median(night._raw.hrv.map(r => r.value));
night.hrvSdnnMsP75 = percentile(night._raw.hrv.map(r => r.value), 0.75);
```

---

### 9. ⚠️ File I/O → Atomic Writes + NSFileCoordinator **[NEEDS ENHANCEMENT]**

**Current:** ✅ Temp file + atomic move
**Missing:** NSFileCoordinator for iCloud containers

**Fix Required:**
```swift
func writeWithCoordinator(_ data: Data, to url: URL) throws {
    let coordinator = NSFileCoordinator()
    var writeError: NSError?
    
    coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &writeError) { newURL in
        try? data.write(to: newURL, options: .atomic)
    }
    
    if let error = writeError {
        throw error
    }
}
```

---

### 10. ⚠️ Feature Math Quality → Robust Stats **[NEEDS NORMALIZER UPDATE]**

**Problems:**
- `hrvScore = max` → Noisy outliers
- Respiratory rate outliers (120 bpm spikes)
- Steps at night → Massive file size

**Solutions Required:**
```javascript
// Robust HRV stats (median + P75)
const hrvValues = night._raw.hrv.map(r => r.value).sort((a,b) => a-b);
night.hrvSdnnMsP50 = median(hrvValues);
night.hrvSdnnMsP75 = percentile(hrvValues, 0.75);

// Respiratory rate (filter outliers, use median)
const respValues = night._raw.respiratory_rate
    .map(r => r.value)
    .filter(v => v >= 8 && v <= 30); // Plausible range
night.respiratoryRateP50 = median(respValues);

// Steps (aggregate per night, not per sample)
night.stepCountTotal = night._raw.step.reduce((sum, r) => sum + r.value, 0);
// Don't store individual step samples (too large)
```

---

## 🔒 High-Impact Spec Gaps

### Schema Versioning **[PARTIAL]**

**Implemented:** ✅ `schema_version`, `exporter_version` fields
**Missing:** Migration strategy when schema changes

**Required:**
```javascript
// In normalizer
if (rec.schema_version === "1.0") {
    // Migrate: local_offset_min → start_offset_min, end_offset_min
    rec.start_offset_min = rec.local_offset_min;
    rec.end_offset_min = rec.local_offset_min;
    delete rec.local_offset_min;
    rec.schema_version = "2.0";
}
```

---

### Device Identity **[PARTIAL]**

**Implemented:** ✅ `device_model`, `device_hw`, `device_sw`
**Issue:** `device.name` is unstable (user renames Apple Watch)

**Current:** Using stable fields only (model, hw version, sw version)

---

### Cutoff Governance **[NEEDS POLICY]**

**Problem:** User changes cutoff 12→11, which rule applies to historical data?

**Solution Required:**
1. **Freeze cutoff per export** ✅ (already emit `cutoff_hour_local` per record)
2. **No retroactive rebucketing** - historical exports keep original `service_day_key`
3. **DoseLog must match** - if DoseLog uses cutoff=12, health export must use 12
4. **Migration tool** - if cutoff changes, provide script to re-export & re-bucket

**Policy Document Required:** `docs/ops/CUTOFF_CHANGE_POLICY.md`

---

### Join Consistency **[CRITICAL TEST]**

**Problem:** `night_key` (DoseLog) must === `service_day_key` (health) for same timestamp

**Test Required:**
```javascript
// Integration test
const doseLogNights = loadDoseLogExport();
const healthNights = loadHealthExport();

for (const dose of doseLogNights) {
    // Find health records for same time window
    const healthForNight = healthNights.filter(h => 
        h.service_day_key === dose.night_key
    );
    
    // Verify 1:1 mapping
    assert(healthForNight.length > 0, `No health data for ${dose.night_key}`);
    
    // Verify timestamps align
    const bedtime = new Date(dose.bedtime_utc);
    const healthServiceDay = computeServiceDayKey(bedtime, cutoff, tz);
    assert(healthServiceDay === dose.night_key, "Service day mismatch!");
}
```

---

### WHOOP Placeholder **[RESERVED]**

**Implemented:** ✅ `source:"whoop"` in schema enum
**Missing:** Fixture data test

**Test Required:**
```javascript
// Create fixture WHOOP record
const whoopRecord = {
    schema_version: "2.0",
    exporter_version: "2.1.0",
    source: "whoop",
    record_type: "recovery",  // NEW type
    start_utc: "2025-11-04T00:00:00Z",
    end_utc: "2025-11-04T23:59:59Z",
    service_day_key: "2025-11-03",
    value: 67,  // Recovery percentage
    unit: "pct",
    deleted: false
};

// Verify normalizer handles it
const features = normalize([whoopRecord, ...healthRecords]);
assert(features.whoopRecoveryPct === 67);
```

---

### Data Retention Job **[NOT IMPLEMENTED]**

**Missing:** Daily purge of old exports

**Implementation Required:**
```swift
// In BGTask or Settings button
func purgeOldExports(olderThanDays: Int) async throws {
    let fm = FileManager.default
    let cutoffDate = Date().addingTimeInterval(-Double(olderThanDays * 86400))
    
    // Find export directories
    let dirs = [iCloudExportsDir, localExportsDir]
    
    for dir in dirs {
        let files = try fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.creationDateKey])
        
        for file in files {
            let attrs = try file.resourceValues(forKeys: [.creationDateKey])
            if let created = attrs.creationDate, created < cutoffDate {
                // Secure delete (overwrite + remove)
                if file.pathExtension == "enc" {
                    try secureDelete(file)
                } else {
                    try fm.removeItem(at: file)
                }
            }
        }
    }
}

func secureDelete(_ url: URL) throws {
    let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as! Int
    let zeros = Data(count: size)
    try zeros.write(to: url, options: .atomic)
    try FileManager.default.removeItem(at: url)
}
```

---

## 🐛 Likely Bugs (Testing Required)

### 1. Watch Backfill After Sync ✅ **[ANCHORS FIX THIS]**

**Scenario:** HR data from Nov 1 arrives on Nov 4 after watch sync
**Old Behavior:** `lastExportAt=Nov 3` → misses Nov 1 data
**New Behavior:** Anchor query catches all new additions regardless of timestamp

---

### 2. DST Jump Inside Sample ✅ **[DUAL OFFSETS FIX THIS]**

**Scenario:** Sleep 01:30 EST → 08:45 EDT (crosses DST)
**Old Behavior:** Single offset → wrong duration calc
**New Behavior:** `start_offset_min=-300`, `end_offset_min=-240` → correct math

---

### 3. iCloud Write Failures **[NEEDS ERROR SURFACING]**

**Scenario:** Battery saver + no Wi-Fi → iCloud write fails silently
**Fix Required:**
```swift
// In exportIncremental()
do {
    let url = try await writeRecords(...)
    defaults.set(url.path, forKey: "lastExportPath")
    defaults.set(Date(), forKey: "lastExportSuccess")
    defaults.removeObject(forKey: "lastExportError")
} catch {
    defaults.set(error.localizedDescription, forKey: "lastExportError")
    defaults.set(Date(), forKey: "lastExportAttempt")
    throw error
}

// Settings UI shows:
if let error = defaults.string(forKey: "lastExportError") {
    Label(error, systemImage: "exclamationmark.triangle")
        .foregroundColor(.red)
}
```

---

### 4. Anonymize Before Hash **[DESIGN ISSUE]**

**Problem:** Fuzzing timestamps before hashing → dedupe breaks across runs

**Solution:** Hash on **unfuzzed**, emit **fuzzed** separately
```swift
// Compute hash on original timestamps
let hash = record.sha256  // Uses unfuzzed values

// Then apply fuzzing for display (optional)
if anonymize {
    record.start_utc_display = fuzz(record.start_utc)
    record.end_utc_display = fuzz(record.end_utc)
}
// But start_utc (used in hash) stays original
```

---

## ⚡ Performance & Ops

### 1. Large JSONL → Gzip Everything

**Implementation:**
```swift
import Compression

func gzipFile(_ source: URL) throws -> URL {
    let dest = source.appendingPathExtension("gz")
    let input = try Data(contentsOf: source)
    let compressed = try (input as NSData).compressed(using: .lzfse)
    try compressed.write(to: dest, options: .atomic)
    try FileManager.default.removeItem(at: source)
    return dest
}

// After writing JSONL:
let gzipped = try gzipFile(jsonlFile)
manifest.files = [gzipped.lastPathComponent]
```

**Agent Update:**
```javascript
// In pull:ios
const files = fs.readdirSync(syncDir).filter(f => 
    f.startsWith("healthkit_export") && 
    (f.endsWith(".jsonl") || f.endsWith(".jsonl.gz"))
);

for (const f of files) {
    if (f.endsWith(".gz")) {
        // Decompress with zlib
        const gzipped = fs.readFileSync(path.join(syncDir, f));
        const decompressed = zlib.gunzipSync(gzipped);
        fs.writeFileSync(path.join(outDir, f.replace('.gz', '')), decompressed);
    } else {
        fs.copyFileSync(path.join(syncDir, f), path.join(outDir, f));
    }
}
```

---

### 2. Streaming Writes (Already Implemented) ✅

Using `FileHandle.write()` line-by-line → memory stays flat

---

### 3. Manifest JSON ✅ **[IMPLEMENTED]**

```json
{
  "schema_version": "2.0",
  "exporter_version": "2.1.0",
  "cutoff_hour_local": 12,
  "tz_name": "America/New_York",
  "anchored_since": "2025-10-21T00:00:00Z",
  "counts": {
    "sleep": 42,
    "hr": 18320,
    "hrv": 120,
    "respiratory_rate": 560,
    "spo2": 90,
    "step": 28
  },
  "files": ["healthkit_export_1730764800.jsonl.gz"],
  "sha256": "a1b2c3...",
  "started_at": "2025-11-04T14:30:00Z",
  "finished_at": "2025-11-04T14:32:15Z",
  "status": "ok"
}
```

---

## 🔐 Security & Privacy (Musts)

### 1. Encryption At Rest ⚠️ **[PARTIAL - NEEDS UI]**

**Implemented:** ✅ AES-GCM encryption
**Missing:** Settings UI, Keychain passphrase storage

---

### 2. Minimize Data ⚠️ **[NEEDS SETTINGS]**

**Required Toggles:**
```swift
Toggle("Include heart rate series", isOn: $includeHR)
Toggle("Include step count", isOn: $includeSteps)
Toggle("Include device identifiers", isOn: $includeDeviceIDs)
```

**Exporter Update:**
```swift
if !prefs.includeHR {
    types.removeAll { $0.1 == "hr" }
}

if !prefs.includeDeviceIDs {
    record.deviceModel = nil
    record.deviceHW = nil
    record.deviceSW = nil
}
```

---

### 3. PII Leak Audit ⚠️ **[NOT IMPLEMENTED]**

**Required:**
```swift
func auditForPII(_ json: [String: Any]) -> [String] {
    let piiKeys = ["fullName", "email", "phone", "address", "name"]
    var leaks: [String] = []
    
    func scanDict(_ dict: [String: Any], path: String = "") {
        for (key, value) in dict {
            let fullPath = path.isEmpty ? key : "\(path).\(key)"
            if piiKeys.contains(key.lowercased()) {
                leaks.append(fullPath)
            }
            if let nested = value as? [String: Any] {
                scanDict(nested, path: fullPath)
            }
        }
    }
    
    scanDict(json)
    return leaks
}

// Before writing:
let pii = auditForPII(record.toJSON())
if !pii.isEmpty {
    throw NSError(domain: "HealthExportBridge", code: 3, 
                  userInfo: [NSLocalizedDescriptionKey: "PII detected: \(pii.joined(separator: ", "))"])
}
```

---

## ✅ "No Ship Unless" Checklist

### Critical (P0 - Must Ship)

- [ ] **Anchored queries implemented** per type with persistent anchors
- [ ] **Deletion tombstones** emitted and handled in normalizer
- [ ] **Dual offsets** (`start_offset_min`, `end_offset_min`) in all records
- [ ] **SHA-256 canonical hashing** with stable tuple (not SHA-1)
- [ ] **DST tests pass** (spring forward, fall back, timezone changes)
- [ ] **Service-day tests pass** (before/after cutoff, midnight crossing)
- [ ] **Encryption toggle** works end-to-end (Settings UI → Keychain → AES-GCM)
- [ ] **Manifest created** per export with counts, sha256, status
- [ ] **Atomic writes** with NSFileCoordinator for iCloud
- [ ] **Schema versioning** present in all records
- [ ] **Unit enums** enforced (no ambiguous "%" vs "pct")
- [ ] **Robust stats** (HRV median/P75, resp rate median, step totals)

### High Priority (P1 - Should Ship)

- [ ] **Nap derivation** logic documented and tested
- [ ] **Service-day logic** implemented in agent for Android/XML sources
- [ ] **Join validation** test (DoseLog night_key === health service_day_key)
- [ ] **Retention job** purges old exports (7/30/90 days)
- [ ] **Settings UI** shows last export, last error, destination path
- [ ] **Error surfacing** in App Health panel
- [ ] **WHOOP fixture test** (source:"whoop" joins correctly)
- [ ] **Gzip compression** enabled (`.jsonl.gz`)
- [ ] **Minimize toggles** (exclude HR, steps, device IDs)

### Medium Priority (P2 - Nice to Have)

- [ ] **PII leak audit** before writes
- [ ] **Cutoff change policy** documented
- [ ] **Migration script** for schema 1.0 → 2.0
- [ ] **Multi-source dedupe** test (iOS + Android same timestamp)
- [ ] **Anonymization tests** (fuzz after hash, not before)

---

## 📊 Updated Estimates

| Item | Original Estimate | New Estimate | Reason |
|------|-------------------|--------------|--------|
| **Item 61** | 3h | **6-7h** | Anchors + dual offsets + nap logic + encryption UI |
| **Item 62** | 2h | **2h** | No change (DoseLog export straightforward) |
| **Item 63** | 3h | **5-6h** | Deletion handling + robust stats + join validation |
| **Item 64** | 1.5h | **3h** | Secure delete + retention job |
| **Item 65** | 2h | **3h** | Error surfacing + minimize toggles |
| **Item 66** | 1h | **2h** | Encryption Keychain + PII audit |
| **Item 67** | 3h | **5h** | Anchor tests + DST tests + join tests |
| **Item 68** | 1h | **2h** | Cutoff policy doc + migration guide |

**New Total:** 28-30 hours (was 15.5h)

---

## 🚀 Recommended Phasing

### Phase 1: Critical Blockers (12-14h)
- Anchored queries + deletions
- Dual offsets
- SHA-256 hashing
- Encryption Settings UI
- Manifest generation
- DST/cutoff tests

### Phase 2: Data Quality (8-10h)
- Nap derivation
- Robust stats (HRV median, resp median)
- Join validation
- Service-day agent logic
- Gzip compression

### Phase 3: Operations (6-8h)
- Retention job + secure delete
- Error surfacing (Settings + App Health)
- PII audit
- Minimize toggles
- Documentation

---

**Status:** ⚠️ **SIGNIFICANT REWORK REQUIRED**  
**Action:** Implement Phase 1 blockers before marking Items 61-63 complete  
**ETA:** +2-3 weeks for production-ready implementation

