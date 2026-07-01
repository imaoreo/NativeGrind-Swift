//
//  errorManagerTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/07/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Error Manager Tests", .serialized)
@MainActor
struct errorManagerTests {
    
    // This runs before every other test to make sure it is cleared
    init() {
        errorManager.shared.clearLogs()
        errorManager.shared.activeToast = nil
    }

    @Test("Verifies logs are correctly appended with the right properties")
    func testBasicLogging() {
        let manager = errorManager.shared
        
        manager.log("AUTH", "User logged in")
        manager.warn("API", "Slow response time")
        
        #expect(manager.logs.count == 2)
        
        let firstLog = manager.logs[0]
        #expect(firstLog.level == .log)
        #expect(firstLog.prefix == "AUTH")
        #expect(firstLog.message == "User logged in")
        
        let secondLog = manager.logs[1]
        #expect(secondLog.level == .warn)
    }

    @Test("Verifies only .error level updates the activeToast property")
    func testActiveToastTrigger() {
        let manager = errorManager.shared
        
        // Make sure logs and warnings do not show on activeToast
        manager.log("SYS", "System boot")
        #expect(manager.activeToast == nil)
        
        manager.warn("SYS", "Memory running high")
        #expect(manager.activeToast == nil)
        
        // Make sure Errors change activeToast
        manager.error("CRIT", "Database failed")
        #expect(manager.activeToast != nil)
        #expect(manager.activeToast?.level == .error)
        #expect(manager.activeToast?.message == "Database failed")
    }

    @Test("Verifies the log array automatically truncates at 100 entries")
    func testLogTruncation() {
        let manager = errorManager.shared
        
        // Inject 105 logs
        for i in 1...105 {
            manager.log("SPAM", "Log number \(i)")
        }
        
        // The array should be capepd
        #expect(manager.logs.count == 100)
        
        // Make sure it drops the first 5
        #expect(manager.logs.first?.message == "Log number 6")
        
        // Double check last log
        #expect(manager.logs.last?.message == "Log number 105")
    }

    @Test("Verifies clearLogs removes all history")
    func testClearLogs() {
        let manager = errorManager.shared
        
        manager.log("TEST", "Test 1")
        manager.error("TEST", "Test 2")
        #expect(manager.logs.count == 2)
        
        manager.clearLogs()
        #expect(manager.logs.isEmpty)
    }
}
