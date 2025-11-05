# Health Data Drop-in Review

**Reviewed:** November 4, 2025  
**Version:** 0.1.0  
**Location:** `review/health-data-dropin/`  
**Status:** ⚠️ Prototype - Needs Integration Planning

---

## 📋 Executive Summary

The health-data-dropin is a **multi-platform health data ingestion system** designed to:
- Export HealthKit data from iOS to JSON
- Pull Android Health Connect data  
- Parse Apple Health XML exports
- Normalize all sources into unified JSONL format
- Generate night-level features for ML pipelines

**Architecture:**
```
iOS App (HealthExportBridge.swift)
    ↓ Exports to iCloud Drive
Node.js Agent (ingest.js)
    ↓ Pulls & normalizes
Unified JSONL → Night Features
    ↓ Feeds into
ML/Analytics Pipeline
```

---

## 🏗️ Architecture Overview

### Components

```
health-data-dropin/
├── ios/App/Bridges/
│   └── HealthExportBridge.swift     # iOS HealthKit → JSON exporter
│
├── android/app/                      # (Android Health Connect bridge - not reviewed)
│
└── agent/dropins/health-data/
    ├── src/
    │   ├── ingest.js                # Main CLI orchestrator
    │   ├── sources/
    │   │   ├── healthkit_json.js    # Pulls iOS exports
    │   │   ├── healthconnect_json.js # Pulls Android exports
    │   │   └── apple_health_xml.js  # Parses Apple Health XML
    │   └── util/
    │       └── normalize.js         # Converts to night features
    │
    ├── schemas/
    │   ├── unified_health.schema.json   # Normalized record schema
    │   └── night_features.schema.json   # ML feature schema
    │
    ├── agent.dropin.yaml            # Agent integration config
    ├── package.json                 # Node.js dependencies
    └── README.md                    # Documentation
```

---

## 🔍 Detailed Component Review

### 1. iOS Bridge: `HealthExportBridge.swift`

**Purpose:** Export HealthKit data to iCloud Drive for agent ingestion

**Capabilities:**
- ✅ Sleep analysis (HKCategoryType)
- ✅ Heart rate (count/min)
- ✅ Heart rate variability (SDNN in ms)
- ✅ Respiratory rate (breaths/min)

**Data Flow:**
```swift
1. requestAuth() → Request HealthKit read permissions
2. exportLastNDays(14) → Query last 14 days of data
3. Convert to JSON lines (one object per line)
4. Write to: iCloud Drive/Documents/DoseTrack/exports/healthkit_export_{timestamp}.json
```

**Output Format:**
```json
{"source":"healthkit","record_type":"sleep","start_utc":"2025-11-04T01:30:00Z","end_utc":"2025-11-04T08:45:00Z","value":null,"metadata":{}}
{"source":"healthkit","record_type":"hr","start_utc":"2025-11-04T02:15:00Z","end_utc":"2025-11-04T02:15:00Z","value":62,"metadata":{}}
{"source":"healthkit","record_type":"hrv","start_utc":"2025-11-04T02:15:00Z","end_utc":"2025-11-04T02:15:00Z","value":45.3,"metadata":{}}
```

**Strengths:**
- ✅ Uses async/await for cleaner code
- ✅ Writes to iCloud Drive (auto-syncs across devices)
- ✅ ISO8601 timestamps (UTC)
- ✅ JSONL format (one record per line, easy to stream)

**Concerns:**
- ⚠️ **No error handling** for iCloud unavailability (throws generic NSError)
- ⚠️ **No deduplication** - Re-running creates duplicate exports
- ⚠️ **No cleanup** - Old exports accumulate in iCloud Drive
- ⚠️ **Missing key metrics**: SpO2, step count, naps (defined in schema but not exported)
- ⚠️ **No metadata** - Always empty `{}` (could include device, source app)
- ⚠️ **Hardcoded 14 days** - No configuration option
- ⚠️ **No progress callback** - Silent operation (could take seconds)

**Privacy Implications:**
- ✅ Local-only (iCloud Drive is user-controlled)
- ✅ No network calls
- ⚠️ Exports persist in iCloud indefinitely (no expiry)

---

### 2. Node.js Agent: `ingest.js`

**Purpose:** CLI orchestrator for pulling and normalizing health data

**Commands:**
```bash
npm run status                    # Show env vars
npm run pull:ios                  # Copy from iCloud Drive
npm run pull:android              # Copy from Android sync folder
npm run ingest:apple-xml --file=  # Parse Apple Health XML export
npm run normalize                 # Generate night features
```

**Data Flow:**
```
1. Pull: Copy JSON exports from sync folders → ml/datasets/raw/health/
2. Normalize: Parse all JSONs → Aggregate by night → ml/datasets/features/night_features_{timestamp}.jsonl
```

**Strengths:**
- ✅ Simple CLI interface
- ✅ Modular source adapters (healthkit_json, healthconnect_json, apple_health_xml)
- ✅ Dotenv config (`.env` file)
- ✅ Creates output directories automatically

**Concerns:**
- ⚠️ **Minimal error handling** - Crashes on missing env vars
- ⚠️ **No validation** - Doesn't check JSON schema compliance
- ⚠️ **No deduplication** - Processes all files, even already-ingested
- ⚠️ **Naive night bucketing** - Uses midnight UTC instead of DoseTrack's noon cutoff
- ⚠️ **Stub normalization** - `normalize.js` is placeholder (only extracts HRV, ignores most data)

---

### 3. Normalization Logic: `normalize.js`

**Purpose:** Convert unified health records → night-level features for ML

**Current Implementation:**
```javascript
// Groups records by ISO date (midnight UTC)
const nightKey = d.toISOString().slice(0,10); // "2025-11-04"

// Only extracts HRV score
if (r.record_type === "hrv" && typeof r.value === "number") 
    perNight[nightKey].hrvScore = r.value;

// All other features hardcoded to 0/null/false:
{ 
    adherence7d: 0, 
    overrideCount7d: 0, 
    bedtimeStdDevMin14d: 0, 
    isWorkday: false,
    whoopRecoveryPct: null,
    hrvScore: r.value  // Only this is real
}
```

**Critical Issues:**
- ❌ **Hardcoded zeros** - adherence7d, overrideCount7d, bedtimeStdDevMin should come from DoseLog data
- ❌ **Wrong cutoff** - Uses midnight UTC, not DoseTrack's noon cutoff (violates Constitution Principle III)
- ❌ **Missing features** - Sleep duration, HR avg/variability, respiratory rate not computed
- ❌ **No workday logic** - isWorkday always false (needs WeeklySchedule integration)
- ❌ **No WHOOP integration** - whoopRecoveryPct always null (needs server proxy)

**Expected Output (per schema):**
```json
{
  "night_key": "2025-11-04",
  "adherence7d": 0.857,           // Should be: 6/7 nights with both doses
  "overrideCount7d": 2,           // Should be: Count from DoseLog.dose2IsOverride
  "bedtimeStdDevMin14d": 23.5,    // Should be: Std dev of bedtimeUTC over 14 days
  "isWorkday": true,              // Should be: WeeklySchedule.isDayScheduled(monday)
  "whoopRecoveryPct": 67,         // Should be: WHOOP API daily recovery
  "hrvScore": 45.3                // ✅ Currently extracted from HealthKit
}
```

---

### 4. Schemas

#### `unified_health.schema.json`

**Purpose:** Standardized format for all health sources

```json
{
  "source": "healthkit" | "healthconnect" | "apple_xml",
  "record_type": "sleep" | "hr" | "hrv" | "respiratory_rate" | "spo2" | "step" | "nap",
  "start_utc": "ISO8601",
  "end_utc": "ISO8601",
  "value": number | null,
  "metadata": {}
}
```

**Strengths:**
- ✅ Simple, flat structure
- ✅ Supports multiple sources
- ✅ Extensible record types
- ✅ UTC timestamps (no timezone ambiguity)

**Concerns:**
- ⚠️ `metadata` is schema-less (no validation)
- ⚠️ No `device_id` or `source_app` fields (could help with deduplication)
- ⚠️ No `unit` field (assumes standard units, could cause confusion)

#### `night_features.schema.json`

**Purpose:** Aggregated features for ML models

```json
{
  "night_key": "YYYY-MM-DD",
  "adherence7d": 0.0-1.0,
  "overrideCount7d": integer,
  "bedtimeStdDevMin14d": number,
  "isWorkday": boolean,
  "whoopRecoveryPct": number | null,
  "hrvScore": number | null
}
```

**Strengths:**
- ✅ Relevant features for dose timing ML
- ✅ Nullable optional fields (WHOOP, HRV)

**Missing Features:**
- ⚠️ No sleep duration (critical for GHB efficacy)
- ⚠️ No wake count (bathroom trips, arousals)
- ⚠️ No Dose 1→2 interval stats (avg, stddev)
- ⚠️ No override reasons (could train NLP model)
- ⚠️ No day-of-week encoding (cyclical features)

---

## 🔗 Integration with DoseTrack

### Current State: **NOT INTEGRATED**

This is a **standalone prototype** with no integration into the main DoseTrack codebase.

### Integration Gaps:

#### 1. HealthExportBridge.swift
**Location:** `review/health-data-dropin/ios/App/Bridges/`  
**Status:** ❌ Not in main codebase  
**Required Actions:**
- Copy to `ios/HealthExportBridge.swift`
- Add to Xcode project (DoseTrackNew)
- Wire to Settings UI (new "Export Health Data" button)
- Add `NSHealthShareUsageDescription` to Info.plist
- Test on device (HealthKit requires physical device)

#### 2. Night Features Schema
**Status:** ❌ No DoseLog integration  
**Required Actions:**
- Add `adherence7d`, `overrideCount7d`, `bedtimeStdDevMin14d` computed properties to DoseLog
- Integrate with WeeklySchedule for `isWorkday`
- Implement `calculateNightFeatures()` in DoseLogController

#### 3. Normalization Logic
**Status:** ❌ Uses wrong cutoff (midnight UTC vs. noon)  
**Required Actions:**
- Replace `normalize.js` with DoseTrack-aware version
- Use NightServiceDay.cutoffHourLocal (default 12)
- Query SwiftData database for adherence/override stats
- Pull WeeklySchedule for workday detection

#### 4. WHOOP Integration
**Status:** ❌ Not implemented  
**Required Actions:**
- Implement WHOOP OAuth proxy (Item 29 in TODO.md)
- Add `WhoopManager.swift` to fetch daily recovery
- Store in new `WhoopData` SwiftData model
- Expose via `night_features.whoopRecoveryPct`

---

## 💡 Recommendations

### High Priority (Required for Production)

1. **Fix Night Bucketing (CRITICAL)**
   - ❌ Current: Midnight UTC
   - ✅ Required: Noon cutoff (NightServiceDay logic)
   - **Action:** Rewrite `normalize.js` to use DoseTrack's cutoff logic

2. **Integrate DoseLog Metrics**
   - ❌ Current: Hardcoded zeros
   - ✅ Required: Real adherence, override stats from SwiftData
   - **Action:** Add SwiftData query layer to Node.js agent (or move to Swift CLI)

3. **Complete HealthExportBridge**
   - ❌ Missing: SpO2, steps, naps
   - ✅ Required: All schema-defined record types
   - **Action:** Add missing HKQuantityType queries

4. **Add Deduplication**
   - ❌ Current: Re-exports duplicate records
   - ✅ Required: Track last export timestamp, only new data
   - **Action:** Store `lastExportDate` in AppPreferences, use as query `start`

### Medium Priority (Quality Improvements)

5. **Error Handling**
   - Add try/catch in all async functions
   - Graceful degradation if iCloud unavailable (fallback to local Files app)
   - User-facing error messages

6. **Settings UI**
   - New section: "Health Data Export"
   - Toggle: "Auto-export to iCloud" (daily BG task)
   - Button: "Export Now" (manual trigger)
   - Label: "Last export: [timestamp]"

7. **Schema Validation**
   - Add `ajv` (JSON Schema validator) to agent
   - Validate all records before ingestion
   - Log invalid records to error file

8. **Cleanup Policy**
   - Auto-delete exports older than 30 days from iCloud
   - Or: Move to "Archive" folder after ingestion

### Low Priority (Future Enhancements)

9. **Additional Metrics**
   - Sleep stages (deep, REM, light)
   - Resting HR (morning baseline)
   - HR during Dose 2 window (arousal detection)
   - Step count (activity level correlation)

10. **ML Features**
    - Dose 1→2 interval stats (7d avg, stddev)
    - Time-to-wake after Dose 2 (consistency metric)
    - Weekend vs. weekday patterns
    - Override reason NLP embeddings

11. **Agent CLI Improvements**
    - `--since=YYYY-MM-DD` flag for incremental pulls
    - `--validate` flag to dry-run schema checks
    - `--output=csv` for Excel-friendly exports

---

## 🚧 Blockers & Dependencies

### Technical Blockers

1. **Node.js → Swift Data Access**
   - Current agent is Node.js, but DoseLog is SwiftData
   - **Options:**
     - A) Export DoseLog to JSON (new CSVExporter variant)
     - B) Rewrite agent in Swift (use swift-argument-parser)
     - C) Use App Group shared container + SQLite direct access

2. **iCloud Drive Sync**
   - HealthExportBridge assumes iCloud enabled
   - Some users may disable iCloud
   - **Mitigation:** Fallback to local Documents folder + manual AirDrop

3. **HealthKit Permissions**
   - Requires user authorization
   - Denied permissions → silent failure
   - **Mitigation:** Check authorization status, prompt in Settings UI

### Dependency Chain (TODO.md Items)

- **Item 29**: WHOOP OAuth Proxy (required for `whoopRecoveryPct`)
- **Item 41**: ClockProvider & Time Abstractions (needed for accurate night bucketing)
- **Item 45**: App Health Panel (show last export timestamp)
- **Item 53**: CI/CD (validate JSON schemas in tests)

---

## 🎯 Integration Roadmap

### Phase 1: Core Export (2-3 hours)
1. Copy `HealthExportBridge.swift` to `ios/`
2. Add to Xcode project
3. Wire to Settings UI ("Export Health Data" button)
4. Test on device (requires HealthKit entitlement)
5. Verify JSON output in iCloud Drive

### Phase 2: DoseLog Integration (3-4 hours)
1. Create `DoseLogExporter.swift`
   - Export last 14 days to `dosetrack_export_{timestamp}.json`
   - Include: nightKey, doses, overrides, bedtime, wake
2. Update `normalize.js`:
   - Parse dosetrack_export files
   - Calculate adherence7d, overrideCount7d
   - Use noon cutoff for night bucketing
3. Add WeeklySchedule → `isWorkday` lookup

### Phase 3: Night Features Model (2-3 hours)
1. Create SwiftData model: `NightFeatures`
   - Properties match schema
   - One-to-one with DoseLog (nightKey FK)
2. Add computed property: `DoseLog.features`
3. Populate after each night closes
4. Expose in CSV export

### Phase 4: WHOOP Integration (4-6 hours)
- **Depends on Item 29** (WHOOP OAuth Proxy)
- Add `WhoopManager.swift`
- Fetch daily recovery on BG task
- Merge into `NightFeatures`

### Phase 5: Agent Polish (2-3 hours)
- Add schema validation (ajv)
- Deduplication (track last export)
- Auto-cleanup (delete old exports)
- Better error messages

**Total Estimate:** 13-19 hours (2-3 days)

---

## ✅ Acceptance Criteria

**Before merging to main codebase:**

- [ ] HealthExportBridge exports all 7 record types (sleep, hr, hrv, respiratory, spo2, step, nap)
- [ ] Exports only new data since last export (no duplicates)
- [ ] DoseLogExporter generates dosetrack_export_{timestamp}.json with all events
- [ ] normalize.js uses noon cutoff (not midnight UTC)
- [ ] Night features include real adherence/override stats (not hardcoded 0)
- [ ] isWorkday correctly reflects WeeklySchedule
- [ ] Settings UI shows "Export Health Data" button
- [ ] Settings UI shows "Last export: [timestamp]"
- [ ] Export works without iCloud (fallback to local Documents)
- [ ] Unit tests for normalization logic
- [ ] Documentation updated (PRODUCT_DESCRIPTION.md, PRD_v1.2.md)
- [ ] WHOOP integration (if Item 29 complete)

---

## 📊 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Wrong night bucketing** | HIGH ✅ | CRITICAL | Already identified, rewrite normalize.js |
| **Missing adherence data** | HIGH ✅ | HIGH | Export DoseLog to JSON, parse in agent |
| **iCloud unavailable** | MEDIUM | MEDIUM | Fallback to local Documents folder |
| **HealthKit denied** | MEDIUM | LOW | Check status, show explanation in Settings |
| **Performance (14d export)** | LOW | LOW | Profile with Instruments, optimize queries |
| **Node.js → Swift gap** | MEDIUM | MEDIUM | Consider Swift rewrite or JSON bridge |

---

## 🔐 Privacy & Security Review

### Strengths ✅
- Local-only processing (no network calls in bridge)
- User-controlled iCloud storage
- HealthKit authorization required
- JSONL format (easy to audit, no binary blobs)

### Concerns ⚠️
- iCloud exports persist indefinitely (no auto-expiry)
- Metadata field is schema-less (could leak PII)
- No anonymization option (e.g., timestamp fuzzing)
- Agent README mentions `--fuzz-min=10` but not implemented

### Recommendations
1. Add "Auto-delete exports after 30 days" toggle in Settings
2. Add "Anonymize exports" toggle (fuzz timestamps ±10min, strip metadata)
3. Document in Privacy Policy: "Health data exported to your iCloud Drive"
4. Add NSHealthUpdateUsageDescription (currently only has read permission)

---

## 📝 Documentation Gaps

**Missing from README.md:**
- Integration with DoseTrack (currently describes standalone use)
- Noon cutoff logic (critical for DoseTrack compatibility)
- Privacy implications (iCloud storage, data retention)
- Troubleshooting (iCloud disabled, HealthKit denied)

**Missing from PRD_v1.2.md:**
- Health data export feature (not in requirements)
- Night features schema (not in data model)
- WHOOP integration (mentioned in TODO but not PRD)

**Action:** Update PRODUCT_DESCRIPTION.md with "Health Data Export" section after Phase 1 complete.

---

## 🎓 Learning & Insights

### Good Patterns to Adopt
1. **JSONL format** - One record per line, easy to stream/append
2. **Unified schema** - Single format for multiple sources (HealthKit, Health Connect, XML)
3. **Agent drop-in architecture** - Modular, plugin-style ingestion
4. **JSON Schema validation** - Self-documenting data contracts

### Anti-Patterns to Avoid
1. **Hardcoded values** - adherence7d: 0 defeats the purpose
2. **Silent failures** - Missing error handling in async code
3. **Naive bucketing** - Midnight UTC vs. noon cutoff (breaks DoseTrack logic)
4. **No deduplication** - Re-exporting same data wastes space

### Architectural Questions
1. **Should the agent be Node.js or Swift?**
   - Pro Node: Cross-platform, easier to parse XML
   - Pro Swift: Direct SwiftData access, single codebase
   - **Recommendation:** Start with Node (working code), migrate to Swift in v2.0

2. **Where should features be computed?**
   - Option A: In agent (normalize.js) → JSONL → Import to SwiftData
   - Option B: In Swift (DoseLogController) → Computed properties
   - **Recommendation:** Option B (single source of truth, no sync lag)

3. **How to handle WHOOP data?**
   - Currently: Fetch in agent (Node.js WHOOP proxy)
   - Alternative: Fetch in Swift (WhoopManager), store in SwiftData
   - **Recommendation:** Fetch in Swift (better error handling, notification integration)

---

## 🚀 Next Steps

**Immediate (This Week):**
1. Create TODO item: "Item 61: Health Data Export Integration"
2. Estimate: 13-19 hours (Phase 1-3)
3. Dependencies: Item 41 (ClockProvider), Item 29 (WHOOP - optional)
4. Priority: MEDIUM (nice-to-have for v1.2, required for ML features)

**Short-Term (Next Sprint):**
1. Implement Phase 1 (Core Export)
2. Test on device with HealthKit
3. Update Settings UI
4. Document in PRODUCT_DESCRIPTION.md

**Long-Term (v1.3+):**
1. WHOOP integration (Item 29)
2. ML model training (predict optimal Dose 2 time)
3. Adaptive window recommendations
4. Sleep quality correlation analysis

---

## 📌 Summary

**Verdict:** ⚠️ **Prototype with High Potential, Requires Integration Work**

**Strengths:**
- ✅ Clean architecture (bridge → agent → features)
- ✅ Cross-platform support (iOS, Android, XML)
- ✅ Privacy-first (local processing)
- ✅ Extensible schemas

**Critical Issues:**
- ❌ Wrong night bucketing (midnight vs. noon)
- ❌ Hardcoded feature values (defeats ML purpose)
- ❌ No DoseLog integration (missing adherence/override data)
- ❌ Incomplete HealthKit export (missing SpO2, steps, naps)

**Recommendation:**
- **Phase 1** (Core Export): Integrate now (2-3h, low risk, high value for debugging)
- **Phase 2-3** (Features): After Item 41 (ClockProvider) complete (3-7h)
- **Phase 4** (WHOOP): After Item 29 (OAuth Proxy) complete (4-6h)
- **Total:** 9-16 hours spread across 3 sprints

**Priority:** MEDIUM (not blocking v1.2 ship, but valuable for power users & future ML)

---

**Reviewed by:** AI Agent (GitHub Copilot)  
**Next Review:** After Phase 1 integration (HealthExportBridge in Settings UI)  
**Related Documents:**
- `docs/PRD_v1.2.md` - Update with Health Export feature
- `docs/ops/TODO.md` - Add Item 61
- `docs/PRODUCT_DESCRIPTION.md` - Add "Health Data Export" section
