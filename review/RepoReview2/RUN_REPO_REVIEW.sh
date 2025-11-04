#!/usr/bin/env bash
set -euo pipefail

OUT="review/RepoReview/output"
LOG="$OUT/logs"
mkdir -p "$LOG"

echo "[iOS] Listing schemes"
xcodebuild -list > "$LOG/ios_list.log" || true

echo "[iOS] Building DoseTrack"
xcodebuild -scheme DoseTrack -destination 'platform=iOS Simulator,name=iPhone 15' build > "$LOG/ios_build.log" || true

if command -v swiftformat >/dev/null 2>&1; then
  echo "[iOS] SwiftFormat lint"
  swiftformat --lint ios/ > "$LOG/ios_swiftformat.log" || true
fi

if [ -d server ]; then
  echo "[Server] npm ci"
  (cd server && npm ci) > "$LOG/server_npm_ci.log" 2>&1 || true
  echo "[Server] npm test"
  (cd server && npm test) > "$LOG/server_test.log" 2>&1 || true
fi

echo "Done. Logs in $LOG"
