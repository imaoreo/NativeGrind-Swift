//
//  gridModels.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 06/08/2026.
//

import Foundation

public struct CascadeResponseProfile: Codable, Sendable, Identifiable {
    public var id: Int { profileId }
    public let profileId: Int
    public let onlineUntil: Int?
    public let displayName: String?
    public let distanceMeters: Int?
    public let rightNow: String?
    public let unreadCount: Int?
    public let isVisiting: Bool?
    public let isPopular: Bool?

    // v3 cascade only
    public let atType: String?
    public let lastOnline: Int?
    public let photoMediaHashes: [String]?
    public let lookingFor: [Int]?
    public let tribes: [Int]?
    public let meetAt: [Int]?
    public let vaccines: [Int]?
    public let genders: [Int]?
    public let pronouns: [Int]?
    public let sexualPosition: Int?
    public let approximateDistance: Bool?
    public let tags: [String]?
    public let isFavorite: Bool?
    public let socialNetworks: [String]?
    public let isBoosting: Bool?
    public let hasChattedInLast24Hrs: Bool?
    public let hasUnviewedSpark: Bool?
    public let isTeleporting: Bool?
    public let isRoaming: Bool?
    public let isRightNow: Bool?
    public let hasUnreadThrob: Bool?
    public let isBlockable: Bool?
    public let isBoostingSomewhereElse: Bool?
    public let hasPhoto: Bool?

    // full_profile_v1
    public let primaryImageUrl: String?
    public let favorite: Bool?
    public let viewed: Bool?
    public let chatted: Bool?
    public let roaming: Bool?
    public let age: Int?
    public let heightCm: Int?
    public let weightGrams: Int?
    public let bodyType: Int?

    // partial_profile_v1 
    public let upsellItemType: String?

    enum CodingKeys: String, CodingKey {
        case profileId, onlineUntil, displayName, distanceMeters, rightNow, unreadCount, isVisiting, isPopular
        case atType = "@type"
        case lastOnline, photoMediaHashes, lookingFor, tribes, meetAt, vaccines, genders, pronouns
        case sexualPosition, approximateDistance, tags, isFavorite, socialNetworks, isBoosting
        case hasChattedInLast24Hrs, hasUnviewedSpark, isTeleporting, isRoaming, isRightNow
        case hasUnreadThrob, isBlockable, isBoostingSomewhereElse, hasPhoto
        case primaryImageUrl, favorite, viewed, chatted, roaming, age, heightCm, weightGrams, bodyType
        case upsellItemType
    }
}

public struct CascadeItem: Codable, Sendable {
    public let type: String
    public let data: CascadeResponseProfile?

    public var isProfile: Bool {
        type == "full_profile_v1" || type == "partial_profile_v1"
    }

    enum CodingKeys: String, CodingKey {
        case type, data
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        if type == "full_profile_v1" || type == "partial_profile_v1" {
            data = try container.decodeIfPresent(CascadeResponseProfile.self, forKey: .data)
        } else {
            data = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(data, forKey: .data)
    }
}
public struct CascadeResponse: Codable, Sendable {
    public let items: [CascadeItem]
    public let nextPage: Int?
    public let shuffled: Bool?
}

public struct GridFilters: Sendable {
    public var onlineOnly: Bool?
    public var photoOnly: Bool?
    public var faceOnly: Bool?
    public var hasAlbum: Bool?
    public var notRecentlyChatted: Bool?
    public var fresh: Bool?
    public var rightNow: Bool?
    public var favorites: Bool?
    public var shuffle: Bool?
    public var hot: Bool?
    public var showSponsoredProfiles: Bool?
    public var ageMin: Int?
    public var ageMax: Int?
    public var heightCmMin: Double?
    public var heightCmMax: Double?
    public var weightGramsMin: Double?
    public var weightGramsMax: Double?
    public var tribes: [tribes]?
    public var lookingFor: [lookingFor]?
    public var relationshipStatuses: [relationshipStatus]?
    public var bodyTypes: [bodyType]?
    public var sexualPositions: [sexualPosition]?
    public var meetAt: [meetAt]?
    public var nsfwPics: [NSFWPics]?
    public var tags: String?
    public var genders: String?
    public var pageNumber: Int?

    public init() {}

    public func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        func add(_ name: String, _ value: Bool?) {
            if let v = value { items.append(URLQueryItem(name: name, value: v ? "true" : "false")) }
        }
        func addInt(_ name: String, _ value: Int?) {
            if let v = value { items.append(URLQueryItem(name: name, value: String(v))) }
        }
        func addDouble(_ name: String, _ value: Double?) {
            if let v = value { items.append(URLQueryItem(name: name, value: String(v))) }
        }
        func addStr(_ name: String, _ value: String?) {
            if let v = value, !v.isEmpty { items.append(URLQueryItem(name: name, value: v)) }
        }
        func addEnum<T: RawRepresentable>(_ name: String, _ values: [T]?) where T.RawValue == Int {
            guard let rawValues = removeENUM(from: values), !rawValues.isEmpty else { return }
            items.append(URLQueryItem(name: name, value: rawValues.map(String.init).joined(separator: ",")))
        }

        add("onlineOnly", onlineOnly)
        add("photoOnly", photoOnly)
        add("faceOnly", faceOnly)
        add("hasAlbum", hasAlbum)
        add("notRecentlyChatted", notRecentlyChatted)
        add("fresh", fresh)
        add("rightNow", rightNow)
        add("favorites", favorites)
        add("shuffle", shuffle)
        add("hot", hot)
        add("showSponsoredProfiles", showSponsoredProfiles)
        addInt("ageMin", ageMin)
        addInt("ageMax", ageMax)
        addDouble("heightCmMin", heightCmMin)
        addDouble("heightCmMax", heightCmMax)
        addDouble("weightGramsMin", weightGramsMin)
        addDouble("weightGramsMax", weightGramsMax)
        addEnum("tribes", tribes)
        addEnum("lookingFor", lookingFor)
        addEnum("relationshipStatuses", relationshipStatuses)
        addEnum("bodyTypes", bodyTypes)
        addEnum("sexualPositions", sexualPositions)
        addEnum("meetAt", meetAt)
        addEnum("nsfwPics", nsfwPics)
        addStr("tags", tags)
        addStr("genders", genders)
        addInt("pageNumber", pageNumber)
        return items
    }
}
