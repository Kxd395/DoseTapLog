//
//  Date+UTC.swift
//  DoseTrack
//
import Foundation

extension Date {
    func toUTCString(_ fmt: String) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = fmt
        return f.string(from: self)
    }
}
