import Foundation
enum Config {
    static let defaultBedtimeHour: Int = 23
    static let defaultBedtimeMinute: Int = 30
    static let defaultTotalGrams: Double = 6.5
    static let perDoseMinG: Double = 1.5
    static let perDoseMaxG: Double = 4.5
    static let totalNightMinG: Double = 3.0
    static let totalNightMaxG: Double = 9.0
    static let splitMinPercentFirst: Double = 40.0
    static let splitMaxPercentFirst: Double = 60.0
    static let windowStartMinAfterDose1: Int = 150
    static let windowEndMinAfterDose1: Int = 240
}
