import Foundation
extension Date {
    func hhmm(withUTCOffsetMinutes offset: Int) -> String {
        var calendar = Calendar(identifier: .gregorian)
        if let tz = TimeZone(secondsFromGMT: offset * 60) { calendar.timeZone = tz }
        let c = calendar.dateComponents([.hour, .minute], from: self)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
