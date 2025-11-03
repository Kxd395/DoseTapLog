//
//  Config.swift
//  DoseTrack
//
import Foundation

enum Config {
    // Dose guardrails
    static let perDoseMinG: Double = 1.5
    static let perDoseMaxG: Double = 4.5
    static let nightlyTotalMinG: Double = 3.0
    static let nightlyTotalMaxG: Double = 9.0

    // Dose 2 window in minutes after Dose 1
    static let windowStartMinAfterDose1: Int = 150
    static let windowEndMinAfterDose1: Int = 240

    // HealthKit window tolerance
    static let physioWindowPaddingMinutes: Int = 15

    // CSV
    static let csvDateFormat = "yyyy-MM-dd"
    static let csvTimeFormat = "HH:mm"
}
