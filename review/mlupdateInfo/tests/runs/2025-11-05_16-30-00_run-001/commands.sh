#!/usr/bin/env bash
# Run 001: Compilation fixes + Parity test harness creation
# Date: 2025-11-05
# Commit: 71306c6

set -euo pipefail

echo "🏗️  Run 001: Compilation + Parity Test Setup"
echo "=============================================="
echo ""

# 1) Verify no compilation errors
echo "1️⃣  Checking Swift compilation..."
cd /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/DoseTrackNew
xcodebuild -project DoseTrackNew.xcodeproj \
  -scheme DoseTrackNew \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  clean build 2>&1 | tee ../review/mlupdateInfo/tests/runs/2025-11-05_16-30-00_run-001/xcodebuild_compile.log

# Extract errors/warnings
grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" \
  ../review/mlupdateInfo/tests/runs/2025-11-05_16-30-00_run-001/xcodebuild_compile.log \
  > ../review/mlupdateInfo/tests/runs/2025-11-05_16-30-00_run-001/build_summary.txt || true

echo ""
echo "2️⃣  Verifying parity test cases generated..."
ls -lh ../review/mlupdateInfo/tests/parity/parity_cases_100.json

echo ""
echo "3️⃣  Test harness files in place:"
ls -l DoseTrackNew/Tests/ServiceDayParityTests.swift
ls -l ../ios/Tests/ServiceDayParityTests.swift

echo ""
echo "✅ Setup complete. Ready for parity test execution (Run 002)."
