//
//  profileControllerTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/07/2026.
//

import Testing
import Foundation
import SwiftData
@testable import NativeGrindCore

@Suite("Profile Controller Tests", .serialized)
@MainActor
struct profileControllerTests {
    
    final class ThreadSafeFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var _value = false
        
        var value: Bool {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _value
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _value = newValue
            }
        }
    }
    
    init() {}
    
    private func setupTestState() {
        errorManager.shared.clearLogs()
        MockURLProtocol.shared.handler = nil
    }
    
    private func injectMockAuth() {
        keychainManager.shared.saveToken("mock-session", type: .sessionId)
    }
    
    private func clearMockAuth() {
        keychainManager.shared.deleteToken(type: .sessionId)
    }

    @Test("Verifies networkFetchProfile catches and ignores offline errors silently")
    func testNetworkFetchOfflineHandling() async throws {
        await TestSerializer.shared.run {
            setupTestState()
            let controller = profileController.shared
            injectMockAuth()
            
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockURLProtocol.self]
            await APIClient.shared.setMockSession(URLSession(configuration: config))
            
            MockURLProtocol.shared.handler = { request in
                throw URLError(.notConnectedToInternet)
            }
            
            defer {
                MockURLProtocol.shared.handler = nil
                clearMockAuth()
            }
            
            _ = await controller.fetchProfile(profileId: "offline-test-id")
            
            let logs = errorManager.shared.logs
            let hasNetworkWarn = logs.contains { $0.prefix == "profileController" }
            
            #expect(hasNetworkWarn == false)
        }
    }
    
    @Test("Verifies networkFetchProfile logs warnings for non-network API failures")
    func testNetworkFetchApiErrorHandling() async throws {
        await TestSerializer.shared.run {
            setupTestState()
            let controller = profileController.shared
            injectMockAuth()
            
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockURLProtocol.self]
            await APIClient.shared.setMockSession(URLSession(configuration: config))
            
            MockURLProtocol.shared.handler = { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                
                let badJSON = "this is obviously not valid json".data(using: .utf8)!
                return (response, badJSON)
            }
            
            defer {
                MockURLProtocol.shared.handler = nil
                clearMockAuth()
            }
            
            _ = await controller.fetchProfile(profileId: "error-test-id")
            
            let logs = errorManager.shared.logs
            let hasApiWarn = logs.contains { $0.prefix == "profileController" }
            
            #expect(hasApiWarn == true)
        }
    }
    
    @Test("Verifies getHistoryFromProfile with .profile source skips network fetch")
    func testGetHistoryFromLocalProfile() async throws {
        await TestSerializer.shared.run {
            setupTestState()
            let controller = profileController.shared
            let testId = "local-hist-\(UUID().uuidString)"
            
            let dummyProfile = mockProfile(id: testId)
            
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockURLProtocol.self]
            await APIClient.shared.setMockSession(URLSession(configuration: config))
            
            MockURLProtocol.shared.handler = { request in
                Issue.record("Network should not be called when source is .profile")
                throw URLError(.cancelled)
            }
            
            defer { MockURLProtocol.shared.handler = nil }
            
            _ = await controller.getHistoryFromProfile(source: .profile(dummyProfile))
        }
    }
    
    @Test("Verifies getHistoryFromProfile with .id source triggers network fetch")
    func testGetHistoryFromIdTriggersNetwork() async throws {
        try await TestSerializer.shared.run {
            setupTestState()
            let controller = profileController.shared
            let testId = "net-hist-\(UUID().uuidString)"
            injectMockAuth()
            
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockURLProtocol.self]
            await APIClient.shared.setMockSession(URLSession(configuration: config))
            
            let networkWasHit = ThreadSafeFlag()
            
            MockURLProtocol.shared.handler = { request in
                networkWasHit.value = true
                #expect(request.url?.absoluteString.contains(testId) == true)
                
                let mockJSON = "{\"profiles\": []}".data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, mockJSON)
            }
            
            defer {
                MockURLProtocol.shared.handler = nil
                clearMockAuth()
            }
            
            _ = await controller.getHistoryFromProfile(source: .id(testId))
            
            #expect(networkWasHit.value == true)
        }
    }
}
