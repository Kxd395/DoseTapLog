import Foundation
@inline(__always) func roundToQuarterGram(_ v: Double) -> Double { (v * 4.0).rounded() / 4.0 }
func safeDisplayGrams(_ v: Double) -> Double { roundToQuarterGram(min(max(v, Config.perDoseMinG), Config.perDoseMaxG)) }
