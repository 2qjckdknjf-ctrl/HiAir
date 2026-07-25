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

    func loadProducts(maxAttempts: Int = 2) {
        if isPurchaseInProgress {
            SubscriptionDiagnostics.log("products_load_skipped_purchase_in_progress")
            return
        }
        if let loadTask, !loadTask.isCancelled {
            SubscriptionDiagnostics.log("products_load_skipped_already_running")
            return
        }
        // Unstructured task owned by the service — not cancelled by SwiftUI view lifetime.
        loadTask = Task { await performLoadProducts(maxAttempts: maxAttempts) }
    }

    func loadProductsAndWait(maxAttempts: Int = 2) async {
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
        await logStorefrontIfAvailable()

        for attempt in 1...maxAttempts {
            guard !isPurchaseInProgress else { return }
            do {
                let loaded = try await productFetcher.fetchProducts(ids: StoreProductIDs.all)
                SubscriptionDiagnostics.log(
                    "returned_product_count",
                    resultType: "count=\(loaded.count)"
                )
                if !loaded.isEmpty {
                    products = loaded.sorted { $0.id < $1.id }
                    lastError = nil
                    catalogState = .loaded
                    let ids = loaded.map(\.id)
                    SubscriptionDiagnostics.log(
                        "products_load_succeeded",
                        productId: ids.joined(separator: ","),
                        resultType: "count=\(loaded.count)"
                    )
                    SubscriptionDiagnostics.log("returned_product_ids", productId: ids.joined(separator: ","))
                    if let monthly = monthlyProduct {
                        SubscriptionDiagnostics.log(
                            "monthly_product_available",
                            productId: StoreProductIDs.monthly,
                            pricePresent: !monthly.displayPrice.isEmpty
                        )
                        SubscriptionDiagnostics.log(
                            "monthly_price_available",
                            productId: StoreProductIDs.monthly,
                            pricePresent: !monthly.displayPrice.isEmpty
                        )
                    }
                    if let yearly = yearlyProduct {
                        SubscriptionDiagnostics.log(
                            "yearly_product_available",
                            productId: StoreProductIDs.yearly,
                            pricePresent: !yearly.displayPrice.isEmpty
                        )
                        SubscriptionDiagnostics.log(
                            "yearly_price_available",
                            productId: StoreProductIDs.yearly,
                            pricePresent: !yearly.displayPrice.isEmpty
                        )
                    }
                    SubscriptionDiagnostics.log("paywall_state_updated", resultType: "loaded")
                    return
                }
                products = []
                lastError = nil
                catalogState = .empty
                SubscriptionDiagnostics.log("products_load_empty", productId: requested, resultType: "count=0")
                SubscriptionDiagnostics.log("paywall_state_updated", resultType: "empty")
            } catch {
                let ns = error as NSError
                let cancelled = Self.isRequestCanceled(error)
                SubscriptionDiagnostics.log(
                    "products_load_failed",
                    productId: requested,
                    resultType: cancelled ? "request_canceled" : "error",
                    errorDomain: ns.domain,
                    errorCode: ns.code
                )
                if cancelled, attempt < maxAttempts {
                    let delayNs = UInt64(attempt) * 1_500_000_000
                    try? await Task.sleep(nanoseconds: delayNs)
                    continue
                }
                products = []
                lastError = Self.userFacingCatalogError(error)
                catalogState = .failed
                SubscriptionDiagnostics.log("paywall_state_updated", resultType: "failed")
            }

            if attempt < maxAttempts {
                let delayNs = UInt64(attempt) * 1_500_000_000
                try? await Task.sleep(nanoseconds: delayNs)
            }
        }

        if catalogState == .loading {
            catalogState = .failed
            lastError = lastError ?? HiAirL10n.t("paywall.products_unavailable", lang: Self.uiLanguage)
            SubscriptionDiagnostics.log("paywall_state_updated", resultType: "failed")
        }
    }

    private func logStorefrontIfAvailable() async {
        if let storefront = await Storefront.current {
            SubscriptionDiagnostics.log(
                "storefront_detected",
                resultType: storefront.countryCode
            )
        }
    }

    private static func isRequestCanceled(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return true }
        let message = ns.localizedDescription.lowercased()
        return message.contains("request canceled") || message.contains("request cancelled")
    }

    private static var uiLanguage: String {
        UserDefaults.standard.string(forKey: "session.preferredLanguage") ?? "ru"
    }

    private static func userFacingCatalogError(_ error: Error) -> String {
        let lang = uiLanguage
        if isRequestCanceled(error) {
            return HiAirL10n.t("paywall.products_unavailable", lang: lang)
        }
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty {
            return HiAirL10n.t("paywall.products_unavailable", lang: lang)
        }
        // Never surface raw "Request Canceled" as the primary empty-state copy.
        if message.lowercased().contains("request canceled") || message.lowercased().contains("request cancelled") {
            return HiAirL10n.t("paywall.products_unavailable", lang: lang)
        }
        return HiAirL10n.t("paywall.products_unavailable", lang: lang)
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

        // Do not scan currentEntitlements before purchase — that path added multi-second
        // latency before the StoreKit sheet. Restore still uses syncVerifiedEntitlementsIfPresent.

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
                // Activating immediately after StoreKit verification (before backend).
                // Not permanent truth — pending until server confirms; terminal reject rolls back.
                let optimistic = UserEntitlementResponse(
                    userId: userId,
                    plan: product.id.contains("yearly") ? "yearly" : "monthly",
                    isPremium: true,
                    maxProfiles: 5,
                    extendedForecastEnabled: true,
                    customAlertsEnabled: true,
                    exportReportsEnabled: true,
                    advancedInsightsEnabled: true
                )
                NotificationCenter.default.post(
                    name: .subscriptionEntitlementDidUpdate,
                    object: optimistic,
                    userInfo: ["activationPending": true]
                )
                do {
                    return try await processVerifiedTransaction(
                        verification,
                        transaction: transaction,
                        userId: userId,
                        accessToken: accessToken,
                        correlationId: String(correlationId)
                    )
                } catch let error as APIError {
                    if Self.isTerminalSubscriptionRejection(error) {
                        NotificationCenter.default.post(
                            name: .subscriptionEntitlementDidUpdate,
                            object: nil,
                            userInfo: ["rollback": true, "userId": userId]
                        )
                    }
                    // Transient failures keep Activating + unfinished transaction for safe retry.
                    throw error
                }
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
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result else { continue }
            guard StoreProductIDs.all.contains(transaction.productID) else {
                await transaction.finish()
                continue
            }
            if let signed = try? signedTransactionString(from: result) {
                signedTransactions.append(signed)
            }
            do {
                _ = try await processVerifiedTransaction(
                    result,
                    transaction: transaction,
                    userId: userId,
                    accessToken: accessToken,
                    correlationId: "restore_unfinished"
                )
            } catch {
                continue
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
                NotificationCenter.default.post(
                    name: .subscriptionEntitlementDidUpdate,
                    object: response.entitlement,
                    userInfo: ["activationPending": false]
                )
            } else {
                // Server explicitly denied entitlement for a verified transaction.
                NotificationCenter.default.post(
                    name: .subscriptionEntitlementDidUpdate,
                    object: nil,
                    userInfo: ["rollback": true, "userId": userId]
                )
            }
            // Always finish after a successful backend verify to avoid retry loops
            // that leave Premium UI stuck on pending when entitlement flags lag.
            await transaction.finish()
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

    func userFacingMessage(for error: APIError, language: String? = nil) -> String {
        let lang = language ?? Self.uiLanguage
        switch error {
        case .serverWithDetail, .server:
            return HiAirL10n.t("paywall.server_error", lang: lang)
        case .invalidURL, .invalidResponse:
            return HiAirL10n.t("paywall.network_error", lang: lang)
        }
    }

    /// 4xx (except timeout/rate-limit) → permanent reject; do not keep optimistic Premium.
    static func isTerminalSubscriptionRejection(_ error: APIError) -> Bool {
        switch error {
        case .server(let code), .serverWithDetail(let code, _):
            return (400..<500).contains(code) && code != 408 && code != 429
        case .invalidURL, .invalidResponse:
            return false
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
        let lang = UserDefaults.standard.string(forKey: "session.preferredLanguage") ?? "ru"
        switch self {
        case .cancelled:
            return HiAirL10n.t("paywall.purchase_cancelled", lang: lang)
        case .pending:
            return HiAirL10n.t("paywall.purchase_pending", lang: lang)
        case .unknown:
            return HiAirL10n.t("paywall.generic_error", lang: lang)
        case .purchaseInProgress:
            return HiAirL10n.t("paywall.purchase_in_progress", lang: lang)
        case .verificationFailed:
            return HiAirL10n.t("paywall.verification_failed", lang: lang)
        }
    }
}
