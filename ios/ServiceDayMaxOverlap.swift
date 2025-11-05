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
