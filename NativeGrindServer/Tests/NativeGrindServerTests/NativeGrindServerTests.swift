import Testing
import Foundation
@testable import NativeGrindServer
import NativeGrindCore

@Suite("NativeGrindServer Tests")
@MainActor
struct NativeGrindServerTests {
    
    init() {}
    
    private func setupTestState() {
        errorManager.shared.clearLogs()
    }
    
    @Test("Verifies signNativeBody returns nil in unsupported environments (e.g. macOS test runner)")
    func testSignNativeBodyUnsupported() async throws {
        setupTestState()
        let result = try await signNativeBody(nil, url: "https://example.com")
        #expect(result == nil)
    }
    
    @Test("Verifies performNativeServerChecks warns in unsupported environments")
    func testPerformNativeServerChecksUnsupported() async throws {
        setupTestState()
        await performNativeServerChecks()
        
        let logs = errorManager.shared.logs
        let hasWarning = logs.contains { log in
            log.prefix == "NativeGrindServer" && 
            log.message == "App Attest is not supported on this platform/environment"
        }
        #expect(hasWarning == true)
    }
}
