import Foundation
import os
import StoreKit

enum SubscriptionDiagnostics {
    private static let logger = Logger(subsystem: "com.hiair.app", category: "subscription")

    /// A bounded local support history. Never stores a JWS,
    /// access token, email, or health data, and is not uploaded or backed up.
    @MainActor
    static func recordVerification(_ transaction: Transaction, ownerId: String, outcome: String) {
        guard APIClient.getAuthState()?.userId == ownerId else { return }
        let record: [String: String] = [
            "transactionId": String(transaction.id),
            "originalTransactionId": String(transaction.originalID),
            "productId": transaction.productID,
            "ownerId": ownerId,
            "appAccountToken": transaction.appAccountToken?.uuidString ?? "",
            "environment": String(describing: transaction.environment),
            "expiresAt": transaction.expirationDate.map { ISO8601DateFormatter().string(from: $0) } ?? "",
            "observedAt": ISO8601DateFormatter().string(from: Date()),
            "outcome": outcome
        ]
        guard let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let url = directory.appendingPathComponent("subscription-verification.json")
        var history: [[String: String]] = []
        if let data = try? Data(contentsOf: url),
           let previous = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
            history = previous.filter { $0["ownerId"] == ownerId }
        }
        history.append(record)
        guard let data = try? JSONSerialization.data(withJSONObject: Array(history.suffix(32)), options: [.sortedKeys]) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    @MainActor
    static func clearVerificationHistory(ownerId: String) {
        guard !ownerId.isEmpty,
              let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        let url = directory.appendingPathComponent("subscription-verification.json")
        guard let data = try? Data(contentsOf: url),
              let history = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return }
        let remaining = history.filter { $0["ownerId"] != ownerId }
        guard remaining.count != history.count else { return }
        if remaining.isEmpty {
            try? FileManager.default.removeItem(at: url)
        } else if let data = try? JSONSerialization.data(withJSONObject: remaining, options: [.sortedKeys]) {
            try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }

    static func log(
        _ event: String,
        productId: String? = nil,
        resultType: String? = nil,
        errorDomain: String? = nil,
        errorCode: Int? = nil,
        verificationState: String? = nil,
        httpStatus: Int? = nil,
        entitlementActive: Bool? = nil,
        correlationId: String? = nil,
        pricePresent: Bool? = nil
    ) {
        var parts: [String] = ["event=\(event)"]
        if let productId { parts.append("product_id=\(productId)") }
        if let resultType { parts.append("result_type=\(resultType)") }
        if let errorDomain { parts.append("error_domain=\(errorDomain)") }
        if let errorCode { parts.append("error_code=\(errorCode)") }
        if let verificationState { parts.append("verification=\(verificationState)") }
        if let httpStatus { parts.append("http_status=\(httpStatus)") }
        if let entitlementActive { parts.append("entitlement_active=\(entitlementActive)") }
        if let correlationId { parts.append("correlation_id=\(correlationId)") }
        if let pricePresent { parts.append("price_present=\(pricePresent)") }
        logger.info("\(parts.joined(separator: " "), privacy: .public)")
    }
}
