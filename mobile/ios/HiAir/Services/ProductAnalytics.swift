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

    private static let log = Logger(subsystem: "com.hiair.app", category: "product")
    /// Test seam: captures sanitized events without PII (unit tests only).
    nonisolated(unsafe) static var testEventSink: ((String, [String: String]) -> Void)?
    /// When false, roadmap retention/store events are suppressed (OS diagnostics may still log elsewhere).
    nonisolated(unsafe) static var analyticsConsentGranted: Bool = false

    static func trackRoadmapEvent(_ name: String, properties: [String: String] = [:]) {
        guard analyticsConsentGranted else { return }
        track(name, properties: properties)
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
}
