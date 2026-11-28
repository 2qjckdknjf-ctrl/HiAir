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

    private static let consentKey = "hiair.product_analytics.consent"
    private static let firstOpenDayKey = "hiair.product_analytics.first_open_day"
    private static let lastOpenDayKey = "hiair.product_analytics.last_open_day"
    private static let firstUsefulSentKey = "hiair.product_analytics.first_useful_sent"

    private static let log = Logger(subsystem: "com.hiair.app", category: "product")
    /// Test seam: captures sanitized events without PII (unit tests only).
    nonisolated(unsafe) static var testEventSink: ((String, [String: String]) -> Void)?
    /// Test seam: override defaults storage.
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    private static func authorizedAccount(_ requestedUserId: String? = nil) -> String? {
        guard let auth = APIClient.getAuthState(),
              !auth.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let owner = auth.userId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !owner.isEmpty else { return nil }
        if let requestedUserId,
           requestedUserId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != owner {
            return nil
        }
        return owner
    }

    private static func scopedKey(_ key: String, owner: String) -> String {
        "\(key).account.\(owner)"
    }

    static func consentGranted(for userId: String? = nil) -> Bool {
        guard let owner = authorizedAccount(userId) else { return false }
        // Legacy device-wide consent has no account provenance and is never inherited.
        return defaults.bool(forKey: scopedKey(consentKey, owner: owner))
    }

    static var analyticsConsentGranted: Bool {
        get { consentGranted() }
        set { setAnalyticsConsent(newValue) }
    }

    @discardableResult
    static func setAnalyticsConsent(_ granted: Bool, userId: String? = nil) -> Bool {
        guard let owner = authorizedAccount(userId) else { return false }
        defaults.set(granted, forKey: scopedKey(consentKey, owner: owner))
        return true
    }

    static func trackRoadmapEvent(_ name: String, properties: [String: String] = [:], userId: String? = nil) {
        guard consentGranted(for: userId) else { return }
        track(name, properties: properties)
    }

    /// Call on cold/warm dashboard entry. Emits repeat_use / retention_window once per day max.
    static func recordAppOpen(surface: String = "dashboard", userId: String? = nil) {
        guard let owner = authorizedAccount(userId), consentGranted(for: owner) else { return }
        let firstOpenDayKey = scopedKey(Self.firstOpenDayKey, owner: owner)
        let lastOpenDayKey = scopedKey(Self.lastOpenDayKey, owner: owner)
        let day = isoDay(Date())
        let first = defaults.string(forKey: firstOpenDayKey)
        if first == nil {
            defaults.set(day, forKey: firstOpenDayKey)
            defaults.set(day, forKey: lastOpenDayKey)
            return
        }
        let last = defaults.string(forKey: lastOpenDayKey)
        guard last != day else { return }
        defaults.set(day, forKey: lastOpenDayKey)
        trackRoadmapEvent(Event.repeatUse, properties: ["surface": surface], userId: owner)
        if let first,
           let firstDate = parseDay(first),
           let nowDate = parseDay(day) {
            let days = Calendar.current.dateComponents([.day], from: firstDate, to: nowDate).day ?? 0
            if days >= 7 {
                trackRoadmapEvent(Event.retentionWindow, properties: ["window": "7d", "surface": surface], userId: owner)
            }
        }
    }

    static func recordUsefulRecommendation(surface: String, userId: String? = nil) {
        guard let owner = authorizedAccount(userId), consentGranted(for: owner) else { return }
        let firstUsefulSentKey = scopedKey(Self.firstUsefulSentKey, owner: owner)
        if defaults.bool(forKey: firstUsefulSentKey) {
            return
        }
        defaults.set(true, forKey: firstUsefulSentKey)
        trackRoadmapEvent(Event.firstUsefulRecommendation, properties: ["surface": surface], userId: owner)
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
