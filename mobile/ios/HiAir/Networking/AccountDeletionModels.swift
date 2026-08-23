import Foundation

struct DeleteAccountRequirementsResponse: Decodable, Sendable {
    let requiresAppleAuthorizationCode: Bool
    let authProvider: String
    let operationId: String?
    let inProgress: Bool
    let stages: [String: String]
    let recoveryHint: String?

    enum CodingKeys: String, CodingKey {
        case requiresAppleAuthorizationCode = "requires_apple_authorization_code"
        case authProvider = "auth_provider"
        case operationId = "operation_id"
        case inProgress = "in_progress"
        case stages
        case recoveryHint = "recovery_hint"
    }
}

struct DeleteAccountResponsePayload: Decodable, Sendable {
    let deleted: Bool
    let operationId: String?
    let stages: [String: String]
    let recoveryHint: String?

    enum CodingKeys: String, CodingKey {
        case deleted
        case operationId = "operation_id"
        case stages
        case recoveryHint = "recovery_hint"
    }
}

struct AccountDeletionAPIError: LocalizedError, Sendable {
    let statusCode: Int
    let message: String
    let operationId: String?
    let stages: [String: String]
    let recoveryHint: String?

    var errorDescription: String? {
        recoveryHint ?? message
    }

    static func parse(statusCode: Int, data: Data) -> AccountDeletionAPIError {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let detail = root["detail"] as? [String: Any]
        else {
            return AccountDeletionAPIError(
                statusCode: statusCode,
                message: "Account deletion failed.",
                operationId: nil,
                stages: [:],
                recoveryHint: nil
            )
        }
        let stages = detail["stages"] as? [String: String] ?? [:]
        return AccountDeletionAPIError(
            statusCode: statusCode,
            message: detail["message"] as? String ?? "Account deletion failed.",
            operationId: detail["operation_id"] as? String,
            stages: stages,
            recoveryHint: detail["recovery_hint"] as? String
        )
    }
}

enum AccountDeletionStageLabel {
    static func summary(_ stages: [String: String], operationId: String? = nil) -> String {
        let stageText = stages
            .sorted { $0.key < $1.key }
            .map { "\($0.key): \($0.value)" }
            .joined(separator: ", ")
        guard let operationId, !operationId.isEmpty else {
            return stageText
        }
        if stageText.isEmpty {
            return "operation_id: \(operationId)"
        }
        return "operation_id: \(operationId), \(stageText)"
    }
}
