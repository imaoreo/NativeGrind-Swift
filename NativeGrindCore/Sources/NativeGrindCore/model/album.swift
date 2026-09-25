//
//  album.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 25/09/2026.
//

import Foundation

public struct albumDetails: Decodable, Sendable {
    public let albumId: String
    public let profileId: String?
    public let albumViewable: Bool
    public let content: [albumContent]

    private enum CodingKeys: String, CodingKey {
        case albumId, profileId, albumViewable, content
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        albumId = try c.decode(flexibleId.self, forKey: .albumId).value
        profileId = (c.lenient(.profileId) as flexibleId?)?.value
        albumViewable = c.lenient(.albumViewable) ?? true
        content = c.lossyArray(.content)
    }
}

public struct albumContent: Decodable, Sendable, Identifiable {
    public let contentId: String
    public let contentType: String?
    public let coverUrl: String?
    public let thumbUrl: String?
    public let url: String?
    public let processing: Bool
    public let remainingViews: Int?

    public var id: String { contentId }
    public var isVideo: Bool { contentType?.hasPrefix("video") ?? false }

    private enum CodingKeys: String, CodingKey {
        case contentId, contentType, coverUrl, thumbUrl, url, processing, remainingViews
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        contentId = try c.decode(flexibleId.self, forKey: .contentId).value
        contentType = c.lenient(.contentType)
        coverUrl = c.lenient(.coverUrl)
        thumbUrl = c.lenient(.thumbUrl)
        url = c.lenient(.url)
        processing = c.lenient(.processing) ?? false
        remainingViews = c.lenient(.remainingViews)
    }
}

public struct albumsSharedResponse: Decodable, Sendable {
    public let albums: [albumSummary]

    private enum CodingKeys: String, CodingKey {
        case albums
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        albums = c.lossyArray(.albums)
    }
}

public struct albumSummary: Decodable, Sendable, Identifiable {
    public let albumId: String
    public let profileId: String?
    public let albumViewable: Bool
    public let expiresAt: Int64? // ms
    public let cover: albumContent?
    public let imageCount: Int
    public let videoCount: Int

    public var id: String { albumId }

    private enum CodingKeys: String, CodingKey {
        case albumId, profileId, albumViewable, expiresAt, content, contentCount
    }

    private struct contentCount: Decodable {
        let imageCount: Int?
        let videoCount: Int?
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        albumId = try c.decode(flexibleId.self, forKey: .albumId).value
        profileId = (c.lenient(.profileId) as flexibleId?)?.value
        albumViewable = c.lenient(.albumViewable) ?? true
        expiresAt = c.lenientTimestamp(.expiresAt)
        cover = c.lenient(.content)
        let counts: contentCount? = c.lenient(.contentCount)
        imageCount = counts?.imageCount ?? 0
        videoCount = counts?.videoCount ?? 0
    }
}

public struct nsAlbumBackup: Codable, Sendable {
    public let albumId: String
    public let ownerProfileId: String
    public let items: [nsAlbumBackupItem]
}

public struct nsAlbumBackupItem: Codable, Sendable {
    public let contentId: String
    public let contentType: String
    public let url: String
    public let createdAt: Int64?
}

public struct nsUploadAlbumMedia: Codable, Sendable {
    public let albumId: String
    public let contentId: String
    public let ownerProfileId: String
    public let base64Data: String
}

