# DoseTrack Constitution

## Core Principles

### I. Safety First (NON-NEGOTIABLE)
Clinical safety requirements are immutable and enforced at multiple layers:
- **Dose bounds**: Each dose between 1.5 g and 4.5 g
- **Total bounds**: Nightly total between 3.0 g and 9.0 g  
- **Timing window**: Second dose must occur 150–240 minutes after first dose
- **Sequence validation**: Dose 2 cannot precede Dose 1
- **Precision math**: Internal calculations use full Double precision; 0.25 g rounding only at display and save boundaries
- All safety logic must have unit test coverage before merge

### II. Local-First Privacy
Patient health data never leaves the device except via explicit, user-initiated export:
- **SwiftData local storage** only; no cloud sync
- **HealthKit read-only**: Sleep Analysis accessed with permission, never persisted
- **WHOOP proxy isolation**: Server only relays API responses, never stores PHI
- **App Group containment**: Widget/intent handoff uses shared container, still local
- **CSV export**: User-controlled share sheet; no automatic transmission

### III. Clinician-Ready Data
Output must be immediately useful for clinical review without transformation:
- **UTC + offset pattern**: All timestamps stored in UTC with `timezoneOffsetMinutes` captured at logging time
- **HH:mm formatting**: CSV times formatted as HH:mm using the stored offset
- **One row per night**: CSV keyed by derived bedtime date (YYYY-MM-DD string)
- **Schema stability**: Changes to CSV structure require version migration and documentation
- **Provenance tracking**: Record source of autofilled data (e.g., "AppleHealth", "WHOOP")

### IV. SwiftUI & Swift 6 Patterns
Modern Swift patterns enforced to enable maintainability and concurrency safety:
- **SwiftUI lifecycle**: No UIKit view controllers; use SwiftUI screens and navigation
- **Main-actor safety**: UI updates and SwiftData access on MainActor
- **Sendable conformance**: Models and data types used across concurrency boundaries must be Sendable
- **Structured concurrency**: Prefer async/await over callbacks; no force-unwrapping of async results
- **View models**: Extract business logic from views into observable view models with clear responsibilities

### V. Testing & Validation
Comprehensive testing ensures safety requirements and data integrity:
- **Safety logic coverage**: All guardrail enforcement (dose bounds, window, sequence) must have XCTest coverage
- **CSV format tests**: Validate header, HH:mm formatting, timezone offset, ordering
- **Precision tests**: Verify internal math uses full Double, display/save rounds to 0.25 g
- **HealthKit mocking**: Test autofill logic with synthetic HKSamples
- **Integration tests**: Widget/intent handoff via App Group; WHOOP proxy endpoint validation
- **Pilot validation**: 14-day internal pilot with real-world CSV export before clinical deployment

### VI. Observability & Debuggability
System behavior must be transparent and diagnosable:
- **Structured logging**: Use Logger with subsystems (e.g., "DoseTrack.DoseLog", "DoseTrack.HealthKit")
- **Error propagation**: Surface failures to user with actionable messages; log full context
- **Debug builds**: Retain preview data and test configurations (e.g., in-memory SwiftData)
- **CSV traceability**: Each export includes metadata (export date, app version, row count)
- **Proxy logging**: Request/response logging with rate limit tracking; no PHI in logs

## Development Workflow

### Code Review Requirements
- All PRs must verify compliance with safety principles
- Changes to dose logic, CSV schema, or HealthKit integration require explicit safety review
- Test coverage must not decrease
- SwiftUI view changes require ASCII layout update in `docs/design/UI_UX_ASCII.md`

### Documentation Standards
- **README.md** is the single source of truth for architecture, setup, and roadmap
- **docs/PRODUCT_DESCRIPTION.md** provides narrative product context aligned with PRD
- **docs/PRD_v1.2.md** defines requirements and success metrics
- **docs/design/** contains UI layouts (ASCII) and logic maps (flow diagrams)
- **docs/ops/** contains operational guides, checklists, completion reports
- **docs/review-notes/** contains review documents and archived analyses
- **docs/SECRETS.md** documents all sensitive configuration (never commit secrets)
- **.specify/memory/** contains Spec Kit documents (constitution, spec, plan)
- **Project root** should ONLY contain README.md and essential config files
- Changes to data model, CSV schema, or API contracts require doc updates before merge
- **File organization violations**: Creating docs in root directory violates this principle

### File Placement Rules (Enforced)
| Document Type | Location | Examples |
|---------------|----------|----------|
| Product docs | `docs/` | PRODUCT_DESCRIPTION.md, PRD_v1.2.md, SECRETS.md |
| Operational guides | `docs/ops/` | ACTION_CHECKLIST.md, FINAL_SUMMARY.md |
| Review documents | `docs/review-notes/` | SPEC_KIT_REVIEW.md |
| Design documents | `docs/design/` | UI_UX_ASCII.md, LOGIC_MAP.md |
| Spec Kit documents | `.specify/memory/` | constitution.md, spec.md, plan.md |
| Scripts | `scripts/` | quick-test.sh, demo-server.sh |

**Enforcement**: AI agents must follow `.github/copilot-instructions.md` for file placement

### Deployment & Configuration
- **No secrets in source control**: Use `.env` for proxy, Info.plist placeholders for iOS
- **Versioning**: SemVer for app builds; API endpoint versioning for proxy
- **Breaking changes**: Require migration guide, backward compatibility plan, or major version bump
- **Pilot before production**: Internal validation with real WHOOP/HealthKit data before external release

## Governance

This constitution supersedes all other practices and patterns. Amendments require:
1. Documented justification (problem being solved)
2. Impact analysis (affected components, tests, docs)
3. Approval from project owner
4. Migration plan for existing code/data

All reviews and decisions must verify compliance with these principles. Complexity or exceptions must be justified in writing.

**Version**: 1.0.0  
**Ratified**: November 1, 2025  
**Last Amended**: November 1, 2025
