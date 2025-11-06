import Foundation
import SwiftData

/// NightFeatures: Stores WHOOP recovery metrics for a service day
/// Joined with DoseLog via nightKey for agent feature computation
@Model
final class NightFeatures {
    // Primary key - matches DoseLog.nightKey (YYYY-MM-DD)
    @Attribute(.unique) var nightKey: String
    
    // WHOOP Recovery Metrics
    var whoopRecoveryPct: Double?       // Recovery score (0-100%)
    var whoopHrvRmssd: Double?          // HRV RMSSD (ms)
    var whoopRestingHR: Double?         // Resting heart rate (bpm)
    var whoopSpo2: Double?              // Blood oxygen saturation (%)
    var whoopSkinTemp: Double?          // Skin temperature (°C)
    
    // WHOOP Identifiers (for data provenance)
    var whoopCycleId: Int?              // WHOOP cycle ID
    var whoopSleepId: String?           // WHOOP sleep ID
    
    // Metadata
    var whoopFetchedAt: Date?           // Last sync timestamp (UTC)
    var whoopDataSource: String?        // "api" or "manual"
    
    init(nightKey: String) {
        self.nightKey = nightKey
    }
    
    // MARK: - CSV Export
    
    static func csvHeader() -> String {
        "night_key,whoop_recovery_pct,whoop_hrv_rmssd,whoop_resting_hr,whoop_spo2,whoop_skin_temp,whoop_cycle_id,whoop_sleep_id,whoop_fetched_at"
    }
    
    func csvRow() -> String {
        let recoveryStr = whoopRecoveryPct.map { String(format: "%.1f", $0) } ?? ""
        let hrvStr = whoopHrvRmssd.map { String(format: "%.1f", $0) } ?? ""
        let rhrStr = whoopRestingHR.map { String(format: "%.0f", $0) } ?? ""
        let spo2Str = whoopSpo2.map { String(format: "%.1f", $0) } ?? ""
        let tempStr = whoopSkinTemp.map { String(format: "%.2f", $0) } ?? ""
        let cycleStr = whoopCycleId.map(String.init) ?? ""
        let sleepStr = whoopSleepId ?? ""
        let fetchedStr = whoopFetchedAt?.ISO8601Format() ?? ""
        
        return [nightKey, recoveryStr, hrvStr, rhrStr, spo2Str, tempStr, cycleStr, sleepStr, fetchedStr].joined(separator: ",")
    }
    
    // MARK: - JSONL Export (for agent features)
    
    func jsonlRecord() -> [String: Any] {
        var record: [String: Any] = [
            "night_key": nightKey,
        ]
        
        if let recovery = whoopRecoveryPct {
            record["whoop_recovery_pct"] = recovery
        }
        if let hrv = whoopHrvRmssd {
            record["whoop_hrv_rmssd"] = hrv
        }
        if let rhr = whoopRestingHR {
            record["whoop_resting_hr"] = rhr
        }
        if let spo2 = whoopSpo2 {
            record["whoop_spo2"] = spo2
        }
        if let temp = whoopSkinTemp {
            record["whoop_skin_temp"] = temp
        }
        if let cycle = whoopCycleId {
            record["whoop_cycle_id"] = cycle
        }
        if let sleep = whoopSleepId {
            record["whoop_sleep_id"] = sleep
        }
        if let fetched = whoopFetchedAt {
            record["whoop_fetched_at"] = ISO8601DateFormatter().string(from: fetched)
        }
        
        return record
    }
}

// MARK: - Helper Extension for Feature Flags

extension NightFeatures {
    /// Returns true if any WHOOP metrics are available
    var hasWhoopData: Bool {
        whoopRecoveryPct != nil || whoopHrvRmssd != nil || whoopRestingHR != nil || whoopSpo2 != nil || whoopSkinTemp != nil
    }
    
    /// Recovery score category for UI display
    var recoveryCategory: String {
        guard let score = whoopRecoveryPct else { return "unknown" }
        if score >= 67 { return "green" }
        if score >= 34 { return "yellow" }
        return "red"
    }
    
    /// Formatted recovery score string for display
    var recoveryScoreDisplay: String {
        guard let score = whoopRecoveryPct else { return "—" }
        return String(format: "%.0f%%", score)
    }
}
