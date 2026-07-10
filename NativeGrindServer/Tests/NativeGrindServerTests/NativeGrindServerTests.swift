import Testing
import Foundation
import DeviceCheck
@testable import NativeGrindServer
import NativeGrindCore

@Suite("NativeGrindServer Tests")
@MainActor
struct NativeGrindServerTests {
    
    init() {}
    
    private func setupTestState() {
        errorManager.shared.clearLogs()
    }
    
    @Test("Verifies WebSocketAttestManager start configures App Attest support status")
    func testWebSocketAttestManagerStart() async throws {
        setupTestState()
        WebSocketAttestManager.shared.start()
        
        #if !os(macOS) && !targetEnvironment(simulator) && !targetEnvironment(macCatalyst)
        let expectedValue = DCAppAttestService.shared.isSupported
        #else
        let expectedValue = false
        #endif
        
        #expect(wsController.isAppAttestSupported == expectedValue)
    }
}
