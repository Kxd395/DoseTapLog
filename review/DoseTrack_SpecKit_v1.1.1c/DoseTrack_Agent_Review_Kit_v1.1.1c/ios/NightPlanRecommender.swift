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
        let splitFirst = max(Config.splitMinPercentFirst, min((preferredSplitFirstPct ?? 50.0), Config.splitMaxPercentFirst)) / 100.0
        var d1 = totalNightG * splitFirst
        var d2 = totalNightG - d1
        if let r = recoveryScore0to100 {
            let delta = (Double(r) - 50.0) / 50.0
            d1 += delta * 0.125
            d2 = totalNightG - d1
        }
        d1 = max(Config.perDoseMinG, min(d1, Config.perDoseMaxG))
        d2 = max(Config.perDoseMinG, min(d2, Config.perDoseMaxG))
        let wStart = Config.windowStartMinAfterDose1
        let wEnd = Config.windowEndMinAfterDose1
        return NightPlan(dose1GramsPrecise: d1, dose2GramsPrecise: d2, windowStartMinAfterDose1: wStart, windowEndMinAfterDose1: wEnd, rationale: "Clamped and split")
    }
}
