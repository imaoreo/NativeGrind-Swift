import CryptoKit
import Security
import Foundation

public enum CryptoError: Error {
    case keychainSaveFailed
    case keyNotFound
    case unsupportedDevice
}

public final class cryptoController: Sendable {
    public static let shared = cryptoController()
    
    private init() {}
    
    /// Generate key and store in secure enclave with a pointer in keychain
    func generateAndStoreKeyPair() throws -> String {
        guard SecureEnclave.isAvailable else {
            throw CryptoError.unsupportedDevice
        }
        
        let accessControl = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.privateKeyUsage],
            nil
        )!
        
        let privateKey = try SecureEnclave.P256.Signing.PrivateKey(accessControl: accessControl)
        
        let keyPointerData = privateKey.dataRepresentation
        
        let success = keychainManager.shared.saveData(keyPointerData, type: .deviceKeyPointer)
        
        guard success else {
            throw CryptoError.keychainSaveFailed
        }
        
        return privateKey.publicKey.rawRepresentation.base64EncodedString()
    }

    /// Load and sign using the poitner
    public func signChallenge(challenge: String) throws -> String {
        guard let keyPointerData = keychainManager.shared.getData(type: .deviceKeyPointer) else {
            throw CryptoError.keyNotFound
        }
        
        let privateKey = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyPointerData)
        
        let challengeData = challenge.data(using: .utf8)!
        let hashedChallenge = SHA256.hash(data: challengeData)
        
        let signature = try privateKey.signature(for: hashedChallenge)
        
        return signature.derRepresentation.base64EncodedString()
    }
    
    /// Load and give publicKey
    public func getPublicKey() throws -> String {
        guard let keyPointerData = keychainManager.shared.getData(type: .deviceKeyPointer) else {
            throw CryptoError.keyNotFound
        }
            
        let privateKey = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: keyPointerData)
        
        let publicKey = privateKey.publicKey
        
        let publicKeyData = publicKey.rawRepresentation
        
        return publicKeyData.base64EncodedString()
    }
}
