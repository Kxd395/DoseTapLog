import XCTest
@testable import DoseTrack

/// Unit tests for ClockProvider abstraction
/// Verifies time mocking, DST handling, timezone changes
final class ClockProviderTests: XCTestCase {
    
    // MARK: - SystemClock Tests
    
    func testSystemClockReturnsRealTime() {
        let clock = SystemClock.shared
        let before = Date()
        let clockTime = clock.now()
        let after = Date()
        
        XCTAssertGreaterThanOrEqual(clockTime, before)
        XCTAssertLessThanOrEqual(clockTime, after)
    }
    
    func testSystemClockReturnsCurrentTimeZone() {
        let clock = SystemClock.shared
        let offsetMinutes = clock.localOffsetMinutes()
        let expectedOffset = TimeZone.current.secondsFromGMT() / 60
        
        XCTAssertEqual(offsetMinutes, expectedOffset)
    }
    
    // MARK: - TestClock Basic Tests
    
    func testTestClockReturnsFixedTime() {
        let fixedTime = Date(timeIntervalSince1970: 1699228800) // Nov 5, 2025, 12:00 PM UTC
        let clock = TestClock(fixedTime: fixedTime)
        
        XCTAssertEqual(clock.now(), fixedTime)
        XCTAssertEqual(clock.nowUTC(), fixedTime)
    }
    
    func testTestClockCreatedFromComponents() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 14, minute: 30)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: clock.now())
        
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 5)
        XCTAssertEqual(components.hour, 14)
        XCTAssertEqual(components.minute, 30)
    }
    
    // MARK: - Time Advancement Tests
    
    func testAdvanceByHours() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 10, minute: 0)
        let initialTime = clock.now()
        
        clock.advance(hours: 2)
        
        let expectedTime = initialTime.addingTimeInterval(2 * 3600)
        XCTAssertEqual(clock.now(), expectedTime)
    }
    
    func testAdvanceByMinutes() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 11, minute: 45)
        let initialTime = clock.now()
        
        clock.advance(minutes: 30)
        
        let expectedTime = initialTime.addingTimeInterval(30 * 60)
        XCTAssertEqual(clock.now(), expectedTime)
    }
    
    func testAdvanceAcrossMidnight() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 23, minute: 30)
        
        clock.advance(hours: 1)
        
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour], from: clock.now())
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 6) // Next day
        XCTAssertEqual(components.hour, 0)
    }
    
    func testAdvanceAcrossNoon() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 11, minute: 45)
        
        clock.advance(minutes: 30)
        
        let components = Calendar.current.dateComponents([.hour, .minute], from: clock.now())
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(components.minute, 15)
    }
    
    // MARK: - DST Tests (Critical for Cutoff Logic)
    
    func testDSTSpringForward() {
        // March 10, 2024, 1:59 AM PST → 3:00 AM PDT
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        let clock = TestClock(year: 2024, month: 3, day: 10, hour: 1, minute: 59, timeZone: pst)
        
        let beforeOffset = clock.localOffsetMinutes()
        
        clock.simulateDSTSpringForward()
        
        // After spring forward, time is 2:59 (but clock "skips" to 3:00 in reality)
        let afterOffset = clock.localOffsetMinutes()
        
        // Offset changes from -480 (PST) to -420 (PDT) = +60 minutes
        XCTAssertEqual(afterOffset, beforeOffset + 60)
    }
    
    func testDSTFallBack() {
        // November 3, 2024, 1:59 AM PDT → 1:00 AM PST
        let pdt = TimeZone(identifier: "America/Los_Angeles")!
        let clock = TestClock(year: 2024, month: 11, day: 3, hour: 1, minute: 59, timeZone: pdt)
        
        let beforeOffset = clock.localOffsetMinutes()
        
        clock.simulateDSTFallBack()
        
        let afterOffset = clock.localOffsetMinutes()
        
        // Offset changes from -420 (PDT) to -480 (PST) = -60 minutes
        XCTAssertEqual(afterOffset, beforeOffset - 60)
    }
    
    func testCutoffStillTriggersAfterDSTSpringForward() {
        // Key test: Cutoff at noon should still trigger even after DST
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        let clock = TestClock(year: 2024, month: 3, day: 10, hour: 11, minute: 59, timeZone: pst)
        
        XCTAssertTrue(clock.isBeforeNoon()) // 11:59 AM
        
        clock.advance(minutes: 2) // Now 12:01 PM
        
        XCTAssertFalse(clock.isBeforeNoon()) // After noon
    }
    
    // MARK: - Timezone Tests
    
    func testTimeZoneChangesPST() {
        let pst = TimeZone(identifier: "America/Los_Angeles")! // UTC-8
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 12, minute: 0, timeZone: pst)
        
        let offsetMinutes = clock.localOffsetMinutes()
        
        XCTAssertEqual(offsetMinutes, -480) // -8 hours = -480 minutes
    }
    
    func testTimeZoneChangesEST() {
        let est = TimeZone(identifier: "America/New_York")! // UTC-5
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 12, minute: 0, timeZone: est)
        
        let offsetMinutes = clock.localOffsetMinutes()
        
        XCTAssertEqual(offsetMinutes, -300) // -5 hours = -300 minutes
    }
    
    func testTimeZoneChangesUTC() {
        let utc = TimeZone(identifier: "UTC")!
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 12, minute: 0, timeZone: utc)
        
        let offsetMinutes = clock.localOffsetMinutes()
        
        XCTAssertEqual(offsetMinutes, 0)
    }
    
    func testSetTimeZoneSimulatesTravel() {
        let pst = TimeZone(identifier: "America/Los_Angeles")!
        let est = TimeZone(identifier: "America/New_York")!
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 12, minute: 0, timeZone: pst)
        
        let pstOffset = clock.localOffsetMinutes()
        XCTAssertEqual(pstOffset, -480)
        
        // User travels from LA to NY
        clock.setTimeZone(est)
        
        let estOffset = clock.localOffsetMinutes()
        XCTAssertEqual(estOffset, -300) // 3 hours ahead
    }
    
    // MARK: - Extension Helper Tests
    
    func testIsNowWithin() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 14, minute: 0)
        
        let start = clock.now().addingTimeInterval(-1800) // 30 min before
        let end = clock.now().addingTimeInterval(1800)    // 30 min after
        
        XCTAssertTrue(clock.isNowWithin(start: start, end: end))
        
        let futureStart = clock.now().addingTimeInterval(3600)
        let futureEnd = clock.now().addingTimeInterval(7200)
        
        XCTAssertFalse(clock.isNowWithin(start: futureStart, end: futureEnd))
    }
    
    func testMinutesUntil() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 14, minute: 0)
        let target = clock.now().addingTimeInterval(30 * 60) // 30 min in future
        
        let minutes = clock.minutesUntil(target)
        
        XCTAssertEqual(minutes, 30)
    }
    
    func testMinutesSince() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 14, minute: 30)
        let past = clock.now().addingTimeInterval(-45 * 60) // 45 min ago
        
        let minutes = clock.minutesSince(past)
        
        XCTAssertEqual(minutes, 45)
    }
    
    func testIsBeforeNoon() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 11, minute: 59)
        
        XCTAssertTrue(clock.isBeforeNoon())
        
        clock.advance(minutes: 2) // Now 12:01
        
        XCTAssertFalse(clock.isBeforeNoon())
    }
    
    func testIsAfterNoon() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 12, minute: 1)
        
        XCTAssertTrue(clock.isAfterNoon())
        
        clock.set(to: TestClock(year: 2025, month: 11, day: 5, hour: 11, minute: 59).now())
        
        XCTAssertFalse(clock.isAfterNoon())
    }
    
    func testCustomCutoffHour() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 13, minute: 30)
        
        // Default cutoff = 12:00
        XCTAssertFalse(clock.isBeforeNoon())
        
        // Custom cutoff = 14:00
        XCTAssertTrue(clock.isBeforeNoon(cutoffHour: 14))
    }
    
    // MARK: - Edge Cases
    
    func testMidnightCrossing() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 23, minute: 59)
        
        let beforeDay = Calendar.current.component(.day, from: clock.now())
        
        clock.advance(minutes: 2) // 00:01 next day
        
        let afterDay = Calendar.current.component(.day, from: clock.now())
        
        XCTAssertEqual(afterDay, beforeDay + 1)
    }
    
    func testNoonCrossing() {
        let clock = TestClock(year: 2025, month: 11, day: 5, hour: 11, minute: 59)
        
        XCTAssertTrue(clock.isBeforeNoon())
        
        clock.advance(minutes: 1) // 12:00 exactly
        
        XCTAssertFalse(clock.isBeforeNoon()) // Noon = not before noon
    }
    
    func testMonthBoundary() {
        let clock = TestClock(year: 2025, month: 10, day: 31, hour: 23, minute: 59)
        
        clock.advance(minutes: 2) // November 1, 00:01
        
        let components = Calendar.current.dateComponents([.month, .day], from: clock.now())
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 1)
    }
    
    func testYearBoundary() {
        let clock = TestClock(year: 2025, month: 12, day: 31, hour: 23, minute: 59)
        
        clock.advance(minutes: 2) // January 1, 2026, 00:01
        
        let components = Calendar.current.dateComponents([.year, .month, .day], from: clock.now())
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)
    }
}
