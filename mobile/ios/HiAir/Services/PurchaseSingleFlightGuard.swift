import Foundation

/// Ensures at most one StoreKit purchase flow runs at a time.
struct PurchaseSingleFlightGuard {
    private(set) var isActive = false

    mutating func begin() -> Bool {
        guard !isActive else { return false }
        isActive = true
        return true
    }

    mutating func end() {
        isActive = false
    }
}
