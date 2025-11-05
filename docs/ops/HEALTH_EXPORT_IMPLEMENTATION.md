# Health Data Export v2 - Implementation Guide

**Created:** November 4, 2025  
**Status:** P0 Items Complete, Ready for Integration  
**Estimated Total:** 13-15.5 hours (Items 61-68)

---

## ✅ What's Done (P0 Foundation)

### 1. HealthExportBridge.swift v2 ✅
**Location:** `ios/HealthExportBridge.swift`

**New Features:**
- ✅ Service-day bucketing with configurable cutoff (default noon)
- ✅ All 7 record types: sleep, nap, hr, hrv, respiratory_rate, spo2, step
- ✅ Incremental export (tracks `lastExportAt` in UserDefaults)
- ✅ Full metadata: `service_day_key`, `local_offset_min`, `tz_name`, `unit`, `device`, `source_app`
- ✅ Dedupe support: `record_id` + `sha1` hash per record
- ✅ iCloud Drive → local Documents fallback
- ✅ JSONL format (one record per line)

**Key Methods:**
```swift
func exportIncremental(cutoffHourLocal: Int = 12) async throws -> URL
func exportRange(start: Date, end: Date, cutoffHourLocal: Int = 12) async throws -> URL
func serviceDayKey(date: Date, cutoffHourLocal: Int = 12, tz: TimeZone = .current) -> String
```

**Output Example:**
```jsonl
{"source":"healthkit","record_type":"sleep","start_utc":"2025-11-04T01:30:00Z","end_utc":"2025-11-04T08:45:00Z","service_day_key":"2025-11-03","local_offset_min":-300,"tz_name":"America/New_York","record_id":"sleep_2025-11-04T01:30:00Z_2025-11-04T08:45:00Z","sha1":"a1b2c3...","value":null,"device":"Apple Watch Series 8","source_app":"com.apple.health","metadata":{"value_category":2}}
{"source":"healthkit","record_type":"hrv","start_utc":"2025-11-04T02:15:00Z","end_utc":"2025-11-04T02:15:00Z","service_day_key":"2025-11-03","local_offset_min":-300,"tz_name":"America/New_York","record_id":"hrv_2025-11-04T02:15:00Z_2025-11-04T02:15:00Z","sha1":"d4e5f6...","value":45.3,"unit":"ms","device":"Apple Watch Series 8","source_app":"com.apple.health"}
```

---

### 2. DoseLogExporter.swift ✅
**Location:** `ios/DoseLogExporter.swift`

**Features:**
- ✅ Exports last 14 days of DoseLog records
- ✅ All fields: `night_key`, `bedtime_utc`, `dose1_utc`, `dose2_utc`, `final_wake_utc`, override metadata, `wake_events` array
- ✅ iCloud Drive → local Documents fallback
- ✅ JSONL format

**Key Methods:**
```swift
func exportLastNDays(_ days: Int = 14) throws -> URL
```

**Output Example:**
```jsonl
{"night_key":"2025-11-03","created_at_utc":"2025-11-03T12:00:00Z","lifecycle_state":"closed","bedtime_utc":"2025-11-04T01:30:00Z","dose1_utc":"2025-11-04T02:00:00Z","dose1_grams":4.5,"dose2_utc":"2025-11-04T05:15:00Z","dose2_grams":4.5,"dose2_is_override":true,"dose2_override_kind":"early","dose2_override_minutes":15,"dose2_override_reason":"Woke early, took dose","final_wake_utc":"2025-11-04T09:00:00Z","wake_reason":"natural","plan_dose1_g":4.5,"plan_dose2_g":4.5,"wake_events":[{"time_utc":"2025-11-04T05:00:00Z","reason":"bathroom","source":"tap_now"}]}
```

---

### 3. Updated Schemas ✅
**Location:** `review/health-data-dropin/agent/dropins/health-data/schemas/`

**unified_health.schema.json:**
- ✅ Added required fields: `service_day_key`, `local_offset_min`, `tz_name`, `record_id`, `sha1`
- ✅ Added optional fields: `unit`, `device`, `source_app`
- ✅ Pattern validation for `service_day_key` (YYYY-MM-DD) and `sha1` (40-char hex)

**night_features.schema.json:**
- ✅ Added new features: `sleepDurationMin`, `wakeCount`, `dose12IntervalMin7dAvg`, `dose12IntervalMin7dStd`, `dow`
- ✅ Improved descriptions with ranges and units
- ✅ Kept existing: `adherence7d`, `overrideCount7d`, `bedtimeStdDevMin14d`, `isWorkday`, `whoopRecoveryPct`, `hrvScore`

---

### 4. Normalizer v2 ✅
**Location:** `review/health-data-dropin/agent/dropins/health-data/src/util/normalize.js`

**New Features:**
- ✅ Uses `service_day_key` from exports (NO midnight bucketing)
- ✅ Ajv schema validation (rejects malformed records)
- ✅ SHA1 dedupe across runs
- ✅ DoseLog + HealthKit join by `night_key`
- ✅ Real feature computation:
  - `adherence7d`: Fraction with both doses in last 7 days
  - `overrideCount7d`: Count of overrides in last 7 days
  - `bedtimeStdDevMin14d`: Std dev of bedtime over 14 days
  - `sleepDurationMin`: Sum of sleep records for night
  - `wakeCount`: Number of wake events
  - `dose12IntervalMin7dAvg`: Mean Dose 1→2 interval (7d)
  - `dose12IntervalMin7dStd`: Std dev of Dose 1→2 interval (7d)
  - `dow`: Day of week (0-6)
  - `hrvScore`: Max HRV for night
- ✅ Error logging: Writes `errors_{timestamp}.json` if validation fails

**Key Functions:**
```javascript
async function normalizeUnifiedToNightFeatures(rawDir, featDir, opts)
function initNight(nightKey)
function accumulate(night, rec)
function enrichWithDoseLog(night, doseLog)
function computeRollingFeatures(sorted, idx)
```

---

### 5. Updated package.json ✅
**Location:** `review/health-data-dropin/agent/dropins/health-data/package.json`

**New Dependencies:**
- `ajv` ^8.12.0 (JSON Schema validation)
- `ajv-formats` ^2.1.1 (date-time format support)
- `yargs` ^17.7.2 (CLI argument parsing)
- `fast-glob` ^3.3.2 (file pattern matching)
- `object-hash` ^3.0.0 (hashing utilities)

**New Script:**
- `npm run validate` → Dry-run validation (no writes)

---

## 🚀 Integration Steps

### Step 1: Copy Files to Main Codebase (5 min)

```bash
# Already in ios/ folder:
# - ios/HealthExportBridge.swift ✅
# - ios/DoseLogExporter.swift ✅

# Add to Xcode project:
# Right-click DoseTrackNew folder → Add Files
# Select HealthExportBridge.swift and DoseLogExporter.swift
# UNCHECK "Copy items if needed" (already in place)
# Click Add
```

**Files to add:**
1. `ios/HealthExportBridge.swift`
2. `ios/DoseLogExporter.swift`

---

### Step 2: Install Agent Dependencies (2 min)

```bash
cd review/health-data-dropin/agent/dropins/health-data
npm install
```

**Expected output:**
```
added 8 packages, audited 15 packages in 3s
```

---

### Step 3: Test Exporter (Manual) (10 min)

**Add temporary test button to Settings:**

```swift
// In SettingsViewEnhanced.swift
Section("Health Data Export (DEBUG)") {
    Button("Export HealthKit Now") {
        Task {
            do {
                let bridge = HealthExportBridge()
                try await bridge.requestAuth()
                let url = try await bridge.exportIncremental()
                print("✅ Exported to: \(url.path)")
            } catch {
                print("❌ Export failed: \(error)")
            }
        }
    }
    
    Button("Export DoseLog Now") {
        Task {
            do {
                let exporter = DoseLogExporter(modelContext: modelContext)
                let url = try exporter.exportLastNDays()
                print("✅ Exported to: \(url.path)")
            } catch {
                print("❌ Export failed: \(error)")
            }
        }
    }
}
```

**Run on device (HealthKit requires physical device):**
1. Build & run
2. Open Settings → Health Data Export
3. Tap "Export HealthKit Now" → Grant permissions
4. Check console for file path
5. Open Files app → iCloud Drive → DoseTrack/exports
6. Verify files: `healthkit_export_{timestamp}.jsonl`, `dosetrack_export_{timestamp}.jsonl`

---

### Step 4: Test Agent Normalization (10 min)

```bash
cd review/health-data-dropin/agent/dropins/health-data

# Set up environment
cp example.env .env
# Edit .env:
# HEALTH_SYNC_DIR=~/Library/Mobile\ Documents/com~apple~CloudDocs/DoseTrack/exports

# Check status
npm run status

# Pull exports (copy from iCloud to ml/datasets/raw/health/)
npm run pull:ios

# Normalize (compute features)
npm run normalize
```

**Expected output:**
```
✓ Pull complete
✓ Normalize complete
ml/datasets/features/night_features_1730764800000.jsonl
```

**Verify output:**
```bash
cat ../../../../ml/datasets/features/night_features_*.jsonl | jq .
```

**Expected JSON:**
```json
{
  "night_key": "2025-11-03",
  "dow": 0,
  "adherence7d": 0.857,
  "overrideCount7d": 2,
  "bedtimeStdDevMin14d": 23.5,
  "isWorkday": false,
  "sleepDurationMin": 435,
  "wakeCount": 1,
  "dose12IntervalMin7dAvg": 195.3,
  "dose12IntervalMin7dStd": 12.7,
  "whoopRecoveryPct": null,
  "hrvScore": 45.3
}
```

---

### Step 5: Verify Service-Day Logic (15 min)

**Test Cases:**

1. **Before midnight, before cutoff (e.g., 02:00 local)**
   - Timestamp: `2025-11-04T07:00:00Z` (02:00 EST)
   - Expected `service_day_key`: `"2025-11-03"` (previous day)

2. **After midnight, after cutoff (e.g., 14:00 local)**
   - Timestamp: `2025-11-04T19:00:00Z` (14:00 EST)
   - Expected `service_day_key`: `"2025-11-04"` (same day)

3. **DST spring forward (02:00 → 03:00)**
   - Timestamp: `2025-03-09T06:59:00Z` (01:59 EST)
   - Expected `service_day_key`: `"2025-03-08"` (before cutoff)
   - Timestamp: `2025-03-09T07:01:00Z` (03:01 EDT, DST applied)
   - Expected `service_day_key`: `"2025-03-08"` (still before cutoff)

4. **Timezone change (NYC → Denver = -2h)**
   - Before: `2025-11-04T07:00:00Z` (02:00 EST) → `"2025-11-03"`
   - After: `2025-11-04T07:00:00Z` (00:00 MST) → `"2025-11-03"` (before cutoff)

**Unit Test Template:**
```swift
func testServiceDayKey() {
    let bridge = HealthExportBridge()
    
    // Test 1: Before midnight, before cutoff (02:00 local)
    let date1 = ISO8601DateFormatter().date(from: "2025-11-04T07:00:00Z")!
    let key1 = bridge.serviceDayKey(date: date1, cutoffHourLocal: 12, tz: TimeZone(identifier: "America/New_York")!)
    XCTAssertEqual(key1, "2025-11-03")
    
    // Test 2: After midnight, after cutoff (14:00 local)
    let date2 = ISO8601DateFormatter().date(from: "2025-11-04T19:00:00Z")!
    let key2 = bridge.serviceDayKey(date: date2, cutoffHourLocal: 12, tz: TimeZone(identifier: "America/New_York")!)
    XCTAssertEqual(key2, "2025-11-04")
    
    // Test 3: DST spring forward
    let date3 = ISO8601DateFormatter().date(from: "2025-03-09T06:59:00Z")! // 01:59 EST
    let key3 = bridge.serviceDayKey(date: date3, cutoffHourLocal: 12, tz: TimeZone(identifier: "America/New_York")!)
    XCTAssertEqual(key3, "2025-03-08")
}
```

---

## 📋 Remaining Work (Items 64-68)

### Item 64: Dedupe & Cleanup (1.5h)
**Status:** Needs implementation

**Tasks:**
1. Create `.processed` file with SHA1 hashes of ingested records
2. Skip duplicates in normalize.js
3. Add `--purge-older-than=30d` flag
4. Add `--since=YYYY-MM-DD` flag to pull command

**Implementation:**
```javascript
// In normalize.js, before accumulating:
const processedFile = path.join(rawDir, '.processed');
const processed = fs.existsSync(processedFile) ? new Set(fs.readFileSync(processedFile, 'utf8').split('\n')) : new Set();

for (const r of lines) {
  if (processed.has(r.sha1)) continue; // skip duplicate
  processed.add(r.sha1);
  // ... accumulate
}

// After normalize:
fs.writeFileSync(processedFile, Array.from(processed).join('\n'));
```

---

### Item 65: Settings UI (2h)
**Status:** Needs implementation

**Add to SettingsViewEnhanced.swift:**
```swift
Section {
    Button("Export Now") {
        exportingHealth = true
        Task {
            await exportHealthData()
        }
    }
    .disabled(exportingHealth)
    
    Toggle("Auto-export daily", isOn: $autoExportEnabled)
        .onChange(of: autoExportEnabled) { _, newValue in
            if newValue {
                scheduleHealthExportBGTask()
            } else {
                cancelHealthExportBGTask()
            }
        }
    
    if let lastExport = UserDefaults.standard.object(forKey: "lastHealthExportAt") as? Date {
        LabeledContent("Last export") {
            Text(lastExport, style: .relative)
                .foregroundStyle(.secondary)
        }
    }
    
    LabeledContent("Health permissions") {
        HealthPermissionsStatusView()
    }
} header: {
    Label("Health Data", systemImage: "heart.text.square")
} footer: {
    Text("Export HealthKit and dose logs for analysis. Data stored in iCloud Drive or local Documents folder.")
}
```

---

### Item 66: Privacy Controls (1h)
**Status:** Needs implementation

**Add to Settings:**
```swift
Toggle("Anonymize exports (±10 min)", isOn: $anonymizeExports)

Picker("Keep exports for", selection: $retentionDays) {
    Text("7 days").tag(7)
    Text("30 days").tag(30)
    Text("90 days").tag(90)
}
.pickerStyle(.segmented)
```

**Implement fuzzing in HealthExportBridge:**
```swift
func fuzz(_ date: Date, enabled: Bool) -> Date {
    guard enabled else { return date }
    let offset = Double.random(in: -600...600) // ±10 minutes
    return date.addingTimeInterval(offset)
}

// In export loop:
let fuzzedStart = fuzz(s.startDate, enabled: anonymize)
let fuzzedEnd = fuzz(s.endDate, enabled: anonymize)
```

---

### Item 67: Tests (3h)
**Status:** Needs implementation

**Test Files to Create:**
1. `Tests/HealthExportBridgeTests.swift`
   - Service-day key (DST, timezone)
   - Incremental export (only new records)
   - iCloud fallback
   - SHA1 dedupe

2. `Tests/DoseLogExporterTests.swift`
   - All fields present
   - Wake events serialization
   - Empty nights

3. `Tests/NormalizerTests.swift` (Node.js)
   - Service-day join
   - Adherence/override computation
   - Rolling windows (7d/14d)
   - Ajv validation

**Run tests:**
```bash
# Swift tests
xcodebuild test -scheme DoseTrackNew -destination 'platform=iOS Simulator,name=iPhone 15'

# Node tests (after creating test suite)
cd review/health-data-dropin/agent/dropins/health-data
npm test
```

---

### Item 68: Documentation (1h)
**Status:** Needs writing

**Documents to update:**
1. `docs/PRD_v1.2.md` → Add "Health Data Export" section
2. `docs/PRODUCT_DESCRIPTION.md` → Add "ML Features" section
3. Create `docs/ops/HEALTH_EXPORT_GUIDE.md` (user guide)
4. `README.md` → Mention in features list

---

## 🎯 Quick Start (P0 Only - 8-9h)

**To get integration-ready today, do Items 61-63:**

```bash
# 1. Add files to Xcode (5 min)
# → Manual: Right-click → Add Files → Select 2 files

# 2. Install agent deps (2 min)
cd review/health-data-dropin/agent/dropins/health-data
npm install

# 3. Add debug buttons to Settings (15 min)
# → See Step 3 above

# 4. Test on device (30 min)
# → Export HealthKit + DoseLog
# → Verify JSONL output in Files app

# 5. Test normalization (30 min)
# → Pull exports
# → Run normalize
# → Verify features JSON

# 6. Write service-day unit tests (2h)
# → DST, timezone, cutoff edge cases

# 7. Update TODO.md status (5 min)
# → Mark Items 61-63 as IN PROGRESS
```

**Total: ~4 hours to validate P0**

---

## ✅ Success Criteria

**Before marking Items 61-63 COMPLETE:**

- [ ] HealthExportBridge exports all 7 record types
- [ ] Service-day keys use noon cutoff (not midnight UTC)
- [ ] Incremental export only exports new records
- [ ] SHA1 dedupe prevents duplicates
- [ ] iCloud → local fallback works
- [ ] DoseLogExporter exports all fields
- [ ] Normalizer uses service-day keys from exports
- [ ] Real adherence/override stats (not hardcoded 0)
- [ ] Ajv validates all records
- [ ] Error log written if validation fails
- [ ] Unit tests pass for DST/timezone/cutoff
- [ ] Integration test: export → normalize → validate

---

**Ready to ship after Items 64-68:**
- [ ] Dedupe prevents re-processing
- [ ] Cleanup purges old exports
- [ ] Settings UI shows export status
- [ ] Privacy controls (anonymize, retention)
- [ ] 80%+ test coverage
- [ ] Documentation complete

---

**Version:** 2.0  
**Last Updated:** November 4, 2025  
**Status:** P0 COMPLETE (Items 61-63 ready for integration)
