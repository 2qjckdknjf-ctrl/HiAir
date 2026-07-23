import Foundation

/// Safe startup diagnostics — stages, durations, flags only (no PII / coords / health values).
enum StartupDiagnostics {
    static func track(
        _ stage: String,
        success: Bool? = nil,
        durationMs: Int? = nil,
        httpStatus: Int? = nil,
        profilePresent: Bool? = nil,
        errorCode: String? = nil
    ) {
        var props: [String: String] = ["stage": stage]
        if let success {
            props["success"] = success ? "true" : "false"
        }
        if let durationMs {
            props["duration_ms"] = String(durationMs)
        }
        if let httpStatus {
            props["http_status"] = String(httpStatus)
        }
        if let profilePresent {
            props["profile_present"] = profilePresent ? "true" : "false"
        }
        if let errorCode {
            props["error_code"] = errorCode
        }
        ProductAnalytics.track(stage, properties: props)
    }
}
