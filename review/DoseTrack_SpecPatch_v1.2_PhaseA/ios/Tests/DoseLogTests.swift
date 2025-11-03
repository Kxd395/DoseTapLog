//
//  DoseLogTests.swift
//  DoseTrackTests
//
import XCTest
@testable import DoseTrack

final class DoseLogTests: XCTestCase {
    func testSequenceValidation() throws {
        let now = Date()
        let log = DoseLog(nightKey: "2025-11-01", nightStartUTC: now, timezoneOffsetMinutes: 0)
        log.dose1TimeUTC = now
        log.dose2TimeUTC = now.addingTimeInterval(200*60)
        let res = log.isValidSequence()
        XCTAssertTrue(res.0)
    }

    func testGuardrails() throws {
        let now = Date()
        let log = DoseLog(nightKey: "2025-11-01", nightStartUTC: now, timezoneOffsetMinutes: 0)
        log.dose1Grams = 3.0
        log.dose2Grams = 3.0
        let res = log.validateDoseGuardrails()
        XCTAssertTrue(res.0)
    }
}
