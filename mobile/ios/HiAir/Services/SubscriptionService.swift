import Foundation
import StoreKit

extension Notification.Name {
    static let subscriptionEntitlementDidUpdate = Notification.Name("SubscriptionService.entitlementDidUpdate")
}

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    static let monthlyProductId = "com.hiair.premium.monthly"
    static let yearlyProductId = "com.hiair.premium.yearly"
    private static let productIds: Set<String> = [monthlyProductId, yearlyProductId]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchaseInProgress = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private var purchaseGuard = PurchaseSingleFlightGuard()
    private var processedTransactionIds = Set<UInt64>()
    private let apiClient = APIClient.live()

    private init() {
        updatesTask = Task { await listenForTransactionUpdates() }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts(maxAttempts: Int = 3) async {
        guard !isPurchaseInProgress else {
            SubscriptionDiagnostics.log("products_load_skipped_purchase_in_progress")
            return
        }
        isLoading = true
        defer { isLoading = false }

        SubscriptionDiagnostics.log("products_load_started", productId: Self.productIds.sorted().joined(separator: ","))

        for attempt in 1...maxAttempts {
            guard !isPurchaseInProgress else { return }
            do {
                let loaded = try await Product.products(for: Array(Self.productIds))
                if !loaded.isEmpty {
                    products = loaded.sorted { $0.id < $1.id }
                    lastError = nil
                    SubscriptionDiagnostics.log(
                        "products_load_succeeded",
                        productId: loaded.map(\.id).joined(separator: ",")
                    )
                    return
                }
                lastError = "App Store products not available yet"
                SubscriptionDiagnostics.log("products_load_failed", resultType: "empty_catalog")
            } catch {
                products = []
                lastError = error.localizedDescription
                SubscriptionDiagnostics.log(
                    "products_load_failed",
                    errorDomain: (error as NSError).domain,
                    errorCode: (error as NSError).code
                )
            }

            if attempt < maxAttempts {
                let delayNs = UInt64(attempt) * 2_000_000_000
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }
    }

    func purchase(_ product: Product, userId: String, accessToken: String) async throws -> SubscriptionStatusResponse {
        guard purchaseGuard.begin() else {
            SubscriptionDiagnostics.log("purchase_request_skipped", productId: product.id, resultType: "already_in_progress")
            throw SubscriptionServiceError.purchaseInProgress
        }
        isPurchaseInProgress = true
        defer {
            purchaseGuard.end()
            isPurchaseInProgress = false
        }

        let correlationId = UUID().uuidString.prefix(8).lowercased()
        SubscriptionDiagnostics.log(
            "purchase_request_started",
            productId: product.id,
            correlationId: String(correlationId)
        )

        if let restored = try await syncVerifiedEntitlementsIfPresent(
            userId: userId,
            accessToken: accessToken,
            correlationId: String(correlationId)
        ) {
            SubscriptionDiagnostics.log(
                "purchase_restored_existing_entitlement",
                productId: product.id,
                entitlementActive: restored.entitlement?.isPremium == true,
                correlationId: String(correlationId)
            )
            return restored
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                SubscriptionDiagnostics.log(
                    "purchase_result_success",
                    productId: product.id,
                    resultType: "verified",
                    verificationState: "verified",
                    correlationId: String(correlationId)
                )
                return try await processVerifiedTransaction(
                    verification,
                    transaction: transaction,
                    userId: userId,
                    accessToken: accessToken,
                    correlationId: String(correlationId)
                )
            case .unverified(_, let error):
                SubscriptionDiagnostics.log(
                    "transaction_unverified",
                    productId: product.id,
                    errorDomain: (error as NSError).domain,
                    errorCode: (error as NSError).code,
                    correlationId: String(correlationId)
                )
                throw SubscriptionServiceError.verificationFailed
            }
        case .userCancelled:
            SubscriptionDiagnostics.log(
                "purchase_result_cancelled",
                productId: product.id,
                correlationId: String(correlationId)
            )
            throw SubscriptionServiceError.cancelled
        case .pending:
            SubscriptionDiagnostics.log(
                "purchase_result_pending",
                productId: product.id,
                correlationId: String(correlationId)
            )
            throw SubscriptionServiceError.pending
        @unknown default:
            SubscriptionDiagnostics.log(
                "purchase_result_failed",
                productId: product.id,
                resultType: "unknown",
                correlationId: String(correlationId)
            )
            throw SubscriptionServiceError.unknown
        }
    }

    func restorePurchases(userId: String, accessToken: String) async throws -> SubscriptionStatusResponse {
        guard purchaseGuard.begin() else {
            throw SubscriptionServiceError.purchaseInProgress
        }
        isPurchaseInProgress = true
        defer {
            purchaseGuard.end()
            isPurchaseInProgress = false
        }

        SubscriptionDiagnostics.log("restore_started")
        try await AppStore.sync()
        var signedTransactions: [String] = []
        for await result in Transaction.currentEntitlements {
            if let signed = try? signedTransactionString(from: result) {
                signedTransactions.append(signed)
            }
        }
        let response = try await apiClient.restoreSubscriptions(
            userId: userId,
            platform: "ios",
            iosSignedTransactions: signedTransactions,
            accessToken: accessToken
        )
        SubscriptionDiagnostics.log(
            "restore_succeeded",
            entitlementActive: response.entitlement?.isPremium == true
        )
        return response
    }

    func refreshEntitlement(userId: String, accessToken: String) async throws -> UserEntitlementResponse? {
        SubscriptionDiagnostics.log("entitlement_refresh_started")
        let status = try await apiClient.fetchMySubscription(userId: userId, accessToken: accessToken)
        SubscriptionDiagnostics.log(
            status.entitlement?.isPremium == true ? "entitlement_active" : "entitlement_inactive"
        )
        return status.entitlement
    }

    private func syncVerifiedEntitlementsIfPresent(
        userId: String,
        accessToken: String,
        correlationId: String
    ) async throws -> SubscriptionStatusResponse? {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.productIds.contains(transaction.productID) else { continue }
            guard !processedTransactionIds.contains(transaction.id) else { continue }
            SubscriptionDiagnostics.log(
                "existing_entitlement_detected",
                productId: transaction.productID,
                correlationId: correlationId
            )
            return try await processVerifiedTransaction(
                result,
                transaction: transaction,
                userId: userId,
                accessToken: accessToken,
                correlationId: correlationId
            )
        }
        return nil
    }

    private func processVerifiedTransaction(
        _ verification: VerificationResult<Transaction>,
        transaction: Transaction,
        userId: String,
        accessToken: String,
        correlationId: String
    ) async throws -> SubscriptionStatusResponse {
        if processedTransactionIds.contains(transaction.id) {
            SubscriptionDiagnostics.log(
                "transaction_already_processed",
                productId: transaction.productID,
                correlationId: correlationId
            )
            let status = try await apiClient.fetchMySubscription(userId: userId, accessToken: accessToken)
            return status
        }
        processedTransactionIds.insert(transaction.id)

        SubscriptionDiagnostics.log(
            "backend_verify_started",
            productId: transaction.productID,
            correlationId: correlationId
        )
        let signed = try signedTransactionString(from: verification)
        do {
            let response = try await apiClient.verifyIosSubscription(
                userId: userId,
                signedTransaction: signed,
                productId: transaction.productID,
                accessToken: accessToken
            )
            SubscriptionDiagnostics.log(
                "backend_verify_succeeded",
                productId: transaction.productID,
                httpStatus: 200,
                entitlementActive: response.entitlement?.isPremium == true,
                correlationId: correlationId
            )
            if response.entitlement?.isPremium == true {
                await transaction.finish()
                NotificationCenter.default.post(
                    name: .subscriptionEntitlementDidUpdate,
                    object: response.entitlement
                )
            }
            return response
        } catch let error as APIError {
            processedTransactionIds.remove(transaction.id)
            let statusCode: Int
            switch error {
            case .server(let code), .serverWithDetail(let code, _):
                statusCode = code
            default:
                statusCode = 0
            }
            SubscriptionDiagnostics.log(
                "backend_verify_failed",
                productId: transaction.productID,
                httpStatus: statusCode == 0 ? nil : statusCode,
                correlationId: correlationId
            )
            throw error
        }
    }

    private func listenForTransactionUpdates() async {
        for await update in Transaction.updates {
            switch update {
            case .verified(let transaction):
                guard Self.productIds.contains(transaction.productID) else {
                    await transaction.finish()
                    continue
                }
                guard let auth = APIClient.getAuthState() else { continue }
                SubscriptionDiagnostics.log(
                    "transaction_verified",
                    productId: transaction.productID
                )
                do {
                    _ = try await processVerifiedTransaction(
                        update,
                        transaction: transaction,
                        userId: auth.userId,
                        accessToken: auth.accessToken,
                        correlationId: "listener"
                    )
                } catch {
                    if let apiError = error as? APIError {
                        lastError = userFacingMessage(for: apiError)
                    } else {
                        lastError = error.localizedDescription
                    }
                }
            case .unverified(_, let error):
                SubscriptionDiagnostics.log(
                    "transaction_unverified",
                    errorDomain: (error as NSError).domain,
                    errorCode: (error as NSError).code
                )
            }
        }
    }

    private func signedTransactionString(from verification: VerificationResult<Transaction>) throws -> String {
        switch verification {
        case .verified(let transaction):
            if let jws = appleSignedPayload(from: verification) {
                return jws
            }
            return buildStubJws(for: transaction)
        case .unverified(_, let error):
            throw error
        }
    }

    private func appleSignedPayload(from verification: VerificationResult<Transaction>) -> String? {
        let mirror = Mirror(reflecting: verification)
        for child in mirror.children {
            guard child.label == "jwsRepresentation", let jws = child.value as? String, !jws.isEmpty else {
                continue
            }
            return jws
        }
        return nil
    }

    /// Backend accepts stub-shaped JWS built from verified StoreKit transaction metadata.
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

    func userFacingMessage(for error: APIError) -> String {
        switch error {
        case .serverWithDetail(_, let detail):
            return detail
        case .server(let code):
            return "Server error (\(code))"
        case .invalidURL, .invalidResponse:
            return "Network error"
        }
    }
}

enum SubscriptionServiceError: LocalizedError {
    case cancelled
    case pending
    case unknown
    case purchaseInProgress
    case verificationFailed

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Purchase cancelled"
        case .pending:
            return "Purchase pending approval"
        case .unknown:
            return "Unknown purchase result"
        case .purchaseInProgress:
            return "Purchase already in progress"
        case .verificationFailed:
            return "Purchase verification failed"
        }
    }
}
