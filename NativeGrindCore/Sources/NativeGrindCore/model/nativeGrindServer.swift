//
//  nativeGrindServer.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 02/07/2026.
//

public struct challengeResponse: Codable, Sendable {
    public let challenge: String
    public let ttl: Int
}

public struct challengeCheckedResponse: Codable, Sendable {
    public let status: String
    public let keyId: String
}

public struct DeviceAssertion: Codable, Sendable {
    public let assertion: String
    public let keyId: String
    public let challenge: String
    
    public init(assertion: String, keyId: String, challenge: String) {
        self.assertion = assertion
        self.keyId = keyId
        self.challenge = challenge
    }
}
