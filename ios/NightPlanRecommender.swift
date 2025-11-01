import Foundation
struct NightPlan {
    let dose1GramsPrecise: Double
    let dose2GramsPrecise: Double
    let windowStartMinAfterDose1: Int
    let windowEndMinAfterDose1: Int
    let rationale: String
    var dose1DisplayG: Double { safeDisplayGrams(dose1GramsPrecise) }
    var dose2DisplayG: Double { safeDisplayGrams(dose2GramsPrecise) }
}
enum NightPlanRecommender {
    static func makePlan(totalNightG: Double, preferredSplitFirstPct: Double?, historyDose2ToWakeMinAvg: Int?, recoveryScore0to100: Int?) -> NightPlan {
        let splitFirst = clamp((preferredSplitFirstPct ?? 50.0), min: Config.splitMinPercentFirst, max: Config.splitMaxPercentFirst) / 100.0
        var d1 = totalNightG * splitFirst
        var d2 = totalNightG - d1
        if let r = recoveryScore0to100 {
            let delta = (Double(r) - 50.0) / 50.0
            d1 += delta * 0.125
            d2 = totalNightG - d1
        }
        d1 = clamp(d1, min: Config.perDoseMinG, max: Config.perDoseMaxG)
        d2 = clamp(d2, min: Config.perDoseMinG, max: Config.perDoseMaxG)
        let wStart = Config.windowStartMinAfterDose1
        let wEnd = Config.windowEndMinAfterDose1
        let rationale = "Split \(Int(splitFirst * 100)) percent first. Doses clamped to guardrails. Window \(wStart) to \(wEnd) minutes."
        return NightPlan(dose1GramsPrecise: d1, dose2GramsPrecise: d2, windowStartMinAfterDose1: wStart, windowEndMinAfterDose1: wEnd, rationale: rationale)
    }
    private static func clamp<T: Comparable>(_ x: T, min lo: T, max hi: T) -> T { max(lo, min(x, hi)) }
}
