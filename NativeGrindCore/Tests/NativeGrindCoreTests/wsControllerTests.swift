//
//  wsControllerTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 10/07/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

final class mockURLSession: URLSession, @unchecked Sendable {
    private let lock = NSLock()
    private var _lastRequest: URLRequest?
    
    var lastRequest: URLRequest? {
        lock.lock()
        defer { lock.unlock() }
        return _lastRequest
    }
    
    private func setLastRequest(_ request: URLRequest) {
        lock.lock()
        defer { lock.unlock() }
        _lastRequest = request
    }
    
    override init() {
        super.init()
    }
    
    override func webSocketTask(with request: URLRequest) -> URLSessionWebSocketTask {
        setLastRequest(request)
        // Use a dummy session to produce a valid URLSessionWebSocketTask without crashing
        let dummySession = URLSession(configuration: .default)
        return dummySession.webSocketTask(with: URLRequest(url: URL(string: "ws://localhost:9999/dummy")!))
    }
}

@Suite("wsControllerTests", .serialized)
struct wsControllerTests {
    
    @MainActor
    @Test("Verifies request header construction for nativeServer WebSocket")
    func testNativeServerRequestHeaders() async throws {
        await TestSerializer.shared.run {
            let mockApiKey = "ng_mac_test_api_key"
            keychainManager.shared.saveToken(mockApiKey, type: .apiKey)
            defer {
                keychainManager.shared.deleteToken(type: .apiKey)
            }
            
            let mockSession = mockURLSession()
            let controller = wsController(session: mockSession)
            controller.shouldResumeTasks = false
            
            let url = URL(string: "wss://nativeserver.imaoreo.dev/ws")!
            controller.connect(to: url, for: .nativeServer)
            
            #expect(mockSession.lastRequest != nil)
            
            let apiKeyHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "x-companion-api-key")
            #expect(apiKeyHeader == mockApiKey)
            
            controller.disconnect()
        }
    }
    
    @MainActor
    @Test("Verifies request header construction for main WebSocket using sessionId")
    func testMainWebSocketRequestHeaders() async throws {
        await TestSerializer.shared.run {
            let mockSessionId = "test_session_id_12345"
            keychainManager.shared.saveToken(mockSessionId, type: .sessionId)
            defer {
                keychainManager.shared.deleteToken(type: .sessionId)
            }
            
            let mockSession = mockURLSession()
            let controller = wsController(session: mockSession)
            controller.shouldResumeTasks = false
            
            let url = URL(string: "wss://grindr.mobi/v1/ws")!
            controller.connect(to: url, for: .main)
            
            #expect(mockSession.lastRequest != nil)
            
            let userAgent = mockSession.lastRequest?.value(forHTTPHeaderField: "User-Agent")
            #expect(userAgent?.contains("Grindr3") == true)
            
            let authHeader = mockSession.lastRequest?.value(forHTTPHeaderField: "Authorization")
            #expect(authHeader == "Grindr3 \(mockSessionId)")
            
            controller.disconnect()
        }
    }
}
