import Foundation

/// ClockProvider: Abstraction for time sources to enable testing
/// Eliminates direct Date() calls from business logic
///
/// Usage:
///   Production: SystemClock.shared.now()
///   Testing:    TestClock(fixedTime: someDate).now()
///
/// Purpose: Prevent time-dependent bugs (DST, timezone, midnight crossing)
protocol ClockProvider {
    /// Current time in device timezone
    func now() -> Date
    
    /// Current time in UTC
    func nowUTC() -> Date
    
    /// Current timezone offset in minutes from UTC
    func localOffsetMinutes() -> Int
    
    /// Current timezone
    func localTimeZone() -> TimeZone
}

// MARK: - SystemClock (Production)

/// Production implementation using real system time
final class SystemClock: ClockProvider {
    static let shared = SystemClock()
    
    private init() {} // Singleton
    
    func now() -> Date {
        Date()
    }
    
    func nowUTC() -> Date {
        Date() // Date is always UTC internally
    }
    
    func localOffsetMinutes() -> Int {
        TimeZone.current.secondsFromGMT() / 60
    }
    
    func localTimeZone() -> TimeZone {
        TimeZone.current
    }
}

// MARK: - TestClock (Unit Tests)

/// Test implementation with controllable time
/// Allows simulating DST transitions, timezone changes, cutoff crossings
final class TestClock: ClockProvider {
    private var currentTime: Date
    private var timeZone: TimeZone
    
    /// Create test clock with fixed time
    init(fixedTime: Date, timeZone: TimeZone = .current) {
        self.currentTime = fixedTime
        self.timeZone = timeZone
    }
    
    /// Create test clock from components (easier for tests)
    /// Example: TestClock(year: 2025, month: 11, day: 5, hour: 11, minute: 59)
    init(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0, second: Int = 0, timeZone: TimeZone = .current) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        components.timeZone = timeZone
        
        self.currentTime = Calendar.current.date(from: components) ?? Date()
        self.timeZone = timeZone
    }
    
    func now() -> Date {
        currentTime
    }
    
    func nowUTC() -> Date {
        currentTime // Date is always UTC internally
    }
    
    func localOffsetMinutes() -> Int {
        timeZone.secondsFromGMT(for: currentTime) / 60
    }
    
    func localTimeZone() -> TimeZone {
        timeZone
    }
    
    // MARK: - Test Helpers
    
    /// Advance time by specified components
    func advance(hours: Int = 0, minutes: Int = 0, seconds: Int = 0) {
        var components = DateComponents()
        components.hour = hours
        components.minute = minutes
        components.second = seconds
        
        if let newTime = Calendar.current.date(byAdding: components, to: currentTime) {
            currentTime = newTime
        }
    }
    
    /// Set time to specific value
    func set(to date: Date) {
        currentTime = date
    }
    
    /// Set timezone (simulates user traveling)
    func setTimeZone(_ tz: TimeZone) {
        timeZone = tz
    }
    
    /// Simulate DST spring forward (+1 hour)
    /// Example: March 10, 2024, 2:00 AM → 3:00 AM
    func simulateDSTSpringForward() {
        advance(hours: 1)
    }
    
    /// Simulate DST fall back (-1 hour)
    /// Example: November 3, 2024, 2:00 AM → 1:00 AM
    func simulateDSTFallBack() {
        advance(hours: -1)
    }
}

// MARK: - Extensions for Common Scenarios

extension ClockProvider {
    /// Check if current time is within a date range
    func isNowWithin(start: Date, end: Date) -> Bool {
        let current = now()
        return current >= start && current <= end
    }
    
    /// Minutes between now and target date
    func minutesUntil(_ target: Date) -> Int {
        Int(target.timeIntervalSince(now()) / 60)
    }
    
    /// Minutes since target date
    func minutesSince(_ target: Date) -> Int {
        Int(now().timeIntervalSince(target) / 60)
    }
    
    /// Check if now is before noon (cutoff logic)
    func isBeforeNoon(cutoffHour: Int = 12) -> Bool {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now())
        return hour < cutoffHour
    }
    
    /// Check if now is after noon (cutoff logic)
    func isAfterNoon(cutoffHour: Int = 12) -> Bool {
        !isBeforeNoon(cutoffHour: cutoffHour)
    }
}

// MARK: - Usage Example in Documentation

/*
 BEFORE (Direct Date() calls - untestable):
 
 func logDose1() {
     night.dose1TimeUTC = Date()  // ❌ Cannot mock in tests
 }
 
 
 AFTER (ClockProvider injection - testable):
 
 final class DoseLogController {
     private let clock: ClockProvider
     
     init(clock: ClockProvider = SystemClock.shared) {
         self.clock = clock
     }
     
     func logDose1() {
         night.dose1TimeUTC = clock.now()  // ✅ Mockable in tests
     }
 }
 
 
 UNIT TEST:
 
 func testDose1LoggedAtCorrectTime() {
     let testClock = TestClock(year: 2025, month: 11, day: 5, hour: 22, minute: 30)
     let controller = DoseLogController(clock: testClock)
     
     controller.logDose1()
     
     XCTAssertEqual(night.dose1TimeUTC, testClock.now())
 }
 
 
 DST TEST:
 
 func testCutoffStillTriggersAfterDSTSpringForward() {
     let testClock = TestClock(year: 2024, month: 3, day: 10, hour: 11, minute: 59)
     
     // Before DST
     XCTAssertTrue(testClock.isBeforeNoon())
     
     // Spring forward at 2am → 3am
     testClock.simulateDSTSpringForward()
     
     // Now 12:59 (still before cutoff at 12:00)
     XCTAssertTrue(testClock.isBeforeNoon())
 }
*/
