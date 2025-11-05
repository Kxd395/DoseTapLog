# Health Export v2 — **Verification Request Prompt**
**Date:** 2025-11-05T01:14:59Z  
**Owner:** Release QA  
**Target Folder for all evidence:** `review/mlupdateInfo/` (this folder)

> Please attach the **exact artifacts** below so we can verify that all plan items and production hardening gates were completed correctly.  
> **Do not** paste screenshots in chat—drop the files here with the requested filenames.

---

## 0) Repo & Build Context (required)
- **Branch:** `feature/health-export-v2` (or name used)
- **Commit SHA:** `{commit}`
- **Xcode Version / iOS SDK:** e.g., 16.4+
- **Node Version:** `node -v`
- **CI run URL(s):** last green runs for iOS + Node

**Drop:** `00_context.json`
```json
{
  "branch": "feature/health-export-v2",
  "commit": "xxxxxxxx",
  "xcode": "15.4",
  "ios_sdk": "18.0",
  "node": "v20.11.0",
  "ci_urls": ["..."]
}
```

---

## 1) Code Landing Proof (file presence)
Confirm these files exist with non‑stub implementations:

**Swift (ios/):**
- `HealthExportBridge+TwoPhaseCommit.swift`
- `HealthExportBridge+Anchors.swift`
- `HealthExportBridge+Steps.swift`
- `ServiceDayMaxOverlap.swift`
- `DoseLogExporter.swift`

**Node (agent):**
- `review/health-data-dropin/agent/dropins/health-data/src/util/serviceDayMaxOverlap.js`
- `review/health-data-dropin/agent/dropins/health-data/src/util/normalize.js` (tombstone cascade + robust stats)

**Drop:** `01_tree.txt` (output of `git ls-files -z | tr '\0' '\n' | grep -E 'HealthExportBridge\+|ServiceDayMaxOverlap|DoseLogExporter|serviceDayMaxOverlap\.js|normalize\.js'`)

---

## 2) Two‑Phase Anchors + WAL (no data loss)
Provide a **manifest** from a real incremental export showing:
- `status: "pending"` then `"ok"` after commit
- Per‑type counts (`added`, `deleted`)
- Old/new anchors (base64) captured in manifest
- Evidence of crash‑recovery replay (anchor stays at OLD until commit)

**Drop:**
- `02_manifest_pending.json`
- `02_manifest_ok.json`
- `02_anchor_recovery_log.txt` (simulated crash run output)

---

## 3) Service‑Day Max‑Overlap (Swift ⇄ JS parity)
- 100‑case parity test across ≥6 time zones, ≥2 cutoffs
- Zero mismatches

**Drop:**
- `03_parity_report.json` (see schema in `evidence_manifest.schema.json#/definitions/parityReport`)
- `03_parity_stdout.txt`

---

## 4) Compression Format Consistency (gzip)
- One export blob: `.jsonl.gz`
- SHA‑256 of **compressed** blob in manifest
- Agent successfully gunzips + parses

**Drop:**
- `04_export_sample.jsonl.gz`
- `04_export_sample.sha256`
- `04_agent_decompress_log.txt`

---

## 5) Steps via HKStatisticsCollection (de‑overlapped)
- Code path proof (file + function symbol)
- Unit test proving watch+phone overlap collapses
- One example **per‑service‑day** step record with `de_overlapped: true`

**Drop:**
- `05_steps_unit_test.log`
- `05_steps_example.jsonl`

---

## 6) Deletion Tombstones → Cascade/Invalidation
- Input lines including `{ "deleted": true }` for some HRV/HR/resp samples
- Normalized features **before/after** showing rolling windows changed
- Proof deleted SHA‑256/HK UUID removed from aggregates

**Drop:**
- `06_tombstone_input.jsonl`
- `06_features_before.jsonl`
- `06_features_after.jsonl`
- `06_tombstone_diff.txt`

---

## 7) Encryption UX (PBKDF2, key versioning, RAM wipe)
- PBKDF2 params (salt bytes, iterations ≥ 100k), keyVersion
- Screenshot/pdf of Settings Encryption UI (passphrase strength, risk ack)
- Encrypted export `.enc` + successful decrypt log (no plaintext left on disk)

**Drop:**
- `07_encryption_params.json`
- `07_encryption_ui.pdf` (or .png)
- `07_encrypted_blob.enc`
- `07_decrypt_log.txt`

---

## 8) Join Invariant + Rebucket Tool
- Join check log that enforces `night_key === service_day_key` (and cutoff equality)
- If mismatch, show **rebucket tool** run fixing it

**Drop:**
- `08_join_check.log`
- `08_rebucket_before.jsonl`
- `08_rebucket_after.jsonl`
- `08_rebucket_log.txt`

---

## 9) Robust Stats & Outlier Clipping
- Show HR clipping [35,220], resp [8,30], HRV [5,300]
- Provide median/P75 (HRV), median (resp), mean/P10/P90 (HR)

**Drop:**
- `09_robust_stats_unit.log`
- `09_robust_stats_example.json`

---

## 10) Strict Schemas + Validation
- `unified_health.schema.json` & `night_features.schema.json` with `additionalProperties:false`, `unit` enums, version = "2.0"
- `npm run validate` passing

**Drop:**
- `10_schema_unified.json`
- `10_schema_night_features.json`
- `10_validate_stdout.txt`

---

## 11) Retention Job & Secure Delete
- Logs showing purge > X days and secure delete path taken
- Configurable retention

**Drop:**
- `11_retention_log.txt`
- `11_retention_config.json`

---

## 12) Exporter Lock + Device‑Locked Guard
- Log showing single‑process lock obtained
- If device locked/protected data unavailable, no anchor advancement & manifest stays `pending`

**Drop:**
- `12_locking_log.txt`
- `12_protected_data_log.txt`

---

## 13) Android / Apple XML Parity (service day)
- Two small fixtures (Android JSON, Apple XML parsed) mapping to **same** `service_day_key`

**Drop:**
- `13_android_fixture.json`
- `13_apple_xml_fixture.xml`
- `13_parity_stdout.txt`

---

## 14) WHOOP Fixture (optional P1)
- One `source:"whoop", record_type:"recovery"` record → features include `whoopRecoveryPct`

**Drop:**
- `14_whoop_fixture.jsonl`
- `14_whoop_normalize_stdout.txt`

---

## 15) CI & Coverage
- iOS test report (anchor WAL, service‑day, steps)
- Node test report (normalize, parity, tombstone cascade)
- Coverage ≥ 70% for critical paths

**Drop:**
- `15_ci_ios.junit.xml`
- `15_ci_node.junit.xml`
- `15_coverage_summary.txt`

---

## 16) App Health / Settings Evidence
- App Health panel text dump (last BG task, last export, last error, next alert)
- Settings → Health Data section: last export time, encryption state, retention

**Drop:**
- `16_app_health.txt`
- `16_settings_health_data.png`

---

## 17) Evidence Manifest (index of what you’re providing)
Fill out **this manifest** to reference every dropped file and boolean results. Use the schema provided.

**Drop:** `evidence_manifest.json`
```json
{
  "commit": "xxxxxxxx",
  "p0_gates": {
    "two_phase_anchors": true,
    "service_day_max_overlap_parity": true,
    "compression_gzip_consistency": true,
    "steps_statistics_collection": true,
    "tombstone_cascade": true,
    "encryption_ux": true,
    "manifests_complete": true,
    "join_invariant_enforced": true
  },
  "artifacts": [
    { "name": "manifest_ok", "path": "02_manifest_ok.json", "sha256": "..." }
  ]
}
```

---

## Commands Reference (suggested)
- Parity: `node scripts/parity.js --cases=100 --tz="America/New_York,Europe/London,Asia/Tokyo,Australia/Sydney,America/Denver,UTC" --cutoffs=11,12`
- Validate: `npm run validate`
- Normalize with tombstones: `npm run normalize -- --raw=ml/datasets/raw/health --features=ml/datasets/features`
- iOS tests: `xcodebuild test -scheme DoseTrackNew -destination 'platform=iOS Simulator,name=iPhone 15'`

> When complete, ensure every file above exists in `review/mlupdateInfo/`, and submit `evidence_manifest.json` as the final index.
