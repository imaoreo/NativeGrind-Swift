//
//  media.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Foundation

public struct mediaUploadResponse: Codable, Sendable {
    public let mediaId: Int64
    public let url: String
    public let mediaHash: String?
}

public struct deviceKeyChallengeResponse: Codable, Sendable {
    public let challenge: String
    public let expiresAt: String?
}

public struct registerDeviceKeyResponse: Codable, Sendable {
    public let keyId: String
}

struct uploadSigningErrorResponse: Decodable {
    let type: String?
    let detail: String?
}
