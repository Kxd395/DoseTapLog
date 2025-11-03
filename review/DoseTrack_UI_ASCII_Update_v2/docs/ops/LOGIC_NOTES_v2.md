
# Dose 2 Eligibility and Overrides — Logic v2
Date: 2025-11-03

Eligibility states
- NoDose1: Dose 2 disabled
- Waiting: elapsed < windowStartMin
- Open: windowStartMin ≤ elapsed ≤ windowEndMin
- Expired: elapsed > windowEndMin

Button logic
- If NoDose1 → disable, reason "Log Dose 1 first"
- If Waiting and allowEarlyDose = false → disable, reason "Too early"
- If Waiting and allowEarlyDose = true and minutesUntilWindow ≤ maxEarlyMinutes
    → show EarlyDose sheet with default time prior buttons
- If Open → allow
- If Expired → convert to "Log missed dose" flow

Reset Night modes
- ArchiveNew: archive current night, mint new nightKey
- KeepEventsResetTimers: keep existing events, clear ring
- KeepDose1ClearDose2: keep Dose 1, clear Dose 2 and timers

Undo
- Allow within 60 s; soft delete event and recompute safety chips

Exports
- v_clinician_csv must include early overrides with reason and time prior
