//
//  AgeModels.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/06/2026.
//


public struct AgeVerficationOptionsResponse: Decodable, Sendable {
    public let methods: [AgeVerficationMethods]
    public let faceTecConfig: AgeVerificationConfig
}

public struct AgeVerificationConfig: Decodable, Sendable {
    public let deviceKeyIdentifier: String // Unique for every device?
    public let encryptionKey: String // Public key to encrypt face contents
    public let sdkKey: String // Seems to just be a key for the FaceTec SDK
}

public struct AgeVerficationSessionResponse: Decodable, Sendable {
    public let sessionId: String // 55 characters long just a identifier for the age verfication
}
