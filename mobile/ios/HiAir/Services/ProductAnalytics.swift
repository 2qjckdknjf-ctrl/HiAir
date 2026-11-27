import Foundation
import os

/// Lightweight product analytics (no third-party SDK, no PII).
/// Events are written to unified logging for TestFlight / device Console capture.
enum ProductAnalytics {
    /// Privacy-minimized roadmap event names (consent required before emission).
    enum Event {
        static let appStoreClick = "app_store_click"
        static let firstUsefulRecommendation = "first_useful_recommendation"
        static let repeatUse = "repeat_use"
        static let retentionWindow = "retention_window"
    }

    private static let keyPrefix = "hiair.product_analytics"
    private static let legacyKeys = [
        "hiair.product_analytics.consent",
        "hiair.product_analytics.first_open_day",
        "hiair.product_analytics.last_open_day",
        "hiair.product_analytics.first_useful_sent",
    ]

    private static let log = Logger(subsystem: "com.hiair.app", category: "product")
    /// Account that owns consent and first-use flags. Empty means logged out.
    nonisolated(unsafe) private(set) static var boundUserId: String = ""
    /// Test seam: captures sanitized events without PII (unit tests only).
    nonisolated(unsafe) static var testEventSink: ((String, [String: String]) -> Void)?
    /// Test seam: override defaults storage.
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    /// Load this account's consent. Does not copy another account's flags.
    static func bindAccount(userId: String) {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            clearAccountSession()
            return
        }
        boundUserId = trimmed
        discardLegacyGlobalKeys()
    }

    /// Drop the in-memory binding. Persisted per-account flags stay for that user.
    /// When `ifUserId` is set, a stale logout cannot clear a newer account.
    static func clearAccountSession(ifUserId userId: String? = nil) {
        if let userId {
            let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, boundUserId == trimmed else { return }
        }
        boundUserId = ""
        discardLegacyGlobalKeys()
    }

    static var analyticsConsentGranted: Bool {
        get {
            guard let key = scopedKey("consent") else { return false }
            return defaults.bool(forKey: key)
        }
        set {
            guard let key = scopedKey("consent") else { return }
            defaults.set(newValue, forKey: key)
        }
    }

    static func setAnalyticsConsent(_ granted: Bool) {
        analyticsConsentGranted = granted
    }

    static func trackRoadmapEvent(_ name: String, properties: [String: String] = [:]) {
        guard analyticsConsentGranted else { return }
        track(name, properties: properties)
    }

    /// Call on cold/warm dashboard entry. Emits repeat_use / retention_window once per day max.
    static func recordAppOpen(surface: String = "dashboard") {
        guard analyticsConsentGranted else { return }
        guard let firstKey = scopedKey("first_open_day"), let lastKey = scopedKey("last_open_day") else { return }
        let day = isoDay(Date())
        let first = defaults.string(forKey: firstKey)
        if first == nil {
            defaults.set(day, forKey: firstKey)
            defaults.set(day, forKey: lastKey)
            return
        }
        let last = defaults.string(forKey: lastKey)
        guard last != day else { return }
        defaults.set(day, forKey: lastKey)
        trackRoadmapEvent(Event.repeatUse, properties: ["surface": surface])
        if let first,
           let firstDate = parseDay(first),
           let nowDate = parseDay(day) {
            let days = Calendar.current.dateComponents([.day], from: firstDate, to: nowDate).day ?? 0
            if days >= 7 {
                trackRoadmapEvent(Event.retentionWindow, properties: ["window": "7d", "surface": surface])
            }
        }
    }

    static func recordUsefulRecommendation(surface: String) {
        guard analyticsConsentGranted else { return }
        guard let key = scopedKey("first_useful_sent") else { return }
        if defaults.bool(forKey: key) {
            return
        }
        defaults.set(true, forKey: key)
        trackRoadmapEvent(Event.firstUsefulRecommendation, properties: ["surface": surface])
    }

    private static func scopedKey(_ name: String) -> String? {
        let userId = boundUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else { return nil }
        return "\(keyPrefix).\(name).\(userId)"
    }

    private static func discardLegacyGlobalKeys() {
        for key in legacyKeys {
            defaults.removeObject(forKey: key)
        }
    }

    static func track(_ name: String, properties: [String: String] = [:]) {
        let sanitized = properties.filter { key, value in
            !key.lowercased().contains("email")
                && !key.lowercased().contains("token")
                && !key.lowercased().contains("user")
                && !value.contains("@")
        }
        testEventSink?(name, sanitized)
        if sanitized.isEmpty {
            log.info("\(name, privacy: .public)")
        } else {
            let payload = sanitized
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            log.info("\(name, privacy: .public) \(payload, privacy: .public)")
        }
    }

    private static func isoDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func parseDay(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: value)
    }
}
