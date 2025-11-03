import Foundation
enum Config {
    static let defaultBedtimeHour = 23
    static let defaultBedtimeMinute = 30
    static let defaultTotalGrams = 6.5
    static let perDoseMinG = 1.5
    static let perDoseMaxG = 4.5
    static let totalNightMinG = 3.0
    static let totalNightMaxG = 9.0
    static let splitMinPercentFirst = 40.0
    static let splitMaxPercentFirst = 60.0
    static let windowStartMinAfterDose1 = 150
    static let windowEndMinAfterDose1 = 240
}
