#!/usr/bin/env swift

import Foundation

// Service-Day Calculator (Standalone Verification)
// Matches the logic in ServiceDayParityTests.swift

struct ParityTestCase: Codable {
    let startUTC: String
    let endUTC: String
    let cutoff: Int
    let tz: String
    
    enum CodingKeys: String, CodingKey {
        case startUTC = "start_utc"
        case endUTC = "end_utc"
        case cutoff
        case tz
    }
}

struct ParityResult: Codable {
    let caseIndex: Int
    let swiftKey: String
    
    enum CodingKeys: String, CodingKey {
        case caseIndex = "case_index"
        case swiftKey = "swift_key"
    }
}

func serviceDayKey(
    sleepStart: Date,
    sleepEnd: Date,
    cutoffHourLocal: Int,
    timeZone: TimeZone
) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    
    // Compute local dates for start/end
    let startLocal = calendar.dateComponents(in: timeZone, from: sleepStart).date!
    let endLocal = calendar.dateComponents(in: timeZone, from: sleepEnd).date!
    
    // Find all candidate service days that overlap [start, end]
    var candidates: [(day: Date, overlap: TimeInterval)] = []
    
    // Start checking from day BEFORE start (in case sample starts before cutoff)
    var candidateDate = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: startLocal))!
    
    // Scan up to 4 days (handles long samples + timezone quirks + early starts)
    for _ in 0..<4 {
        // Service day boundaries in target timezone
        // Service day labeled with the ENDING day (when you wake up)
        // So "Nov 4" service day = Nov 3 noon → Nov 4 noon
        let serviceDayStart = serviceDayBoundary(date: candidateDate, cutoff: cutoffHourLocal, tz: timeZone, calendar: calendar)
        let serviceDayEnd = serviceDayBoundary(
            date: calendar.date(byAdding: .day, value: 1, to: candidateDate)!,
            cutoff: cutoffHourLocal,
            tz: timeZone,
            calendar: calendar
        )
        
        // Compute overlap: max(0, min(end, dayEnd) - max(start, dayStart))
        let overlapStart = max(sleepStart, serviceDayStart)
        let overlapEnd = min(sleepEnd, serviceDayEnd)
        let overlap = max(0, overlapEnd.timeIntervalSince(overlapStart))
        
        if overlap > 0 {
            // Label with the ENDING day (next day after candidateDate)
            let serviceDay = calendar.date(byAdding: .day, value: 1, to: candidateDate)!
            candidates.append((day: serviceDay, overlap: overlap))
        }
        
        candidateDate = calendar.date(byAdding: .day, value: 1, to: candidateDate)!
        
        // Early exit if well past end date
        if candidateDate > calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: endLocal))! {
            break
        }
    }
    
    // Pick max overlap; ties → earlier day
    guard let winner = candidates.max(by: { a, b in
        if abs(a.overlap - b.overlap) < 0.01 { // Ties (within 10ms)
            return a.day > b.day // Earlier day wins
        }
        return a.overlap < b.overlap
    }) else {
        // Fallback: use start date
        return formatServiceDay(calendar.startOfDay(for: startLocal), timeZone: timeZone)
    }
    
    return formatServiceDay(winner.day, timeZone: timeZone)
}

/// Compute service day boundary in UTC for a given local date + cutoff hour
func serviceDayBoundary(
    date: Date,
    cutoff: Int,
    tz: TimeZone,
    calendar: Calendar
) -> Date {
    var cal = calendar
    cal.timeZone = tz
    
    var components = cal.dateComponents([.year, .month, .day], from: date)
    components.hour = cutoff
    components.minute = 0
    components.second = 0
    components.timeZone = tz
    
    return cal.date(from: components) ?? date
}

/// Format date as YYYY-MM-DD service day key
func formatServiceDay(_ date: Date, timeZone: TimeZone) -> String {
    // Extract the local date components in the target timezone
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
}

// Main execution
let casesPath = "/Users/kevindialmb/Downloads/DoseTrack_v1.1.1c/review/mlupdateInfo/tests/parity/parity_cases_100.json"

guard let data = try? Data(contentsOf: URL(fileURLWithPath: casesPath)) else {
    print("ERROR: Could not read test cases file")
    exit(1)
}

guard let testCases = try? JSONDecoder().decode([ParityTestCase].self, from: data) else {
    print("ERROR: Could not decode test cases")
    exit(1)
}

let formatter = ISO8601DateFormatter()
formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

for (index, testCase) in testCases.enumerated() {
    guard let startDate = formatter.date(from: testCase.startUTC),
          let endDate = formatter.date(from: testCase.endUTC),
          let timeZone = TimeZone(identifier: testCase.tz) else {
        continue
    }
    
    let serviceKey = serviceDayKey(
        sleepStart: startDate,
        sleepEnd: endDate,
        cutoffHourLocal: testCase.cutoff,
        timeZone: timeZone
    )
    
    let result = ParityResult(caseIndex: index, swiftKey: serviceKey)
    if let jsonData = try? JSONEncoder().encode(result),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print("PARITY_RESULT: \(jsonString)")
    }
}
