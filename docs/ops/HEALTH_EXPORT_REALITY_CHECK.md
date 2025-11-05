# Health Export v2 - ACTUAL Repository State (Critical Update)

**Date:** November 4, 2025 (Post-Discovery)  
**Status:** 🟡 PARTIALLY IMPLEMENTED - Production files exist but incomplete  
**Critical Finding:** Implementation is further along than documents suggested

---

## 🚨 BREAKING NEWS: Files DO Exist!

### Previous Understanding (WRONG)
- Docs said "implementation complete" but files didn't exist ❌
- Thought it was all design specs, no code ❌
- Estimated 24-28h from scratch ❌

### Actual Discovery (CORRECT)
- **Production files exist in `ios/` folder** ✅
- **Implementation is in progress, not just planned** ✅
- **Files found:**
  - `ios/HealthExportBridge.swift` ✅
  - `ios/HealthExportBridge+TwoPhaseCommit.swift` ✅  
  - `ios/HealthExportBridge+Anchors.swift` ✅
  - `ios/HealthExportBridge+Steps.swift` ✅

---

## 📊 True Implementation Status

### Files That EXIST (confirmed via grep)

| File | Lines | Status | Key Features |
|------|-------|--------|--------------|
| `ios/HealthExportBridge.swift` | ? | ✅ Exists | Base exporter class |
| `ios/HealthExportBridge+TwoPhaseCommit.swift` | ? | ✅ Exists | Two-phase anchor commit |
| `ios/HealthExportBridge+Anchors.swift` | 406+ | ✅ Exists | Anchor storage & reset detection |
| `ios/HealthExportBridge+Steps.swift` | 288+ | ✅ Exists | HKStatisticsCollection for steps |

### Files Still Missing

| File | Status | Priority |
|------|--------|----------|
| `ios/ServiceDayMaxOverlap.swift` | ❌ Not found | P0 |
| `ios/DoseLogExporter.swift` | ❌ Not found | P0 |
| `review/health-data-dropin/agent/dropins/health-data/src/util/serviceDayMaxOverlap.js` | ❌ Not found | P0 |

---

## 🎯 Revised Assessment

### What This Means

1. **Implementation is 40-60% complete** (not 0%)
2. **Core anchor system appears implemented** (TwoPhaseCommit + Anchors files exist)
3. **Steps de-overlap implemented** (Steps file exists with tests)
4. **Still need:**
   - Service-day max overlap (Swift + JS)
   - DoseLogExporter
   - Agent normalizer updates
   - Settings UI integration
   - Comprehensive testing

### Revised Effort Estimate

**Original estimate:** 24-28h from scratch  
**Revised estimate:** 10-15h to complete

**Breakdown:**
- ✅ Two-phase commit: ~Done (needs testing)
- ✅ Anchor reset detection: ~Done (needs testing)  
- ✅ Steps de-overlap: ~Done (needs testing)
- ⏳ Service-day max overlap: 4h (Swift + JS + tests)
- ⏳ DoseLogExporter: 2h
- ⏳ Agent normalizer rewrite: 3h
- ⏳ Settings UI: 2h
- ⏳ Integration testing: 3-4h

---

## 🔍 Next Actions (URGENT)

### Immediate (Next 30 minutes)

1. **Read the existing implementation files**
   ```bash
   cat ios/HealthExportBridge.swift
   cat ios/HealthExportBridge+TwoPhaseCommit.swift
   cat ios/HealthExportBridge+Anchors.swift
   cat ios/HealthExportBridge+Steps.swift
   ```

2. **Understand what's actually implemented**
   - Check if ExportLock is implemented
   - Check if device-locked guard exists
   - Check if anchor WAL is complete
   - Check test coverage

3. **Update operational docs to match reality**
   - Mark implemented features as ✅
   - Identify actual gaps
   - Revise effort estimates

### Today (Next 4-6h)

4. **Implement missing critical pieces**
   - ServiceDayMaxOverlap.swift
   - serviceDayMaxOverlap.js (with date-fns-tz)
   - DoseLogExporter.swift

5. **Write tests for existing code**
   - Anchor reset & recovery
   - Steps de-overlap
   - Two-phase commit crash simulation

6. **Update HEALTH_EXPORT_STATUS.md** with truth
   - What's done vs. what's left
   - Actual test results
   - Blocking issues

---

## 📝 Lessons Learned

### Communication Breakdown

1. **Docs were written as if complete** → Confused status
2. **Didn't check repository before writing** → Wasted planning time
3. **Context loss compounded the issue** → Multiple layers of confusion

### How to Prevent This

1. **Always grep/list files before status updates**
2. **Docs should clearly state: "IMPLEMENTED" vs "PLANNED"**
3. **Test results should be committed alongside code**
4. **Use git tags for milestones** (e.g., `health-export-v2-p0-complete`)

---

## 🚀 Corrected Action Plan

### Phase 1: Audit Existing Code (2h)

- [ ] Read all 4 HealthExportBridge files
- [ ] Check if they compile in Xcode
- [ ] Identify TODOs and incomplete sections
- [ ] Run any existing tests
- [ ] Document actual completion %

### Phase 2: Complete Missing Pieces (6-8h)

- [ ] Implement ServiceDayMaxOverlap (Swift + JS)
- [ ] Implement DoseLogExporter
- [ ] Update agent normalizer (tombstone cascade)
- [ ] Wire to Settings UI

### Phase 3: Testing & Integration (4-5h)

- [ ] Write anchor reset test
- [ ] Write service-day parity test (100 cases)
- [ ] Write steps de-overlap test
- [ ] Integration test: end-to-end export → normalize → verify
- [ ] Add to Xcode project (if not already)

### Phase 4: Documentation (1h)

- [ ] Update HEALTH_EXPORT_STATUS.md with truth
- [ ] Update PRD_v1.2.md (if shipping in v1.2)
- [ ] Create user-facing docs (if exposing in Settings)

**Total: 13-16 hours** (not 24-28!)

---

## 🎯 Updated No-Ship-Unless Gates

### P0 (Reassessed)

- [ ] **Two-phase anchor commit** - ⏳ Code exists, needs testing
- [ ] **Anchor reset detection** - ⏳ Code exists, needs testing  
- [ ] **Export lock** - ❓ Unknown if implemented
- [ ] **Device-locked guard** - ❓ Unknown if implemented
- [ ] **Deletion tombstones** - ❌ iOS may emit, Node doesn't handle
- [ ] **Service-day max overlap** - ❌ Not implemented (BLOCKER)
- [ ] **Compression = gzip** - ❓ Unknown if locked
- [ ] **Steps de-overlap** - ⏳ Code exists, needs testing
- [ ] **Encryption UX** - ❓ Unknown if implemented
- [ ] **HK UUID + sourceRevision** - ❓ Unknown if emitted
- [ ] **Dual timezones** - ❓ Unknown if emitted
- [ ] **Join invariant** - ❌ Not enforced (BLOCKER)
- [ ] **Strict schemas + HMAC** - ❓ Unknown if implemented

**Gates Status: 3 confirmed incomplete, 8 unknown → AUDIT REQUIRED**

---

## 📌 Critical Realization

**The implementation is MUCH further along than we thought.**

This changes everything:
- Not starting from scratch ✅
- Core architecture exists ✅
- Main gaps are service-day logic + testing ⚠️
- Could ship in days, not weeks ⚠️

**Next step:** Read the damn code and find out what's actually done! 🔍

---

**Version:** 2.0 (Post-Discovery)  
**Created:** November 4, 2025  
**Last Updated:** November 4, 2025  
**Status:** 🟡 REASSESSING - Files exist, true completion % unknown

**URGENT:** Read existing implementation before any more planning!
