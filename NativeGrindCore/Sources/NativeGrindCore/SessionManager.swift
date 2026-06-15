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
    
    // UI components listen to this to switch between LoginView and MainView
    @Published public private(set) var isAuthenticated: Bool = false
    @Published public private(set) var isLoading: Bool = false
    
    private let keychain = KeychainManager.shared
    
    public init() {
        // Run a silent check immediately on startup
        checkCurrentAuthStatus()
    }
    
    /// Evaluates if a token is already stored locally on launch
    public func checkCurrentAuthStatus() {
        if let existingToken = keychain.getToken() {
            // Optional: You can trigger an API call here to ensure the session hasn't expired
            print("Found valid local session token in Keychain.")
            self.isAuthenticated = true
        } else {
            self.isAuthenticated = false
        }
    }
    
    /// Exchange the idToken from google login to a Grindr3 Auth Token
    public func authenticateWithGoogle(accessToken: String) async {
            do {
                let response = try await APIClient.shared.request(.loginWithGoogle(token: accessToken))
                
                print("Successfully authenticated with Google. Received auth token: \(response.authenticationResponse.sessionId)")
                
                KeychainManager.shared.saveToken(response.authenticationResponse.sessionId)
                self.isAuthenticated = true
            } catch {
                print("Login failed: \(error.localizedDescription)")
                // Handle UI error state here
            }
        }
    
    /// Clears credentials and tears down the active state
    public func logout() {
        keychain.deleteToken()
        self.isAuthenticated = false
    }
}
