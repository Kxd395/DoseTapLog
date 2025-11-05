import XCTest
import Foundation

/// Parity test runner for serviceDayKey algorithm
/// Reads test cases from JSON and outputs results for comparison with JS implementation
final class ServiceDayParityTests: XCTestCase {
    
    func testParity100Cases() throws {
        let casesPath = "../../../review/mlupdateInfo/tests/parity/parity_cases_100.json"
        let url = URL(fileURLWithPath: casesPath, relativeTo: URL(fileURLWithPath: #file))
        
        guard let data = try? Data(contentsOf: url),
              let cases = try? JSONDecoder().decode([ParityCase].self, from: data) else {
            XCTFail("Failed to load parity cases from \(url.path)")
            return
        }
        
        for (index, testCase) in cases.enumerated() {
            let startDate = ISO8601DateFormatter().date(from: testCase.start_utc)!
            let endDate = ISO8601DateFormatter().date(from: testCase.end_utc)!
            let tz = TimeZone(identifier: testCase.tz)!
            
            let swiftKey = ServiceDayMaxOverlap.serviceDayKey(
                start: startDate,
                end: endDate,
                cutoffHourLocal: testCase.cutoff,
                tz: tz
            )
            
            // Output for parity script to parse
            let result = "{\"case_index\":\(index),\"swift_key\":\"\(swiftKey)\"}"
            print("PARITY_RESULT: \(result)")
        }
    }
}

struct ParityCase: Codable {
    let start_utc: String
    let end_utc: String
    let cutoff: Int
    let tz: String
}
