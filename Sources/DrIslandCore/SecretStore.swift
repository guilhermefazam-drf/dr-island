import Foundation
import LocalAuthentication
import Security

/// Generic-password items in the login keychain. Secrets never touch UserDefaults, files or logs.
public enum SecretStore {
    /// Kept from the app's previous name so a saved Jira token is still found.
    public static let service = "com.fazam.token-island"

    public enum Failure: Error, Equatable { case keychain(OSStatus) }

    public static func read(account: String) -> String? {
        var query = baseQuery(account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func exists(account: String) -> Bool {
        var query = baseQuery(account)
        // Never prompt: an item that would need to ask reports errSecInteractionNotAllowed instead.
        let context = LAContext()
        context.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = context
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        // errSecInteractionNotAllowed means the item exists but would prompt; that still counts as present.
        return status == errSecSuccess || status == errSecInteractionNotAllowed
    }

    public static func write(_ secret: String, account: String) throws {
        let data = Data(secret.utf8)
        let update = SecItemUpdate(baseQuery(account) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return }
        guard update == errSecItemNotFound else { throw Failure.keychain(update) }
        var add = baseQuery(account)
        add[kSecValueData as String] = data
        let status = SecItemAdd(add as CFDictionary, nil)
        guard status == errSecSuccess else { throw Failure.keychain(status) }
    }

    public static func delete(account: String) {
        SecItemDelete(baseQuery(account) as CFDictionary)
    }

    private static func baseQuery(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
}
