import Foundation
@inline(__always) func roundToQuarterGram(_ value: Double) -> Double { (value * 4.0).rounded() / 4.0 }
func safeDisplayGrams(_ value: Double) -> Double {
    let clamped = min(max(value, Config.perDoseMinG), Config.perDoseMaxG)
    return roundToQuarterGram(clamped)
}
