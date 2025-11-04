//
//  NightTurnoverTests.swift
//  DoseTrackTests
//
//  Unit tests for Night Turnover System (cutoff crossing, auto-close, minting)
//

import XCTest
import SwiftData
@testable import DoseTrack

@MainActor
final class NightTurnoverTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    var controller: NightTurnoverController!
    var prefs: AppPreferencesEnhanced!
    
    override func setUp() async throws {
        // Create in-memory container
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: DoseLog.self, configurations: config)
        context = ModelContext(container)
        
        // Set up preferences with noon cutoff
        prefs = AppPreferencesEnhanced.shared
        prefs.cutoffHourLocal = 12
        
        // Create controller
        controller = NightTurnoverController(modelContext: context, preferences: prefs)
    }
    
    override func tearDown() async throws {
        container = nil
        context = nil
        controller = nil
    }
    
    // MARK: - Midnight Crossing Tests
    
    func testMidnightCrossing_DoesNotTriggerTurnover() throws {
        // Midnight crossing should be a no-op (cutoff is noon)
        
        // Create a night from yesterday
        let yesterdayKey = "2025-11-02"
        let yesterday = DoseLog(
            nightKey: yesterdayKey,
            nightStartUTC: Date().addingTimeInterval(-86400),
            timezoneOffsetMinutes: -300
        )
        yesterday.currentLifecycleState = .active
        context.insert(yesterday)
        try context.save()
        
        // Simulate midnight crossing (11:59 PM → 12:01 AM)
        // This should NOT close yesterday's night (cutoff is noon)
        let changesMade = controller.handleCutoffCrossing()
        
        XCTAssertFalse(changesMade, "Midnight crossing should not trigger turnover")
        XCTAssertEqual(yesterday.currentLifecycleState, .active, "Yesterday's night should still be active")
    }
    
    // MARK: - Noon Crossing Tests
    
    func testNoonCrossing_AutoClosesLingeringNight() throws {
        // Noon crossing should auto-close nights from before last night
        
        // Create a night from 2 days ago (should be closed)
        let twoDaysAgoKey = "2025-11-01"
        let twoDaysAgo = DoseLog(
            nightKey: twoDaysAgoKey,
            nightStartUTC: Date().addingTimeInterval(-172800), // 2 days
            timezoneOffsetMinutes: -300
        )
        twoDaysAgo.currentLifecycleState = .active  // Still active (lingering)
        context.insert(twoDaysAgo)
        
        // Create last night (should NOT be closed)
        let lastNightKey = NightServiceDay.lastNightKey(cutoffHour: 12)
        let lastNight = DoseLog(
            nightKey: lastNightKey,
            nightStartUTC: Date().addingTimeInterval(-86400),
            timezoneOffsetMinutes: -300
        )
        lastNight.currentLifecycleState = .active
        context.insert(lastNight)
        
        try context.save()
        
        // Trigger cutoff crossing
        let changesMade = controller.handleCutoffCrossing()
        
        XCTAssertTrue(changesMade, "Cutoff crossing should make changes")
        XCTAssertEqual(twoDaysAgo.currentLifecycleState, .closed, "2-day-old night should be closed")
        XCTAssertNotNil(twoDaysAgo.autoClosedAt, "autoClosedAt should be set")
        XCTAssertEqual(lastNight.currentLifecycleState, .active, "Last night should still be active")
    }
    
    func testNoonCrossing_MintsTonight() throws {
        // Noon crossing should mint tonight if it doesn't exist
        
        let tonightKey = NightServiceDay.tonightKey(cutoffHour: 12)
        
        // Ensure tonight doesn't exist yet
        let descriptor = FetchDescriptor<DoseLog>(
            predicate: #Predicate { $0.nightKey == tonightKey }
        )
        let existing = try context.fetch(descriptor)
        XCTAssertTrue(existing.isEmpty, "Tonight should not exist yet")
        
        // Trigger cutoff crossing
        let changesMade = controller.handleCutoffCrossing()
        
        XCTAssertTrue(changesMade, "Minting tonight should make changes")
        
        // Verify tonight was minted
        let minted = try context.fetch(descriptor)
        XCTAssertEqual(minted.count, 1, "Tonight should be minted")
        XCTAssertEqual(minted.first?.currentLifecycleState, .planned, "Tonight should be in planned state")
        XCTAssertNotNil(minted.first?.plannedDose1Time, "plannedDose1Time should be set")
    }
    
    func testNoonCrossing_IdempotentMinting() throws {
        // Calling handleCutoffCrossing() multiple times should not create duplicate tonights
        
        let tonightKey = NightServiceDay.tonightKey(cutoffHour: 12)
        
        // First call: mint tonight
        let changesMade1 = controller.handleCutoffCrossing()
        XCTAssertTrue(changesMade1, "First call should mint tonight")
        
        // Second call: should detect tonight exists
        let changesMade2 = controller.handleCutoffCrossing()
        XCTAssertFalse(changesMade2, "Second call should not make changes (idempotent)")
        
        // Verify only one tonight exists
        let descriptor = FetchDescriptor<DoseLog>(
            predicate: #Predicate { $0.nightKey == tonightKey }
        )
        let nights = try context.fetch(descriptor)
        XCTAssertEqual(nights.count, 1, "Should only have one tonight session")
    }
    
    // MARK: - DST Transition Tests
    
    func testDSTSpringForward_CutoffStillWorks() throws {
        // Spring forward (2 AM → 3 AM): cutoff at noon should still work
        
        // Create a night from yesterday (before DST change)
        let yesterdayKey = "2025-03-08" // Example DST date
        let yesterday = DoseLog(
            nightKey: yesterdayKey,
            nightStartUTC: Date(),
            timezoneOffsetMinutes: -300  // EST
        )
        yesterday.currentLifecycleState = .active
        context.insert(yesterday)
        try context.save()
        
        // After DST change, timezone offset would be -240 (EDT)
        // But cutoff logic uses wall clock time (noon local)
        
        let changesMade = controller.handleCutoffCrossing()
        
        // Should close yesterday and mint today regardless of DST
        XCTAssertTrue(changesMade, "DST should not prevent turnover")
        XCTAssertEqual(yesterday.currentLifecycleState, .closed, "Yesterday should be closed")
    }
    
    func testDSTFallBack_CutoffStillWorks() throws {
        // Fall back (2 AM → 1 AM): cutoff at noon should still work
        
        let yesterdayKey = "2025-11-01" // Example DST date
        let yesterday = DoseLog(
            nightKey: yesterdayKey,
            nightStartUTC: Date(),
            timezoneOffsetMinutes: -240  // EDT
        )
        yesterday.currentLifecycleState = .active
        context.insert(yesterday)
        try context.save()
        
        // After DST change, timezone offset would be -300 (EST)
        
        let changesMade = controller.handleCutoffCrossing()
        
        XCTAssertTrue(changesMade, "DST should not prevent turnover")
        XCTAssertEqual(yesterday.currentLifecycleState, .closed, "Yesterday should be closed")
    }
    
    // MARK: - Timezone Hop Tests
    
    func testTimezoneHop_EastWest() throws {
        // Travel from NYC (EST) to LA (PST) - 3 hour difference
        
        let tonightBefore = controller.fetchTonight()
        
        // Simulate timezone change from EST to PST
        let previousTZ = TimeZone(identifier: "America/New_York")!
        let currentTZ = TimeZone(identifier: "America/Los_Angeles")!
        
        // Mint tonight in EST
        controller.mintTonightIfNeeded()
        try context.save()
        
        let tonightEST = controller.fetchTonight()
        XCTAssertNotNil(tonightEST, "Tonight should be minted in EST")
        
        let plannedTimeEST = tonightEST?.plannedDose1Time
        
        // Handle timezone change with local rebase
        controller.handleTimeZoneChange(
            from: previousTZ,
            to: currentTZ,
            action: .local
        )
        
        let tonightPST = controller.fetchTonight()
        XCTAssertNotNil(tonightPST, "Tonight should still exist after rebase")
        
        // Planned time should be different (rebased to local)
        let plannedTimePST = tonightPST?.plannedDose1Time
        XCTAssertNotEqual(plannedTimeEST, plannedTimePST, "Planned time should be rebased")
    }
    
    // MARK: - State Transition Tests
    
    func testStateTransition_ValidForwardPath() throws {
        let night = DoseLog(
            nightKey: "2025-11-03",
            nightStartUTC: Date(),
            timezoneOffsetMinutes: -300
        )
        night.currentLifecycleState = .planned
        context.insert(night)
        
        // planned → armed (valid)
        controller.transition(night, to: .armed)
        XCTAssertEqual(night.currentLifecycleState, .armed)
        
        // armed → active (valid)
        controller.transition(night, to: .active)
        XCTAssertEqual(night.currentLifecycleState, .active)
        
        // active → windowOpen (valid)
        controller.transition(night, to: .windowOpen)
        XCTAssertEqual(night.currentLifecycleState, .windowOpen)
        
        // windowOpen → awaitWake (valid)
        controller.transition(night, to: .awaitWake)
        XCTAssertEqual(night.currentLifecycleState, .awaitWake)
        
        // awaitWake → closed (valid)
        controller.transition(night, to: .closed)
        XCTAssertEqual(night.currentLifecycleState, .closed)
    }
    
    func testStateTransition_InvalidBackwardPath() throws {
        let night = DoseLog(
            nightKey: "2025-11-03",
            nightStartUTC: Date(),
            timezoneOffsetMinutes: -300
        )
        night.currentLifecycleState = .active
        context.insert(night)
        
        // active → planned (invalid - can't go backward)
        controller.transition(night, to: .planned)
        XCTAssertEqual(night.currentLifecycleState, .active, "Should not allow backward transition")
    }
    
    func testStateTransition_ResetFromAnyState() throws {
        let night = DoseLog(
            nightKey: "2025-11-03",
            nightStartUTC: Date(),
            timezoneOffsetMinutes: -300
        )
        night.currentLifecycleState = .windowOpen
        context.insert(night)
        
        // Any state → abandoned (valid - reset/skip)
        controller.transition(night, to: .abandoned, reason: "User reset")
        XCTAssertEqual(night.currentLifecycleState, .abandoned)
    }
    
    // MARK: - Query Helper Tests
    
    func testFetchTonight() throws {
        // Mint tonight
        controller.mintTonightIfNeeded()
        try context.save()
        
        let tonight = controller.fetchTonight()
        XCTAssertNotNil(tonight, "fetchTonight should return tonight")
        XCTAssertEqual(tonight?.nightKey, NightServiceDay.tonightKey(cutoffHour: 12))
    }
    
    func testFetchLastNight() throws {
        // Create last night
        let lastNightKey = NightServiceDay.lastNightKey(cutoffHour: 12)
        let lastNight = DoseLog(
            nightKey: lastNightKey,
            nightStartUTC: Date().addingTimeInterval(-86400),
            timezoneOffsetMinutes: -300
        )
        context.insert(lastNight)
        try context.save()
        
        let fetched = controller.fetchLastNight()
        XCTAssertNotNil(fetched, "fetchLastNight should return last night")
        XCTAssertEqual(fetched?.nightKey, lastNightKey)
    }
    
    func testFetchActiveNights() throws {
        // Create mix of active and closed nights
        let active1 = DoseLog(nightKey: "2025-11-01", nightStartUTC: Date(), timezoneOffsetMinutes: -300)
        active1.currentLifecycleState = .active
        
        let active2 = DoseLog(nightKey: "2025-11-02", nightStartUTC: Date(), timezoneOffsetMinutes: -300)
        active2.currentLifecycleState = .windowOpen
        
        let closed1 = DoseLog(nightKey: "2025-10-31", nightStartUTC: Date(), timezoneOffsetMinutes: -300)
        closed1.currentLifecycleState = .closed
        
        context.insert(active1)
        context.insert(active2)
        context.insert(closed1)
        try context.save()
        
        let activeNights = controller.fetchActiveNights()
        XCTAssertEqual(activeNights.count, 2, "Should return only active nights")
        XCTAssertTrue(activeNights.contains(where: { $0.nightKey == "2025-11-01" }))
        XCTAssertTrue(activeNights.contains(where: { $0.nightKey == "2025-11-02" }))
    }
}
