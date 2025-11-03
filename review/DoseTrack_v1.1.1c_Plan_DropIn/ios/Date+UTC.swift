import Foundation
extension Date {
    func toHHmm(offsetMinutes: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: offsetMinutes * 60) ?? .current
        let fmt = DateFormatter()
        fmt.calendar = cal
        fmt.timeZone = cal.timeZone
        fmt.dateFormat = "HH:mm"
        return fmt.string(from: self)
    }
}
func todayNightKey(offsetMinutes: Int) -> String {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(secondsFromGMT: offsetMinutes * 60) ?? .current
    let now = Date()
    let comps = cal.dateComponents([.year, .month, .day], from: now)
    return String(format: "%04d-%02d-%02d", comps.year!, comps.month!, comps.day!)
}
