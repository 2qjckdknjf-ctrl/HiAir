import Foundation

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

    /// When true, ProfileBootstrapCard should offer location recovery actions.
    var suggestsLocationRecovery: Bool {
        switch self {
        case .needsLocation:
            return true
        case .failure(let reason):
            return reason.suggestsLocationRecovery
        case .ready, .needsAuthentication:
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

    var suggestsLocationRecovery: Bool {
        switch self {
        case .offline, .transport, .server, .decode, .unknown, .cancelled:
            return true
        case .unauthorized, .forbidden, .unavailable, .premiumRequired:
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
    static func analyticsProperties(for error: Error, outcome: ProfileEnsureOutcome) -> [String: String] {
        var props: [String: String] = ["reason": outcome.analyticsReason]
        if let apiError = error as? APIError {
            switch apiError {
            case .server(let status), .serverWithDetail(let status, _):
                props["http_status"] = String(status)
                props["error_type"] = "api"
            case .invalidURL:
                props["error_type"] = "invalid_url"
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
