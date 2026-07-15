//
//  nativeGrindServer.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 02/07/2026.
//

import Foundation

public struct nsAuthChallengeResponse: Codable, Sendable {
    public let challenge: String
}

public protocol nsResponseProtocol {
    var status: String { get } // "success" or "failed"
    var message: String { get } // "Account created", "Account creation failed cause x,y,z"
}

public struct nsResponse: nsResponseProtocol, Codable {
    public let status: String
    public let message: String
}

public struct nsAuthentication: Codable {
    public let deviceId: String
    public let deviceName: String?
    public let publicKey: String
    public let signature: String
    public let challenge: String
}

public struct nsAuthenticationResponse: nsResponseProtocol, Codable {
    public let status: String
    public let message: String
    public let accountId: String?
}

public struct nsAccountInfomationResponse: nsResponseProtocol, Codable {
    public let status: String
    public let message: String
    public let accountId: String?
    public let deviceId: String?
}
