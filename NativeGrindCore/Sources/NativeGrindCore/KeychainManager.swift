//
//  KeychainManager.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

import Foundation
import Security

public final class KeychainManager {
    
    @MainActor public static let shared = KeychainManager()
    private let service = "dev.imaoreo.NativeGrind"
    private let account = "authToken"
    
    private init() {}
    
    /// Saves or updates the authentication token in the secure Keychain
    @discardableResult
    public func saveToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }
        
        // 1. Prepare the query to look for an existing token
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        // 2. Check if the item already exists
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            // Attributes to update
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            // Update the existing item
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            return updateStatus == errSecSuccess
        } else {
            // 3. Item doesn't exist, create a brand new one
            var newItem = query
            newItem[kSecValueData as String] = data
            // Restrict read access until the device is explicitly unlocked by the user
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
    }
    
    /// Retrieves the token from the Keychain
    public func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        guard status == errSecSuccess, let data = dataTypeRef as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// Deletes the token from the Keychain (used during logout)
    @discardableResult
    public func deleteToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
