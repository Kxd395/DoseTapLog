# DoseTrack v1.1.1c - UI Wiring Update Kit

This bundle contains drop-in SwiftUI components, a view model, a stub controller, a settings panel, and a SQL migration for the event log.
All code is Apple native and tested in Xcode 15.4 on iOS 17 Simulators. Time handling is UTC for storage and local for display.

## Files

- Sources/DoseTrack/TodayViewModel.swift
- Sources/DoseTrack/SafetyBanner.swift
- Sources/DoseTrack/CountdownRing.swift
- Sources/DoseTrack/EventStrip.swift
- Sources/DoseTrack/EarlyDoseSheet.swift
- Sources/DoseTrack/SettingsView.swift
- Sources/DoseTrack/TodayLogView.swift
- Database/migrations/002_event_log_extensions.sql

## Quick install

1. Drag the `Sources/DoseTrack/*.swift` files into your app target.
2. Ensure your app has an App Group named `group.com.jefferson.dosetrack` or change the suite in `AppPreferences`.
3. Replace `RealDoseLogController` with your production controller that conforms to `DoseLogControllering`.
4. Apply SQL migration to your SQLite DB:
   ```sql
   .read Database/migrations/002_event_log_extensions.sql
   ```
5. Run the app. Open TodayLogView to verify ring, chips, and event strip.

## Feature highlights

- Window gating for Dose 2 with early override confirmation
- Safety banner with per-dose and nightly bounds
- Status chips for Health and WHOOP
- Countdown ring backed by TimelineView with 30 second ticks
- Event strip with single-level undo for the last 60 seconds
- Settings panel with total night grams, split presets, rounding step, window, and early policy
- Night context line with date, offset, and night key

## Manager note

- Added TodayViewModel with strict window gating and early override flow
- Added SafetyBanner, StatusChips, CountdownRing, EventStrip
- Added EarlyDoseSheet and SettingsView with App Group persistence
- Extended event_log to include early override and wake classification fields
- Live Activity hooks are surfaced on the controller protocol for your implementation

Updated: 2025-11-02
