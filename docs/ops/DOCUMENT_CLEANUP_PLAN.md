# Document Cleanup Plan - November 3, 2025

## 📋 Status: 90+ operational docs in docs/ops/ need cleanup

## ✅ KEEP (Essential Active Documents)

### Current Work
- **TODO.md** - Master task list (50 items, production roadmap)
- **UPDATE3_ACTION_PLAN.md** - Current UI/UX implementation guide
- **START_HERE.md** - Onboarding for new sessions

### Testing & Quality
- **TESTING_GUIDE.md** - Comprehensive test procedures
- **VERIFICATION_CHECKLIST.md** - QA checklist for releases

### Setup Guides (Consolidate into one)
- Keep ONE comprehensive setup guide (recommend START_HERE.md + TESTING_GUIDE.md)
- Archive all others

---

## 🗄️ ARCHIVE (Move to docs/ops/archive/)

### Completed Work (Session Summaries)
These are historical records - archive for reference:
- ACTION_CHECKLIST_COMPLETE.md
- ALL_DONE.md
- ALL_SET_UP.md
- APP_ICON_COMPLETE.md
- BUILD_COMPLETE.md
- BUILD_SUCCESS.md
- COMPLETE_FEATURE_SUMMARY_v1.1.1c.md
- COMPLETE_UI_COMPONENTS.md
- COMPLETION_REPORT.md
- DOSE2_GATING_COMPLETE.md
- DOSE2_OVERRIDE_IMPLEMENTATION.md
- EVERYTHING_WORKING.md
- FILES_ADDED_BUILD_NOW.md
- FINAL_REVIEW_SUMMARY.md
- FINAL_SUMMARY.md
- INTEGRATION_COMPLETE.md
- ITEM1_COMPLETION.md
- NEW_PROJECT_COMPLETE.md
- NIGHT_FLOW_INTEGRATION_COMPLETE.md
- ROOT_CLEANUP_COMPLETE.md
- SESSION_SUMMARY_COMPLETE.md
- SETUP_COMPLETE.md
- SPEC_KIT_COMPLETE.md
- TASKS_1-4_COMPLETION_REPORT.md
- TESTING_GUIDE_COMPLETE.md

### Issue Resolution (Historical)
Archive these troubleshooting docs:
- APPPREFERENCES_NAMING_FIXED.md
- APPPREFERENCES_OBSERVATION_FIXED.md
- BUILD_ERRORS_PHASE1_FIXED.md
- BUILD_FIX_PROGRESS.md
- DEPLOYMENT_TARGET_FIXED.md
- DUPLICATE_CLASS_FIXED.md
- FIX_WRONG_PLATFORM.md
- INFOPLIST_FIX.md
- SETTINGS_ACCESS_ISSUE.md
- SETTINGS_FIX_COMPLETE.md
- STATUSCHIP_FIX_AND_DEVICE_SUPPORT.md
- SWIFT_ERRORS_EXPLAINED.md
- SYNTAX_ERRORS_FIXED.md
- WAKE_SHEET_UI_FIX.md

### Setup Instructions (Redundant)
Keep ONE, archive duplicates:
- ACTION_CHECKLIST.md (redundant with TODO.md)
- ADD_FILES_TO_XCODE.md
- BUILD_STATUS.md
- DOSETRACK_NEW_SETUP.md
- HOW_TO_ADD_FILES_TO_XCODE.md
- HOW_TO_RUN_APP.md
- INSTALL_XCODE_FIRST.md
- INSTALLATION_SUMMARY.md
- INTEGRATION_STEPS.md
- QUICK_INTEGRATION_GUIDE.md
- STEP_1_CREATE_PROJECT.md
- STEP_2_ADD_FILES.md
- TESTING_QUICK_START.md (redundant with TESTING_GUIDE.md)
- XCODE_COMPLETE_SETUP.md
- XCODE_QUICK_START.md
- XCODE_SETUP_GUIDE.md
- WIDGET_EXTENSION_SETUP.md

### Implementation Details (Consolidated into TODO.md)
- ALARM_LADDER_IMPLEMENTATION.md
- ENHANCED_UI_IMPLEMENTATION.md
- LATE_DOSE_AND_UI_LAYOUTS.md
- MODERN_UI_PROGRESS.md
- NIGHT_TURNOVER_REFACTOR.md
- NIGHT_TURNOVER_SUMMARY.md
- SETTINGS_IMPLEMENTATION.md
- WAKE_EVENT_IMPLEMENTATION.md

### Spec Kit Analysis (Completed)
- SPECKIT_ANALYZE_INSTRUCTIONS.md
- SPECKIT_CHAT_COMMAND_NOTICE.md
- SPECKIT_MANUAL_ANALYSIS.md

### Status Reports (Redundant)
- AGENT_HANDOFF.md
- COMPONENT_COMPARISON.md
- CRITICAL_FINDINGS.md
- FINAL_2_STEPS.md
- INTEGRATION_REMEDIATION.md
- NEXT_STEPS_WAKE_EVENTS.md
- REPOSITORY_STATUS_REVIEW.md
- STATUS_TLDR.md

### Visual/Preview Docs
- APP_ICON_VISUAL_PREVIEW.md

---

## 🗂️ REVIEW DIRECTORY (/review/)

### KEEP
- **update3.md** - Latest comprehensive UI/UX review (move to docs/review-notes/)
- **ModernUI.md** - Design system spec (move to docs/design/)

### ARCHIVE
- update2.md (superseded by update3.md)
- updates.md (initial notes, superseded)
- DoseTrack_* directories (old review kits - keep as zip backups)

---

## 📁 RECOMMENDED FINAL STRUCTURE

```
docs/
├── PRD_v1.2.md (requirements)
├── PRODUCT_DESCRIPTION.md (narrative)
├── SECRETS.md (never commit)
├── CONTENTS.md (directory index)
│
├── design/
│   ├── ModernUI.md (moved from review/)
│   └── UI_UX_ASCII.md
│
├── ops/
│   ├── TODO.md ⭐ MASTER TASK LIST
│   ├── START_HERE.md ⭐ NEW USER ONBOARDING
│   ├── TESTING_GUIDE.md ⭐ QA PROCEDURES
│   ├── VERIFICATION_CHECKLIST.md ⭐ RELEASE GATES
│   │
│   └── archive/
│       └── [90+ historical docs]
│
└── review-notes/
    ├── update3.md (latest review - moved from review/)
    ├── SPEC_KIT_REVIEW.md
    └── archive/
        └── [older reviews]
```

---

## 🎯 ACTION PLAN

### Step 1: Create Archive Directories
```bash
mkdir -p docs/ops/archive
mkdir -p docs/review-notes/archive
```

### Step 2: Archive Completed Work (40+ files)
```bash
cd docs/ops
mv ACTION_CHECKLIST_COMPLETE.md archive/
mv ALL_DONE.md archive/
mv ALL_SET_UP.md archive/
# ... (see full list above)
```

### Step 3: Archive Issue Resolution Docs (15+ files)
```bash
mv APPPREFERENCES_NAMING_FIXED.md archive/
mv BUILD_ERRORS_PHASE1_FIXED.md archive/
# ... (see full list above)
```

### Step 4: Archive Redundant Setup Docs (20+ files)
```bash
mv ADD_FILES_TO_XCODE.md archive/
mv HOW_TO_ADD_FILES_TO_XCODE.md archive/
# ... (see full list above)
```

### Step 5: Move Review Documents
```bash
mv ../../review/update3.md ../review-notes/
mv ../../review/ModernUI.md ../design/
mv ../../review/update2.md ../review-notes/archive/
mv ../../review/updates.md ../review-notes/archive/
```

### Step 6: Update CONTENTS.md
Update the documentation index to reflect new structure.

---

## ✅ FINAL ACTIVE DOCUMENT SET (4 files in docs/ops/)

1. **TODO.md** - 50-item master task list
2. **START_HERE.md** - Quick start for new sessions
3. **TESTING_GUIDE.md** - Comprehensive QA procedures
4. **VERIFICATION_CHECKLIST.md** - Release checklist

**Total Reduction:** 90+ files → 4 files (96% cleanup)

---

## 🔍 ARCHIVE RETENTION POLICY

**Keep archived docs for:**
- Historical reference
- Troubleshooting similar future issues
- Understanding decision rationale
- Audit trail for development process

**Never delete:**
- Completion reports (session summaries)
- Critical findings documents
- Build fix history

---

## 📊 Summary

**Before Cleanup:**
- docs/ops/: 90+ files (overwhelming)
- review/: 13+ items (mixed purpose)

**After Cleanup:**
- docs/ops/: 4 active files
- docs/ops/archive/: 85+ historical docs
- docs/design/: ModernUI.md added
- docs/review-notes/: update3.md + archive

**Benefit:** Clear, navigable structure. New developers/AI agents can find current work instantly.

---

**Execute cleanup?** Run the commands above or request automation.
