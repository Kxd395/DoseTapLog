//
//  FeatureVector.swift
//  DoseTrack
//
import Foundation
import CryptoKit

struct FeatureVectorBuilder {
    static func featureVector(for log: DoseLog, survey: NightSurvey?) -> [String: String] {
        var f: [String: String] = [:]
        // minimal Phase A feature set - strings for stability in CSV
        f["avgHR"] = log.physio_avgHR.map { String(format: "%.2f", $0) }
        f["minHR"] = log.physio_minHR.map { String(format: "%.2f", $0) }
        f["avgResp"] = log.physio_avgRespRate.map { String(format: "%.2f", $0) }
        f["rMSSD"] = log.physio_rMSSD.map { String(format: "%.2f", $0) }
        f["SDNN"] = log.physio_SDNN.map { String(format: "%.2f", $0) }
        f["restingHR"] = log.physio_restingHR.map { String(format: "%.2f", $0) }
        f["disturbances"] = log.sleep_disturbances.map { String($0) }
        f["stress"] = survey?.stress_1to5.map { String($0) }
        f["alcohol_units"] = survey?.alcohol_units.map { String(format: "%.2f", $0) }
        return f
    }

    static func stableId(from dict: [String: String]) -> String {
        let joined = dict.keys.sorted().map { "\($0)=\(dict[$0] ?? "")" }.joined(separator: "|")
        let hash = SHA256.hash(data: joined.data(using: .utf8)!)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
