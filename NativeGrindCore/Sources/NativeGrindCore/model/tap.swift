//
//  tap.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 30/06/2026.
//

import Foundation

public struct getTapsResponseV2: Decodable, Sendable {
    public let profiles: [tapProfileV2]

    private enum CodingKeys: String, CodingKey {
        case profiles
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profiles = c.lossyArray(.profiles)
    }
}

public struct tapProfileV2: Decodable, Sendable, Identifiable {
    public let profileId: String
    public let displayName: String?
    public let profileImageMediaHash: String?
    public let distance: Double?
    public let isFavorite: Bool
    public let timestamp: Int64
    public let tapType: tapType
    public let lastOnline: Int64?
    public let onlineUntil: Int64?
    public let isMutual: Bool
    public let isViewable: Bool
    public let unreadMessageCount: Int
    public let hasChatted: Bool

    public var id: String { "\(profileId)-\(timestamp)" }
    public var date: Date { Date(milliseconds: timestamp) }
    public var isOnline: Bool { onlineUntil.map { Date(milliseconds: $0) > Date() } ?? false }

    private enum CodingKeys: String, CodingKey {
        case profileId, displayName, profileImageMediaHash, distance, isFavorite, timestamp, tapType, lastOnline,
             onlineUntil, isMutual, isViewable, unreadMessageCount, hasChatted
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        profileId = try c.decode(flexibleId.self, forKey: .profileId).value // a number here, despite the docs saying string
        displayName = c.lenient(.displayName)
        profileImageMediaHash = c.lenient(.profileImageMediaHash)
        distance = c.lenient(.distance)
        isFavorite = c.lenient(.isFavorite) ?? false
        timestamp = c.lenientTimestamp(.timestamp) ?? 0
        tapType = c.lenient(.tapType) ?? .none
        lastOnline = c.lenientTimestamp(.lastOnline)
        onlineUntil = c.lenientTimestamp(.onlineUntil)
        isMutual = c.lenient(.isMutual) ?? false
        isViewable = c.lenient(.isViewable) ?? true
        unreadMessageCount = c.lenient(.unreadMessageCount) ?? 0
        hasChatted = c.lenient(.hasChatted) ?? false
    }
}
