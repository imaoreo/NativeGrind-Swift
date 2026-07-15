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
    var status: nsStatus { get } // "success" or "failed"
    var message: String { get } // "Account created", "Account creation failed cause x,y,z"
}

public struct nsResponse: nsResponseProtocol, Codable {
    public let status: nsStatus
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
    public let status: nsStatus
    public let message: String
    public let accountId: String?
}

public struct nsAccountInfomationResponse: nsResponseProtocol, Codable {
    public let status: nsStatus
    public let message: String
    public let accountId: String?
    public let deviceId: String?
}

public struct nsDeviceAuthResponse: nsResponseProtocol, Codable {
    public let status: nsStatus
    public let message: String
    public let accountId: String?
}

public struct nsAccountCreatedResponse: nsResponseProtocol, Codable {
    public let status: nsStatus
    public let message: String
    public let accountId: String?
}

public struct nsDeviceListResponse: nsResponseProtocol, Codable {
    public let status: nsStatus
    public let message: String
    public let devices: [device]?
}

public struct device: Codable {
    public let publicKey: String
    public let id: String
    public let name: String
    public let createdAt: Date
    public let updatedAt: Date
    public let userId: String?
    public let addedById: String?
}

public struct nsDeviceRemovedDeviceResponse: nsResponseProtocol, Codable {
    public let status: nsStatus
    public let message: String // 'Your device has been removed from the account'
}

public struct nsDeviceRemovedResponse: nsResponseProtocol, Codable {
    public let status: nsStatus
    public let message: String
}

public struct nsDeviceRemoved: Codable {
    public let deviceId: String
}

public struct nsConnectDevice: Codable {
    public let code: String
}


public struct nsLinkCodeResponse: nsResponseProtocol, Codable {
    public let status: nsStatus
    public let message: String
    public let code: String?
    public let ttl: Int? // 180
}

public struct nsDeviceAddedResponse: nsResponseProtocol, Codable {
    public let status: nsStatus
    public let message: String
}

public struct nsDeviceLinkedResponse: nsResponseProtocol, Codable {
    public let status: nsStatus
    public let message: String
}
