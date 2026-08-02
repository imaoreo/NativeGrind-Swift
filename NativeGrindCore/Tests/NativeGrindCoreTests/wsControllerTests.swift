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

    @MainActor
    @Test("Verifies that sendAndWait succeeds when the response arrives within timeout")
    func testSendAndWaitSuccess() async throws {
        await TestSerializer.shared.run {
            let mockSession = mockURLSession()
            let controller = wsController(session: mockSession)
            controller.shouldResumeTasks = false
            
            Task {
                try? await Task.sleep(nanoseconds: 50_000_000)
                let responseJson = """
                {
                    "event": "device_linked",
                    "payload": {
                        "status": "success",
                        "message": "all good"
                    }
                }
                """
                let data = responseJson.data(using: .utf8)!
                await controller.simulateIncomingMessage(domain: .nativeServer, data: data)
            }
            
            let request = wsRequest<String>(domain: .nativeServer, eventName: "link_device", payload: "")
            let response = await controller.sendAndWait(
                request: request,
                expectedEvent: .onDeviceLinked,
                timeout: 1.0
            )
            
            #expect(response != nil)
            #expect(response?.status == .success)
            #expect(response?.message == "all good")
            controller.disconnect()
        }
    }
    
    @MainActor
    @Test("Verifies that sendAndWait times out and returns nil when no response arrives")
    func testSendAndWaitTimeout() async throws {
        await TestSerializer.shared.run {
            let mockSession = mockURLSession()
            let controller = wsController(session: mockSession)
            controller.shouldResumeTasks = false
            
            let request = wsRequest<String>(domain: .nativeServer, eventName: "link_device", payload: "")
            let response = await controller.sendAndWait(
                request: request,
                expectedEvent: .onDeviceLinked,
                timeout: 0.1
            )
            
            #expect(response == nil)
            controller.disconnect()
        }
    }
    
    @MainActor
    @Test("Verifies that sendAndWait successfully retries and reconnects when the first attempt times out but the second succeeds")
    func testSendAndWaitRetrySuccess() async throws {
        await TestSerializer.shared.run {
            let mockSession = mockURLSession()
            let controller = wsController(session: mockSession)
            controller.shouldResumeTasks = false
            
            // Clear logs first
            await errorManager.shared.clearLogs()
            
            Task {
                // Wait until the first timeout is logged
                while true {
                    let logs = await errorManager.shared.logs
                    if logs.contains(where: { $0.message.contains("timed out") }) {
                        break
                    }
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }
                
                // The first timeout just occurred. Reconnect sleeps take 1.5 seconds.
                // We sleep for 1.7 seconds to ensure the retry wait is fully active.
                try? await Task.sleep(nanoseconds: 1_700_000_000)
                
                let responseJson = """
                {
                    "event": "device_linked",
                    "payload": {
                        "status": "success",
                        "message": "retry success"
                    }
                }
                """
                let data = responseJson.data(using: .utf8)!
                await controller.simulateIncomingMessage(domain: .nativeServer, data: data)
            }
            
            let request = wsRequest<String>(domain: .nativeServer, eventName: "link_device", payload: "")
            let response = await controller.sendAndWait(
                request: request,
                expectedEvent: .onDeviceLinked,
                timeout: 0.5
            )
            
            #expect(response != nil)
            #expect(response?.status == .success)
            #expect(response?.message == "retry success")
            controller.disconnect()
        }
    }
}
