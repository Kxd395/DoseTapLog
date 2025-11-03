//
//  HealthKitManager.swift
//  DoseTrack
//
import Foundation
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    private init() {}

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let types: Set<HKObjectType> = [
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        ]
        store.requestAuthorization(toShare: [], read: types) { ok, _ in
            completion(ok)
        }
    }

    // Consolidate best-effort sleep window using user final wake if available
    func computeSleepWindow(nightAnchor: Date,
                            userFinalWake: Date?,
                            hkInterval: (Date, Date)?,
                            whoopInterval: (Date, Date)?) -> (start: Date, end: Date, source: SleepWindowSource, conflict: Bool) {
        var startCandidates: [Date] = []
        if let hk = hkInterval { startCandidates.append(hk.0) }
        if let wp = whoopInterval { startCandidates.append(wp.0) }
        // assume bedtime within 6 hours before anchor
        startCandidates.append(nightAnchor.addingTimeInterval(-6*3600))

        var end: Date
        var source: SleepWindowSource
        if let ufw = userFinalWake {
            end = ufw
            source = .userFinalWake
        } else if let hk = hkInterval?.1 {
            end = hk
            source = .healthKit
        } else if let wp = whoopInterval?.1 {
            end = wp
            source = .whoop
        } else {
            end = nightAnchor.addingTimeInterval(8*3600)
            source = .fallback
        }
        let start = startCandidates.min() ?? nightAnchor.addingTimeInterval(-6*3600)
        let conflict = (userFinalWake == nil) ? false : (
            (hkInterval != nil && abs(end.timeIntervalSince(hkInterval!.1)) > 15*60) ||
            (whoopInterval != nil && abs(end.timeIntervalSince(whoopInterval!.1)) > 15*60)
        )
        return (start, end, source, conflict)
    }

    func fetchStatsAverage(for type: HKQuantityTypeIdentifier,
                           unit: HKUnit,
                           start: Date, end: Date,
                           completion: @escaping (Double?) -> Void) {
        guard let qType = HKObjectType.quantityType(forIdentifier: type) else {
            completion(nil); return
        }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: qType, quantitySamplePredicate: pred, options: .discreteAverage) { _, stats, _ in
            guard let s = stats, let q = s.averageQuantity() else { completion(nil); return }
            completion(q.doubleValue(for: unit))
        }
        store.execute(q)
    }

    func fetchStatsMinimum(for type: HKQuantityTypeIdentifier,
                           unit: HKUnit,
                           start: Date, end: Date,
                           completion: @escaping (Double?) -> Void) {
        guard let qType = HKObjectType.quantityType(forIdentifier: type) else {
            completion(nil); return
        }
        let pred = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let q = HKStatisticsQuery(quantityType: qType, quantitySamplePredicate: pred, options: .discreteMin) { _, stats, _ in
            guard let s = stats, let q = s.minimumQuantity() else { completion(nil); return }
            completion(q.doubleValue(for: unit))
        }
        store.execute(q)
    }
}
