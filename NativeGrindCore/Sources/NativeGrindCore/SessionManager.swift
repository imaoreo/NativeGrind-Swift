//
//  SessionManager.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

import Foundation
import Combine

@MainActor
public final class SessionManager: ObservableObject {
    public static let shared = SessionManager()
    
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isLoading: Bool = false
    
    private let keychain = KeychainManager.shared
    
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
    public func authenticateWithGoogle(accessToken: String) async {
        do {
            let response = try await APIClient.shared.request(.thirdPartyLogin(token: accessToken, isFacebook: false))
            
            // make sure there isn't a error
            if let response = response {
                let sessionId = response.authenticationResponse.sessionId
                let authToken = response.authenticationResponse.authToken
                
                KeychainManager.shared.saveToken(sessionId, type: .sessionId)
                KeychainManager.shared.saveToken(authToken, type: .authToken)
                self.isAuthenticated = true
            }
        } catch {
            errorManager.shared.error("SessionManager", "Google Login: \(error.localizedDescription)")
        }
    }
    
    /// change the facebook login to a grindr auth token
    public func authenticateWithFacebook(accessToken: String) async {
        do {
            let response = try await APIClient.shared.request(.thirdPartyLogin(token: accessToken, isFacebook: true))
            
            // make sure there isn't a error
            if let response = response {
                let sessionId = response.authenticationResponse.sessionId
                let authToken = response.authenticationResponse.authToken
                
                KeychainManager.shared.saveToken(sessionId, type: .sessionId)
                KeychainManager.shared.saveToken(authToken, type: .authToken)
                self.isAuthenticated = true
            }
        } catch {
            errorManager.shared.error("SessionManager", "Facebook Login: \(error.localizedDescription)")
        }
    }
    
    public func authenticateWithEmail(email: String, password: String) async {
        do {
            let response = try await APIClient.shared.request(.login(email: email, password: password))
            
            // make sure there isn't a error
            if let response = response {
                let sessionId = response.sessionId
                let authToken = response.authToken
                
                KeychainManager.shared.saveToken(sessionId, type: .sessionId)
                KeychainManager.shared.saveToken(authToken, type: .authToken)
                self.isAuthenticated = true
            }
        } catch {
            errorManager.shared.error("SessionManager", "Email Login: \(error.localizedDescription)")
        }
    }

    public func authenticateWithAuthToken(token: String, email: String) async {
    
        do {
            let response = try await APIClient.shared.request(.refreshToken(email: email, token: token))
            
            guard let sessionId = response?.sessionId else {
                self.isAuthenticated = false
                return
            }
            
            guard let authToken = response?.authToken else {
                self.isAuthenticated = false
                return
            }
            
            KeychainManager.shared.saveToken(sessionId, type: .sessionId)
            KeychainManager.shared.saveToken(authToken, type: .authToken)
            self.isAuthenticated = true
            
        } catch {
            errorManager.shared.error("SessionManager", "Failed to authenticate with auth token: \(error.localizedDescription)")
            self.isAuthenticated = false
        }
    }
    
    public func authenticateWithThirdPartyToken(token: String, thirdPartyUserId: String) async {
    
        do {
            let response = try await APIClient.shared.request(.refreshThirdParty(thirdPartyUserId: thirdPartyUserId, authToken: token))
            
            guard let sessionId = response?.sessionId else {
                self.isAuthenticated = false
                return
            }
            
            guard let authToken = response?.authToken else {
                self.isAuthenticated = false
                return
            }
            
            KeychainManager.shared.saveToken(sessionId, type: .sessionId)
            KeychainManager.shared.saveToken(authToken, type: .authToken)
            self.isAuthenticated = true
            
        } catch {
            errorManager.shared.error("SessionManager", "Failed to authenticate with third party token: \(error.localizedDescription)")
            self.isAuthenticated = false
        }
    }
    
    public func refreshToken() async {
        guard let currentToken = KeychainManager.shared.getToken(type: .authToken) else {
            self.isAuthenticated = false
            return
        }
        
        do {
            let response = try await APIClient.shared.request(.refreshToken(email: "user@example.com", token: currentToken))
            
            guard let sessionId = response?.sessionId else {
                self.isAuthenticated = false
                return
            }
            
            guard let authToken = response?.authToken else {
                self.isAuthenticated = false
                return
            }
            
            KeychainManager.shared.saveToken(sessionId, type: .sessionId)
            KeychainManager.shared.saveToken(authToken, type: .authToken)
            self.isAuthenticated = true
            
        } catch {
            errorManager.shared.error("SessionManager", "Failed to refresh token: \(error.localizedDescription)")
            self.isAuthenticated = false
        }
    }
    
    /// Clears credentials and tears down the active state
    public func logout() {
        keychain.deleteToken(type: .authToken)
        keychain.deleteToken(type: .sessionId)
        self.isAuthenticated = false
    }
}
