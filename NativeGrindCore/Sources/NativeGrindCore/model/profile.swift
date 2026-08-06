//
//  profile.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

import Foundation

public struct profileResponse: Codable, Sendable {
    public let profiles: [profile]
}

public struct profile: Codable, Sendable {
    public let distance: Double?
    public let profileImageMediaHash: String
    public let isFavorite: Bool
    public let lastViewed: Int?
    public let seen: Int?
    public let rightNow: rightNowType
    public let sexualPosition: sexualPosition?
    public let foundVia: viewSource?
    public let profileId: String
    public let displayName: String?
    public let onlineUntil: Date?
    public let age: Int?
    public let showAge: Bool
    public let showDistance: Bool
    public let approximateDistance: Bool
    public let lastChatTimestamp: Int?
    public let isNew: Bool
    public let lastUpdatedTime: Int
    public let medias: [profileMedia]
    public let meetAt: [meetAt]?
    public let vaccines: [vaccines]?
    public let genders: [Int] // ENUM
    public let pronouns: [Int] // ENUM
    public let rightNowText: String?
    public let rightNowPosted: Int? // Unix Timestamp
    public let rightNowDistance: Int?
    public let rightNowThumbnailUrl: String?
    public let rightNowFullImageUrl: String?
    public let nsfw: NSFWPics?
    public let verifiedInstagramId: String?
    public let isBlockable: Bool?
    public let showTribes: Bool
    public let showPosition: Bool
    public let aboutMe: String?
    public let ethnicity: ethnicity
    public let relationshipStatus: relationshipStatus
    public let grindrTribes: [tribes]
    public let lookingFor: [lookingFor]
    public let bodyType: bodyType?
    public let hivStatus: HIVStatus?
    public let lastTestedDate: Int?
    public let height: Double // Currently in cm
    public let weight: Double? // Currently in grams
    public let socialNetworks: socialNetworks
    public let identity: String?
    public let hashtags: [String]
    public let profileTags: [String] // Type GET /v1/tags
    public let tapped: Bool
    public let tapType: tapType?
    public let lastReceivedTapTimestamp: Int?
    public let isTeleporting: Bool
    public let isRoaming: Bool
    public let arrivalDays: Int?
    public let unreadCount: Int?
    public let lastThrobTimestamp: String?
    public let sexualHealth: [sexualHealth]
    public let isVisiting: Bool
    public let travelPlans: [travelPlan] // Type
    public let isInAList: Bool
    public let tribesImInto: [tribes]?
    public let showVipBadge: Bool
    public let rightNowShareLocation: String? // Rather "NONE" or null
    public let rightNowMedias: [rightNowMedia]?
    public var dbCreatedAt: Date? // used by the db for DIFF
}

public struct travelPlan: Codable, Sendable {
    public let endDate: Int? // Unix Timestamp
    public let geohash: String
    public let travelPlanId: Int
    public let locationName: String
    public let showOnProfile: Bool?
    public let startDate: Int? // Unix Timestamp
}

public struct rightNowMedia: Codable, Sendable {
    public let mediaId: Int?
    public let thumbnailUrl: String
    public let fullImageUrl: String
    public let contentType: String
    public let isNsfw: Bool?
}

public struct socialNetworks: Codable, Sendable {
    public let twitter: socialNetwork?
    public let facebook: socialNetwork?
    public let instagram: socialNetwork?
}

public struct socialNetwork: Codable, Sendable {
    public let userId: String?
    public let site: String?
}

public struct profileMedia: Codable, Sendable {
    public let mediaHash: String
    public let type: Int
    public let state: Int
    public let reason: String?
    public let takenOnGrindr: Bool?
    public let createdAt: Int?
}
