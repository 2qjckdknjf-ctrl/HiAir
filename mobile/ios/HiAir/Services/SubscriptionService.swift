import Foundation
import StoreKit

extension Notification.Name {
    static let subscriptionEntitlementDidUpdate = Notification.Name("SubscriptionService.entitlementDidUpdate")
}

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    static nonisolated var monthlyProductId: String { StoreProductIDs.monthly }
    static nonisolated var yearlyProductId: String { StoreProductIDs.yearly }

    @Published private(set) var products: [Product] = []
    @Published private(set) var catalogState: PaywallCatalogState = .idle
    @Published private(set) var isLoading = false
    @Published private(set) var isPurchaseInProgress = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var purchaseGuard = PurchaseSingleFlightGuard()
    private var processedTransactionIds = Set<UInt64>()
    private let apiClient = APIClient.live()
    private let productFetcher: any StoreProductFetching

    private init(productFetcher: any StoreProductFetching = AppStoreProductFetcher()) {
        self.productFetcher = productFetcher
        updatesTask = Task { await listenForTransactionUpdates() }
    }

    /// Test seam — do not use in production UI.
    init(testingFetcher: any StoreProductFetching) {
        self.productFetcher = testingFetcher
        updatesTask = nil
    }

    deinit {
        updatesTask?.cancel()
        loadTask?.cancel()
    }

    var monthlyProduct: Product? {
        products.first { $0.id == StoreProductIDs.monthly }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == StoreProductIDs.yearly }
    }

    /// Device diagnostic: fetch products without purchasing. Safe fields only.
    func probeProducts() async -> (count: Int, ids: [String], monthlyPrice: Bool, yearlyPrice: Bool, errorDomain: String?, errorCode: Int?) {
        do {
            let loaded = try await productFetcher.fetchProducts(ids: StoreProductIDs.all)
            let ids = loaded.map(\.id).sorted()
            SubscriptionDiagnostics.log(
                "products_probe_succeeded",
                productId: ids.joined(separator: ","),
                resultType: "count=\(loaded.count)"
            )
            return (
                count: loaded.count,
                ids: ids,
                monthlyPrice: loaded.contains { $0.id == StoreProductIDs.monthly && !$0.displayPrice.isEmpty },
                yearlyPrice: loaded.contains { $0.id == StoreProductIDs.yearly && !$0.displayPrice.isEmpty },
                errorDomain: nil,
                errorCode: nil
            )
        } catch {
            let ns = error as NSError
            SubscriptionDiagnostics.log(
                "products_probe_failed",
                errorDomain: ns.domain,
                errorCode: ns.code
            )
            return (0, [], false, false, ns.domain, ns.code)
        }
    }

    func loadProducts(maxAttempts: Int = 3) {
        if isPurchaseInProgress {
            SubscriptionDiagnostics.log("products_load_skipped_purchase_in_progress")
            return
        }
        if let loadTask, !loadTask.isCancelled {
            SubscriptionDiagnostics.log("products_load_skipped_already_running")
            return
        }
        loadTask = Task { await performLoadProducts(maxAttempts: maxAttempts) }
    }

    func loadProductsAndWait(maxAttempts: Int = 3) async {
        loadProducts(maxAttempts: maxAttempts)
        await loadTask?.value
    }

    private func performLoadProducts(maxAttempts: Int) async {
        guard !isPurchaseInProgress else { return }
        isLoading = true
        catalogState = .loading
        lastError = nil
        defer {
            isLoading = false
            loadTask = nil
        }

        let requested = StoreProductIDs.sorted.joined(separator: ",")
        SubscriptionDiagnostics.log("products_load_started", productId: requested)
        SubscriptionDiagnostics.log("products_requested", productId: requested)

        for attempt in 1...maxAttempts {
            if Task.isCancelled { return }
            guard !isPurchaseInProgress else { return }
            do {
                let loaded = try await productFetcher.fetchProducts(ids: StoreProductIDs.all)
                if !loaded.isEmpty {
                    products = loaded.sorted { $0.id < $1.id }
                    lastError = nil
                    catalogState = .loaded
                    SubscriptionDiagnostics.log(
                        "products_load_succeeded",
                        productId: loaded.map(\.id).joined(separator: ","),
                        resultType: "count=\(loaded.count)"
                    )
                    if monthlyProduct != nil {
                        SubscriptionDiagnostics.log(
                            "product_monthly_available",
                            productId: StoreProductIDs.monthly,
                            resultType: "price_present=\(!(monthlyProduct?.displayPrice.isEmpty ?? true))"
                        )
                    }
                    if yearlyProduct != nil {
                        SubscriptionDiagnostics.log(
                            "product_yearly_available",
                            productId: StoreProductIDs.yearly,
                            resultType: "price_present=\(!(yearlyProduct?.displayPrice.isEmpty ?? true))"
                        )
                    }
                    SubscriptionDiagnostics.log("paywall_state_updated", resultType: "loaded")
                    return
                }
                products = []
                lastError = "App Store products not available yet"
                catalogState = .empty
                SubscriptionDiagnostics.log("products_load_empty", productId: requested, resultType: "count=0")
                SubscriptionDiagnostics.log("paywall_state_updated", resultType: "empty")
            } catch is CancellationError {
                return
            } catch {
                products = []
                lastError = error.localizedDescription
                catalogState = .failed
                let ns = error as NSError
                SubscriptionDiagnostics.log(
                    "products_load_failed",
                    productId: requested,
                    errorDomain: ns.domain,
                    errorCode: ns.code
                )
                SubscriptionDiagnostics.log("paywall_state_updated", resultType: "failed")
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
        catalogState = .purchasing
        defer {
            purchaseGuard.end()
            isPurchaseInProgress = false
            if !products.isEmpty {
                catalogState = .loaded
            }
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
            guard StoreProductIDs.all.contains(transaction.productID) else { continue }
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
                guard StoreProductIDs.all.contains(transaction.productID) else {
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
