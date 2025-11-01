import XCTest
@testable import DoseTrack

final class DoseLogTests: XCTestCase {
    func testCSVHeader() {
        XCTAssertEqual(DoseLog.csvHeader(), "night_date,bedtime,dose1_time,dose1_g,dose2_time,dose2_g,bathroom_wakes,final_wake,morning_alertness,notes")
    }
}
