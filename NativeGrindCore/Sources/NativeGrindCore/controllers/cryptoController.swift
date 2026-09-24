import CryptoKit
import Security
import Foundation

public enum cryptoError: Error {
    case keychainSaveFailed
    case keyNotFound
    case unsupportedDevice
    case invalidPublicKey
    case invalidData
}

public final class cryptoController: Sendable {
    public static let shared = cryptoController()
    
    private init() {}
    
    /// Generate key and store in secure enclave with a pointer in keychain
    public func generateAndStoreKeyPair() throws -> String {
        guard SecureEnclave.isAvailable else {
            throw cryptoError.unsupportedDevice
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
            throw cryptoError.keychainSaveFailed
        }
        
        return privateKey.publicKey.rawRepresentation.base64EncodedString()
    }

    /// Load and sign using the poitner
    public func signChallenge(challenge: String) throws -> String {
        guard let keyPointerData = keychainManager.shared.getData(type: .deviceKeyPointer) else {
            throw cryptoError.keyNotFound
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
            throw cryptoError.keyNotFound
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
            throw cryptoError.invalidPublicKey
        }
        
        let ephemeralPrivateKey = P256.KeyAgreement.PrivateKey()
        let sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: recipientPublicKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(), sharedInfo: Data(), outputByteCount: 32)
        let sealedBox = try AES.GCM.seal(textData, using: symmetricKey)
        
        var payload = ephemeralPrivateKey.publicKey.rawRepresentation
        payload.append(sealedBox.combined!)
        return payload.base64EncodedString()
    }
    
    public func decryptWithPrivateKey(encryptedBase64: String) async throws -> String {
        await errorManager.shared.log("cryptoController", "decryptWithPrivateKey: Starting decryption (base64 length: \(encryptedBase64.count))")
        
        guard let keyPointerData = keychainManager.shared.getData(type: .deviceKeyPointer),
              let payload = Data(base64Encoded: encryptedBase64), payload.count > 64,
              let ephemeralKey = try? P256.KeyAgreement.PublicKey(rawRepresentation: payload.prefix(64)),
              let privateKey = try? SecureEnclave.P256.KeyAgreement.PrivateKey(dataRepresentation: keyPointerData) else {
            await errorManager.shared.log("cryptoController", "decryptWithPrivateKey: Failed to parse 64-byte raw key or SecureEnclave key")
            throw cryptoError.keyNotFound
        }
        
        let sharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: ephemeralKey)
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(), sharedInfo: Data(), outputByteCount: 32)
        let sealedBox = try AES.GCM.SealedBox(combined: payload.dropFirst(64))
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        guard let text = String(data: decryptedData, encoding: .utf8) else {
            await errorManager.shared.log("cryptoController", "decryptWithPrivateKey: Decrypted data is not valid UTF-8 text")
            throw cryptoError.invalidPublicKey
        }
        
        await errorManager.shared.log("cryptoController", "decryptWithPrivateKey: Decryption successful")
        return text
    }
    
    /// Encrypt text using the shared account key
    public func encryptTextWithSharedKey(text: String) throws -> String {
        guard let accountKeyBase64 = keychainManager.shared.getToken(type: .accountKey),
              let keyData = Data(base64Encoded: accountKeyBase64) else {
            throw cryptoError.keyNotFound
        }
        
        let symmetricKey = SymmetricKey(data: keyData)
        
        guard let textData = text.data(using: .utf8) else {
            throw cryptoError.invalidData
        }
        
        let sealedBox = try AES.GCM.seal(textData, using: symmetricKey)
        
        guard let combinedData = sealedBox.combined else {
            throw cryptoError.keyNotFound
        }
        
        return combinedData.base64EncodedString()
    }
    
    public func syncIdentifier(for value: String) throws -> String {
        guard let accountKeyBase64 = keychainManager.shared.getToken(type: .accountKey),
              let keyData = Data(base64Encoded: accountKeyBase64) else {
            throw cryptoError.keyNotFound
        }

        let identifierKey = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: keyData),
            info: Data("nativegrind-sync-identifier".utf8),
            outputByteCount: 32
        )
        let mac = HMAC<SHA256>.authenticationCode(for: Data(value.utf8), using: identifierKey)

        return Data(mac).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Decrypt text using shared Account Key
    public func decryptTextWithSharedKey(encryptedBase64: String) throws -> String {
        guard let accountKeyBase64 = keychainManager.shared.getToken(type: .accountKey),
              let keyData = Data(base64Encoded: accountKeyBase64) else {
            throw cryptoError.keyNotFound
        }
        
        let symmetricKey = SymmetricKey(data: keyData)
        
        guard let encryptedData = Data(base64Encoded: encryptedBase64) else {
            throw cryptoError.invalidData
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        
        let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        
        guard let text = String(data: decryptedData, encoding: .utf8) else {
            throw cryptoError.invalidData
        }
        
        return text
    }
}
