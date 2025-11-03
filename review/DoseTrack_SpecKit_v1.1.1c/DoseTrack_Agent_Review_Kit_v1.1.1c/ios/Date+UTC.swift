import Foundation
extension Date {
    func hhmm(withUTCOffsetMinutes offset: Int) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: offset * 60) ?? .gmt
        let c = cal.dateComponents([.hour,.minute], from: self)
        return String(format: "%02d:%02d", c.hour ?? 0, c.minute ?? 0)
    }
}
