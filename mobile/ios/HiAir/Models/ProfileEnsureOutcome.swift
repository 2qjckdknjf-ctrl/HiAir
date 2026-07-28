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
}

enum ProfileEnsureFailureReason: Equatable, Sendable {
    case unauthorized
    case forbidden
    case unavailable
    case offline
    case server
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
        case .server: return "server"
        case .unknown: return "unknown"
        }
    }

    var suggestsReauthentication: Bool {
        switch self {
        case .unauthorized:
            return true
        case .forbidden, .unavailable, .offline, .server, .unknown:
            return false
        }
    }
}

enum ProfileEnsureMapper {
    static func outcome(for error: Error) -> ProfileEnsureOutcome {
        if let apiError = error as? APIError {
            return outcome(for: apiError)
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
                return .failure(.offline)
            default:
                return .failure(.unknown)
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
            case 403:
                return .failure(.forbidden)
            case 503:
                return .failure(.unavailable)
            default:
                return .failure(.server)
            }
        case .invalidURL, .invalidResponse:
            return .failure(.unknown)
        }
    }
}
