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

public struct nsResponse: nsResponseProtocol, Codable, Sendable {
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

public struct nsAuthenticationResponse: nsResponseProtocol, Codable,  Sendable {
    public let status: nsStatus
    public let message: String
    public let accountId: String?
}

public struct nsAccountInformationResponse: nsResponseProtocol, Codable,  Sendable {
    public let status: nsStatus
    public let message: String
    public let accountId: String?
    public let deviceId: String?
}

public struct nsDeviceAuthResponse: nsResponseProtocol, Codable,  Sendable {
    public let status: nsStatus
    public let message: String
    public let accountId: String?
}

public struct nsAccountCreatedResponse: nsResponseProtocol, Codable,  Sendable {
    public let status: nsStatus
    public let message: String
    public let accountId: String?
}

public struct nsDeviceListResponse: nsResponseProtocol, Codable, Sendable {
    public let status: nsStatus
    public let message: String
    public let devices: [device]?
}

public struct device: Codable, Identifiable, Sendable, Hashable {
    public let publicKey: String
    public let id: String
    public let name: String
    public let createdAt: String
    public let updatedAt: String
    public let userId: String?
    public let addedById: String?
}

public struct nsDeviceRemovedDeviceResponse: nsResponseProtocol, Codable, Sendable {
    public let status: nsStatus
    public let message: String // 'Your device has been removed from the account'
}

public struct nsDeviceRemovedResponse: nsResponseProtocol, Codable, Sendable {
    public let status: nsStatus
    public let message: String
}

public struct nsDeviceRemoved: Codable {
    public let deviceId: String
}

public struct nsConnectDevice: Codable {
    public let code: String
    public let key: String // the account private key encrypted with the public key from before
}

public struct nsDevicePublicKey: Codable {
    public let code: String
}

public struct nsLinkCodeResponse: nsResponseProtocol, Codable, Sendable {
    public let status: nsStatus
    public let message: String
    public let code: String?
    public let ttl: Int? // 180
}

public struct nsDeviceAddedResponse: nsResponseProtocol, Codable, Sendable {
    public let status: nsStatus
    public let message: String
    public let accountId: String?
    public let key: String? // The account key encrypted by the devices public key
}

public struct nsDeviceLinkedResponse: nsResponseProtocol, Codable, Sendable {
    public let status: nsStatus
    public let message: String
}

public struct nsDevicePublicKeyResponse: nsResponseProtocol, Codable, Sendable {
    public let status: nsStatus
    public let message: String
    public let publicKey: String?
    public let code: String?
}

public struct nsGetData: Codable, Sendable {
    public let location: String
}

public struct nsGetDataResponse: nsResponseProtocol, Codable, Sendable {
    public let status: nsStatus
    public let message: String
    public let accountId: String?
    public let location: String?
    public let data: String?
}

public struct nsSaveData: Codable, Sendable {
    public let location: String
    public let encryptedPayload: String
}

public struct nsSaveDataResponse: nsResponseProtocol, Codable, Sendable {
    public let status: nsStatus
    public let message: String
    public let accountId: String?
    public let location: String?
}

public struct nsSyncProfileRequest: Codable, Sendable {
    public let profile: profile
    public let geohash: String?
    
    public init(profile: profile, geohash: String?) {
        self.profile = profile
        self.geohash = geohash
    }
}

public struct nsSyncProfileResponse: nsResponseProtocol, Codable, Sendable {
    public let status: nsStatus
    public let message: String
    public let profileId: String?
    public let missingMediaHashes: [String]?
}

public struct nsUploadMedia: Codable, Sendable {
    public let mediaHash: String
    public let base64Data: String
    
    public init(mediaHash: String, base64Data: String) {
        self.mediaHash = mediaHash
        self.base64Data = base64Data
    }
}

public struct nsGetProfileByImageRequest: Codable, Sendable {
    public let mediaHash: String
    
    public init(mediaHash: String) {
        self.mediaHash = mediaHash
    }
}

public struct nsGetProfileByImageResponse: nsResponseProtocol, Codable, Sendable {
    public let status: nsStatus
    public let message: String
    public let mediaHash: String?
    public let profileId: String?
}
