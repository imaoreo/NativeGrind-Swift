//
//  sessionManager.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

import Foundation
import Combine

@MainActor
public final class sessionManager: ObservableObject {
    public static let shared = sessionManager()
    
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isLoading: Bool = false
    
    private let keychain = keychainManager.shared

    public var profileId: Int? {
        keychain.getToken(type: .profileId).flatMap { Int($0) }
    }

    private var activeRefreshTask: Task<Void, Never>? = nil
    
    private func registerCurrentAccount() async {
        if let authToken = keychain.getToken(type: .authToken),
           let sessionId = keychain.getToken(type: .sessionId),
           let isEmail = keychain.getToken(type: .isEmail),
           let data = keychain.getToken(type: .data) {
            let account = nsAccount(authToken: authToken, sessionId: sessionId, isEmail: isEmail, data: data)
            do {
                try await accountController.shared.addAccount(account)
            } catch {
                errorManager.shared.error("SessionManager", "Failed to add account to accountController: \(error.localizedDescription)")
            }
        }
    }

    private func handleAuth(provider: String, showErrors: Bool = true, isNewLogin: Bool = false, function: () async throws -> Void) async {
        do {
            try await function()
            
            self.isAuthenticated = true
            if isNewLogin {
                await registerCurrentAccount()
            }
            
        } catch authenticationError.networkError {
            // make sure there is authToken and sessionId for allowing it to stay authed
            self.isAuthenticated = (self.keychain.getToken(type: .authToken) != nil &&
                                    self.keychain.getToken(type: .sessionId) != nil)
            if self.isAuthenticated && isNewLogin {
                await registerCurrentAccount()
            }
            if showErrors {
                errorManager.shared.warn("SessionManager", "Offline: \(provider) skipped due to no internet.")
            }
        } catch {
            if showErrors {
                errorManager.shared.error("SessionManager", "\(provider): \(error.localizedDescription)")
            }
            self.isAuthenticated = false
        }
    }
    
    public init() {
        if !appEnvironment.isTesting {
            Task { await refreshToken(showError: false) }
        }
    }
    
    /// change the google login to a grindr auth token
    private func _authenticateWithGoogle(accessToken: String) async throws{
        let response = try await APIClient.shared.request(.thirdPartyLogin(token: accessToken, isFacebook: false))
        
        guard let response = response else {
            throw authenticationError.invalidResponse
        }
        
        let sessionId = response.authenticationResponse.sessionId
        let authToken = response.authenticationResponse.authToken
        let thirdPartyUserId = response.authenticationResponse.thirdPartyUserId
        
        keychainManager.shared.saveToken(response.authenticationResponse.profileId, type: .profileId)
        keychainManager.shared.saveToken(sessionId.rawValue, type: .sessionId)
        keychainManager.shared.saveToken(authToken, type: .authToken)
        keychainManager.shared.saveToken("false", type: .isEmail)
        keychainManager.shared.saveToken(thirdPartyUserId, type: .data)
    }
    
    public func authenticateWithGoogle(accessToken: String) async {
        await handleAuth(provider: "Google Login", isNewLogin: true) {
            try await _authenticateWithGoogle(accessToken: accessToken)
        }
    }
    
    /// change the facebook login to a grindr auth token
    private func _authenticateWithFacebook(accessToken: String) async throws {
        let response = try await APIClient.shared.request(.thirdPartyLogin(token: accessToken, isFacebook: true))
        
        guard let response = response else {
            throw authenticationError.invalidResponse
        }
        
        let sessionId = response.authenticationResponse.sessionId
        let authToken = response.authenticationResponse.authToken
        let thirdPartyUserId = response.authenticationResponse.thirdPartyUserId

        keychainManager.shared.saveToken(response.authenticationResponse.profileId, type: .profileId)
        keychainManager.shared.saveToken(sessionId.rawValue, type: .sessionId)
        keychainManager.shared.saveToken(authToken, type: .authToken)
        keychainManager.shared.saveToken("false", type: .isEmail)
        keychainManager.shared.saveToken(thirdPartyUserId, type: .data)
    }
    
    public func authenticateWithFacebook(accessToken: String) async {
        await handleAuth(provider: "Facebook Login", isNewLogin: true) {
            try await _authenticateWithFacebook(accessToken: accessToken)
        }
    }
    
    private func _authenticateWithEmail(email: String, password: String) async throws {
        let response = try await APIClient.shared.request(.login(email: email, password: password))
        
        guard let response = response else {
            throw authenticationError.invalidResponse
        }
        
        let sessionId = response.sessionId
        let authToken = response.authToken

        keychainManager.shared.saveToken(response.profileId, type: .profileId)
        keychainManager.shared.saveToken(sessionId.rawValue, type: .sessionId)
        keychainManager.shared.saveToken(authToken, type: .authToken)
        keychainManager.shared.saveToken("true", type: .isEmail)
        keychainManager.shared.saveToken(email, type: .data)
    }
    
    public func authenticateWithEmail(email: String, password: String) async {
        await handleAuth(provider: "Email Login", isNewLogin: true) {
            try await _authenticateWithEmail(email: email, password: password)
        }
    }

    private func _authenticateWithAuthToken(token: String, email: String) async throws {
        let response = try await APIClient.shared.request(.refreshToken(email: email, token: token))
        
        guard let response = response else {
            throw authenticationError.invalidResponse
        }
            
        let sessionId = response.sessionId
        let authToken = response.authToken

        keychainManager.shared.saveToken(response.profileId, type: .profileId)
        keychainManager.shared.saveToken(sessionId.rawValue, type: .sessionId)
        keychainManager.shared.saveToken(authToken, type: .authToken)
        keychainManager.shared.saveToken("true", type: .isEmail)
        keychainManager.shared.saveToken(email, type: .data)
    }
    
    public func authenticateWithAuthToken(token: String, email: String) async {
        await handleAuth(provider: "AuthToken Login", isNewLogin: true) {
            try await _authenticateWithAuthToken(token: token, email: email)
        }
    }
    
    private func _authenticateWithThirdPartyToken(token: String, thirdPartyUserId: String) async throws {
        let response = try await APIClient.shared.request(.refreshThirdParty(thirdPartyUserId: thirdPartyUserId, authToken: token))
        
        guard let response = response else {
            throw authenticationError.invalidResponse
        }
        
        let sessionId = response.authenticationResponse.sessionId
        let authToken = response.authenticationResponse.authToken

        keychainManager.shared.saveToken(response.authenticationResponse.profileId, type: .profileId)
        keychainManager.shared.saveToken(sessionId.rawValue, type: .sessionId)
        keychainManager.shared.saveToken(authToken, type: .authToken)
        keychainManager.shared.saveToken("false", type: .isEmail)
        keychainManager.shared.saveToken(thirdPartyUserId, type: .data)
    }
    
    public func authenticateWithThirdPartyToken(token: String, thirdPartyUserId: String) async {
        await handleAuth(provider: "Third Party Token Login", isNewLogin: true) {
            try await _authenticateWithThirdPartyToken(token: token, thirdPartyUserId: thirdPartyUserId)
        }
    }
    
    private func _refreshToken() async throws {
        
        guard let isEmail = keychainManager.shared.getToken(type: .isEmail) else {
            throw authenticationError.missing
        }
        
        guard let data = keychainManager.shared.getToken(type: .data) else {
            throw authenticationError.missing
        }
        
        guard let authToken = keychainManager.shared.getToken(type: .authToken) else {
            throw authenticationError.missing
        }
        
        do {
            // Email Refresh
            if (isEmail == "true") {
                let response = try await APIClient.shared.request(.refreshToken(email: data, token: authToken))
                
                guard let response = response else {
                    throw authenticationError.invalidResponse
                }
                
                let sessionId = response.sessionId
                let authToken = response.authToken

                keychainManager.shared.saveToken(response.profileId, type: .profileId)
                keychainManager.shared.saveToken(sessionId.rawValue, type: .sessionId)
                keychainManager.shared.saveToken(authToken, type: .authToken)
                
                return
            }
            
            // Third Party Refresh
            let response = try await APIClient.shared.request(.refreshThirdParty(thirdPartyUserId: data, authToken: authToken))
            
            guard let response = response else {
                throw authenticationError.invalidResponse
            }
            
            let sessionId = response.authenticationResponse.sessionId
            let responseAuthToken = response.authenticationResponse.authToken

            keychainManager.shared.saveToken(response.authenticationResponse.profileId, type: .profileId)
            keychainManager.shared.saveToken(sessionId.rawValue, type: .sessionId)
            keychainManager.shared.saveToken(responseAuthToken, type: .authToken)
        } catch requestError.networkError  {
            throw authenticationError.networkError
        } catch {
            throw error
        }
    }
    
    public func refreshToken(showError: Bool = true) async {
        if let existingTask = activeRefreshTask {
            _ = await existingTask.result
            return
        }
        
        let newTask = Task { @MainActor in
            await handleAuth(provider: "Refresh Token", showErrors: showError) {
                try await _refreshToken()
            }
        }
        activeRefreshTask = newTask
        
        _ = await newTask.result
        
        activeRefreshTask = nil
    }
    
    public func logout(isSwitching: Bool = false) async {
        let currentData = keychain.getToken(type: .data)
        
        if !isSwitching, let data = currentData {
            try? await accountController.shared.removeAccount(sessionId: data)
        }
        
        keychain.deleteToken(type: .authToken)
        keychain.deleteToken(type: .sessionId)
        keychain.deleteToken(type: .isEmail)
        keychain.deleteToken(type: .data)
        keychain.deleteToken(type: .profileId)
        keychain.deleteToken(type: .uploadSigningKey)
        keychain.deleteToken(type: .uploadSigningKeyId)

        self.isAuthenticated = false
    }
}
