# Review Plan

1. Prepare environment
   - Ensure Xcode 15.4+ and iOS 17 simulator installed.
   - Ensure Node 18+ and npm installed.
   - Ensure sqlite3 available.

2. Inventory repo layout
   - Expect: ios/, server/, docs/, review/.
   - Build the file map and detect duplicates.

3. Run static checks and builds
   - iOS: xcodebuild list and build. Capture warnings.
   - Server: npm ci, npm test. Capture logs.
   - SQLite: PRAGMA integrity_check if a DB exists.

4. Deep audit
   - UI wiring review.
   - Settings coverage vs behavior.
   - Schema alignment with SwiftData.

5. WHOOP proxy
   - Endpoint presence and middleware audit.
   - Optional local run and curl tests.

6. Report and remediation
   - Write REPORT.md, ISSUES.md, and PR plan.
