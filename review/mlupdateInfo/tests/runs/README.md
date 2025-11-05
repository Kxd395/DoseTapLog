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
| [run-001](./2025-11-05_16-30-00_run-001/RUN.yaml) | 2025-11-05 | 71306c6 | ✅ Complete | Compilation fixes + parity test setup | 8 commits, 100 test cases generated |
| [run-002](./2025-11-05_16-19-43_run-002/RUN.yaml) | 2025-11-05 | Current | ✅ **PASSED** | P0 Parity Gate: 100/100 Swift↔JS | Standalone Swift script, 100% match |

## Evidence Gates (Required for RFE)

- [x] **P0 Parity**: 100/100 Swift↔JS match (✅ Run 002: parity_report.md)
- [ ] **Anchors/Tombstones**: Export manifest with added/deleted counts
- [ ] **Deletion Cascade**: Normalizer log showing recomputed stats
- [ ] **Compression**: .jsonl.gz export + agent gunzip proof
- [ ] **Steps De-overlap**: HKStatisticsCollection aggregation log
- [ ] **Encryption**: Settings UI screenshot + encrypted export

## Next Run (003)

**Goal**: Integration testing - compression + encryption wiring

Commands:
```bash
# Run iOS app on simulator
# Export health data (should produce .jsonl.gz)
# Verify file format and compression
# Test encryption UI flow
```

Expected: Compressed export, encryption settings functional

---

**Run 002 Archived** - See [./2025-11-05_16-19-43_run-002/commands.sh](./2025-11-05_16-19-43_run-002/commands.sh) for reproduction steps
