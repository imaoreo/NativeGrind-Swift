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
        if let existingToken = keychain.getToken() {
            // We need to add a check here to make sure token is still valid
            ErrorManager.shared.log("SessionManager", "Existing token found")
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
                
                KeychainManager.shared.saveToken(sessionId)
                self.isAuthenticated = true
            }
        } catch {
            ErrorManager.shared.error("SessionManager", "Google Login: \(error.localizedDescription)")
        }
    }
    
    /// change the facebook login to a grindr auth token
    public func authenticateWithFacebook(accessToken: String) async {
        do {
            let response = try await APIClient.shared.request(.thirdPartyLogin(token: accessToken, isFacebook: true))
            
            // make sure there isn't a error
            if let response = response {
                let sessionId = response.authenticationResponse.sessionId
                
                KeychainManager.shared.saveToken(sessionId)
                self.isAuthenticated = true
            }
        } catch {
            ErrorManager.shared.error("SessionManager", "Facebook Login: \(error.localizedDescription)")
        }
    }
    
    public func authenticateWithEmail(email: String, password: String) async {
        do {
            let response = try await APIClient.shared.request(.login(email: email, password: password))
            
            // make sure there isn't a error
            if let response = response {
                let sessionId = response.sessionId
                
                KeychainManager.shared.saveToken(sessionId)
                self.isAuthenticated = true
            }
        } catch {
            ErrorManager.shared.error("SessionManager", "Email Login: \(error.localizedDescription)")
        }
    }

    public func authenticateWithToken(token: String) {
        var correctedToken = token
        
        // If the token is prefixed with "Grindr3 ", extract the sessionId portion.
        if correctedToken.hasPrefix("Grindr3 ") {
            let parts = correctedToken.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if parts.count == 2 {
                correctedToken = String(parts[1])
            }
        }
        
        // Make sure the token isn't just white space or that
        let trimmed = correctedToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, KeychainManager.shared.saveToken(trimmed) else {
            ErrorManager.shared.error("SessionManager", "Token Login: Failed to save token")
            self.isAuthenticated = false
            return
        }
    
        self.isAuthenticated = true
    }
    
    /// Clears credentials and tears down the active state
    public func logout() {
        keychain.deleteToken()
        self.isAuthenticated = false
    }
}
