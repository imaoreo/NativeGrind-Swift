//
//  dummies.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/07/2026.
//

@testable import NativeGrindCore
import Foundation

/// Dummy Profile
func mockProfile(id: String) -> profile {
    return profile(
        distance: nil,
        profileImageMediaHash: "",
        isFavorite: true,
        lastViewed: 0,
        seen: 0,
        rightNow: .notActive,
        sexualPosition: .versTop,
        foundVia: .unknown,
        profileId: id,
        displayName: "SexyBoy",
        onlineUntil: Date(),
        age: nil,
        showAge: false,
        showDistance: false,
        approximateDistance: true,
        lastChatTimestamp: 0,
        isNew: true,
        lastUpdatedTime: 0,
        medias: [
            profileMedia(
                mediaHash: "123",
                type: 0,
                state: 0,
                reason: "test",
                takenOnGrindr: true,
                createdAt: 0
            )
        ],
        meetAt: [.bar, .myPlace],
        vaccines: [.covid19],
        genders: [0],
        pronouns: [0],
        rightNowText: nil,
        rightNowPosted: nil,
        rightNowDistance: nil,
        rightNowThumbnailUrl: nil,
        rightNowFullImageUrl: nil,
        nsfw: .yesPlease,
        verifiedInstagramId: nil,
        isBlockable: true,
        showTribes: true,
        showPosition: true,
        aboutMe: "sexyass",
        ethnicity: .black,
        relationshipStatus: .committed,
        grindrTribes: [.discreet],
        lookingFor: [.relationship],
        bodyType: .slim,
        hivStatus: .negativeOnPrep,
        lastTestedDate: 0,
        height: 0,
        weight: nil,
        socialNetworks: socialNetworks(twitter: socialNetwork(userId: "1234", site: "twitter"), facebook: nil, instagram: nil),
        identity: "1234",
        hashtags: ["yes"],
        profileTags: [],
        tapped: false,
        tapType: nil,
        lastReceivedTapTimestamp: nil,
        isTeleporting: false,
        isRoaming: false,
        arrivalDays: 0,
        unreadCount: 0,
        lastThrobTimestamp: "0",
        sexualHealth: [.PrEP],
        isVisiting: false,
        travelPlans: [],
        isInAList: false,
        tribesImInto: [.leather],
        showVipBadge: false,
        rightNowShareLocation: "idk",
        rightNowMedias: [])
}
