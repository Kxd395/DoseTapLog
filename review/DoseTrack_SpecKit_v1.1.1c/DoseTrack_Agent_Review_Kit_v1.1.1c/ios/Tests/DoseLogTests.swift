import XCTest
@testable import DoseTrack
final class DoseLogTests: XCTestCase {
    func testOrderingGuard() {
        let log = DoseLog(nightKey: "2025-10-31", nightStartUTC: Date(), timezoneOffsetMinutes: 0)
        log.dose1TimeUTC = Date(timeIntervalSince1970: 1000)
        log.dose2TimeUTC = Date(timeIntervalSince1970: 900)
        let res = log.isValidSequence(windowStartMin: 150, windowEndMin: 240)
        XCTAssertFalse(res.ok)
    }
    func testCSVHeader() {
        XCTAssertEqual(DoseLog.csvHeader(), "night_date,bedtime,dose1_time,dose1_g,dose2_time,dose2_g,bathroom_wakes,final_wake,morning_alertness,notes")
    }
}
