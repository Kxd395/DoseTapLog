# Health Export v2 - Actual Implementation Status

**Date:** November 4, 2025  
**Status:** 🔴 NOT STARTED - Design Complete, Implementation Pending  
**Branch:** `feature/health-export-v2` (to be created)  
**Estimated Effort:** 24-28 hours

---

## 📊 Reality Check

### What Actually Exists ✅

- ✅ Basic prototype: `review/health-data-dropin/ios/App/Bridges/HealthExportBridge.swift` (100 lines)
- ✅ Node.js agent framework (ingest CLI)
- ✅ Basic JSON schemas
- ✅ Comprehensive design documents (in `docs/ops/`)

### What Does NOT Exist ❌

- ❌ Production HealthExportBridge (main codebase)
- ❌ Two-phase anchor commit
- ❌ Service-day max overlap (Swift + JS)
- ❌ HKStatisticsCollection for steps
- ❌ DoseLogExporter
- ❌ Production normalizer (agent has stubs only)
- ❌ Settings UI integration
- ❌ Tests

---

## 🚫 No-Ship-Unless Gates (0/12 Complete)

### Critical (P0 - Must Ship)

- [ ] **Two-phase anchor with WAL + recovery** (6-7h)
  - Manifest status: pending/ok/failed
  - Per-type old/new anchor checkpoints
  - Crash recovery with anchor rollback
  - Keychain persistence (not UserDefaults)

- [ ] **Anchor reset detector** (2h)
  - Store fingerprint (device + HK store ID)
  - Monotonic watermark (last seen endDate per type)
  - Automatic fallback to time-range replay on reset

- [ ] **Exporter lock + device-locked guard** (2h)
  - Advisory file lock (prevent concurrent exports)
  - Protected data availability check
  - Defer anchor commit until unlock

- [ ] **Deletion tombstone cascade** (3h)
  - iOS emits `{deleted: true}` records
  - Normalizer removes from aggregates
  - Recomputes rolling windows (7d/14d)

- [ ] **Service-day max overlap (Swift + JS)** (4h)
  - Identical algorithm in both platforms
  - 100-case parity test suite (6 timezones)
  - Metadata: `assignment_method: "max_overlap_v2"`

- [ ] **Compression format locked (gzip)** (1h)
  - Swift uses `.zlib` compression
  - Node uses `zlib.gunzipSync`
  - Extension must be `.gz`
  - CI content-type verification

- [ ] **HKStatisticsCollection for steps** (2h)
  - De-overlapped totals (watch + phone)
  - Anchor aligned to service-day cutoff
  - Partial days excluded unless requested

- [ ] **Encryption UX shippable** (4h)
  - PBKDF2/HKDF key derivation
  - Key versioning in manifest
  - Keychain storage (device-only)
  - RAM wipe after use
  - Settings UI: strength meter, risk acknowledgment

- [ ] **HK UUID + sourceRevision emitted** (1h)
  - All records include `hk_uuid`
  - All records include `hk_source_revision`
  - Cross-source dedupe on `(source, hk_uuid)`

- [ ] **Dual timezones (start_tz, end_tz)** (2h)
  - Handle travel across timezone boundaries
  - Node uses `date-fns-tz` or Luxon (not `new Date(localStr)`)

- [ ] **Join invariant enforced** (2h)
  - Hard failure if `night_key != service_day_key`
  - Hard failure if `cutoff_hour_local` differs
  - Rebucket tool provided and tested

- [ ] **Strict schemas + integrity HMAC** (2h)
  - `additionalProperties: false`
  - Unit enum: `count|count/min|ms|bpm|pct|breaths/min`
  - `oneOf` for deletion vs record
  - Manifest includes `blob_sha256`, `manifest_sha256`, `hmac_sha256`

**P0 Progress:** 0/12 (0%)

### High Priority (P1 - Should Ship)

- [ ] **Memory-safe normalizer** (3h)
  - Streaming line reader
  - Online aggregates (not materialized `_raw`)
  - `DEBUG_RAW=1` flag gates full retention

- [ ] **Robust stats with outlier clipping** (2h)
  - HRV: median + P75 (not max)
  - HR: clip 35-220 bpm
  - Respiratory: clip 8-30, median (not mean)

- [ ] **Nap detection v2 context guards** (3h)
  - Blacklist ±45min around dose windows
  - Confidence ≤0.5 for night shift workers
  - Planned night overlap check (>15min = not nap)

- [ ] **Telemetry + energy budgets** (3h)
  - OSLog counters in App Health panel
  - Time budget: 30s per export
  - Size budget: 25MB per export
  - Battery check: pause if <20% without power

**P1 Progress:** 0/4 (0%)

---

## 📋 Implementation Plan

### Phase 1: Foundation (Day 1 - 6-7h)

**Branch:** `feature/health-export-v2`

1. **Create file scaffolds** (30min)
   - `ios/HealthExportBridge+TwoPhaseCommit.swift`
   - `ios/HealthExportBridge+Anchors.swift`
   - `ios/HealthExportBridge+Steps.swift`
   - `ios/ServiceDayMaxOverlap.swift`
   - `ios/DoseLogExporter.swift`
   - `review/health-data-dropin/agent/dropins/health-data/src/util/serviceDayMaxOverlap.js`

2. **Exporter lock** (1h)
   - Advisory file lock in export directory
   - Single-process guarantee
   - "Export in progress" error surfacing

3. **Device-locked guard** (1h)
   - Check `UIApplication.protectedDataAvailable`
   - Defer anchor commit if unavailable
   - Schedule retry after unlock notification

4. **Two-phase anchor commit** (4h)
   - `AnchorCheckpoint` struct (old/new tokens)
   - `ExportManifest` with status field
   - WAL: query → temp file → pending manifest
   - Commit: gzip → fsync → verify → ok → save anchors
   - Recovery: pending manifests → restore old anchors

### Phase 2: Service-Day + Steps (Day 2 - 6-7h)

5. **Service-day max overlap (Swift)** (2h)
   - Candidate day enumeration
   - Temporal overlap calculation
   - Ties → earlier day wins
   - DST-aware boundaries

6. **Service-day max overlap (Node)** (2h)
   - Install `date-fns-tz`
   - Use `zonedTimeToUtc`/`utcToZonedTime`
   - Kill all `new Date(localStr)` parsing
   - Emit `assignment_method` metadata

7. **Steps de-overlap** (2h)
   - `HKStatisticsCollectionQuery` with `.cumulativeSum`
   - Anchor aligned to cutoff hour
   - One aggregate record per service day

8. **Compression = gzip** (1h)
   - Swift: `.compressed(using: .zlib)`
   - Node: `zlib.gunzipSync`
   - Extension: `.jsonl.gz`

### Phase 3: Deletions + Join (Day 3 - 6-7h)

9. **Deletion tombstones** (3h)
   - iOS: emit `{deleted: true, hk_uuid, sha256}`
   - Node: remove from `_raw` arrays
   - Recompute rolling windows (impacted + 6 days forward)
   - Test: verify HRV 7-day median changes

10. **Strict schemas** (2h)
    - `additionalProperties: false`
    - Unit enum enforcement
    - `oneOf` for tombstone vs record
    - Pattern validation (ISO dates, SHA hashes)

11. **Join invariant** (2h)
    - Check `night_key === service_day_key`
    - Check `cutoff_hour_local` consistency
    - Hard failure with rebucket instructions
    - Create `scripts/rebucket-health-export.js`

### Phase 4: Security + Polish (Day 4 - 6-7h, optional)

12. **Encryption UX** (4h)
    - HKDF key derivation (CryptoKit)
    - Keychain storage
    - Settings UI: passphrase field, strength meter
    - Risk acknowledgment toggle
    - RAM wipe after encryption

13. **Dual timezones** (2h)
    - `start_tz`, `end_tz` fields
    - `start_offset_min`, `end_offset_min`
    - Handle travel across boundaries

14. **Tests** (2h minimum)
    - Service-day parity (Swift vs JS, 100 cases)
    - Anchor WAL crash simulation
    - Tombstone cascade validation
    - Steps de-overlap verification

---

## 🧪 Test Requirements

### Must-Have Tests (Before Merge)

- [ ] **Anchor reset & replay**
  - Simulate HK store reset
  - Verify fallback to time-range
  - Ensure no loss/duplication

- [ ] **Device-locked export**
  - BG task before unlock
  - Deferred anchor commit
  - Post-unlock replay succeeds

- [ ] **Service-day parity (100 cases)**
  - Swift vs Node exact match
  - 6 timezones (US/EU/Asia)
  - DST spring/fall boundaries
  - Midnight crossing edge cases

- [ ] **Tombstone cascade**
  - Delete 5 HRV samples from night N
  - Verify nights [N, N+6] recomputed
  - Check 7-day median changed

- [ ] **Steps de-overlap**
  - Watch + phone samples (same time)
  - Naive sum vs HKStatisticsCollection
  - Verify ~50% reduction in inflated case

- [ ] **Integrity check**
  - Corrupt `.gz` payload
  - Manifest checksum mismatch
  - Anchors NOT advanced

### Nice-to-Have Tests (Post-MVP)

- [ ] Chunked export resume (2GB HR data)
- [ ] Cross-source dedupe (XML + live HK)
- [ ] Energy budget enforcement
- [ ] Encryption key rotation

---

## 📦 Dependencies

### Swift Dependencies (Built-in)
- HealthKit framework
- CryptoKit (encryption, hashing)
- Compression (gzip)

### Node Dependencies (New)
```json
{
  "dependencies": {
    "date-fns": "^2.30.0",
    "date-fns-tz": "^2.0.0",
    "ajv": "^8.12.0",
    "ajv-formats": "^2.1.1"
  }
}
```

---

## 📈 Progress Tracking

### Week 1 Goals
- [ ] Branch created: `feature/health-export-v2`
- [ ] File scaffolds in place (compile-safe)
- [ ] Phase 1 complete (foundation)
- [ ] Phase 2 complete (service-day + steps)

### Week 2 Goals
- [ ] Phase 3 complete (deletions + join)
- [ ] Basic tests passing
- [ ] Settings UI integration
- [ ] Documentation updated

### Definition of Done
- [ ] All 12 P0 gates passing
- [ ] Test coverage >70% for critical paths
- [ ] 100-case parity test suite passing
- [ ] Documentation complete
- [ ] PR reviewed and merged to main

---

## 🎯 Success Criteria

**Before marking "COMPLETE":**
1. All P0 no-ship gates implemented and tested
2. Service-day parity: 100% match (Swift vs JS, 100 random cases)
3. Crash recovery verified (anchor rollback works)
4. Deletion cascade verified (rolling windows recompute)
5. No data loss, no double-counting, no silent failures
6. Settings UI integrated and working
7. CI passing (schema validation, parity tests, integrity checks)

---

## 🚨 Current Blockers

**None** - Design complete, ready to start implementation.

---

## 📝 Notes

- Previous operational docs moved to `docs/design/health-export/` (design specs)
- This document reflects **actual repository state** (not aspirational)
- Estimates are conservative (experienced iOS + Node developer)
- Can be phased: P0 first (12 gates), then P1 polish

---

**Version:** 1.0  
**Created:** November 4, 2025  
**Last Updated:** November 4, 2025  
**Status:** 🔴 NOT STARTED - Awaiting branch creation

**Next Action:** Create `feature/health-export-v2` branch and begin Phase 1.
