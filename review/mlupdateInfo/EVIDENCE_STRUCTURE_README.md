# Health Export v2 – Evidence Drop (RFE)

**Generated:** 2025-11-05T01:49:06.430325Z  
**Purpose:** Single drop with code pointers, manifests, runtime artifacts, test outputs, screenshots, and sign-off gates for Health Export v2 production-readiness review.

## Folder Map

```
mlupdateInfo/
├─ EVIDENCE_STRUCTURE_README.md
├─ code_pointers/
│  ├─ swift_code_pointers.json
│  └─ agent_code_pointers.json
├─ manifests/
│  └─ MANIFEST_TEMPLATE.json
├─ runtime_artifacts/
│  ├─ exports/               # put real healthkit_export_*.jsonl(.gz) + dosetrack_export_*.jsonl(.gz) here
│  └─ logs/                  # xcodebuild logs, normalizer/validator logs
├─ tests/
│  ├─ parity/
│  │  ├─ PARITY_TEST_PLAN.md
│  │  └─ parity_cases_template.json
│  └─ unit/
│     └─ EXPECTED_COMMANDS.md
├─ screenshots/              # encryption_toggle.png, passphrase_flow.png, last_export_status.png
├─ signoff/
│  └─ P0_GATES_CHECKLIST.md
├─ status/
│  └─ STATUS_TRACKER.yaml
└─ scripts/
   └─ verify_evidence_structure.py
```

## What to Drop In

- **runtime_artifacts/exports/**: Actual `.jsonl` or `.jsonl.gz` exports and their manifests
- **runtime_artifacts/logs/**: `xcodebuild` test output, agent normalize logs, validation logs
- **tests/parity/**: `parity_100_cases.json` and `parity_report.md`
- **screenshots/**: UI screenshots proving encryption settings and status

## Verify Structure

Run:
```
python /mnt/data/review/mlupdateInfo/scripts/verify_evidence_structure.py
```
The script checks for required files, validates JSON/YAML, and reports gaps.
