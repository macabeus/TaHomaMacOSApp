import Foundation
import Security
import OSLog

private let logger = Logger(subsystem: "com.tahoma-macos-app", category: "KeychainHelper")

enum KeychainHelper {
    private static let service = "com.tahoma-macos-app"

    static func save(_ value: String, forKey key: String) {
        guard let data = value.data(using: .utf8) else { return }

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
            kSecUseDataProtectionKeychain as String: true,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess {
            logger.error("save: wrote \(value.count, privacy: .public) chars for key \(key, privacy: .public)")
        } else {
            logger.error("save: FAILED for key \(key, privacy: .public), status=\(status, privacy: .public)")
        }
    }

    static func load(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data, let value = String(data: data, encoding: .utf8) {
            logger.error("load: \(key, privacy: .public) = <\(value.count, privacy: .public) chars>")
            return value
        }
        logger.error("load: \(key, privacy: .public) = nil (status=\(status, privacy: .public))")
        return nil
    }

    static func delete(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecUseDataProtectionKeychain as String: true,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Convenience accessors

    private static let tokenKey = "bearerToken"
    private static let gatewayPinKey = "gatewayPin"
    private static let deviceURLKey = "deviceURL"

    static func saveToken(_ token: String) {
        save(token, forKey: tokenKey)
    }

    static func loadToken() -> String? {
        load(forKey: tokenKey)
    }

    static func saveGatewayPin(_ pin: String) {
        save(pin, forKey: gatewayPinKey)
    }

    static func loadGatewayPin() -> String? {
        load(forKey: gatewayPinKey)
    }

    static func saveDeviceURL(_ url: String) {
        save(url, forKey: deviceURLKey)
    }

    static func loadDeviceURL() -> String? {
        load(forKey: deviceURLKey)
    }
}
