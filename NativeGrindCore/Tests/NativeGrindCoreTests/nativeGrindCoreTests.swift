import Testing
@testable import NativeGrindCore

@Suite("nativeGrindCoreTest") struct `nativeGrindCoreTest` {
    @Test("Verifies that the test function works")
    func testHelloPizza() {
        let coreInstance = nativeGrindCore()
        let result = coreInstance.test()
        
        #expect(result == "Hello Pizza")
    }
}
