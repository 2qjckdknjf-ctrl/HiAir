import Foundation

enum ActionTimePreference: String, CaseIterable {
    case any, morning, afternoon, evening

    func bounds(now: Date = Date(), timezone: String) -> (earliest: String?, latest: String?) {
        guard self != .any, let zone = TimeZone(identifier: timezone) else { return (nil, nil) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let hours: (Int, Int) = self == .morning ? (6, 12) : self == .afternoon ? (12, 18) : (18, 24)
        var day = calendar.startOfDay(for: now)
        func interval(_ day: Date) -> (Date, Date) {
            let start = calendar.date(bySettingHour: hours.0, minute: 0, second: 0, of: day)!
            let end = hours.1 == 24 ? calendar.date(byAdding: .day, value: 1, to: day)! :
                calendar.date(bySettingHour: hours.1, minute: 0, second: 0, of: day)!
            return (start, end.addingTimeInterval(-1))
        }
        var dates = interval(day)
        if dates.1 < now {
            day = calendar.date(byAdding: .day, value: 1, to: day)!
            dates = interval(day)
        }
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = zone
        return (formatter.string(from: max(now, dates.0)), formatter.string(from: dates.1))
    }
}
