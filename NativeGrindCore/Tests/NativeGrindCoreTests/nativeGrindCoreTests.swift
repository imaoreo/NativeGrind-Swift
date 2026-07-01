import Testing
@testable import NativeGrindCore

@Suite("keychainManagerTest") struct `keychainManagerTest` {
    @MainActor
    @Test func checkVariables() async throws {
        let isLocation = keychainManager.shared.service == "dev.imaoreo.NativeGrind"
        
        #expect(isLocation)
    }
    
    @MainActor
    @Test("Save and Fetch", arguments: ["1234", "_", "{String, 1234}"], [keyType.authToken, keyType.data, keyType.isEmail, keyType.sessionId])
    func saveAndFetch(item: String, type: keyType) async throws {
        keychainManager.shared.saveToken(item, type: type)
        
        let token = keychainManager.shared.getToken(type: type)
        
        #expect(token == item)
    }
    
    static var SaveandSaveCombinations: [(String, String, keyType)] {
            let items1 = ["1234", "_", "{String, 1234}"]
            let items2 = ["1234", "_", "{String, 1234}"]
            let types = [keyType.authToken, keyType.data, keyType.isEmail, keyType.sessionId]
            
            var result: [(String, String, keyType)] = []
            for i1 in items1 {
                for i2 in items2 {
                    for t in types {
                        result.append((i1, i2, t))
                    }
                }
            }
            return result
        }
    
    @MainActor
    @Test("Save and Save", arguments: SaveandSaveCombinations)
    func saveAndSave(item: String, item2: String, type: keyType) async throws {
        keychainManager.shared.saveToken(item, type: type)
        
        keychainManager.shared.saveToken(item2, type: type)
        
        let token = keychainManager.shared.getToken(type: type)
        
        #expect(token == item2)
    }
    
    @MainActor
    @Test("Save and Delete", arguments: ["1234", "_", "{String, 1234}"], [keyType.authToken, keyType.data, keyType.isEmail, keyType.sessionId])
    func saveAndDelete(item: String, type: keyType) async throws {
        keychainManager.shared.saveToken(item, type: type)
        
        keychainManager.shared.deleteToken(type: type)
        
        let token = keychainManager.shared.getToken(type: type)
        
        #expect(token == nil)
    }
}
