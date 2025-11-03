# Test Matrix

## iOS App

1. Build compiles on Xcode 15.4
   - Command: xcodebuild -scheme DoseTrack -destination 'platform=iOS Simulator,name=iPhone 15' build
   - Expected: Build succeeds with zero errors.

2. Dose 2 window gating
   - Set Dose 1 now, verify Dose 2 disabled until 150 min or early override path.
   - Expected: Disabled state before window, early override sheet allowed if policy true.

3. Live Activity start-end
   - Trigger Dose 1. Live Activity starts.
   - Trigger Dose 2 or let window expire. Live Activity ends.

4. Event strip and Undo
   - Log In bed, Dose 1, Bathroom. Undo last within 60 sec.
   - Expected: Undo reverts last event and removes it from recent list.

5. Reset Night safety
   - Start a night, then Reset Night.
   - Expected: Confirmation appears, all tonight events cleared, nightKey regenerated on next action.

## Server

1. Health endpoint
   - curl http://localhost:3000/health
   - Expected: status ok with JSON.

2. Auth middleware
   - curl /api/sleep/latest without API-KEY
   - Expected: 401 or 403.

3. Rate limit
   - Repeated calls 100 per minute to protected route.
   - Expected: 429 after limit.

## Database

1. Constraints and triggers
   - Insert out-of-bounds dose. Expect failure.

2. Nightly total guardrail
   - Insert two doses that exceed nightly max. Expect failure.

3. Window trigger
   - Insert Dose 2 earlier than 150 min. Expect failure or blocked by app logic.
