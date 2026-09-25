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

public struct drawerMedia: Decodable, Sendable, Identifiable {
    public let id: Int64
    public let url: String?
    public let contentType: String?
    public let createdTs: Int64?
    public let used: Bool
    public let takenOnGrindr: Bool

    public var isVideo: Bool { contentType?.hasPrefix("video") ?? false }

    private enum CodingKeys: String, CodingKey {
        case id, url, contentType, createdTs, used, takenOnGrindr
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int64.self, forKey: .id)
        url = c.lenient(.url)
        contentType = c.lenient(.contentType)
        createdTs = c.lenientTimestamp(.createdTs)
        used = c.lenient(.used) ?? false
        takenOnGrindr = c.lenient(.takenOnGrindr) ?? false
    }
}

public struct deviceKeyChallengeResponse: Codable, Sendable {
    public let challenge: String
}

public struct registerDeviceKeyResponse: Codable, Sendable {
    public let keyId: String?
}

struct uploadSigningErrorResponse: Decodable {
    let type: String?
    let detail: String?
}
