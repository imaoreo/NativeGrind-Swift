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
    
    @Test("Verifies WebSocketAttestManager start configures App Attest support status")
    func testWebSocketAttestManagerStart() async throws {
        setupTestState()
        WebSocketAttestManager.shared.start()
        
        #expect(wsController.isAppAttestSupported == false)
    }
}
