# DoseTrack Spec Kit Review & Update Recommendations

**Generated:** November 1, 2025  
**Project:** DoseTrack v1.1.1c  
**Status:** Spec Kit initialized and ready for use

---

## Executive Summary

DoseTrack is a well-structured, safety-critical iOS health application for Xywav medication tracking. The project has solid foundations with existing PRD v1.2, implementation notes, and a clean SwiftData/HealthKit architecture. This document provides comprehensive recommendations for leveraging Spec Kit to formalize, maintain, and evolve your specifications.

---

## Current State Analysis

### ✅ Strengths
- **Clear PRD**: PRD v1.2 defines goals, users, scope, and success metrics
- **Safety-first design**: Dosage guardrails (1.5-4.5g per dose, 3.0-9.0g total)
- **Local-first architecture**: No PHI transmission, SwiftData storage
- **Precision handling**: Full precision math with 0.25g display rounding
- **HealthKit integration**: Automatic final wake detection
- **Widget support**: One-tap logging via App Intents
- **Clinician-friendly CSV export**: HH:mm format keyed by bedtime date
- **UTC + timezone offset storage**: Correct cross-midnight handling

### ⚠️ Gaps Identified
1. **No formal constitution**: Principles scattered across docs
2. **Implementation drift risk**: No single source of truth for current state
3. **Missing technical spec**: Architecture decisions not formally documented
4. **Test coverage unclear**: Validation plan mentioned but not detailed
5. **Future enhancements undefined**: No v1.2+ roadmap
6. **WHOOP integration scope**: Proxy implementation details incomplete

---

## Recommended Spec Kit Workflow

### Phase 1: Establish Foundation (Week 1)

#### Step 1: Create Project Constitution
**Command:** `/speckit.constitution`

**What to include:**
```
Create a DoseTrack constitution focused on:

1. Safety & Medical Compliance
   - All dose calculations must respect guardrails (1.5-4.5g per dose, 3.0-9.0g nightly)
   - Never provide medical advice; suggestions are planning aids only
   - UTC + timezone offset for all timestamps to handle midnight crossings
   - Full precision math internally; 0.25g rounding only for display/save

2. Privacy & Data Sovereignty
   - 100% local-first: no cloud sync, no analytics, no PHI transmission
   - HealthKit data used only for final wake autofill with explicit consent
   - WHOOP proxy must gate with API key and rate limiting
   - App Group sharing only between app and widget on same device

3. User Experience
   - One-tap logging for dose events from app or widget
   - Auto-populate grams from latest night plan
   - Auto-schedule Dose 2 reminder based on window start
   - Autofill final wake from HealthKit or WHOOP when available
   - Validate sequences and alert on impossible timing

4. Code Quality
   - Swift native with SwiftData for persistence
   - Unit tests for ordering guards, CSV export, and rounding logic
   - Type-safe models with @Model and @Attribute(.unique) for nightKey
   - Enum-based configuration for all magic numbers

5. Clinician Support
   - CSV export in HH:mm format keyed to bedtime date
   - Include all relevant fields: doses, times, bathroom wakes, alertness
   - Target 80% clinician acceptance rate
```

**Expected outcome:** `.specify/memory/constitution.md` with versioned governance

---

#### Step 2: Document Current State Specification
**Command:** `/speckit.specify`

**What to include:**
```
Create a comprehensive specification for DoseTrack v1.1.1c that captures:

PRODUCT OVERVIEW
- Local-first iOS app for Xywav (twice-nightly medication) tracking
- Supports bedtime, two doses, bathroom wakes, final wake logging
- Widget for frictionless capture, CSV export for clinicians
- WHOOP proxy for sleep data and 7-day aggregates

USER PERSONAS
- Primary: Adult patient on twice-nightly Xywav
- Secondary: Treating clinician reviewing CSV logs

CORE WORKFLOWS
1. First-run onboarding: Collect bedtime preference and total nightly grams
2. Nightly planning: Generate dose split and window timing
3. Dose logging: One-tap from app or widget (Dose 1, Dose 2)
4. Final wake capture: Auto-fill from HealthKit or manual WHOOP fetch
5. CSV export: Generate clinician-friendly report

DATA MODEL
- DoseLog: SwiftData model keyed by nightKey (YYYY-MM-DD)
- Fields: nightStartUTC, timezoneOffsetMinutes, bedtime, dose1/2 times & grams, bathroom wakes, final wake, alertness, notes, provenance
- Ordering validation: dose2 must be after dose1, within window (150-240 min)

SAFETY GUARDRAILS
- Per dose: 1.5g to 4.5g
- Total nightly: 3.0g to 9.0g
- Dose 2 window: 150 to 240 minutes after Dose 1
- Full precision internally, 0.25g rounding for display

INTEGRATIONS
- HealthKit: Read Sleep Analysis for final wake autofill (NSHealthShareUsageDescription required)
- App Groups: group.com.jefferson.dosetrack for widget communication
- WHOOP proxy: /api/sleep/latest and /api/aggregates/7days with API key gate

NIGHT PLAN RECOMMENDER
- Split total grams by preferred percentage (default 50/50)
- Adjust Dose 1 by ±0.125g based on WHOOP recovery score (0-100)
- Clamp both doses to guardrails
- Return precise and display-rounded values

SUCCESS METRICS
- 90% capture rate (nights logged)
- 85% completeness (including final wake)
- 60% final wake autofilled from HealthKit
- 80% clinician CSV acceptance

NON-GOALS
- No cloud sync or multi-device support
- No analytics or telemetry
- No medication reminders beyond Dose 2
```

**Expected outcome:** `.specify/memory/spec.md` with full requirements

---

#### Step 3: Create Technical Implementation Plan
**Command:** `/speckit.plan`

**What to include:**
```
Create a technical implementation plan for DoseTrack that specifies:

TECHNOLOGY STACK
- Platform: iOS 16+ (SwiftUI, Swift 5.9+)
- Persistence: SwiftData with @Model and in-memory container for tests
- Health: HealthKit for Sleep Analysis queries
- Widgets: App Intents + App Groups for background writes
- Server: Node.js Express proxy (localhost only during pilot)

ARCHITECTURE
- SwiftUI app with @main DoseTrackApp
- ModelContainer with DoseLog schema
- Controllers: DoseLogController for CRUD operations
- Managers: HealthKitManager for HK authorization and queries
- Recommender: NightPlanRecommender for dose split calculations
- CSV: CSVExporter enum with header and row generation
- Config: Centralized constants (guardrails, window bounds)

MODELS
- DoseLog: @Model with @Attribute(.unique) nightKey, UTC timestamps, timezone offset
- NightPlan: struct with precise/display grams and window bounds
- AppGroupStore: UserDefaults wrapper for pending actions

VIEWS
- TodayLogView: Main logging interface with dose buttons and autofill
- Widget: DoseWidgetProvider with timeline updates

DATA FLOW
1. User taps "Log Dose 1" → Intent writes to App Group → App processes pending action
2. App reads pending action → Creates/updates DoseLog → Schedules Dose 2 reminder
3. HealthKit query → Fetch latest sleep end → Auto-populate final wake if recent
4. CSV export → Iterate DoseLog sorted by nightKey → Write HH:mm with offset

VALIDATION
- Unit tests: DoseLogTests for sequence validation, CSV formatting
- Manual testing: 14-day internal pilot with CSV clinician review

CAPABILITIES REQUIRED
- HealthKit: com.apple.developer.healthkit (read Sleep Analysis)
- App Groups: group.com.jefferson.dosetrack
- Notifications: Local notifications for Dose 2 reminder

DEPENDENCIES
- Express, express-rate-limit for server
- No third-party iOS dependencies (native Swift)

DEPLOYMENT
- Xcode project with bundle ID: com.jefferson.dosetrack
- Widget bundle ID: com.jefferson.dosetrack.widget
- Localhost server during pilot (no production deployment yet)
```

**Expected outcome:** `.specify/memory/plan.md` with architecture decisions

---

### Phase 2: Capture Current Implementation (Week 1-2)

#### Step 4: Break Down Into Tasks
**Command:** `/speckit.tasks`

**Prompt:**
```
Generate a task breakdown for documenting the current v1.1.1c implementation
```

**Expected outcome:** Checklist of documentation tasks

---

#### Step 5: Optional - Run Analysis
**Command:** `/speckit.analyze`

**Use case:** Verify constitution, spec, and plan are aligned

**Expected outcome:** Consistency report identifying any gaps or conflicts

---

### Phase 3: Plan Future Enhancements (Week 2+)

Now that you have a baseline, use Spec Kit to plan new features:

#### Example: HealthKit Final Wake Enhancement
```
/speckit.specify Build automatic final wake detection using HealthKit that:
- Queries Sleep Analysis samples with tolerance window (60 min default)
- Filters for accepted sleep states (REM, Core, Deep, Unspecified, InBed)
- Finds first end time after night anchor
- Auto-populates final wake field with "AppleHealth" provenance
- Falls back to manual entry if no recent data
- Provides user preference to disable auto-fill
```

Then continue with `/speckit.plan`, `/speckit.tasks`, `/speckit.implement`

---

## Specific Recommendations by Area

### 1. Constitution Principles

**Essential principles to formalize:**

- **Medical Safety**
  - All calculations MUST respect dose and timing guardrails
  - App provides planning aids, not medical advice
  - Display disclaimer on first launch
  
- **Data Precision**
  - UTC + timezone offset for all timestamps
  - Full precision (Double) for all calculations
  - 0.25g rounding ONLY for display and final save
  
- **Privacy First**
  - No PHI leaves device
  - HealthKit data never stored permanently
  - WHOOP proxy must authenticate and rate-limit
  
- **Testing Standards**
  - Unit tests for all safety-critical logic (ordering, guardrails, CSV)
  - Manual validation before any dose calculation changes
  - 14-day pilot for any major feature

---

### 2. Technical Spec Updates Needed

**Architecture decisions to document:**

1. **Why SwiftData vs Core Data?**
   - Document rationale: Swift-native, @Model convenience, typed queries

2. **Why nightKey (date string) vs Date primary key?**
   - Document: Human-readable CSV key, avoids timezone conversion issues

3. **Why separate dose1/dose2 fields vs array?**
   - Document: Type safety, explicit ordering, simpler CSV mapping

4. **Why App Groups vs direct widget SwiftData access?**
   - Document: Background execution reliability, pending action pattern

5. **WHOOP proxy vs direct API calls?**
   - Document: API key protection, rate limiting, aggregates computation

---

### 3. Missing Specifications

**Areas that need formal specs:**

#### A. Error Handling
```
/speckit.specify Define error handling for:
- HealthKit authorization denied
- WHOOP proxy unreachable or rate limited
- Invalid dose sequences (user override flow)
- Missing onboarding data
- CSV export failures
```

#### B. Notification Strategy
```
/speckit.specify Define notification requirements:
- Dose 2 reminder scheduling logic
- Reminder text and sound
- User preferences (enable/disable, custom timing)
- Handling when app is terminated
```

#### C. Data Migration
```
/speckit.specify Define data migration strategy for:
- SwiftData model schema changes
- Adding new fields to DoseLog
- Backward compatibility requirements
- User data preservation during updates
```

#### D. Testing Strategy
```
/speckit.specify Define comprehensive testing approach:
- Unit tests: Ordering validation, CSV formatting, rounding, recommender
- Integration tests: HealthKit mock queries, App Group communication
- UI tests: Logging flows, widget interaction
- Manual QA: 14-day pilot checklist
```

---

### 4. Version Planning

**Use Spec Kit for future versions:**

#### v1.2 (Current - Documentation)
- Use `/speckit.specify` to document current state as baseline
- Generate constitution and technical plan
- Create task list for any pending v1.1.1c work

#### v1.3 (Enhancements)
Potential features to spec:
- HealthKit deep integration (automatic detection, no manual WHOOP fetch)
- Morning alertness trends (7-day rolling average)
- Bathroom wake patterns (count, clustering)
- Export formats (PDF summary for patient)

#### v2.0 (Major Evolution)
Consider spec-driven approach for:
- iCloud sync (optional, user-controlled)
- Apple Watch complications
- HealthKit write (log doses as Medications in Health app)
- Clinician dashboard (read-only web view of CSVs)

**Workflow for new features:**
```bash
# 1. Create feature branch
git checkout -b feature/002-watch-complications

# 2. Specify the feature
/speckit.specify Build Apple Watch complications that show:
- Tonight's recommended Dose 1 and Dose 2
- Time remaining until Dose 2 window opens
- Quick "Log Dose" action
- Sync with phone via Watch Connectivity

# 3. Plan implementation
/speckit.plan Use WatchOS 10+, Watch Connectivity framework, shared App Group

# 4. Break into tasks
/speckit.tasks

# 5. Implement
/speckit.implement
```

---

### 5. Maintenance & Living Document

**Keep specs synchronized:**

1. **After every PR merge:**
   ```
   /speckit.specify Update the spec to reflect the changes in PR #123
   ```

2. **Quarterly reviews:**
   - Run `/speckit.analyze` to check for drift
   - Update constitution if principles evolve
   - Refresh success metrics based on pilot data

3. **Before major releases:**
   - Generate fresh spec from current state
   - Run `/speckit.checklist` for quality validation
   - Export spec.md and plan.md to `docs/` for archival

---

### 6. Immediate Action Items

**Week 1 Checklist:**

- [ ] Run `/speckit.constitution` with the recommended principles
- [ ] Run `/speckit.specify` with current state description
- [ ] Run `/speckit.plan` with technical architecture
- [ ] Review generated `.specify/memory/` artifacts
- [ ] Add `.github/prompts/` to `.gitignore` (contains AI context)
- [ ] Create `docs/specs/` folder and copy versioned specs for archival
- [ ] Run `/speckit.analyze` to validate consistency

**Week 2 Checklist:**

- [ ] Document missing error handling specs
- [ ] Document notification strategy
- [ ] Create testing strategy spec
- [ ] Define v1.3 enhancement candidates
- [ ] Set up quarterly spec review calendar reminder

---

## Integration with Existing Workflow

### Git Workflow
```bash
# Before starting a feature
git checkout -b feature/003-new-enhancement
/speckit.specify [describe feature]
/speckit.plan [tech approach]

# During development
git commit -m "feat: implement X per spec"

# After implementation
/speckit.specify Update spec to reflect implementation of feature 003
git add .specify/memory/spec.md
git commit -m "docs: update spec for feature 003"
```

### Documentation Structure
```
/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/
├── .specify/
│   ├── memory/
│   │   ├── constitution.md          # Living governance doc
│   │   ├── spec.md                  # Current requirements
│   │   └── plan.md                  # Current tech plan
│   ├── templates/                    # Spec Kit templates
│   └── scripts/                      # Automation helpers
├── docs/
│   ├── PRD_v1.2.md                  # Original PRD (archived)
│   ├── v1.1.1b.md                   # Patch notes (archived)
│   ├── specs/                       # **NEW** - Versioned spec snapshots
│   │   ├── v1.1.1c-spec.md
│   │   ├── v1.2.0-spec.md
│   │   └── ...
│   └── architecture/                # **NEW** - Technical decisions
│       ├── adr-001-swiftdata.md     # Architecture Decision Records
│       └── adr-002-app-groups.md
├── README.md                        # High-level overview
└── SPEC_KIT_RECOMMENDATIONS.md      # This document
```

---

## Quality Gates

**Before merging any spec changes:**

1. Run `/speckit.analyze` → No critical inconsistencies
2. Run `/speckit.checklist` → All items pass
3. Review with at least one other person
4. Update `docs/specs/vX.X.X-spec.md` snapshot

**Before releasing any version:**

1. Constitution ratified and dated
2. Spec reflects all implemented features
3. Plan documents all architectural decisions
4. CSV export tested with sample clinician
5. 14-day pilot completed with >85% capture rate

---

## Common Pitfalls to Avoid

1. **Don't let specs drift from code**
   - Update spec in the same PR that changes behavior
   - Use `/speckit.specify Update...` frequently

2. **Don't over-specify implementation details**
   - Focus on *what* and *why*, not exact Swift syntax
   - Leave room for refactoring within spec boundaries

3. **Don't skip the constitution**
   - Principles guide all future decisions
   - Prevents feature creep that violates safety or privacy

4. **Don't version specs only at releases**
   - Create snapshots for each significant feature
   - Easier to trace requirements → implementation → testing

---

## Success Metrics for Spec Kit Usage

Track these to measure Spec Kit value:

- **Specification coverage**: 100% of features have spec entries
- **Spec-code alignment**: <5% drift detected by `/speckit.analyze`
- **Decision traceability**: Every architecture choice documented in plan
- **Constitution stability**: <2 amendments per year
- **Onboarding time**: New contributors understand system from specs in <1 day

---

## Resources & Next Steps

### Learning Resources
- Spec Kit docs: https://github.com/github/spec-kit
- Spec-Driven Development guide: https://github.com/github/spec-kit/blob/main/spec-driven.md
- Video overview: https://www.youtube.com/watch?v=a9eR1xsfvHg

### Recommended First Commands

**Right now, in GitHub Copilot Chat:**

1. `/speckit.constitution` (paste the Safety & Medical Compliance section above)
2. `/speckit.specify` (paste the PRODUCT OVERVIEW section above)
3. `/speckit.plan` (paste the TECHNOLOGY STACK section above)

Then review the generated files in `.specify/memory/`

---

## Questions to Answer via Clarify

If any requirements are unclear, use `/speckit.clarify` before planning:

```
/speckit.clarify Ask questions about:
- What happens if user logs Dose 2 before Dose 1?
- Should bathroom wakes be required or optional fields?
- What level of WHOOP recovery score justifies dose adjustment?
- Should CSV include timezone offset column for clinician clarity?
- What happens if HealthKit returns multiple sleep sessions for one night?
```

---

## Conclusion

DoseTrack has a strong foundation and Spec Kit is now configured to help you:

1. **Formalize** existing knowledge into versioned, traceable specs
2. **Maintain** alignment between requirements, architecture, and code
3. **Evolve** the product with clear planning and validation workflows
4. **Communicate** decisions to future contributors and stakeholders

**Immediate next action:** Run `/speckit.constitution` with the principles outlined in Section "Step 1: Create Project Constitution"

---

*Generated by GitHub Copilot using Spec Kit analysis*  
*Review and adapt recommendations based on your team's workflow and priorities*
