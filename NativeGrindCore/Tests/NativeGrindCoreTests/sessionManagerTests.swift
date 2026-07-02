//
//  sessionManagerTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/07/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Session Manager Tests", .serialized)
@MainActor
struct sessionManagerTests {
    
    public func clearKeychain() {
        keychainManager.shared.deleteToken(type: .authToken)
        keychainManager.shared.deleteToken(type: .data)
        keychainManager.shared.deleteToken(type: .isEmail)
        keychainManager.shared.deleteToken(type: .sessionId)
    }
    
    private func setupTestState() {
        sessionManager.shared.logout()
        errorManager.shared.clearLogs()
        clearKeychain()
        MockURLProtocol.shared.handler = nil
    }
    
    init() async {}
    
    @Test("Verifies logout clears all keychain data and resets authentication state")
    func testLogoutClearsState() async throws {
        try await TestSerializer.shared.run {
            setupTestState()
            
            let manager = sessionManager.shared
            let keychain = keychainManager.shared
            
            // Pretend there was a login
            keychain.saveToken("mock-session-123", type: .sessionId)
            keychain.saveToken("mock-auth-abc", type: .authToken)
            keychain.saveToken("true", type: .isEmail)
            keychain.saveToken("test@example.com", type: .data)
            
            // logout
            manager.logout()
            
            // Make sure every field is wiped
            #expect(manager.isAuthenticated == false)
            #expect(keychain.getToken(type: .sessionId) == nil)
            #expect(keychain.getToken(type: .authToken) == nil)
            #expect(keychain.getToken(type: .isEmail) == nil)
            #expect(keychain.getToken(type: .data) == nil)
        }
    }
    
    @Test("Verifies refreshToken fails and logs out if keychain credentials are missing")
    func testRefreshFailsWithEmptyKeychain() async throws {
        try await TestSerializer.shared.run {
            setupTestState()
            
            let manager = sessionManager.shared
            
            // empty keychain
            clearKeychain()
            
            // Attempt to get a new sessionId, Should get missing authentication
            await manager.refreshToken(showError: false)
            
            // Will be caught and set isAuthenticated to false
            #expect(manager.isAuthenticated == false)
        }
    }
    
    @Test("Verifies offline fallback keeps user authenticated if network fails but tokens exist")
    func testOfflineFallbackRetainsAuthentication() async throws {
        try await TestSerializer.shared.run {
            setupTestState()
            
            let manager = sessionManager.shared
            let keychain = keychainManager.shared
            
            // Make it like  user was previously logged in
            keychain.saveToken("valid-session", type: .sessionId)
            keychain.saveToken("valid-auth", type: .authToken)
            keychain.saveToken("true", type: .isEmail)
            keychain.saveToken("test@example.com", type: .data)
            
            // Intercept network
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockURLProtocol.self]
            await APIClient.shared.setMockSession(URLSession(configuration: config))
            
            MockURLProtocol.shared.handler = { _ in
                // Throw no internet
                throw URLError(.notConnectedToInternet)
            }
            
            defer { MockURLProtocol.shared.handler = nil }
            
            await manager.refreshToken(showError: false)
            
            // User should still be authed due to offline mode backup
            #expect(manager.isAuthenticated == true)
        }
    }
    
    @Test("Verifies network error does NOT keep user authenticated if tokens are missing")
    func testOfflineFallbackFailsIfTokensMissing() async throws {
        try await TestSerializer.shared.run {
            setupTestState()
            
            let manager = sessionManager.shared
            let keychain = keychainManager.shared
            
            // Have only some stored data
            keychain.saveToken("valid-auth", type: .authToken)
            keychain.saveToken("true", type: .isEmail)
            keychain.saveToken("test@example.com", type: .data)
            
            // Intercept with no internet
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockURLProtocol.self]
            await APIClient.shared.setMockSession(URLSession(configuration: config))
            
            MockURLProtocol.shared.handler = { _ in
                throw URLError(.notConnectedToInternet)
            }
            
            defer { MockURLProtocol.shared.handler = nil }
            
            await manager.refreshToken(showError: false)
            
            // User logged out due to not having all the fields
            #expect(manager.isAuthenticated == false)
        }
    }
}
