# DoseTrack v1.1.1c – Action Checklist

**Last updated:** November 1, 2025  
**Canonical reference:** `README.md`

---

## Status Snapshot
- ✅ Spec Kit formal specification complete (constitution → spec → plan)
- ✅ Documentation reorganized (README as SSOT, PRODUCT_DESCRIPTION, design/ folder)
- 🚧 Architecture refactor pending (SwiftUI view model + main-actor enforcement)
- ⚠️ Night anchoring bug open in `ios/DoseLogController`
- ℹ️ WHOOP proxy requires populated `.env` before tests

---

## 0. Spec Kit Workflow (NEW - Priority 0)
- [x] **Constitution:** Created DoseTrack Constitution v1.0.0 with 6 core principles
- [x] **Specification:** Generated comprehensive spec.md (11,000+ lines) aligned with PRD v1.2
- [x] **Plan:** Created implementation plan with technical architecture, stack details, testing strategy
- [x] **Analyze:** COMPLETED via manual analysis - SPECKIT_MANUAL_ANALYSIS.md created with 96/100 alignment score (A+)
- [x] **Review Integration:** Complete - SPEC_KIT_REVIEW.md created with 100% alignment validation
- [x] **Documentation Links:** Complete - README updated with links to PRODUCT_DESCRIPTION and spec.md
- [x] **Server Validation:** Complete - Server operational (PID 42540), health check passing
- [x] **Quick Tests:** Complete - All validation tests passing (77 packages, iOS files, docs)
- [x] **Archive Legacy Reviews:** Complete - 4 legacy documents moved to docs/review-notes/archive/

**Status:** ✅ ALL TASKS COMPLETE - Spec Kit workflow fully validated with manual analysis.

---

## 1. iOS Stabilization (Priority 0)
- [ ] **Night anchoring fix:** ensure bedtime anchoring handles post-midnight logs; add targeted XCTest coverage.
- [ ] **HealthKit anchor API:** expose a public computed property or method for the view layer instead of calling a private helper.
- [ ] **Main-actor guarantees:** mark persistence controller `@MainActor` (or gate writes through `MainActor.run`) and refactor HealthKit calls to async/await.
- [ ] **Regression tests:** use an in-memory SwiftData container to cover controller logic, CSV edge cases, and recommender guardrails.

## 2. SwiftUI Architecture Improvements
- [ ] Introduce a `TodayLogViewModel` `ObservableObject` that owns the controller, exposes derived state, and surfaces errors.
- [ ] Update `TodayLogView` to use `NavigationStack`, structured layout (e.g., `Form` sections), and the new view model bindings.
- [ ] Replace deprecated share-sheet access with `ShareLink` or an `ActivityViewController` wrapper.
- [ ] Ensure widget and App Intent paths reuse shared logging logic where practical.

## 3. WHOOP Proxy Hardening
- [ ] Break `server/index.js` into modules (app bootstrap, routes, middleware, WHOOP client).
- [ ] Validate configuration on startup (e.g., with Zod) and guard pagination against token loops or excessive pages.
- [ ] Add structured logging/metrics and tighten CORS configuration via allowlist.
- [ ] Decide on future stack (TypeScript recommended) and update tooling/tests accordingly.

## 4. Tooling & Automation
- [ ] Adopt formatting/linting: `swift-format`/`swiftlint` for iOS; `eslint` or `biome` (and `tsc` if TypeScript) for the proxy.
- [ ] Set up CI (GitHub Actions or equivalent) to run lint + tests for both stacks on each PR.
- [ ] Expand `scripts/quick-test.sh` to include linting and unit tests once they exist.
- [ ] Draft `CONTRIBUTING.md` covering branch strategy, testing expectations, and secrets handling.

## 5. Documentation & Compliance
- [x] Promote `README.md` to SSOT (complete).
- [x] Add `docs/SECRETS.md` and `server/.env.example` (complete).
- [x] Review and archive legacy review-kit summaries (4 files moved to archive/).
- [x] Keep `README.md` and this checklist synchronized with implementation changes.

**Status:** ✅ All documentation tasks complete.

---

### References
- `docs/ops/START_HERE.md` – orientation.
- `docs/ops/EVERYTHING_WORKING.md` – verification log template.
- `docs/review-notes/` – historical review analyses.
- `scripts/` – helper tooling (`demo-server.sh`, `quick-test.sh`, etc.).

Update this checklist as items land; tie each completion to an issue or commit for traceability.
