//
//  tap.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 30/06/2026.
//

import Foundation

public struct getTapsResponseV2: Codable, Sendable {
    public let profiles: [tapProfileV2]
}

public struct tapProfileV2: Codable, Sendable {
    public let profileId: String
    public let displayName: String?
    public let profileImageMediaHash: String?
    public let distance: Double?
    public let isFavorite: Bool
    public let timestamp: Date
    public let tapType: Int
    public let lastOnline: Date?
    public let isBoosting: Bool
    public let isMutual: Bool
    public let rightNowType: rightNowType
    public let isViewable: Bool
    public let onlineUntil: Date?
    public let unreadMessageCount: Int
    public let hasChatted: Bool
    public let rightNowStatus: rightNowStatus
    public let receivedDuringBoost: Bool
}
