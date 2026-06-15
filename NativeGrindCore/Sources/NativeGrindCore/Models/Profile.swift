//
//  Profile.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

public struct ProfileResponse: Decodable, Sendable {
    public let profiles: [Profile]
}

public struct Profile: Decodable, Sendable {
    public let distance: Double
    public let profileImageMediaHash: String
    public let isFavorite: Bool
    public let lastViewed: Int?
    public let seen: Int?
    public let rightNow: RightNowStatus
    public let sexualPosition: SexualPosition
    public let foundVia: ViewSource?
    public let profileId: ProfileID
    public let displayName: String?
    public let onlineUntil: Int?
    public let age: Int?
    public let showAge: Bool
    public let showDistance: Bool
    public let approximateDistance: Bool
    public let lastChatTimestamp: Int?
    public let isNew: Bool
    public let lastUpdatedTime: Int
    public let medias: [ProfileMedia]
    public let meetAt: [MeetAt]?
    public let vaccines: [Vaccines]?
    public let genders: [Int] // ENUM
    public let pronouns: [Int] // ENUM
    public let rightNowText: String?
    public let rightNowPosted: Int?
    public let rightNowDistance: Int?
    public let rightNowThumbnailUrl: String?
    public let rightNowFullImageUrl: String?
    public let nsfw: NSFWPics?
    public let verifiedInstagramId: String?
    public let isBlockable: Bool?
    public let showTribes: Bool
    public let showPosition: Bool
    public let aboutMe: String
    public let ethnicity: Ethnicity
    public let relationshipStatus: RelationshipStatus
    public let grindrTribes: [Tribes]
    public let lookingFor: [LookingFor]
    public let bodyType: BodyType?
    public let hivStatus: HIVStatus?
    public let lastTestedDate: Int?
    public let height: Int // Currently in cm
    public let weight: Int? // Currently in grams
    public let socialNetworks: SocialNetworks
    public let identity: String?
    public let hashtags: [String]
    public let profileTags: [String] // Type GET /v1/tags
    public let tapped: Bool
    public let tapType: TapType?
    public let lastReceivedTapTimestamp: Int?
    public let isTeleporting: Bool
    public let isRoaming: Bool
    public let arrivalDays: Int?
    public let unreadCount: Int?
    public let lastThrobTimestamp: String?
    public let sexualHealth: [SexualHealth]
    public let isVisiting: Bool
    public let travelPlans: String // Type
    public let isInAList: Bool
    public let tribesImInto: [Tribes]
    public let showVipBadge: Bool
    public let rightNowShareLocation: String? // Rather "NONE" or null
    public let rightNowMedias: [RightNowMedia]?
}

public struct RightNowMedia: Decodable, Sendable {
    public let mediaId: Int?
    public let thumbnailUrl: String
    public let fullImageUrl: String
    public let contentType: String
    public let isNsfw: Bool?
}

public struct SocialNetworks: Decodable, Sendable {
    public let twitter: SocialNetwork?
    public let facebook: SocialNetwork?
    public let instagram: SocialNetwork?
}

public struct SocialNetwork: Decodable, Sendable {
    public let userId: String?
    public let site: String?
}

public struct ProfileMedia: Decodable, Sendable {
    public let mediaHash: String
    public let type: Int
    public let state: Int
    public let reason: String?
    public let takenOnGrindr: Bool?
    public let createdAt: Int?
}
