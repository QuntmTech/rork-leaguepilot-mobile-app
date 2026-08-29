import Foundation
import Security

/// Stores the PocketBase session token so the user stays signed in on this device.
/// Values live in the Keychain only — never in UserDefaults, files, or logs.
enum KeychainStore {
    enum Key: String {
        case authToken
        case userID
        case email
    }

    private static let service = "com.leaguepilot.ai.session"

    /// Writes a value, replacing any existing one.
    static func set(_ value: String, for key: Key) {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(baseQuery as CFDictionary)
        var attributes = baseQuery
        attributes[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(attributes as CFDictionary, nil)
    }

    /// Reads a value, or nil when absent.
    static func string(for key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// Removes every stored session value.
    static func removeAll() {
        for key in [Key.authToken, .userID, .email] {
            remove(key)
        }
    }

    static func remove(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
