import Foundation
struct AppGroupStore {
    static let suite = "group.com.jefferson.dosetrack"
    enum Key: String { case pendingActionJSON = "pending_action_json" }
    struct PendingAction: Codable {
        enum Kind: String, Codable { case dose1Now, dose2Now }
        let kind: Kind
        let grams: Double?
        let timestamp: Date
    }
    static func writePending(_ action: PendingAction) {
        if let d = UserDefaults(suiteName: suite) {
            d.set(try? JSONEncoder().encode(action), forKey: Key.pendingActionJSON.rawValue)
        }
    }
    static func consumePending() -> PendingAction? {
        guard let d = UserDefaults(suiteName: suite), let data = d.data(forKey: Key.pendingActionJSON.rawValue) else { return nil }
        d.removeObject(forKey: Key.pendingActionJSON.rawValue)
        return try? JSONDecoder().decode(PendingAction.self, from: data)
    }
}
