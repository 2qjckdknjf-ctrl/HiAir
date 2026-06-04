import Foundation
import StoreKit

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    static let monthlyProductId = "com.hiair.premium.monthly"
    static let yearlyProductId = "com.hiair.premium.yearly"
    private static let productIds: Set<String> = [monthlyProductId, yearlyProductId]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private let apiClient = APIClient.live()

    private init() {
        updatesTask = Task { await listenForTransactionUpdates() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: Array(Self.productIds))
            products = loaded.sorted { $0.id < $1.id }
            lastError = nil
        } catch {
            products = []
            lastError = error.localizedDescription
        }
    }

    func purchase(_ product: Product, userId: String, accessToken: String) async throws -> SubscriptionStatusResponse {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let signed = try signedTransactionString(from: verification)
            return try await apiClient.verifyIosSubscription(
                userId: userId,
                signedTransaction: signed,
                productId: product.id,
                accessToken: accessToken
            )
        case .userCancelled:
            throw SubscriptionServiceError.cancelled
        case .pending:
            throw SubscriptionServiceError.pending
        @unknown default:
            throw SubscriptionServiceError.unknown
        }
    }

    func restorePurchases(userId: String, accessToken: String) async throws -> SubscriptionStatusResponse {
        var signedTransactions: [String] = []
        for await result in Transaction.currentEntitlements {
            if let signed = try? signedTransactionString(from: result) {
                signedTransactions.append(signed)
            }
        }
        return try await apiClient.restoreSubscriptions(
            userId: userId,
            platform: "ios",
            iosSignedTransactions: signedTransactions,
            accessToken: accessToken
        )
    }

    func refreshEntitlement(userId: String, accessToken: String) async throws -> UserEntitlementResponse? {
        let status = try await apiClient.fetchMySubscription(userId: userId, accessToken: accessToken)
        return status.entitlement
    }

    private func listenForTransactionUpdates() async {
        for await update in Transaction.updates {
            guard case .verified(let transaction) = update else { continue }
            await transaction.finish()
        }
    }

    private func signedTransactionString(from verification: VerificationResult<Transaction>) throws -> String {
        switch verification {
        case .verified(let transaction):
            return buildStubJws(for: transaction)
        case .unverified(_, let error):
            throw error
        }
    }

    /// Backend stub verifier accepts a minimal JWS-shaped token with transaction metadata.
    private func buildStubJws(for transaction: Transaction) -> String {
        var payload: [String: Any] = [
            "productId": transaction.productID,
            "transactionId": String(transaction.id),
            "originalTransactionId": String(transaction.originalID),
            "status": "active",
        ]
        if let expiration = transaction.expirationDate {
            payload["expiresDate"] = Int(expiration.timeIntervalSince1970 * 1000)
        }
        let header = base64URLEncode(Data("{\"alg\":\"none\"}".utf8))
        let bodyData = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        let body = base64URLEncode(bodyData)
        return "\(header).\(body).stub"
    }

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

enum SubscriptionServiceError: LocalizedError {
    case cancelled
    case pending
    case unknown

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Purchase cancelled"
        case .pending:
            return "Purchase pending approval"
        case .unknown:
            return "Unknown purchase result"
        }
    }
}
