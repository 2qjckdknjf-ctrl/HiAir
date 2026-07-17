import Foundation
import StoreKit

protocol StoreProductFetching: Sendable {
    func fetchProducts(ids: Set<String>) async throws -> [Product]
}

struct AppStoreProductFetcher: StoreProductFetching {
    func fetchProducts(ids: Set<String>) async throws -> [Product] {
        try await Product.products(for: Array(ids))
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
