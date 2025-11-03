# GitHub Copilot Agent Instructions

## File Organization Rules (CRITICAL)

### ❌ NEVER Create Files in Project Root

**The project root should ONLY contain:**
- `README.md` (canonical SSOT)
- Standard config files (`.gitignore`, `.env.example`, `package.json`, etc.)
- Top-level directories: `ios/`, `server/`, `docs/`, `examples/`, `scripts/`, `.specify/`

### ✅ ALWAYS Use These Locations

| Document Type | Correct Location | Examples |
|---------------|------------------|----------|
| **Product documentation** | `docs/` | `PRODUCT_DESCRIPTION.md`, `PRD_v1.2.md`, `SECRETS.md` |
| **Operational guides** | `docs/ops/` | `ACTION_CHECKLIST.md`, `START_HERE.md`, `TESTING_GUIDE.md` |
| **Completion reports** | `docs/ops/` | `COMPLETION_REPORT.md`, `FINAL_SUMMARY.md` |
| **Review documents** | `docs/review-notes/` | `SPEC_KIT_REVIEW.md`, `PROJECT_REVIEW.md` |
| **Design docs** | `docs/design/` | `UI_UX_ASCII.md`, `LOGIC_MAP.md` |
| **Spec Kit memory** | `.specify/memory/` | `constitution.md`, `spec.md`, `plan.md` |
| **Scripts** | `scripts/` | `quick-test.sh`, `demo-server.sh` |
| **Examples** | `examples/` | `examples_sample_dosing.csv` |

### Rule Enforcement

**Before creating ANY document:**
1. Check if it's product docs → `docs/`
2. Check if it's operational → `docs/ops/`
3. Check if it's a review → `docs/review-notes/`
4. Check if it's design → `docs/design/`
5. If unsure → ASK THE USER before creating

**If you create a file in the wrong location:**
1. Immediately move it to the correct location
2. Update any references to the file
3. Apologize and explain the correct location

---

## Documentation Standards

### Constitution Principle: File Organization

**From `.specify/memory/constitution.md` - Development Workflow:**

```
Documentation Standards:
- README.md is the single source of truth for architecture
- PRODUCT_DESCRIPTION.md is the narrative companion to the PRD
- PRD (docs/PRD_v1.2.md) contains requirements
- Design docs (docs/design/) contain UI layouts and logic flows
- Operational docs (docs/ops/) contain guides and checklists
- Secrets go in docs/SECRETS.md (never committed)
- Spec Kit documents live in .specify/memory/
```

**Enforcement:**
- Constitution supersedes all other practices
- File organization violations are constitution violations
- When in doubt, refer to Constitution Principle III (Clinician-Ready Data) for documentation traceability

---

## Agent Behavior Rules

### When Creating Documents

1. **Determine Purpose First:**
   - Is this a product overview? → `docs/`
   - Is this operational guidance? → `docs/ops/`
   - Is this a review/analysis? → `docs/review-notes/`
   - Is this UI/logic design? → `docs/design/`
   - Is this Spec Kit memory? → `.specify/memory/`

2. **Check Existing Structure:**
   - Run `ls docs/` to see existing organization
   - Match naming patterns (e.g., all caps for ops guides)
   - Follow existing conventions

3. **Update References:**
   - If creating a new document, update `docs/CONTENTS.md` if it exists
   - Update `README.md` if it's a major document
   - Update `ACTION_CHECKLIST.md` if it's a completion artifact

4. **Avoid Root Clutter:**
   - Root directory should be clean and navigable
   - Only essential top-level files allowed
   - All narratives, reports, summaries go in `docs/`

### When Moving Files

If you realize a file is in the wrong location:

```bash
# Good approach
mv ROOT_FILE.md docs/ops/
# Then update any references in README.md, ACTION_CHECKLIST.md, etc.
```

### When Archiving Files

Legacy documents go in subdirectory archives:

```bash
# Example
mkdir -p docs/review-notes/archive
mv docs/review-notes/OLD_REVIEW.md docs/review-notes/archive/
```

---

## DoseTrack-Specific Rules

### Safety-Critical Documentation

Per Constitution Principle I (Safety First):
- Safety guardrails MUST be documented in:
  - `docs/PRD_v1.2.md`
  - `.specify/memory/constitution.md`
  - `.specify/memory/spec.md`
- All three must stay synchronized

### CSV Schema Documentation

Per Constitution Principle III (Clinician-Ready Data):
- CSV schema MUST be documented in:
  - `examples/examples_sample_dosing.csv` (actual example)
  - `.specify/memory/spec.md` (Appendix A)
  - `docs/PRODUCT_DESCRIPTION.md` (data model section)

### Secrets Management

Per Constitution Principle II (Local-First Privacy):
- Secrets documentation goes in `docs/SECRETS.md`
- Example files go in `server/.env.example`
- NEVER commit actual secrets
- Update `docs/SECRETS.md` when adding new config

---

## Quick Reference

### ✅ Good File Creation Examples

```bash
# Product documentation
docs/PRODUCT_DESCRIPTION.md
docs/PRD_v1.2.md
docs/SECRETS.md

# Operational guides
docs/ops/ACTION_CHECKLIST.md
docs/ops/START_HERE.md
docs/ops/COMPLETION_REPORT.md

# Reviews
docs/review-notes/SPEC_KIT_REVIEW.md
docs/review-notes/archive/OLD_REVIEW.md

# Design
docs/design/UI_UX_ASCII.md
docs/design/LOGIC_MAP.md

# Spec Kit
.specify/memory/constitution.md
.specify/memory/spec.md
.specify/memory/plan.md
```

### ❌ Bad File Creation Examples

```bash
# NEVER do this:
FINAL_SUMMARY.md              # Should be docs/ops/FINAL_SUMMARY.md
COMPLETION_REPORT.md          # Should be docs/ops/COMPLETION_REPORT.md
SPEC_KIT_REVIEW.md            # Should be docs/review-notes/SPEC_KIT_REVIEW.md
PROJECT_OVERVIEW.md           # Should be docs/PRODUCT_DESCRIPTION.md
```

---

## Enforcement

When you (the AI agent) create a file:

1. **Before creation:** Confirm location follows these rules
2. **After creation:** Verify it's in the correct directory
3. **If wrong:** Immediately move it and update references
4. **Document:** Note the file location in completion reports

---

**Version:** 1.0.0  
**Last Updated:** November 1, 2025  
**Supersedes:** All previous file organization practices  
**Authority:** Constitution Principle III (Clinician-Ready Data, Documentation Standards)
