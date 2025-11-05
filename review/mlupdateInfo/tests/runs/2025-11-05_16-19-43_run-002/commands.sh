#!/bin/bash
# Run 002: Parity Validation - Reproduction Steps
# Execute from project root: /Users/kevindialmb/Downloads/DoseTrack_v1.1.1c

set -e  # Exit on error

echo "🧪 Run 002: Parity Validation (Swift ↔ JS)"
echo "=========================================="
echo ""

# Step 1: Verify environment
echo "1️⃣  Checking environment..."
swift --version
node --version
git rev-parse --abbrev-ref HEAD
git rev-parse HEAD
echo ""

# Step 2: Run parity test
echo "2️⃣  Executing parity test (100 cases)..."
node review/health-data-dropin/agent/dropins/health-data/scripts/run-parity.js
PARITY_EXIT=$?
echo ""

# Step 3: Check results
echo "3️⃣  Verifying results..."
if [ $PARITY_EXIT -eq 0 ]; then
    echo "✅ PARITY TEST PASSED"
    echo ""
    echo "📊 Results:"
    grep "Total Cases:" review/mlupdateInfo/tests/parity/parity_report.md
    grep "Pass:" review/mlupdateInfo/tests/parity/parity_report.md
    grep "Fail:" review/mlupdateInfo/tests/parity/parity_report.md
    echo ""
    exit 0
else
    echo "❌ PARITY TEST FAILED (exit code: $PARITY_EXIT)"
    echo ""
    echo "📄 See detailed report:"
    echo "   review/mlupdateInfo/tests/parity/parity_report.md"
    echo ""
    exit 1
fi
