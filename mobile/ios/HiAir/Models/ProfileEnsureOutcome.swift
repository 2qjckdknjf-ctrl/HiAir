import Foundation

/// Stage inside `performEnsureProfileIdIfNeeded` for telemetry + UI recovery.
enum ProfileEnsurePhase: String, Equatable, Sendable {
    case idle
    case list
    case locationGate
    case create
}

/// Stable high-level category for recovery UX (not raw errors).
enum ProfileEnsureCategory: String, Equatable, Sendable {
    case none
    case location
    case auth
    case network
    case server
    case decode
    case cancelled
    case unknown
}

/// Typed result for profile bootstrap. Callers must surface non-ready outcomes in UI.
enum ProfileEnsureOutcome: Equatable, Sendable {
    case ready
    case needsAuthentication
    case needsLocation
    case failure(ProfileEnsureFailureReason)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }

    var analyticsReason: String {
        switch self {
        case .ready:
            return "ready"
        case .needsAuthentication:
            return "needs_authentication"
        case .needsLocation:
            return "needs_location"
        case .failure(let reason):
            return reason.analyticsReason
        }
    }

    var category: ProfileEnsureCategory {
        switch self {
        case .ready:
            return .none
        case .needsAuthentication:
            return .auth
        case .needsLocation:
            return .location
        case .failure(let reason):
            return reason.category
        }
    }

    var diagnosticCode: String {
        switch self {
        case .ready:
            return "PE_READY"
        case .needsAuthentication:
            return "PE_AUTH"
        case .needsLocation:
            return "PE_LOC"
        case .failure(let reason):
            return reason.diagnosticCode
        }
    }

    var messageKey: String? {
        switch self {
        case .ready:
            return nil
        case .needsAuthentication:
            return "auth.session_expired"
        case .needsLocation:
            return "profile.ensure.needs_location"
        case .failure(let reason):
            return reason.messageKey
        }
    }

    /// Location recovery only for true location blockers — never for API/auth/network.
    var suggestsLocationRecovery: Bool {
        if case .needsLocation = self { return true }
        return false
    }

    var suggestsNetworkRetry: Bool {
        switch self {
        case .failure(let reason):
            return reason.suggestsNetworkRetry
        case .ready, .needsAuthentication, .needsLocation:
            return false
        }
    }
}

enum ProfileEnsureFailureReason: Equatable, Sendable {
    case unauthorized
    case forbidden
    case unavailable
    case offline
    case premiumRequired
    case server
    case decode
    case transport
    case cancelled
    case unknown

    var messageKey: String {
        switch self {
        case .unauthorized:
            return "auth.session_expired"
        case .forbidden:
            return "profile.ensure.forbidden"
        case .unavailable:
            return "profile.ensure.unavailable"
        case .offline:
            return "profile.ensure.offline"
        case .premiumRequired:
            return "profile.ensure.premium_required"
        case .decode:
            return "profile.ensure.decode"
        case .transport:
            return "profile.ensure.transport"
        case .cancelled:
            return "profile.ensure.cancelled"
        case .server, .unknown:
            return "profile.ensure.failed"
        }
    }

    var analyticsReason: String {
        switch self {
        case .unauthorized: return "unauthorized"
        case .forbidden: return "forbidden"
        case .unavailable: return "unavailable"
        case .offline: return "offline"
        case .premiumRequired: return "premium_required"
        case .server: return "server"
        case .decode: return "decode"
        case .transport: return "transport"
        case .cancelled: return "cancelled"
        case .unknown: return "unknown"
        }
    }

    var category: ProfileEnsureCategory {
        switch self {
        case .unauthorized, .forbidden:
            return .auth
        case .offline, .transport:
            return .network
        case .unavailable, .server, .premiumRequired:
            return .server
        case .decode:
            return .decode
        case .cancelled:
            return .cancelled
        case .unknown:
            return .unknown
        }
    }

    var diagnosticCode: String {
        switch self {
        case .unauthorized: return "PE_HTTP_401"
        case .forbidden: return "PE_HTTP_403"
        case .premiumRequired: return "PE_HTTP_402"
        case .unavailable: return "PE_HTTP_503"
        case .server: return "PE_HTTP_5XX"
        case .offline: return "PE_NET_OFFLINE"
        case .transport: return "PE_NET_TRANSPORT"
        case .decode: return "PE_DECODE"
        case .cancelled: return "PE_CANCELLED"
        case .unknown: return "PE_UNKNOWN"
        }
    }

    var suggestsReauthentication: Bool {
        switch self {
        case .unauthorized:
            return true
        case .forbidden, .unavailable, .offline, .premiumRequired, .server, .decode, .transport, .cancelled, .unknown:
            return false
        }
    }

    var suggestsPaywall: Bool {
        if case .premiumRequired = self { return true }
        return false
    }

    var suggestsNetworkRetry: Bool {
        switch self {
        case .offline, .transport, .unavailable, .server, .decode, .unknown:
            return true
        case .unauthorized, .forbidden, .premiumRequired, .cancelled:
            return false
        }
    }
}

enum ProfileEnsureMapper {
    static func outcome(for error: Error) -> ProfileEnsureOutcome {
        if let apiError = error as? APIError {
            return outcome(for: apiError)
        }
        if error is DecodingError {
            return .failure(.decode)
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff:
                return .failure(.offline)
            case .cancelled:
                return .failure(.cancelled)
            case .secureConnectionFailed, .serverCertificateUntrusted, .clientCertificateRejected,
                 .badServerResponse, .cannotParseResponse:
                return .failure(.transport)
            default:
                return .failure(.transport)
            }
        }
        return .failure(.unknown)
    }

    static func outcome(for error: APIError) -> ProfileEnsureOutcome {
        switch error {
        case .server(let status), .serverWithDetail(let status, _):
            switch status {
            case 401:
                return .needsAuthentication
            case 402:
                return .failure(.premiumRequired)
            case 403:
                return .failure(.forbidden)
            case 503:
                return .failure(.unavailable)
            default:
                return .failure(.server)
            }
        case .invalidURL, .invalidResponse:
            return .failure(.transport)
        }
    }

    /// Sanitized analytics props for device Console (no tokens / PII).
    static func analyticsProperties(
        for error: Error?,
        outcome: ProfileEnsureOutcome,
        phase: ProfileEnsurePhase
    ) -> [String: String] {
        var props: [String: String] = [
            "reason": outcome.analyticsReason,
            "phase": phase.rawValue,
            "category": outcome.category.rawValue,
            "diagnostic_code": outcome.diagnosticCode,
        ]
        guard let error else { return props }
        if let apiError = error as? APIError {
            switch apiError {
            case .server(let status), .serverWithDetail(let status, _):
                props["http_status"] = String(status)
                props["error_type"] = "api"
            case .invalidURL:
                props["error_type"] = "invalid_url"
                props["url_source"] = APIInvalidURLDiagnostics.lastSource.rawValue
                props["url_has_scheme"] = APIInvalidURLDiagnostics.lastHasScheme ? "1" : "0"
                props["url_has_host"] = APIInvalidURLDiagnostics.lastHasHost ? "1" : "0"
                props["url_config_source"] = APIInvalidURLDiagnostics.lastConfigSource
            case .invalidResponse:
                props["error_type"] = "invalid_response"
            }
        } else if error is DecodingError {
            props["error_type"] = "decode"
        } else if let urlError = error as? URLError {
            props["error_type"] = "url"
            props["url_code"] = String(urlError.code.rawValue)
        } else {
            props["error_type"] = String(describing: type(of: error))
        }
        return props
    }
}
