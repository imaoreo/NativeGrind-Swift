//
//  accountControllerTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/08/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Account Controller Tests", .serialized)
struct accountControllerTests {
    
    init() {}
    
    private func setupTestState() async {
        await accountController.shared.clearAccounts()
        await errorManager.shared.clearLogs()
    }
    
    @MainActor
    @Test("Verifies that accountController tracks and de-duplicates accounts locally")
    func testAccountControllerTrackingAndSwitching() async throws {
        await setupTestState()
        let controller = accountController.shared
        
        let account1 = nsAccount(authToken: "token1", sessionId: "sess1", isEmail: "true", data: "user1@example.com")
        let account2 = nsAccount(authToken: "token2", sessionId: "sess2", isEmail: "false", data: "user2_id")
        
        // Add first account
        try await controller.addAccount(account1)
        var currentAccounts = await controller.getAccounts()
        #expect(currentAccounts.count == 1)
        #expect(currentAccounts.first?.sessionId == "sess1")
        
        // Add second account
        try await controller.addAccount(account2)
        currentAccounts = await controller.getAccounts()
        #expect(currentAccounts.count == 2)
        
        // Add duplicate account (same email/data - should replace/de-duplicate)
        let account1Updated = nsAccount(authToken: "token1_new", sessionId: "sess1_new", isEmail: "true", data: "user1@example.com")
        try await controller.addAccount(account1Updated)
        currentAccounts = await controller.getAccounts()
        #expect(currentAccounts.count == 2)
        #expect(currentAccounts.first(where: { $0.data == "user1@example.com" })?.sessionId == "sess1_new")
        #expect(currentAccounts.first(where: { $0.data == "user1@example.com" })?.authToken == "token1_new")
        
        // Test local persistence reload check
        let savedJson = keychainManager.shared.getToken(type: .accountsList)
        #expect(savedJson != nil)
        #expect(savedJson?.contains("sess1_new") == true)
        
        // Remove account
        try await controller.removeAccount(sessionId: "sess2")
        currentAccounts = await controller.getAccounts()
        #expect(currentAccounts.count == 1)
        #expect(currentAccounts.first?.sessionId == "sess1_new")
    }
}
