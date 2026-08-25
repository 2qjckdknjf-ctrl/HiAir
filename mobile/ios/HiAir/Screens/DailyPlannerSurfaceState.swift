import Foundation

/// Independent surface states for Planner day-plan forecast.
enum PlannerForecastSurface: Equatable {
    case idle
    case loading
    case loaded(hours: Int)
    case partial(hours: Int, message: String)
    case unavailable(message: String)
    case failed(message: String)
    case premiumLocked(message: String)

    var hasDisplayableData: Bool {
        switch self {
        case .loaded, .partial:
            return true
        default:
            return false
        }
    }

    /// Shown only when forecast data is not on screen.
    var bannerMessage: String? {
        switch self {
        case .unavailable(let message), .failed(let message), .premiumLocked(let message):
            return message
        case .partial(_, let message):
            return message
        case .idle, .loading, .loaded:
            return nil
        }
    }
}

/// Independent surface states for activity planning (best-time windows).
enum PlannerActivitySurface: Equatable {
    case idle
    case loading
    case loaded(windowCount: Int)
    case partial(message: String)
    case empty(message: String)
    case failed(message: String)
    case premiumLocked(message: String)

    var hasDisplayableData: Bool {
        switch self {
        case .loaded, .partial:
            return true
        default:
            return false
        }
    }

    /// Inline message inside the activity card; suppressed when windows are visible.
    var inlineMessage: String? {
        switch self {
        case .partial(let message), .empty(let message), .failed(let message), .premiumLocked(let message):
            return message
        case .idle, .loading, .loaded:
            return nil
        }
    }
}
