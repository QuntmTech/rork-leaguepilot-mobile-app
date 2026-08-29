import Foundation
import Security

protocol KeychainStoring {
    func set(_ value: String, for key: KeychainStore.Key) throws
    func string(for key: KeychainStore.Key) throws -> String?
    func removeAll() throws
}

enum KeychainStoreError: LocalizedError { case unavailable
    var errorDescription: String? { "Secure storage is unavailable on this device." }
}

struct KeychainStore: KeychainStoring {
    enum Key: String { case authToken }
    private let service = "com.leaguepilot.ai.session"

    func set(_ value: String, for key: Key) throws {
        try remove(key)
        let status = SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: Data(value.utf8),
        ] as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainStoreError.unavailable }
    }

    func string(for key: Key) throws -> String? {
        var result: AnyObject?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ] as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainStoreError.unavailable }
        return String(data: data, encoding: .utf8)
    }

    func removeAll() throws { try remove(.authToken) }

    private func remove(_ key: Key) throws {
        let status = SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainStoreError.unavailable }
    }
}
