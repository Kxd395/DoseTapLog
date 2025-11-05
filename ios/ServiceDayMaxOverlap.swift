// ServiceDayMaxOverlap.swift
// Deterministic service-day bucketing using maximum temporal overlap rule
// Handles DST, timezone changes, cutoff hour shifts

import Foundation

struct ServiceDayCalculator {
    
    /// Assign sample to service day with maximum temporal overlap.
    /// Ties → choose **earlier** day for stability.
    ///
    /// - Parameters:
    ///   - start: Sample start time (UTC)
    ///   - end: Sample end time (UTC)
    ///   - cutoffHourLocal: Hour of day (0-23) when service day begins
    ///   - tz: Timezone for local interpretation
    /// - Returns: Service day key in YYYY-MM-DD format
    static func serviceDayKey(
        start: Date,
        end: Date,
        cutoffHourLocal: Int,
        tz: TimeZone
    ) -> String {
        
        var calendar = Calendar.current
        calendar.timeZone = tz
        
        // Compute local dates for start/end
        let startLocal = calendar.dateComponents(in: tz, from: start).date!
        let endLocal = calendar.dateComponents(in: tz, from: end).date!
        
        // Find all candidate service days that overlap [start, end]
        var candidates: [(day: Date, overlap: TimeInterval)] = []
        
        var candidateDate = calendar.startOfDay(for: startLocal)
        
        // Scan up to 3 days (handles samples >24h or timezone quirks)
        for _ in 0..<3 {
            guard candidateDate <= calendar.startOfDay(for: endLocal).addingTimeInterval(86400) else { break }
            
            // Service day boundaries in UTC
            let serviceDayStart = serviceDayBoundary(date: candidateDate, cutoff: cutoffHourLocal, tz: tz)
            let serviceDayEnd = serviceDayBoundary(
                date: calendar.date(byAdding: .day, value: 1, to: candidateDate)!,
                cutoff: cutoffHourLocal,
                tz: tz
            )
            
            // Compute overlap: max(0, min(end, dayEnd) - max(start, dayStart))
            let overlapStart = max(start, serviceDayStart)
            let overlapEnd = min(end, serviceDayEnd)
            let overlap = max(0, overlapEnd.timeIntervalSince(overlapStart))
            
            if overlap > 0 {
                candidates.append((day: candidateDate, overlap: overlap))
            }
            
            candidateDate = calendar.date(byAdding: .day, value: 1, to: candidateDate)!
        }
        
        // Pick max overlap; ties → earlier day
        guard let winner = candidates.max(by: { a, b in
            if abs(a.overlap - b.overlap) < 0.01 { // Ties (within 10ms)
                return a.day > b.day // Earlier day wins
            }
            return a.overlap < b.overlap
        }) else {
            // Fallback: use start date
            return formatServiceDay(calendar.startOfDay(for: startLocal))
        }
        
        return formatServiceDay(winner.day)
    }
    
    /// Compute service day boundary in UTC for a given local date + cutoff hour
    private static func serviceDayBoundary(
        date: Date,
        cutoff: Int,
        tz: TimeZone
    ) -> Date {
        var calendar = Calendar.current
        calendar.timeZone = tz
        
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = cutoff
        components.minute = 0
        components.second = 0
        components.timeZone = tz
        
        return calendar.date(from: components) ?? date
    }
    
    /// Format date as YYYY-MM-DD service day key
    private static func formatServiceDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0) // Format in UTC
        return formatter.string(from: date)
    }
}

// MARK: - Extensions for HealthRecord

extension HealthRecord {
    
    /// Compute service day using max-overlap rule
    mutating func assignServiceDay(cutoffHourLocal: Int, tz: TimeZone) {
        guard let startUTC = ISO8601DateFormatter().date(from: self.startUTC),
              let endUTC = ISO8601DateFormatter().date(from: self.endUTC) else {
            return
        }
        
        self.serviceDayKey = ServiceDayCalculator.serviceDayKey(
            start: startUTC,
            end: endUTC,
            cutoffHourLocal: cutoffHourLocal,
            tz: tz
        )
    }
}

// MARK: - Unit Tests

#if DEBUG
import XCTest

class ServiceDayMaxOverlapTests: XCTestCase {
    
    func testNormalSleepPostCutoff() {
        // Sleep 23:30 → 06:30 (7h total, 6.5h post-cutoff)
        let start = iso8601("2025-11-03T23:30:00-05:00")! // 23:30 EST = 04:30 UTC
        let end = iso8601("2025-11-04T06:30:00-05:00")!   // 06:30 EST = 11:30 UTC
        
        let key = ServiceDayCalculator.serviceDayKey(
            start: start,
            end: end,
            cutoffHourLocal: 12,
            tz: TimeZone(identifier: "America/New_York")!
        )
        
        XCTAssertEqual(key, "2025-11-04", "Majority overlap is Nov 4 (6.5h vs 0.5h)")
    }
    
    func testEarlyBedtimePreCutoff() {
        // Sleep 21:00 → 04:00 (7h total, 3h pre-cutoff, 4h post-cutoff)
        let start = iso8601("2025-11-03T21:00:00-05:00")! // 21:00 EST = 02:00 UTC
        let end = iso8601("2025-11-04T04:00:00-05:00")!   // 04:00 EST = 09:00 UTC
        
        let key = ServiceDayCalculator.serviceDayKey(
            start: start,
            end: end,
            cutoffHourLocal: 12,
            tz: TimeZone(identifier: "America/New_York")!
        )
        
        // 21:00–00:00 = 3h in Nov 3 service day
        // 00:00–04:00 = 4h in Nov 4 service day
        XCTAssertEqual(key, "2025-11-04", "4h > 3h → Nov 4")
    }
    
    func testDSTSpringForward() {
        // DST on 2025-03-09 at 02:00 → 03:00 EST → EDT
        // Sleep 01:30 EST → 08:45 EDT (clock shows 01:30 → 08:45, but only 6.25h actual)
        let start = iso8601("2025-03-09T06:30:00Z")!  // 01:30 EST
        let end = iso8601("2025-03-09T12:45:00Z")!    // 08:45 EDT (07:45 EST equivalent)
        
        let key = ServiceDayCalculator.serviceDayKey(
            start: start,
            end: end,
            cutoffHourLocal: 12,
            tz: TimeZone(identifier: "America/New_York")!
        )
        
        XCTAssertEqual(key, "2025-03-09", "All within March 9 service day")
    }
    
    func testDSTFallBack() {
        // DST ends 2025-11-02 at 02:00 → 01:00 EDT → EST
        // Sleep 00:30 EDT → 07:30 EST (clock shows 8h, actual 9h)
        let start = iso8601("2025-11-02T04:30:00Z")!  // 00:30 EDT
        let end = iso8601("2025-11-02T12:30:00Z")!    // 07:30 EST
        
        let key = ServiceDayCalculator.serviceDayKey(
            start: start,
            end: end,
            cutoffHourLocal: 12,
            tz: TimeZone(identifier: "America/New_York")!
        )
        
        XCTAssertEqual(key, "2025-11-02", "All within Nov 2 service day")
    }
    
    func testExactTieEarlierDayWins() {
        // Sleep 00:00 → 12:00 (exactly 50/50 split around cutoff)
        let start = iso8601("2025-11-04T00:00:00-05:00")! // Midnight
        let end = iso8601("2025-11-04T12:00:00-05:00")!   // Noon (cutoff)
        
        let key = ServiceDayCalculator.serviceDayKey(
            start: start,
            end: end,
            cutoffHourLocal: 12,
            tz: TimeZone(identifier: "America/New_York")!
        )
        
        // Both Nov 3 and Nov 4 service days have 6h overlap
        // Tie → choose earlier (Nov 3)
        XCTAssertEqual(key, "2025-11-03", "Tie: earlier day wins")
    }
    
    func testShortNapSingleDay() {
        // Nap 14:00 → 15:30 (1.5h, entirely within Nov 4)
        let start = iso8601("2025-11-04T14:00:00-05:00")!
        let end = iso8601("2025-11-04T15:30:00-05:00")!
        
        let key = ServiceDayCalculator.serviceDayKey(
            start: start,
            end: end,
            cutoffHourLocal: 12,
            tz: TimeZone(identifier: "America/New_York")!
        )
        
        XCTAssertEqual(key, "2025-11-04")
    }
    
    // MARK: - Helpers
    
    func iso8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ISO8601DateFormatter().date(from: string)
    }
}
#endif
