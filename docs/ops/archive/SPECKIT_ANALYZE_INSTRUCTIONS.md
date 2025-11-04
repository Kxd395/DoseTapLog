# How to Run Spec Kit Analyze

**Date:** November 1, 2025  
**Purpose:** Validate consistency across Spec Kit documents

---

## ⚠️ Important: This is a Chat Command

The `/speckit.analyze` command **cannot be run in the terminal**. It must be executed in the **GitHub Copilot Chat** interface.

---

## Steps to Run

### 1. Open GitHub Copilot Chat

- Press `Cmd+Shift+I` (or click the chat icon in VS Code)
- This opens the Copilot Chat panel

### 2. Type the Command

In the chat input, type exactly:

```
/speckit.analyze
```

Press Enter.

### 3. What It Does

The command will:
- Read `.specify/memory/constitution.md`
- Read `.specify/memory/spec.md`
- Read `.specify/memory/plan.md`
- Validate consistency across all three documents
- Check for contradictions
- Identify missing requirements
- Report alignment issues

### 4. Expected Output

You should see a report covering:
- ✅ **Alignment checks** - Are principles in constitution reflected in spec and plan?
- ✅ **Completeness checks** - Are all requirements from spec addressed in plan?
- ✅ **Consistency checks** - Do documents contradict each other?
- ⚠️ **Gaps** - Missing elements or unclear specifications
- ❌ **Errors** - Contradictions or violations

### 5. Review Results

If the analyze command finds issues:
1. Note the specific contradictions or gaps
2. Update the relevant documents
3. Re-run `/speckit.analyze` to verify fixes

---

## Manual Validation (Alternative)

If `/speckit.analyze` is not available, I can perform manual validation:

### Constitution ✅ (Validated)
- 6 core principles defined
- Development workflow documented
- File organization rules added
- Governance model established
- Version 1.0.0

### Specification ✅ (Validated)
- Product overview aligned with constitution principles
- 3 user personas defined
- 5 core workflows documented
- Data model complete (DoseLog, NightPlan, AppGroupStore)
- Safety guardrails match constitution Principle I
- External integrations specified (HealthKit, WHOOP, Widget)
- Success metrics align with PRD
- Non-goals clearly stated
- Version 1.0.0

### Plan ✅ (Validated)
- Technical architecture aligns with constitution Principles II, IV, VI
- iOS stack matches specification requirements
- WHOOP proxy design reflects constitution Principle II (Local-First Privacy)
- Testing strategy implements constitution Principle V
- Build & deployment follows constitution deployment standards
- Version 1.0.0

### Cross-Document Alignment ✅

**Manual validation completed in `docs/review-notes/SPEC_KIT_REVIEW.md`:**
- 100% alignment score
- All critical concepts consistent across documents
- No contradictions found
- File organization rules now in constitution and copilot-instructions.md

---

## Known Issues (Fixed)

### ❌ Issue: Files in Root Directory
**Problem:** Completion documents were created in project root instead of `docs/ops/`

**Fix Applied:**
- Moved `FINAL_SUMMARY.md` → `docs/ops/`
- Moved `ACTION_CHECKLIST_COMPLETE.md` → `docs/ops/`
- Moved `SPEC_KIT_COMPLETE.md` → `docs/ops/`
- Added file organization rules to `.specify/memory/constitution.md`
- Created `.github/copilot-instructions.md` with enforcement rules

**Prevention:**
- Constitution now includes file placement table
- AI agents must follow `.github/copilot-instructions.md`
- File organization violations are constitution violations

---

## Validation Checklist

Before running `/speckit.analyze`, verify:

- [x] Constitution exists: `.specify/memory/constitution.md` ✅
- [x] Specification exists: `.specify/memory/spec.md` ✅
- [x] Plan exists: `.specify/memory/plan.md` ✅
- [x] All three documents are version 1.0.0 ✅
- [x] Constitution updated with file organization rules ✅
- [x] Copilot instructions created ✅
- [x] Files moved to correct locations ✅

**Status:** Ready for `/speckit.analyze` execution

---

## After Running Analyze

1. **Review findings** in the chat output
2. **Address any gaps** or contradictions
3. **Update documents** as needed
4. **Re-run analyze** to verify fixes
5. **Document results** in `docs/ops/COMPLETION_REPORT.md`

---

**Instructions Version:** 1.0.0  
**Created:** November 1, 2025  
**Location:** `docs/ops/SPECKIT_ANALYZE_INSTRUCTIONS.md`
