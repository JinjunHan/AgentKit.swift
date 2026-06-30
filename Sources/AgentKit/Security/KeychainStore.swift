// KeychainStore.swift
// AgentKit
//
// SPDX-License-Identifier: MIT

import Foundation
import Security

/// A secure storage utility for managing sensitive credentials in the iOS Keychain.
///
/// Use `KeychainStore` to save, retrieve, and delete API keys, secret keys,
/// and other sensitive tokens. Items are stored as generic passwords and are
/// only accessible when the device is unlocked.
///
/// ## Usage
/// ```swift
/// let keychain = KeychainStore()
/// keychain.save("sk-...", forAccount: "openai-api-key")
///
/// if let apiKey = keychain.retrieve(forAccount: "openai-api-key") {
///     print("Retrieved API Key securely.")
/// }
/// ```
public struct KeychainStore: Sendable {
    
    private let service: String
    
    /// Creates a new Keychain store.
    ///
    /// - Parameter service: The service name used to group Keychain items.
    ///   Defaults to the app's bundle identifier or "com.agentkit" if unavailable.
    public init(service: String? = nil) {
        self.service = service ?? Bundle.main.bundleIdentifier ?? "com.agentkit"
    }
    
    /// Saves a string value to the Keychain.
    ///
    /// - Parameters:
    ///   - value: The string to store.
    ///   - account: The account identifier (e.g., "openai-api-key").
    /// - Returns: `true` if the item was saved successfully, `false` otherwise.
    @discardableResult
    public func save(_ value: String, forAccount account: String) -> Bool {
        let data = Data(value.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Delete existing item first to avoid errSecDuplicateItem
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    /// Retrieves a string value from the Keychain.
    ///
    /// - Parameter account: The account identifier.
    /// - Returns: The stored string, or `nil` if not found.
    public func retrieve(forAccount account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
    
    /// Deletes an item from the Keychain.
    ///
    /// - Parameter account: The account identifier.
    /// - Returns: `true` if the item was deleted successfully, `false` otherwise.
    @discardableResult
    public func delete(forAccount account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}
