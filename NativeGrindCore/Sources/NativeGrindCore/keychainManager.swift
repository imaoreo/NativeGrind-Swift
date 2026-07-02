//
//  keychainManager.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

import Foundation
import Security

public enum keyType: String, Decodable, Sendable {
    case authToken = "authToken"
    case sessionId = "sessionId"
    case isEmail = "isEmail"
    case data = "data" // for email this is the email for third party this is the thirdparty user id
}

public final class keychainManager {
    
    @MainActor public static let shared = keychainManager()
    let service = "dev.imaoreo.NativeGrind"
    
    private let lock = NSLock()
    private var testStorage: [String: String] = [:]
    
    private init() {}
    
    /// Saves or updates the authentication token in Keychain
    @discardableResult
    public func saveToken(_ token: String, type: keyType) -> Bool {
        if appEnvironment.isTesting {
            lock.lock()
            defer { lock.unlock() }
            testStorage[type.rawValue] = token
            return true
        }
        
        guard let data = token.data(using: .utf8) else { return false }
        
        // Prepare query to check if there is a token
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: type.rawValue
        ]
        
        // check if it exists
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            // update the item
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]

            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            return updateStatus == errSecSuccess
        } else {
            // create a new item
            var newItem = query
            newItem[kSecValueData as String] = data
            // security to make sure the token can only be accessed after the device has been unlocked
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            return addStatus == errSecSuccess
        }
    }
    
    /// Retrieves the token from the Keychain
    public func getToken(type: keyType) -> String? {
        if appEnvironment.isTesting {
            lock.lock()
            defer { lock.unlock() }
            return testStorage[type.rawValue]
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: type.rawValue,
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
    
    /// Deletes the token from the Keychain
    @discardableResult
    public func deleteToken(type: keyType) -> Bool {
        if appEnvironment.isTesting {
            lock.lock()
            defer { lock.unlock() }
            testStorage.removeValue(forKey: type.rawValue)
            return true
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: type.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
