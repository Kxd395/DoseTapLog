import Foundation
import HealthKit
final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()
    private init() {}
    enum HKWakeSource: String { case appleHealth = "AppleHealth", none = "None" }
    func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else { completion(false); return }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { completion(false); return }
        store.requestAuthorization(toShare: [], read: [sleepType]) { ok, _ in completion(ok) }
    }
    func fetchLatestFinalWake(nightAnchor: Date, toleranceMin: Int, completion: @escaping (Date?, HKWakeSource) -> Void) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { completion(nil, .none); return }
        let start = Calendar.current.date(byAdding: .hour, value: -1, to: nightAnchor) ?? nightAnchor
        let pred = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let q = HKSampleQuery(sampleType: sleepType, predicate: pred, limit: 500, sortDescriptors: [sort]) { _, samples, _ in
            guard let catSamples = samples as? [HKCategorySample], !catSamples.isEmpty else { completion(nil, .none); return }
            let accepted = Set([HKCategoryValueSleepAnalysis.asleepREM, .asleepCore, .asleepDeep, .asleepUnspecified, .inBed].map { $0.rawValue })
            let filtered = catSamples.filter { accepted.contains($0.value) }
            let maybe = filtered.first(where: { $0.endDate > nightAnchor && $0.endDate <= Date() })?.endDate
            if let end = maybe {
                let minutesSince = Int(Date().timeIntervalSince(end) / 60.0)
                if minutesSince <= max(toleranceMin, 60) { completion(end, .appleHealth) } else { completion(nil, .none) }
            } else { completion(nil, .none) }
        }
        store.execute(q)
    }
}
