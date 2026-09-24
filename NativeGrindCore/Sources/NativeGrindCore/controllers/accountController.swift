//
//  accountController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/08/2026.
//

import Foundation
import CryptoKit

public actor accountController {
    public static let shared = accountController()
    

    private var accounts: [nsAccount] = []
    private var currentAccount: nsAccount?
    
    private init() {
        if let jsonString = keychainManager.shared.getToken(type: .accountsList),
           let data = jsonString.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([nsAccount].self, from: data) {
            self.accounts = decoded
        }
    }
    
    private func saveLocalAccounts() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(accounts),
           let jsonString = String(data: data, encoding: .utf8) {
            keychainManager.shared.saveToken(jsonString, type: .accountsList)
        }
    }
    
    public func getAccounts() -> [nsAccount] {
        return accounts
    }
    
    public func addAccount(_ account: nsAccount) async {
        let replaced = accounts.filter { ($0.data == account.data && $0.isEmail == account.isEmail) || $0.sessionId == account.sessionId }
        accounts.removeAll { ($0.data == account.data && $0.isEmail == account.isEmail) || $0.sessionId == account.sessionId }
        accounts.append(account)
        saveLocalAccounts()

        for old in replaced where Self.syncKey(for: old) != Self.syncKey(for: account) {
            await localStore.shared.noteChange(collection: .grindrAccounts, key: Self.syncKey(for: old), kind: .delete)
        }
        await localStore.shared.noteChange(collection: .grindrAccounts, key: Self.syncKey(for: account), kind: .upsert)
        Task { await syncController.shared.syncNow() }
    }

    public func removeAccount(sessionId: String) async {
        let removed = accounts.filter { $0.sessionId == sessionId || $0.data == sessionId }
        accounts.removeAll { $0.sessionId == sessionId || $0.data == sessionId }
        if currentAccount?.sessionId == sessionId || currentAccount?.data == sessionId {
            currentAccount = nil
        }
        saveLocalAccounts()

        for account in removed {
            await localStore.shared.noteChange(collection: .grindrAccounts, key: Self.syncKey(for: account), kind: .delete)
        }
        Task { await syncController.shared.syncNow() }
    }

    public func queueAllForSync() async {
        for account in accounts {
            await localStore.shared.noteChange(collection: .grindrAccounts, key: Self.syncKey(for: account), kind: .upsert)
        }
    }

    static func syncKey(for account: nsAccount) -> String {
        let digest = SHA256.hash(data: Data("\(account.isEmail)|\(account.data)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private var activeTokenChanged = false

    func exportForSync(key: String) -> Data? {
        guard let account = accounts.first(where: { Self.syncKey(for: $0) == key }) else { return nil }
        return try? JSONEncoder().encode(nsCloudAccount(from: account))
    }

    func importFromSync(key: String, value: Data?) {
        let index = accounts.firstIndex { Self.syncKey(for: $0) == key }

        guard let value, let cloudAccount = try? JSONDecoder().decode(nsCloudAccount.self, from: value) else {
            if let index {
                accounts.remove(at: index)
                saveLocalAccounts()
            }
            return
        }

        if let index {
            let existing = accounts[index]
            if existing.authToken != cloudAccount.authToken, isActive(existing) {
                activeTokenChanged = true
            }
            accounts[index] = cloudAccount.toAccount(sessionId: existing.sessionId)
        } else {
            accounts.append(cloudAccount.toAccount())
        }
        saveLocalAccounts()
    }

    func reconcileAfterSync() async {
        let isAuthenticated = await sessionManager.shared.isAuthenticated
        defer { activeTokenChanged = false }

        guard isAuthenticated else {
            if let first = accounts.first {
                await switchAccount(account: first)
            }
            return
        }

        guard let active = accounts.first(where: isActive) else {
            currentAccount = nil
            if let first = accounts.first {
                await switchAccount(account: first)
            } else {
                await sessionManager.shared.logout(isSwitching: true)
            }
            return
        }

        if activeTokenChanged {
            keychainManager.shared.saveToken(active.authToken, type: .authToken)
            await sessionManager.shared.refreshToken()
        }
    }
    
    private func isActive(_ account: nsAccount) -> Bool {
        account.data == keychainManager.shared.getToken(type: .data) && account.isEmail == keychainManager.shared.getToken(type: .isEmail)
    }

    public func switchAccount(account: nsAccount) async {
        if let current = currentAccount, current.sessionId == account.sessionId {
            return
        }
        
        currentAccount = account
        
        await sessionManager.shared.logout(isSwitching: true)
        
        keychainManager.shared.saveToken(account.sessionId, type: .sessionId)
        keychainManager.shared.saveToken(account.data, type: .data)
        keychainManager.shared.saveToken(account.authToken, type: .authToken)
        keychainManager.shared.saveToken(account.isEmail, type: .isEmail)
        
        await sessionManager.shared.refreshToken()
    }
    
    #if DEBUG
    public func clearAccounts() {
        self.accounts = []
        keychainManager.shared.deleteToken(type: .accountsList)
        self.currentAccount = nil
    }
    #endif
}
