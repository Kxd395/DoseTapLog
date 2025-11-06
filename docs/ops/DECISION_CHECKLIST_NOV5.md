# Decision Checklist - Post-Audit Action Items

**Date:** November 5, 2025  
**Context:** Auditor identified 20 red flags; Items 69-75 need production hardening  
**Decision Maker:** Project Owner  
**Status:** ⏳ AWAITING DECISIONS

---

## ✅ Decisions Needed (Check One Per Section)

### Decision 1: Scope & Timeline

**Question:** 4-week beta or 8-week full release?

- [ ] **Option A: 4-week beta (descoped)**
  - Ship: Critical infrastructure + core features + WHOOP
  - Defer to Phase 2: Modern UI, trend cards, battery math, full RTL
  - **Pros:** Quality gates met, App Review safe
  - **Cons:** Minimal feature set
  - **Estimated Effort:** 80-100 hours (Week 1 infrastructure + core features)

- [ ] **Option B: 8-week full release (original scope)**
  - Ship: All 80 items
  - **Pros:** Feature-complete v1.2
  - **Cons:** Higher risk of quality issues
  - **Estimated Effort:** 180-240 hours (revised realistic estimate)

**Owner Decision:**
```
Choice: [ A | B ]
Rationale: ___________________________________________
```

---

### Decision 2: WHOOP Production Hardening

**Question:** Fix Items 69-75 now, or pause WHOOP work?

**Context:** Items 69-75 marked "COMPLETE" but are dev-only. Need 11-16h to harden for production.

**Required Work:**
- Item 70a: PostgreSQL backend (6-8h)
- Item 72: Health check (1-2h)
- Items 71-75: Unit tests (4-6h)

**Options:**

- [ ] **Option A: Fix WHOOP now (11-16h)**
  - Complete Items 70a + tests before continuing
  - **Pros:** WHOOP ready to ship
  - **Cons:** Delays other work

- [ ] **Option B: Pause WHOOP, do Week 1 infrastructure first**
  - Complete Items 41, 54, 8, 51, 52, 26, 24 (14-21h)
  - Return to WHOOP later
  - **Pros:** Solid foundation prevents future bugs
  - **Cons:** WHOOP incomplete for longer

- [ ] **Option C: Continue to Item 76 (not recommended)**
  - Proceed with WHOOP service day mapping
  - **Pros:** Forward progress
  - **Cons:** Builds on shaky foundation, will need rework

**Owner Decision:**
```
Choice: [ A | B | C ]
Rationale: ___________________________________________
```

---

### Decision 3: Testing Requirements

**Question:** What's the acceptable test coverage?

**Auditor Recommendation:** ≥80% coverage on time math + gating + turnover

**Options:**

- [ ] **Option A: Strict (≥80% coverage)**
  - All Items 9, 10, 41, 54 tests required before ship
  - **Pros:** High quality, fewer bugs
  - **Cons:** More time upfront

- [ ] **Option B: Moderate (≥60% coverage)**
  - Focus on critical paths only
  - **Pros:** Faster shipping
  - **Cons:** May miss edge cases

- [ ] **Option C: Minimal (spot tests only)**
  - Happy path tests only
  - **Pros:** Ship fastest
  - **Cons:** High bug risk in production

**Owner Decision:**
```
Choice: [ A | B | C ]
Target Coverage: ____%
```

---

### Decision 4: TODO.md Corrections

**Question:** Accept corrected TODO or modify further?

**Files:**
- `docs/ops/TODO.md` (current, with misleading "COMPLETE" markers)
- `docs/ops/TODO_CORRECTED_NOV5.md` (auditor-approved corrections)

**Options:**

- [ ] **Option A: Replace TODO.md with TODO_CORRECTED_NOV5.md**
  - Adopt all auditor recommendations
  - **Pros:** Aligned with best practices
  - **Cons:** Significant scope/estimate changes

- [ ] **Option B: Keep current TODO.md, cherry-pick some corrections**
  - Manually merge specific fixes
  - **Pros:** Owner control
  - **Cons:** More work to integrate

- [ ] **Option C: Keep current TODO.md, ignore audit**
  - Proceed with original plan
  - **Pros:** No rework
  - **Cons:** Risks auditor identified remain

**Owner Decision:**
```
Choice: [ A | B | C ]
If B, which corrections to adopt: ___________________
```

---

### Decision 5: Week 1 Priority Order

**Question:** What should AI agent work on next?

**Auditor's Recommended Order:**
1. ClockProvider + TimeMath (Items 41, 54)
2. StateMachine (Item 8)
3. Freeze notification IDs (Item 51)
4. File protection (Items 52, 52a)
5. Notification audit trail (Item 26)
6. Idempotent writes (Item 24)

**Options:**

- [ ] **Option A: Follow auditor's order exactly**
  - Start with Items 41, 54 tomorrow
  - **Pros:** Solid foundation
  - **Cons:** Delays visible features

- [ ] **Option B: Finish WHOOP first, then infrastructure**
  - Complete Items 70a, 72 fix, tests
  - Then do Items 41, 54, 8, etc.
  - **Pros:** WHOOP feels "done"
  - **Cons:** May need to refactor WHOOP later

- [ ] **Option C: Hybrid approach**
  - Do Item 41 (ClockProvider) first
  - Then finish WHOOP with proper time mocking
  - Then rest of infrastructure
  - **Pros:** Best of both worlds
  - **Cons:** More context switching

**Owner Decision:**
```
Choice: [ A | B | C ]
First 3 items to work on:
1. _____________
2. _____________
3. _____________
```

---

### Decision 6: Compliance & Legal

**Question:** Prioritize health disclaimer (Item 29)?

**Context:** Auditor changed Item 29 from HIGH to CRITICAL (App Review blocker)

**Options:**

- [ ] **Option A: Do Item 29 immediately**
  - First-run disclaimer before any other work
  - **Pros:** Legal protection, App Review requirement
  - **Cons:** 0.5h delay

- [ ] **Option B: Do Item 29 before beta ship**
  - Somewhere in Week 2-3
  - **Pros:** Not rushed
  - **Cons:** Risk of forgetting

- [ ] **Option C: Skip for internal beta, add for App Store**
  - Only required for public release
  - **Pros:** Faster internal testing
  - **Cons:** Legal risk if beta leaks

**Owner Decision:**
```
Choice: [ A | B | C ]
When: ___________________________________________
```

---

## 📋 Summary of Decisions

Once you've checked boxes above, fill this in:

**Scope:** [ 4-week beta | 8-week full ]  
**WHOOP:** [ Fix now | Pause | Continue ]  
**Test Coverage:** [ ≥80% | ≥60% | Minimal ]  
**TODO:** [ Replace | Cherry-pick | Keep current ]  
**Week 1 Priority:** [ Auditor order | WHOOP first | Hybrid ]  
**Disclaimer:** [ Now | Week 2-3 | Before public ]

---

## 🚀 Next Steps for AI Agent

Based on decisions above, AI agent will:

**If "Fix WHOOP now":**
1. Implement Item 70a (PostgreSQL backend)
2. Add health check to Item 72
3. Write unit tests for Items 71-75
4. Mark Items 69-75 as truly COMPLETE
5. Push to repo

**If "Do Week 1 infrastructure":**
1. Implement Item 41 (ClockProvider)
2. Implement Item 54 (TimeMath)
3. Implement Item 8 (StateMachine)
4. Write unit tests for all three
5. Push to repo

**If "Continue to Item 76":**
1. Agent will warn about risks again
2. Proceed with service day mapping
3. Note: will need refactoring later

---

## 📝 Notes / Additional Context

(Owner: Add any additional thoughts, constraints, or decisions here)

```


```

---

**Status:** ⏳ AWAITING OWNER DECISIONS  
**Last Updated:** November 5, 2025  
**Next Review:** After owner completes checklist
