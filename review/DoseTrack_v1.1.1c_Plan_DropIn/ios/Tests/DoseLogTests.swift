import XCTest
final class DoseLogTests: XCTestCase {
    func testDose2TooSoon() {
        let log = DoseLog(nightKey: "2025-11-01", nightStartUTC: Date(), timezoneOffsetMinutes: 0)
        log.dose1TimeUTC = Date()
        log.dose2TimeUTC = Date().addingTimeInterval(100 * 60)
        let (ok, err) = log.isValidSequence(windowStartMin: 150, windowEndMin: 240)
        XCTAssertFalse(ok)
        XCTAssertEqual(err, "Dose 2 too soon")
    }
}
