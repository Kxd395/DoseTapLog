# Bundle Contents

- `ios/` – SwiftUI app, SwiftData models, HealthKit wrapper, CSV exporter, widget provider, and XCTest target.
- `server/` – Express proxy (`index.js`), environment template, tests, and README.
# DoseTrack Documentation Index

**Last Updated:** November 3, 2025  
**Status:** Active Development - Modern UI Phase  

---

## 📚 Quick Navigation

| For... | Start Here |
|--------|------------|
| **New Developers** | [`ops/START_HERE.md`](ops/START_HERE.md) |
| **Current Work** | [`ops/TODO.md`](ops/TODO.md) (50 items) |
| **Product Overview** | [`PRODUCT_DESCRIPTION.md`](PRODUCT_DESCRIPTION.md) |
| **Architecture** | [`../README.md`](../README.md) (Project Root) |
| **Testing** | [`ops/TESTING_GUIDE.md`](ops/TESTING_GUIDE.md) |
| **Latest Review** | [`review-notes/update3.md`](review-notes/update3.md) |

---

## 📁 Directory Structure

```
docs/
├── PRODUCT_DESCRIPTION.md ........ Product narrative (SSOT)
├── PRD_v1.2.md ................... Requirements (SSOT)
├── SECRETS.md .................... Config & keys (never commit!)
├── CONTENTS.md ................... This file
│
├── design/ ....................... Design specifications
│   ├── ModernUI.md ............... Design system (Nov 2025)
│   ├── UI_UX_ASCII.md ............ UI schematics
│   └── LOGIC_MAP.md .............. System flows
│
├── ops/ .......................... Operational docs ⭐
│   ├── TODO.md ................... 50-item production roadmap
│   ├── START_HERE.md ............. Setup & onboarding
│   ├── TESTING_GUIDE.md .......... QA procedures
│   ├── VERIFICATION_CHECKLIST.md . Release gates
│   └── archive/ .................. Historical (85+ files)
│
└── review-notes/ ................. Reviews & analysis
    ├── update3.md ................ Latest UI review (Nov 3)
    ├── SPEC_KIT_REVIEW.md ........ Spec Kit analysis
    └── archive/ .................. Older reviews
```

---

## 🎯 Essential Documents (SSOT)

### Product & Requirements
- **[PRODUCT_DESCRIPTION.md](PRODUCT_DESCRIPTION.md)** - Product narrative, user stories
- **[PRD_v1.2.md](PRD_v1.2.md)** - Functional requirements, features
- **[SECRETS.md](SECRETS.md)** - Configuration guide ⚠️ Never commit!

### Development
- **[../README.md](../README.md)** - Architecture, setup, codebase map
- **[ops/TODO.md](ops/TODO.md)** - Active task list (50 items)
- **[ops/START_HERE.md](ops/START_HERE.md)** - New developer onboarding

### Quality & Testing
- **[ops/TESTING_GUIDE.md](ops/TESTING_GUIDE.md)** - Test procedures
- **[ops/VERIFICATION_CHECKLIST.md](ops/VERIFICATION_CHECKLIST.md)** - Release checklist

---

## 🎨 Design Documents

### UI/UX Specifications
- **[design/ModernUI.md](design/ModernUI.md)** - Design system (Nov 2025)
  - Dark mode palette (#0F1117)
  - Component library (WindowBar, StatusChip, ActionButtons)
  - Three-card planning view layout

- **[design/UI_UX_ASCII.md](design/UI_UX_ASCII.md)** - UI schematics
  - Screen layouts (ASCII art)
  - User flows
  - Component placement

- **[design/LOGIC_MAP.md](design/LOGIC_MAP.md)** - System logic flows
  - State transitions
  - Business rules
  - Data flows

---

## 📋 Operational Documents

### Active Development
- **[ops/TODO.md](ops/TODO.md)** ⭐ MASTER TASK LIST
  - 50 items to production
  - Prioritized by impact
  - Estimated effort per item
  - Dependencies mapped

- **[ops/START_HERE.md](ops/START_HERE.md)** - Setup guide
  - Prerequisites
  - Installation steps
  - First build
  - Common issues

- **[ops/TESTING_GUIDE.md](ops/TESTING_GUIDE.md)** - QA procedures
  - Unit test guide
  - UI test procedures
  - Manual testing checklist
  - Performance benchmarks

- **[ops/VERIFICATION_CHECKLIST.md](ops/VERIFICATION_CHECKLIST.md)** - Release gates
  - Pre-release checklist
  - Build verification
  - TestFlight requirements
  - App Store requirements

### Archive (Historical Reference)
- **[ops/archive/](ops/archive/)** - 85+ historical documents
  - Completion reports
  - Bug fix documentation
  - Session summaries
  - Implementation details
  - Status updates from past sprints

---

## 📝 Review & Analysis

### Current Reviews
- **[review-notes/update3.md](review-notes/update3.md)** - Latest UI/UX review
  - Modern UI feedback (Nov 3, 2025)
  - 50+ actionable items
  - Priority recommendations
  - Code snippets provided

- **[review-notes/SPEC_KIT_REVIEW.md](review-notes/SPEC_KIT_REVIEW.md)** - Spec Kit analysis
  - Constitution alignment check
  - Specification completeness
  - Implementation gaps

### Archived Reviews
- **[review-notes/archive/](review-notes/archive/)** - Older reviews
  - update2.md - Previous UI review
  - updates.md - Initial notes

---

## 🏗️ Implementation Status (November 2025)

### ✅ Complete
- Modern dark mode UI (#0F1117 background)
- Three-card planning view (Last/Tonight/Tomorrow)
- Night turnover integration
- Dose 2 gating system
- SwiftData models with lifecycle tracking
- Widget extension
- CSV export

### 🚧 In Progress
- Window status pill + next alert chip
- Dose 2 disabled reason captions
- Safety chips (planned vs logged split)
- Data source status chips

### 📅 Upcoming
- State chart documentation
- ClockProvider abstraction
- Feature flags & kill switches
- Comprehensive test suite
- Settings enhancements

**See:** [ops/TODO.md](ops/TODO.md) for complete roadmap

---

## 🔗 External References

### Spec Kit Integration
- **[../.specify/memory/constitution.md](../.specify/memory/constitution.md)** - Core principles
  - Safety First (dose limits)
  - Local-First Privacy (no cloud)
  - Clinician-Ready Data (export)

- **[../.specify/memory/spec.md](../.specify/memory/spec.md)** - Technical specification
  - Data models
  - API contracts
  - Business rules

- **[../.specify/memory/plan.md](../.specify/memory/plan.md)** - Project plan
  - Phases & milestones
  - Sprint planning
  - Resource allocation

### Historical Context
- **[v1.1.1b.md](v1.1.1b.md)** - Previous release notes
- **[../review/](../review/)** - Vendor review kits (archived)

---

## 📊 Document Lifecycle

### Active Documents (Updated Regularly)
- README.md (architecture SSOT)
- PRODUCT_DESCRIPTION.md (product SSOT)
- PRD_v1.2.md (requirements SSOT)
- ops/TODO.md (task SSOT)
- SECRETS.md (config SSOT - never commit!)

### Reference Documents (Stable)
- design/*.md (design specs)
- review-notes/update3.md (latest review)
- ops/START_HERE.md (setup guide)
- ops/TESTING_GUIDE.md (QA procedures)

### Archived Documents (Historical)
- ops/archive/ (85+ completion reports, bug fixes, status updates)
- review-notes/archive/ (older reviews)

---

## 🔄 Update Guidelines

**When to update this index:**
- New document created in docs/
- Document moved or renamed
- Major structural change to docs/
- New review or analysis added
- Quarterly cleanup (archive old docs)

**How to update:**
1. Edit this file (CONTENTS.md)
2. Update date at top
3. Add entry in appropriate section
4. Update status if needed
5. Commit with message: "docs: update CONTENTS.md - [reason]"

---

**Maintained by:** Development Team  
**Review Frequency:** After each sprint / major doc change  
**Next Review:** After Item 1-7 completion (Window pill + UI polish)
- `examples/` – Sample data artifacts when provided.
- `review/` – Consolidated and agent review kits (read-only reference).
- `scripts/` – helper shell scripts (`demo-server.sh`, `quick-test.sh`, installation checks).

Refer to the repository `README.md` for authoritative setup and architecture details.
