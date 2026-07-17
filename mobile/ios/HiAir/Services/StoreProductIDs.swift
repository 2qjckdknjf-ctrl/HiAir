import Foundation

/// Single canonical source for iOS App Store subscription product identifiers.
enum StoreProductIDs {
    static let monthly = "com.hiair.premium.monthly"
    static let yearly = "com.hiair.premium.yearly"
    static let all: Set<String> = [monthly, yearly]
    static var sorted: [String] { all.sorted() }
}
