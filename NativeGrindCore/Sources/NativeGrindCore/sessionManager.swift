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
    
    private func handleAuth(provider: String, function: () async throws -> Void) async {
        do {
            try await function()
            
            self.isAuthenticated = true
            
        } catch {
            errorManager.shared.error("SessionManager", "\(provider): \(error.localizedDescription)")
            self.isAuthenticated = false
        }
    }
    
    public init() {
        checkCurrentAuthStatus()
    }
    
    /// Check if the token is in the keychain
    public func checkCurrentAuthStatus() {
        if let existingToken = keychain.getToken(type: .authToken) {
            // We need to add a check here to make sure token is still valid
            errorManager.shared.log("SessionManager", "Existing authtoken found")
            self.isAuthenticated = true
        } else {
            self.isAuthenticated = false
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
        
        keychainManager.shared.saveToken(sessionId, type: .sessionId)
        keychainManager.shared.saveToken(authToken, type: .authToken)
        keychainManager.shared.saveToken("false", type: .isEmail)
        keychainManager.shared.saveToken(thirdPartyUserId, type: .data)
    }
    
    public func authenticateWithGoogle(accessToken: String) async {
        await handleAuth(provider: "Google Login") {
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
        
        keychainManager.shared.saveToken(sessionId, type: .sessionId)
        keychainManager.shared.saveToken(authToken, type: .authToken)
        keychainManager.shared.saveToken("false", type: .isEmail)
        keychainManager.shared.saveToken(thirdPartyUserId, type: .data)
    }
    
    public func authenticateWithFacebook(accessToken: String) async {
        await handleAuth(provider: "Facebook Login") {
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
        
        keychainManager.shared.saveToken(sessionId, type: .sessionId)
        keychainManager.shared.saveToken(authToken, type: .authToken)
        keychainManager.shared.saveToken("true", type: .isEmail)
        keychainManager.shared.saveToken(email, type: .data)
    }
    
    public func authenticateWithEmail(email: String, password: String) async {
        await handleAuth(provider: "Email Login") {
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
        
        keychainManager.shared.saveToken(sessionId, type: .sessionId)
        keychainManager.shared.saveToken(authToken, type: .authToken)
        keychainManager.shared.saveToken("true", type: .isEmail)
        keychainManager.shared.saveToken(email, type: .data)
    }
    
    public func authenticateWithAuthToken(token: String, email: String) async {
        await handleAuth(provider: "AuthToken Login") {
            try await _authenticateWithAuthToken(token: token, email: email)
        }
    }
    
    public func _authenticateWithThirdPartyToken(token: String, thirdPartyUserId: String) async throws {
        let response = try await APIClient.shared.request(.refreshThirdParty(thirdPartyUserId: thirdPartyUserId, authToken: token))
        
        guard let response = response else {
            throw authenticationError.invalidResponse
        }
        
        let sessionId = response.authenticationResponse.sessionId
        let authToken = response.authenticationResponse.authToken
        
        keychainManager.shared.saveToken(sessionId, type: .sessionId)
        keychainManager.shared.saveToken(authToken, type: .authToken)
        keychainManager.shared.saveToken("false", type: .isEmail)
        keychainManager.shared.saveToken(thirdPartyUserId, type: .data)
    }
    
    public func authenticateWithThirdPartyToken(token: String, thirdPartyUserId: String) async {
        await handleAuth(provider: "Third Party Token Login") {
            try await _authenticateWithThirdPartyToken(token: token, thirdPartyUserId: thirdPartyUserId)
        }
    }
    
    public func _refreshToken() async throws {
        
        guard let isEmail = keychainManager.shared.getToken(type: .isEmail) else {
            throw authenticationError.missing(itemName: "isEmail")
        }
        
        guard let data = keychainManager.shared.getToken(type: .data) else {
            throw authenticationError.missing(itemName: "data")
        }
        
        guard let authToken = keychainManager.shared.getToken(type: .authToken) else {
            throw authenticationError.missing(itemName: "authToken")
        }
        
        if (isEmail == "true") {
            let response = try await APIClient.shared.request(.refreshToken(email: data, token: authToken))
            
            guard let response = response else {
                throw authenticationError.invalidResponse
            }
            
            let sessionId = response.sessionId
            let authToken = response.authToken
            
            keychainManager.shared.saveToken(sessionId, type: .sessionId)
            keychainManager.shared.saveToken(authToken, type: .authToken)
        } else {
            let response = try await APIClient.shared.request(.refreshThirdParty(thirdPartyUserId: data, authToken: authToken))
            
            guard let response = response else {
                throw authenticationError.invalidResponse
            }
            
            let sessionId = response.authenticationResponse.sessionId
            let authToken = response.authenticationResponse.authToken
            
            keychainManager.shared.saveToken(sessionId, type: .sessionId)
            keychainManager.shared.saveToken(authToken, type: .authToken)
        }
    }
    
    public func refreshToken() async {
        await handleAuth(provider: "Refresh Token") {
            try await _refreshToken()
        }
    }
    
    /// Clears credentials and tears down the active state
    public func logout() {
        keychain.deleteToken(type: .authToken)
        keychain.deleteToken(type: .sessionId)
        keychain.deleteToken(type: .isEmail)
        keychain.deleteToken(type: .data)

        self.isAuthenticated = false
    }
}
