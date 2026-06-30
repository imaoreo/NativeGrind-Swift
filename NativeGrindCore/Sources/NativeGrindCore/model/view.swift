//
//  view.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 30/06/2026.
//

import Foundation

public struct viewResponseV6: Codable, Sendable {
    public let viewCount: Int
    public let mostRecent: mostRecentViewV6
}

public struct mostRecentViewV6: Codable, Sendable {
    public let profileId: String
    public let photoHash: String
    public let timestamp: Date
}

public struct viewsResponseV7: Codable, Sendable {
    public let totalViewers: Int
    public let profiles: [profileViewsResponseV7]
}

public struct profileViewsResponseV7: Codable, Sendable {
    public let profileId: String
    public let seen: Date?
    public let onlineUntil: Date?
    public let isFavorite: Bool
    public let displayName: String?
    public let profileImageMediaHash: String?
    public let age: Int?
    public let showAge: Bool
    public let showDistance: Bool
    public let distance: Double?
    public let approximateDistance: Bool
    public let lastChatTimestamp: Int?
    public let isNew: Bool
    public let hasFaceRecognition: Bool
    public let lastViewed: Date?
    public let isIncognito: Bool
    public let isInBadNeighbourhood: Bool
    public let medias: [profileMedia]
    public let lastUpdatedTime: Int?
    public let boosting: Bool
    public let profileTags: [String]
    public let isSecretAdmirer: Bool
    public let isViewedMeFreshFace: Bool
    public let sexualPosition: [sexualPosition]?
    public let foundVia: String?
    public let rightNow: rightNowType
    public let rightNowStatus: rightNowStatus
    public let receivedDuringBoost: Bool
    public let showUnlockReward: Bool
    public let viewedCount: viewedCount
    public let unreadMessageCount: Int
    public let hasChatted: Bool
}

public struct previewProfileViewsResponseV7: Codable, Sendable {
    public let distance: Double?
    public let lastViewed: Date?
    public let profileImageMediaHash: String?
    public let isInBadNeighborhood: Bool
    public let isViewMeFreshFace: Bool
    public let isSecretAdmirer: Bool
    public let isFavorite: Bool
    public let seen: Date?
    public let sexualPosition: [sexualPosition]?
    public let foundVia: String?
    public let rightNow: rightNowType
    public let rightNowStatus: rightNowStatus
    public let receivedDuringBoost: Bool
    public let viewedCount: viewedCount
}

public struct viewedCount: Codable, Sendable {
    public let totalCount: Int
    public let maxDisplayCount: Int
}
