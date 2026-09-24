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

// expiresAt is left out on purpose, the docs say ISO-8601 but it isn't needed and may not be a string
public struct deviceKeyChallengeResponse: Codable, Sendable {
    public let challenge: String
}

public struct registerDeviceKeyResponse: Codable, Sendable {
    public let keyId: String? // echoed back, may be missing or the body may be empty
}

struct uploadSigningErrorResponse: Decodable {
    let type: String?
    let detail: String?
}
