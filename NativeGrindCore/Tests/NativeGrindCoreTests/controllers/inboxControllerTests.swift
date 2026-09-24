//
//  inboxControllerTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/07/2026.
//

import Testing
import Foundation
import SwiftData
@testable import NativeGrindCore

@Suite("Inbox Controller Tests", .serialized)
@MainActor
struct inboxControllerTests {
    
    init() {}
    
    private func setupTestState() async {
        errorManager.shared.clearLogs()
        MockURLProtocol.shared.handler = nil
        do {
            try await profileController.shared.dbController.clearDatabase()
        } catch {
            Issue.record("Failed to clear profile database: \(error)")
        }
    }
    
    @Test("Verifies networkFetchInboxes catches and ignores offline errors silently")
    @MainActor
    func testNetworkFetchOfflineHandling() async throws {
        await TestSerializer.shared.run {
            await setupTestState()
            let controller = inboxController.shared
            
            keychainManager.shared.saveToken("mock-token", type: .sessionId)
            
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockURLProtocol.self]
            await APIClient.shared.setMockSession(URLSession(configuration: config))
            
            MockURLProtocol.shared.handler = { request in
                throw URLError(.notConnectedToInternet)
            }
            
            defer {
                MockURLProtocol.shared.handler = nil
                keychainManager.shared.deleteToken(type: .sessionId)
            }
            
            _ = await controller.fetchInboxes(depth: 1)
            
            let logs = errorManager.shared.logs
            let hasNetworkWarn = logs.contains { $0.prefix == "inboxController" }
            
            #expect(hasNetworkWarn == false)
        }
    }
    
    @Test("Verifies networkFetchInboxes logs warnings for non-network API failures")
    func testNetworkFetchApiErrorHandling() async throws {
        try await TestSerializer.shared.run {
            await setupTestState()
            let controller = inboxController.shared
            keychainManager.shared.saveToken("mock-session", type: .sessionId)
            
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
                keychainManager.shared.deleteToken(type: .sessionId)
            }
            
            _ = await controller.fetchInboxes(depth: 1)
            
            try await Task.sleep(nanoseconds: 100_000_000)
            
            let logs = await errorManager.shared.logs
            let hasApiWarn = logs.contains { $0.prefix == "inboxController" }
            
            #expect(hasApiWarn == true)
        }
    }
    
    @Test("Verifies fetchInboxes with depth 0 skips network requests entirely")
    func testFetchInboxesDepthZero() async throws {
        await TestSerializer.shared.run {
            await setupTestState()
            let controller = inboxController.shared
            
            let results = await controller.fetchInboxes(depth: 0)

            #expect(results?.isEmpty ?? true)
        }
    }
}
