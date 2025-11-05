# REQUEST FOR EVIDENCE (RFE) — Health Export v2 & ML Update

**Owner:** _Assign on receipt_  
**Due:** _Set date/time_  
**Repo Drop Location:** `review/mlupdateInfo/` (this folder)  
**Context:** Collect objective **evidence artifacts** proving that every planned change and gate for **Health Export v2** and the **Normalizer/ML features** are implemented and correct. Use the exact filenames/paths below. Provide both **code pointers** and **runtime artifacts** (logs, manifests, fixtures, screenshots).
**Run of Record (timestamp):** 2025-11-05T01:33:40Z

---

## What to deliver (exact structure)

Create the following structure **inside** `review/mlupdateInfo/`:

```
review/mlupdateInfo/
├── 00_README.md
├── 01_CODE_POINTERS/
│   ├── ios_file_index.json
│   ├── agent_file_index.json
│   └── diffs.patch
├── 02_MANIFESTS/
│   ├── export_manifest_sample.json
│   └── compression_check.txt
├── 03_ARTIFACTS/
│   ├── sample_health_export.jsonl.gz
│   ├── sample_dosetrack_export.jsonl
│   ├── features_night_sample.jsonl
│   ├── tombstone_batch.jsonl
│   └── parity_cases.csv
├── 04_TEST_LOGS/
│   ├── xcode_tests.txt
│   ├── node_tests.txt
│   ├── parity_100cases.txt
│   ├── encryption_e2e.txt
│   ├── join_invariant.txt
│   └── retention_job.txt
├── 05_SCREENSHOTS/
│   ├── settings_encryption_ui.png
│   ├── settings_health_export_section.png
│   └── app_health_panel.png
└── 99_SIGNOFF/
    ├── checklist.md
    └── owner_signoff.md
```

> **Note:** If a file is not applicable, include it with a single line explaining **why** (N/A rationale).

---

## P0 “No Ship Unless” — Evidence Requirements

> Provide the artifacts listed per item. Where a **command** is shown, paste the **exact output** into the corresponding file under `04_TEST_LOGS/`. Where a **sample** is requested, save it under `02_MANIFESTS/` or `03_ARTIFACTS/` as indicated.

### 1) Two‑Phase Anchor Commit & Crash Recovery
- **Code pointers:** Add entries to `01_CODE_POINTERS/ios_file_index.json` for:
  - `ios/HealthExportBridge+TwoPhaseCommit.swift`
  - `ios/HealthExportBridge+Anchors.swift`
- **Artifacts:**
  - `02_MANIFESTS/export_manifest_sample.json` — includes per‑type counts, **old/new anchor tokens (base64)**, start/finish times, file SHA‑256.
  - `04_TEST_LOGS/xcode_tests.txt` — output from:  
    ```bash
    xcodebuild test -scheme DoseTrackNew -destination 'platform=iOS Simulator,name=iPhone 15' | tee review/mlupdateInfo/04_TEST_LOGS/xcode_tests.txt
    ```
  - Evidence that **anchors are committed only after fsync + manifest OK** and that **recovery** replays from old anchors (paste targeted test logs).

### 2) Deletion Tombstones → Normalizer Cascade
- **Artifacts:**
  - `03_ARTIFACTS/tombstone_batch.jsonl` — small set of `{{"deleted":true}}` records (mixed types).
  - `04_TEST_LOGS/node_tests.txt` — includes `testTombstoneCascade` showing rolling windows recomputed for impacted nights + 6 days forward.
  - `03_ARTIFACTS/features_night_sample.jsonl` — before/after stats highlighting changed HRV/respiratory summaries.

### 3) Service‑Day “Max Overlap” Rule (Swift & JS **parity**)
- **Code pointers:**  
  - `ios/ServiceDayMaxOverlap.swift`  
  - `review/health-data-dropin/agent/dropins/health-data/src/util/serviceDayMaxOverlap.js`
- **Artifacts:**
  - `03_ARTIFACTS/parity_cases.csv` — 100 randomized cases across time zones and cutoffs.
  - `04_TEST_LOGS/parity_100cases.txt` — run output proving **100% match**.  
    ```bash
    node review/health-data-dropin/agent/dropins/health-data/scripts/run-parity.js > review/mlupdateInfo/04_TEST_LOGS/parity_100cases.txt
    ```

### 4) Compression Format Consistency (pick **one**)
- Decision recorded in `02_MANIFESTS/compression_check.txt` with:
  - Chosen format: `gzip` **or** `lzfse` (must match extension)
  - CLI verification:  
    ```bash
    # if gzip
    zcat review/mlupdateInfo/03_ARTIFACTS/sample_health_export.jsonl.gz | head -n 3 | tee -a review/mlupdateInfo/02_MANIFESTS/compression_check.txt
    ```
- **Artifact:** `03_ARTIFACTS/sample_health_export.jsonl.gz` (or `.lzfse`).

### 5) Steps De‑Overlap via `HKStatisticsCollection`
- **Artifacts:** Short diff in `01_CODE_POINTERS/diffs.patch` covering exporter step totals.  
- Test snippet in `04_TEST_LOGS/xcode_tests.txt` proving naive sum ≠ de‑overlapped sum and one record per **service day** is emitted.

### 6) Encryption UX (PBKDF2 + Keychain + Strength Meter + RAM wipe)
- **Artifacts:**  
  - `05_SCREENSHOTS/settings_encryption_ui.png`
  - `04_TEST_LOGS/encryption_e2e.txt` — includes derive‑key params (salt base64, iterations), encrypt→decrypt round‑trip on a sample export, and confirmation that plaintext is deleted.
- **Code pointers:** `EncryptionSettingsView`, Keychain helper, exporter hook.

### 7) Join Invariant + Rebucket Tool
- **Artifacts:**  
  - `04_TEST_LOGS/join_invariant.txt` — failing example when `night_key ≠ service_day_key` plus successful run post‑rebucket.
  - `03_ARTIFACTS/features_night_sample.jsonl` — after enforcing invariant.
- **Code pointers:** `scripts/rebucket-health-export.js` and join checks in normalizer.

### 8) Export Manifest Content (per‑type)
- **Artifacts:** `02_MANIFESTS/export_manifest_sample.json` shows `{{ added, deleted, old_anchor_base64, new_anchor_base64 }}` for each type and overall blob **sha256**.

---

## P1 “Should Ship” — Evidence Requirements

- **HK UUID + source revision present**
  - Show example lines in `03_ARTIFACTS/sample_health_export.jsonl.gz` (decompressed excerpt in `02_MANIFESTS/compression_check.txt`).

- **Dual time zones for travel nights (`start_tz`, `end_tz`)**
  - Provide at least one sample crossing zones; show offsets differ.

- **Nap detection v2 with context guards**
  - Paste rule summary + 3 labeled examples with `nap_confidence` in `03_ARTIFACTS/tombstone_batch.jsonl` or separate `03_ARTIFACTS/nap_examples.jsonl`.

- **Robust stats with clipping**
  - In `03_ARTIFACTS/features_night_sample.jsonl`, include fields: `hrvSdnnMsP50`, `hrvSdnnMsP75`, `hrMeanBpm`, `hrP10Bpm`, `hrP90Bpm`, `respiratoryRateP50`, and confirm clipping ranges (HR 35–220, RR 8–30, HRV 5–300).

- **Retention job + secure delete**
  - `04_TEST_LOGS/retention_job.txt` — shows purge of old exports and overwrite‑then‑remove for encrypted blobs.

- **Settings minimization toggles**
  - Screenshots and code pointer where HR/steps/device IDs can be excluded.

- **Schema validation (Ajv)**
  - `04_TEST_LOGS/node_tests.txt` includes `npm run validate` with counts of accepted/rejected and error examples.

- **PII audit**
  - Short report noting audit pass/fail and any blocked keys.

---

## Commands & How to Capture

> Use these **exact** commands (adjust paths if your shell differs).

```bash
# Install agent deps
cd review/health-data-dropin/agent/dropins/health-data
npm install

# Validate unified + features schemas
npm run validate | tee ../../../../../review/mlupdateInfo/04_TEST_LOGS/node_tests.txt

# Normalize current sample exports into features
npm run normalize &&   cp -f ../../../../ml/datasets/features/night_features_*.jsonl         ../../../../../review/mlupdateInfo/03_ARTIFACTS/features_night_sample.jsonl

# Parity tests (Swift vs JS service-day)
node scripts/run-parity.js > ../../../../../review/mlupdateInfo/04_TEST_LOGS/parity_100cases.txt

# iOS tests
xcodebuild test -scheme DoseTrackNew -destination 'platform=iOS Simulator,name=iPhone 15'   | tee ../../review/mlupdateInfo/04_TEST_LOGS/xcode_tests.txt
```

---

## 01_CODE_POINTERS — Expected JSON shape

**`ios_file_index.json`**
```json
{{
  "two_phase": "ios/HealthExportBridge+TwoPhaseCommit.swift",
  "anchors": "ios/HealthExportBridge+Anchors.swift",
  "steps": "ios/HealthExportBridge+Steps.swift",
  "service_day": "ios/ServiceDayMaxOverlap.swift",
  "encryption_ui": "ios/Settings/EncryptionSettingsView.swift",
  "export_bridge": "ios/HealthExportBridge.swift",
  "doselog_exporter": "ios/DoseLogExporter.swift"
}}
```

**`agent_file_index.json`**
```json
{{
  "normalizer": "review/health-data-dropin/agent/dropins/health-data/src/util/normalize.js",
  "service_day_js": "review/health-data-dropin/agent/dropins/health-data/src/util/serviceDayMaxOverlap.js",
  "rebucket_tool": "review/health-data-dropin/agent/dropins/health-data/scripts/rebucket-health-export.js"
}}
```

---

## Acceptance & Sign‑off

Fill out `99_SIGNOFF/checklist.md` (copy this block and check each box):

- [ ] All **P0** artifacts present with commands + outputs
- [ ] Two‑phase anchor commit verified with recovery
- [ ] Tombstone cascade recomputes rolling windows
- [ ] Service‑day parity 100/100 Swift↔JS pass
- [ ] Compression decision is consistent and verified
- [ ] De‑overlapped steps proven via HKStatisticsCollection
- [ ] Encryption UX complete (PBKDF2, Keychain, strength meter, RAM wipe) with E2E proof
- [ ] Join invariant enforced; rebucket tool demonstrated
- [ ] Manifest includes per‑type counts + anchors + sha256
- [ ] P1 items supplied (UUID/revision, dual TZ, nap v2, robust stats, retention, minimization, Ajv, PII audit)
- [ ] `01_CODE_POINTERS` JSONs present and accurate

**Owner:** _Name_  
**Reviewers:** _Names_  
**Date:** _YYYY‑MM‑DD_  
**Decision:** _Approve / Block_

---

## Notes

- If any artifact cannot be produced, put an **N/A** file with rationale and owner/date.  
- Keep all files small; compress samples if >5MB.  
- Use UTC in logs where possible.  
- This RFE should take precedence over feature work until complete.
