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
    
    init() {}
    
    private func setupTestState() async {
        errorManager.shared.clearLogs()
        MockURLProtocol.shared.handler = nil
        do {
            try await inboxController.shared.dbController.clearDatabase()
        } catch {
            Issue.record("Failed to clear inbox database: \(error)")
        }

        do {
            try await profileController.shared.dbController.clearDatabase()
        } catch {
            Issue.record("Failed to clear profile database: \(error)")
        }
    }
    
    @Test("Verifies networkFetchProfile catches and ignores offline errors silently")
    func testNetworkFetchOfflineHandling() async throws {
        await TestSerializer.shared.run {
            await setupTestState()
            let controller = profileController.shared
            
            keychainManager.shared.saveToken("mock-session", type: .sessionId)
            
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
            
            _ = await controller.fetchProfile(profileId: "offline-test-id")
            
            let logs = errorManager.shared.logs
            let hasNetworkWarn = logs.contains { $0.prefix == "profileController" }
            
            #expect(hasNetworkWarn == false)
        }
    }
    
    @Test("Verifies networkFetchProfile logs warnings for non-network API failures")
    func testNetworkFetchApiErrorHandling() async throws {
        await TestSerializer.shared.run {
            await setupTestState()
            let controller = profileController.shared
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
            
            _ = await controller.fetchProfile(profileId: "error-test-id")
            
            let logs = errorManager.shared.logs
            let hasApiWarn = logs.contains { $0.prefix == "profileController" }
            
            #expect(hasApiWarn == true)
        }
    }
    
    @Test("Verifies getHistoryFromProfile with .profile source skips network fetch")
    func testGetHistoryFromLocalProfile() async throws {
        await TestSerializer.shared.run {
            await setupTestState()
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
            await setupTestState()
            let controller = profileController.shared
            let testId = "net-hist-\(UUID().uuidString)"
            keychainManager.shared.saveToken("mock-session", type: .sessionId)
            
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockURLProtocol.self]
            await APIClient.shared.setMockSession(URLSession(configuration: config))
            
            MockURLProtocol.shared.handler = { request in
                #expect(request.url?.absoluteString.contains(testId) == true)
                
                let mockJSON = "{\"profiles\": []}".data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, mockJSON)
            }
            
            defer {
                MockURLProtocol.shared.handler = nil
                keychainManager.shared.deleteToken(type: .sessionId)
            }
            
            _ = await controller.getHistoryFromProfile(source: .id(testId))
        }
    }
    
    @Test("Verifies fetchGrid parses successful response and returns profiles")
    func testFetchGridSuccess() async throws {
        await TestSerializer.shared.run {
            await setupTestState()
            let controller = profileController.shared
            keychainManager.shared.saveToken("mock-session", type: .sessionId)
            
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockURLProtocol.self]
            await APIClient.shared.setMockSession(URLSession(configuration: config))
            
            MockURLProtocol.shared.handler = { request in
                #expect(request.url?.absoluteString.contains("nearbyGeoHash=test-geohash") == true)
                let mockJSON = """
                {
                    "items": [
                        {
                            "type": "full_profile_v1",
                            "data": {
                                "profileId": 98765,
                                "displayName": "Grid User"
                            }
                        }
                    ]
                }
                """.data(using: .utf8)!
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, mockJSON)
            }
            
            defer {
                MockURLProtocol.shared.handler = nil
                keychainManager.shared.deleteToken(type: .sessionId)
            }
            
            let gridResponse = await controller.fetchGrid(geohash: "test-geohash")
            #expect(gridResponse != nil)
            #expect(gridResponse?.profiles.count == 1)
            #expect(gridResponse?.profiles.first?.profileId == 98765)
            #expect(gridResponse?.profiles.first?.displayName == "Grid User")
        }
    }
    
    @Test("Verifies fetchGrid logs error and returns nil when API fails")
    func testFetchGridErrorHandling() async throws {
        await TestSerializer.shared.run {
            await setupTestState()
            let controller = profileController.shared
            keychainManager.shared.saveToken("mock-session", type: .sessionId)
            
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [MockURLProtocol.self]
            await APIClient.shared.setMockSession(URLSession(configuration: config))
            
            MockURLProtocol.shared.handler = { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
                return (response, "Internal Server Error".data(using: .utf8)!)
            }
            
            defer {
                MockURLProtocol.shared.handler = nil
                keychainManager.shared.deleteToken(type: .sessionId)
            }
            
            let gridResponse = await controller.fetchGrid(geohash: "test-geohash")
            #expect(gridResponse == nil)
            
            let logs = errorManager.shared.logs
            let hasGridError = logs.contains { $0.prefix == "profileController" && $0.message.contains("Failed to fetch grid") }
            #expect(hasGridError == true)
        }
    }
}
