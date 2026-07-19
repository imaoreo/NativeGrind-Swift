import CryptoKit
import Security
import Foundation

public enum CryptoError: Error {
    case keychainSaveFailed
    case keyNotFound
    case unsupportedDevice
    case invalidPublicKey
}

public final class cryptoController: Sendable {
    public static let shared = cryptoController()
    
    private init() {}
    
    /// Generate key and store in secure enclave with a pointer in keychain
    public func generateAndStoreKeyPair() throws -> String {
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
    
    /// Generate a new 256-bit symmetric account key encoded as base64
    public func generateAccountKey() -> String {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0).base64EncodedString() }
    }
    
    /// Encrypt text using recipient's PEM public key (ECDH + HKDF + AES-GCM)
    public func encryptWithPublicKey(text: String, recipientPublicKeyBase64: String) throws -> String {
        let pemBody = recipientPublicKeyBase64
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")
        
        guard let derData = Data(base64Encoded: pemBody),
              let recipientPublicKey = try? P256.KeyAgreement.PublicKey(derRepresentation: derData),
              let textData = text.data(using: .utf8) else {
            throw CryptoError.invalidPublicKey
        }
        
        let ephemeralPrivateKey = P256.KeyAgreement.PrivateKey()
        let sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: recipientPublicKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(), sharedInfo: Data(), outputByteCount: 32)
        let sealedBox = try AES.GCM.seal(textData, using: symmetricKey)
        
        var payload = ephemeralPrivateKey.publicKey.rawRepresentation
        payload.append(sealedBox.combined!)
        return payload.base64EncodedString()
    }
}