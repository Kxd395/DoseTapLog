import Foundation
import HealthKit
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()
    private init() {}
    enum HKWakeSource: String { case appleHealth = "AppleHealth"; case none = "None" }
    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { completion(false); return }
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        store.requestAuthorization(toShare: [], read: [sleepType]) { ok, _ in completion(ok) }
    }
    func fetchLatestFinalWake(nightAnchor: Date, toleranceMin: Int, completion: @escaping (Date?, HKWakeSource) -> Void) {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let start = Calendar.current.date(byAdding: .hour, value: -1, to: nightAnchor) ?? nightAnchor
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: sleepType, predicate: pred, limit: 500, sortDescriptors: [sort]) { _, samples, _ in
            guard let cat = samples as? [HKCategorySample], !cat.isEmpty else { completion(nil, .none); return }
            let accepted: Set<HKCategoryValueSleepAnalysis> = [.asleepREM, .asleepCore, .asleepDeep, .asleepUnspecified, .inBed]
            let filtered = cat.filter { accepted.contains(HKCategoryValueSleepAnalysis(rawValue: $0.value) ?? .inBed) }
            let maybe = filtered.first(where: { $0.endDate > nightAnchor && $0.endDate <= Date() })?.endDate
            if let end = maybe {
                let mins = Int(Date().timeIntervalSince(end) / 60.0)
                completion(mins <= max(toleranceMin, 60) ? end : nil, mins <= max(toleranceMin, 60) ? .appleHealth : .none)
            } else { completion(nil, .none) }
        }
        store.execute(q)
    }
}
