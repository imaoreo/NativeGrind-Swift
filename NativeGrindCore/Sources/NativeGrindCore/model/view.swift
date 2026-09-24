//
//  view.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 30/06/2026.
//

import Foundation

public struct viewResponseV6: Codable, Sendable {
    public let viewedCount: Int
    public let mostRecent: mostRecentViewV6?
}

public struct mostRecentViewV6: Codable, Sendable {
    public let profileId: String?
    public let photoHash: String?
    public let timestamp: Int64?

    public var date: Date? { timestamp.map(Date.init(milliseconds:)) }
}

public struct viewsResponseV7: Decodable, Sendable {
    public let totalViewers: Int
    public let profiles: [profileViewsResponseV7]
    public let previews: [previewProfileViewsResponseV7]

    private enum CodingKeys: String, CodingKey {
        case totalViewers, profiles, previews
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        totalViewers = c.lenient(.totalViewers) ?? 0
        profiles = c.lossyArray(.profiles)
        previews = c.lossyArray(.previews)
    }
}

public struct profileViewsResponseV7: Decodable, Sendable, Identifiable {
    public let profileId: String
    public let displayName: String?
    public let profileImageMediaHash: String?
    public let age: Int?
    public let showAge: Bool
    public let distance: Double?
    public let showDistance: Bool
    public let lastViewed: Int64? // ms
    public let seen: Int64? // ms
    public let onlineUntil: Int64? // ms
    public let isFavorite: Bool
    public let isNew: Bool
    public let isSecretAdmirer: Bool
    public let isIncognito: Bool
    public let foundVia: String? // DISCOVER / FOR_YOU / UNKNOWN
    public let viewedCount: viewedCount?
    public let unreadMessageCount: Int
    public let hasChatted: Bool

    public var id: String { profileId }
    public var lastViewedDate: Date? { lastViewed.map(Date.init(milliseconds:)) }
    public var isOnline: Bool { onlineUntil.map { Date(milliseconds: $0) > Date() } ?? false }

    private enum CodingKeys: String, CodingKey {
        case profileId, displayName, profileImageMediaHash, age, showAge, distance, showDistance, lastViewed, seen,
             onlineUntil, isFavorite, isNew, isSecretAdmirer, isIncognito, foundVia, viewedCount, unreadMessageCount, hasChatted
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profileId = try c.decode(flexibleId.self, forKey: .profileId).value // can be a number or a string
        displayName = c.lenient(.displayName)
        profileImageMediaHash = c.lenient(.profileImageMediaHash)
        age = c.lenient(.age).flatMap { $0 > 0 ? $0 : nil } // 0 means hidden
        showAge = c.lenient(.showAge) ?? false
        distance = c.lenient(.distance)
        showDistance = c.lenient(.showDistance) ?? false
        lastViewed = c.lenientTimestamp(.lastViewed)
        seen = c.lenientTimestamp(.seen)
        onlineUntil = c.lenientTimestamp(.onlineUntil)
        isFavorite = c.lenient(.isFavorite) ?? false
        isNew = c.lenient(.isNew) ?? false
        isSecretAdmirer = c.lenient(.isSecretAdmirer) ?? false
        isIncognito = c.lenient(.isIncognito) ?? false
        foundVia = c.lenient(.foundVia)
        viewedCount = c.lenient(.viewedCount)
        unreadMessageCount = c.lenient(.unreadMessageCount) ?? 0
        hasChatted = c.lenient(.hasChatted) ?? false
    }
}

public struct previewProfileViewsResponseV7: Decodable, Sendable {
    public let profileImageMediaHash: String?
    public let distance: Double?
    public let lastViewed: Int64? // ms
    public let isSecretAdmirer: Bool
    public let isFavorite: Bool
    public let viewedCount: viewedCount?

    public var lastViewedDate: Date? { lastViewed.map(Date.init(milliseconds:)) }

    private enum CodingKeys: String, CodingKey {
        case profileImageMediaHash, distance, lastViewed, isSecretAdmirer, isFavorite, viewedCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profileImageMediaHash = c.lenient(.profileImageMediaHash)
        distance = c.lenient(.distance)
        lastViewed = c.lenientTimestamp(.lastViewed)
        isSecretAdmirer = c.lenient(.isSecretAdmirer) ?? false
        isFavorite = c.lenient(.isFavorite) ?? false
        viewedCount = c.lenient(.viewedCount)
    }
}

public struct viewedCount: Codable, Sendable {
    public let totalCount: Int
    public let maxDisplayCount: Int
}

public extension Date {
    init(milliseconds: Int64) {
        self.init(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}

extension KeyedDecodingContainer {
    func lenient<T: Decodable>(_ key: Key) -> T? {
        (try? decodeIfPresent(T.self, forKey: key)) ?? nil
    }

    func lenientTimestamp(_ key: Key) -> Int64? {
        if let value: Int64 = lenient(key) { return value }
        if let value: Double = lenient(key) { return Int64(value) }
        return nil
    }

    func lossyArray<T: Decodable>(_ key: Key) -> [T] {
        guard var container = try? nestedUnkeyedContainer(forKey: key) else { return [] }
        var items: [T] = []
        while !container.isAtEnd {
            if let item = try? container.decode(T.self) {
                items.append(item)
            } else {
                _ = try? container.decode(skipItem.self)
            }
        }
        return items
    }
}

private struct skipItem: Decodable {}
