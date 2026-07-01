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
    
    init() {
        errorManager.shared.clearLogs()
    }
    
    @Test("Verifies getHistoryForInbox with .inbox source bypasses network and fetches local diffs")
    func testGetHistoryFromLocalInbox() async throws {
        let controller = inboxController.shared
        let testId = "local-history-\(UUID().uuidString)"
        
        let mockData = mockConversation(id: testId)
        try await controller.dbController.updateInbox(inbox: mockData)
        
        let history = await controller.getHistoryForInbox(source: .inbox(mockData))
        
        #expect(history != nil)
        #expect(history?.isEmpty == false)
        #expect(history?.first?.conversationId == testId)
    }
    
    @Test("Verifies getHistoryForInbox with .id source triggers network fetch before returning history")
    func testGetHistoryFromIdTriggersNetwork() async throws {
        let controller = inboxController.shared
        let testId = "net-history-\(UUID().uuidString)"
        
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        await APIClient.shared.setMockSession(URLSession(configuration: config))
        
        MockURLProtocol.shared.handler = { request in
            #expect(request.url?.absoluteString.contains("page=1") == true)
            
            // Return Empty
            let mockJSON = "{\"entries\": []}".data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, mockJSON)
        }
        
        defer { MockURLProtocol.shared.handler = nil }
        
        // Request Id
        let history = await controller.getHistoryForInbox(source: .id(testId))
        
        // will fall back to db but that is also empty
        #expect(history?.isEmpty == true)
    }
    
    @Test("Verifies networkFetchInboxes catches and ignores offline errors silently")
    @MainActor
    func testNetworkFetchOfflineHandling() async throws {
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
    
    @Test("Verifies networkFetchInboxes logs warnings for non-network API failures")
    func testNetworkFetchApiErrorHandling() async throws {
        let controller = inboxController.shared
        
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        await APIClient.shared.setMockSession(URLSession(configuration: config))
        
        MockURLProtocol.shared.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        defer { MockURLProtocol.shared.handler = nil }
        
        _ = await controller.fetchInboxes(depth: 1)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        let logs = await errorManager.shared.logs
        let hasApiWarn = logs.contains { $0.prefix == "inboxController" }
        
        #expect(hasApiWarn == true)
    }
    
    @Test("Verifies fetchInboxes with depth 0 skips network requests entirely")
    func testFetchInboxesDepthZero() async throws {
        let controller = inboxController.shared
        
        let results = await controller.fetchInboxes(depth: 0)

        #expect(results?.isEmpty ?? true)
    }
}
