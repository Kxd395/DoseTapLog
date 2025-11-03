# DoseTrack v1.1.1c – Verification Log

Use this template to confirm the state of the project whenever you cut a build or hand off the repo. Replace the placeholders with fresh output. When in doubt, rerun the checks.

---

## 1. Snapshot
- **Date:** _YYYY-MM-DD_
- **Verifier:** _Name_
- **Commit:** `_git rev-parse HEAD_`
- **Overall status:** ✅ / ⚠️ (explain if not green)

---

## 2. Server Validation
```bash
cd server
npm install
cp .env.example .env   # if new environment; set real secrets
npm test               # TODO: add integration tests
npm start &
SERVER_PID=$!
sleep 2
curl -i http://localhost:3000/health
curl -i http://localhost:3000/api/sleep/latest            # expect 401 without header
curl -i -H "x-api-key: $API_KEY" http://localhost:3000/api/aggregates/7days
kill $SERVER_PID
```

Record the key results here:
- Health: _HTTP status / payload summary_
- Auth without key: _HTTP status_
- Auth with key: _HTTP status (200 or 500 with WHOOP detail)_
- Notes: _timeouts, missing token, etc._

---

## 3. iOS Validation
```bash
# Run from repository root
xcodebuild test \
  -scheme DoseTrack \
  -destination "platform=iOS Simulator,name=iPhone 15"
```

Include additional manual checks after the upcoming architecture refactor:
- Verify widget updates.
- Trigger HealthKit fetch (requires real data).
- Export CSV and confirm content.

Document findings:
- Tests: _pass/fail + log path_
- Manual smoke: _observations_

---

## 4. Lint & Formatting (Planned)
- `swift-format lint Sources` (once config lands)
- `swiftlint` (if adopted)
- `npm run lint` (when TypeScript/ESLint is added)

Note any deviations or TODOs if rules are not yet enforced.

---

## 5. Outstanding Issues
List open bugs or regressions uncovered during verification. Reference issue IDs or checklist items from `docs/ops/ACTION_CHECKLIST.md`.

---

## 6. Attachments
- Health check output
- xcodebuild logs
- Any screenshots or CSV samples (store in `artifacts/` if needed)

---

Keep this log evergreen: do not claim success without evidence, and archive older entries if the file becomes too long. The README remains the SSOT; this document captures point-in-time verification.
