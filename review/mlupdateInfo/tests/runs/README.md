# Test Runs Evidence Log

This directory contains structured evidence for every test execution during Health Export v2 implementation.

## Structure

Each run is a timestamped directory: `YYYY-MM-DD_HH-MM-SS_run-NNN/`

Required files:
- `RUN.yaml` - Metadata (environment, commit, results, artifacts)
- `commands.sh` - Reproducible script to replay the run
- Logs (xcodebuild.log, node-tests.log, etc.)
- Artifacts (exports, manifests, screenshots)

## Run Index

| Run ID | Date | Commit | Status | Scope | Evidence |
|--------|------|--------|--------|-------|----------|
| [run-001](./2025-11-05_16-30-00_run-001/RUN.yaml) | 2025-11-05 | 71306c6 | Partial | Compilation fixes + parity test setup | 8 commits, 100 test cases generated |

## Evidence Gates (Required for RFE)

- [ ] **P0 Parity**: 100/100 Swift↔JS match (parity_report.json)
- [ ] **Anchors/Tombstones**: Export manifest with added/deleted counts
- [ ] **Deletion Cascade**: Normalizer log showing recomputed stats
- [ ] **Compression**: .jsonl.gz export + agent gunzip proof
- [ ] **Steps De-overlap**: HKStatisticsCollection aggregation log
- [ ] **Encryption**: Settings UI screenshot + encrypted export

## Next Run (002)

**Goal**: Execute Swift parity tests and validate 100/100 match

Commands:
```bash
cd DoseTrackNew
xcodebuild test -project DoseTrackNew.xcodeproj \
  -scheme DoseTrackNew \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:ServiceDayParityTests \
  -resultBundlePath ../review/mlupdateInfo/tests/runs/2025-11-05_XX-XX-XX_run-002/unit.xcresult

cd ../review/health-data-dropin/agent/dropins/health-data
node scripts/run-parity.js > ../../../../../../review/mlupdateInfo/tests/runs/2025-11-05_XX-XX-XX_run-002/parity_report.json
```

Expected: Green parity (100/100), .xcresult bundle, parity JSON report
