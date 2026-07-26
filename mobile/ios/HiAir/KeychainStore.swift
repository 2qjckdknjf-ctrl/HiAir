import Foundation
import Security

/// Production-shaped credential persistence used by `AppSession`.
/// Real builds use `KeychainStore`; unit tests inject `InMemorySessionCredentialStore`
/// so ownership/relaunch proofs stay deterministic under `CODE_SIGNING_ALLOWED=NO`
/// (SecItem writes can silently fail without a signed identity).
protocol SessionCredentialStoring {
    func setString(_ value: String, forKey key: String)
    func getString(forKey key: String) -> String?
    func deleteValue(forKey key: String)
}

struct KeychainStore: SessionCredentialStoring {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func setString(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else {
            return
        }

        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]

        let status = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if status == errSecSuccess {
            return
        }

        var createQuery = baseQuery
        createQuery[kSecValueData as String] = data
        createQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(createQuery as CFDictionary, nil)
    }

    func getString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    func deleteValue(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Deterministic credential backend for ownership / relaunch unit tests.
final class InMemorySessionCredentialStore: SessionCredentialStoring {
    private var values: [String: String] = [:]

    func setString(_ value: String, forKey key: String) {
        values[key] = value
    }

    func getString(forKey key: String) -> String? {
        values[key]
    }

    func deleteValue(forKey key: String) {
        values.removeValue(forKey: key)
    }

    func removeAll() {
        values.removeAll()
    }
}
