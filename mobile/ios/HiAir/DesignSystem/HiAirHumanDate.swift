import Foundation

/// Locale-aware date/time formatting for UI. Never surface raw ISO-8601 to users.
enum HiAirHumanDate {
    enum Style {
        case date
        case time
        case dateTime
        case dateMedium
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoBasic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static func date(fromISO iso: String) -> Date? {
        let trimmed = iso.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let date = isoFractional.date(from: trimmed) { return date }
        if let date = isoBasic.date(from: trimmed) { return date }
        // Fallback for "yyyy-MM-dd'T'HH:mm:ssZ" without fractional seconds variants.
        let legacy = DateFormatter()
        legacy.locale = Locale(identifier: "en_US_POSIX")
        legacy.timeZone = TimeZone(secondsFromGMT: 0)
        legacy.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        if let date = legacy.date(from: trimmed) { return date }
        legacy.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return legacy.date(from: trimmed)
    }

    static func string(
        from date: Date,
        locale: Locale = .autoupdatingCurrent,
        style: Style = .dateTime,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        switch style {
        case .date:
            formatter.dateStyle = .short
            formatter.timeStyle = .none
        case .time:
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        case .dateTime:
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        case .dateMedium:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }
        return formatter.string(from: date)
    }

    /// Formats an ISO string for display. Returns `nil` if parsing fails (caller may hide or keep fallback).
    static func string(
        fromISO iso: String,
        locale: Locale = .autoupdatingCurrent,
        style: Style = .dateTime,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String? {
        guard let date = date(fromISO: iso) else { return nil }
        return string(from: date, locale: locale, style: style, timeZone: timeZone)
    }

    /// Prefer human string; if ISO cannot be parsed, return a sanitized non-ISO fallback (never the raw ISO).
    static func display(
        fromISO iso: String,
        locale: Locale = .autoupdatingCurrent,
        style: Style = .dateTime,
        unavailable: String = "—"
    ) -> String {
        string(fromISO: iso, locale: locale, style: style) ?? unavailable
    }

    /// Compact range for planner windows, e.g. "08:00–09:00".
    static func timeRange(
        from start: Date,
        to end: Date,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: start))–\(formatter.string(from: end))"
    }

    static func timeRange(
        fromISO startISO: String,
        toISO endISO: String,
        locale: Locale = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        unavailable: String = "—"
    ) -> String {
        guard let start = date(fromISO: startISO), let end = date(fromISO: endISO) else {
            return unavailable
        }
        return timeRange(from: start, to: end, locale: locale, timeZone: timeZone)
    }

    static func timeZone(identifier: String?) -> TimeZone {
        if let identifier, let zone = TimeZone(identifier: identifier) {
            return zone
        }
        return .autoupdatingCurrent
    }
}
