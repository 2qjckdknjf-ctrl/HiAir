import Foundation
import StoreKit

protocol StoreProductFetching: Sendable {
    func fetchProducts(ids: Set<String>) async throws -> [Product]
}

/// Fetches App Store products off the main actor so SwiftUI view updates
/// (e.g. swapping to a ProgressView) cannot cancel the StoreKit request.
struct AppStoreProductFetcher: StoreProductFetching {
    func fetchProducts(ids: Set<String>) async throws -> [Product] {
        let idList = Array(ids)
        return try await Task.detached(priority: .userInitiated) {
            try await Product.products(for: idList)
        }.value
    }
}

enum PaywallCatalogState: Equatable {
    case idle
    case loading
    case loaded
    case empty
    case failed
    case purchasing
}
