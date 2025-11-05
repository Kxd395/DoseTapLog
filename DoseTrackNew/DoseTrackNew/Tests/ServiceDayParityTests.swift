//
//  ServiceDayParityTests.swift
//  DoseTrack - Service-Day Parity Test Harness
//
//  Reads test cases from JSON and outputs results in parseable format
//  for comparison with Node.js implementation.
//

import XCTest
import Foundation

/// Parity test harness for ServiceDayCalculator.serviceDayKey()
/// Outputs results in format: PARITY_RESULT: {"case_index":0,"swift_key":"2025-11-04"}
final class ServiceDayParityTests: XCTestCase {
    
    struct ParityTestCase: Codable {
        let caseIndex: Int
        let startUTC: String
        let endUTC: String
        let cutoff: Int
        let tz: String
        
        enum CodingKeys: String, CodingKey {
            case caseIndex = "case_index"
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
    
    /// Test parity across all cases
    func testParityCases() throws {
        // Read test cases from JSON file
        let casesURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("review/mlupdateInfo/tests/parity/parity_cases_100.json")
        
        guard FileManager.default.fileExists(atPath: casesURL.path) else {
            XCTFail("Test cases file not found: \(casesURL.path)")
            return
        }
        
        let data = try Data(contentsOf: casesURL)
        let testCases = try JSONDecoder().decode([ParityTestCase].self, from: data)
        
        // Process each case
        for testCase in testCases {
            // Parse ISO8601 dates
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            guard let startDate = formatter.date(from: testCase.startUTC),
                  let endDate = formatter.date(from: testCase.endUTC) else {
                XCTFail("Failed to parse dates for case \(testCase.caseIndex)")
                continue
            }
            
            // Get timezone
            guard let timeZone = TimeZone(identifier: testCase.tz) else {
                XCTFail("Invalid timezone '\(testCase.tz)' for case \(testCase.caseIndex)")
                continue
            }
            
            // Call ServiceDayCalculator.serviceDayKey()
            let serviceKey = ServiceDayCalculator.serviceDayKey(
                sleepStart: startDate,
                sleepEnd: endDate,
                cutoffHourLocal: testCase.cutoff,
                timeZone: timeZone
            )
            
            // Output result in parseable format
            let result = ParityResult(caseIndex: testCase.caseIndex, swiftKey: serviceKey)
            if let jsonData = try? JSONEncoder().encode(result),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("PARITY_RESULT: \(jsonString)")
            }
        }
    }
}

/// ServiceDayCalculator implementation (standalone for tests)
/// This matches the logic in ServiceDayMaxOverlap.swift
enum ServiceDayCalculator {
    
    /// Calculate service-day key using maximum temporal overlap algorithm
    /// - Parameters:
    ///   - sleepStart: UTC start time of sleep window
    ///   - sleepEnd: UTC end time of sleep window
    ///   - cutoffHourLocal: Hour of day (0-23) for service-day cutoff in local time
    ///   - timeZone: Timezone for local time calculations
    /// - Returns: Service-day key in "yyyy-MM-dd" format
    static func serviceDayKey(
        sleepStart: Date,
        sleepEnd: Date,
        cutoffHourLocal: Int,
        timeZone: TimeZone
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        
        // Get candidate dates
        let startComponents = calendar.dateComponents([.year, .month, .day], from: sleepStart)
        let endComponents = calendar.dateComponents([.year, .month, .day], from: sleepEnd)
        
        guard let startDate = calendar.date(from: startComponents),
              let endDate = calendar.date(from: endComponents) else {
            return formatter.string(from: sleepStart) // fallback
        }
        
        // Generate all candidate service days between start and end
        var candidates: [(date: Date, overlap: TimeInterval)] = []
        var currentDate = startDate
        
        while currentDate <= endDate {
            // Calculate service-day boundaries (cutoff hour to next cutoff hour)
            let cutoffComponents = DateComponents(hour: cutoffHourLocal, minute: 0, second: 0)
            guard let dayStart = calendar.date(byAdding: cutoffComponents, to: currentDate),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
                continue
            }
            
            // Calculate overlap between sleep window and service day
            let overlapStart = max(sleepStart, dayStart)
            let overlapEnd = min(sleepEnd, dayEnd)
            let overlap = max(0, overlapEnd.timeIntervalSince(overlapStart))
            
            if overlap > 0 {
                candidates.append((date: currentDate, overlap: overlap))
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        // Return date with maximum overlap
        if let maxCandidate = candidates.max(by: { $0.overlap < $1.overlap }) {
            return formatter.string(from: maxCandidate.date)
        }
        
        // Fallback to start date
        return formatter.string(from: sleepStart)
    }
}
