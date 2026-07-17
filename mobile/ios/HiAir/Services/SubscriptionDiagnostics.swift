import Foundation
import os

enum SubscriptionDiagnostics {
    private static let logger = Logger(subsystem: "com.hiair.app", category: "subscription")

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
