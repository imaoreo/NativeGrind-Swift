//
//  ageModels.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/06/2026.
//


public struct ageVerificationOptionsResponse: Codable, Sendable {
    public let methods: [ageVerificationMethods]
    public let faceTecConfig: ageVerificationConfig
}

public struct ageVerificationConfig: Codable, Sendable {
    public let deviceKeyIdentifier: String // Unique for every device?
    public let encryptionKey: String // Public key to encrypt face contents
    public let sdkKey: String // Seems to just be a key for the FaceTec SDK
}

public struct ageVerificationSessionResponse: Codable, Sendable {
    public let sessionId: String // 55 characters long just a identifier for the age verification
}
