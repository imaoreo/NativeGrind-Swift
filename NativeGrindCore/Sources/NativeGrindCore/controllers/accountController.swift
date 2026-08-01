//
//  accountController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/08/2026.
//

import Foundation

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
    
    public func addAccount(_ account: nsAccount) async throws {
        accounts.removeAll { ($0.data == account.data && $0.isEmail == account.isEmail) || $0.sessionId == account.sessionId }
        accounts.append(account)
        saveLocalAccounts()
        try await syncToCloud()
    }
    
    public func removeAccount(sessionId: String) async throws {
        accounts.removeAll { $0.sessionId == sessionId }
        saveLocalAccounts()
        try await syncToCloud()
    }
    
    private func syncToCloud() async throws {
        guard appEnvironment.isServerEnabled else { return }
        _ = try await nsStorageController.shared.saveData(location: .accounts, data: accounts)
    }
    
    public func syncFromCloud() async throws {
        guard appEnvironment.isServerEnabled else { return }
        self.accounts = try await nsStorageController.shared.getData(location: .accounts)
        saveLocalAccounts()
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
