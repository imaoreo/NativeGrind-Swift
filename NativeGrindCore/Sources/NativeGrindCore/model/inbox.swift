//
//  inbox.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

import Foundation

public struct inboxResponse: Codable, Sendable {
    public let entries: [conversation]
    public let showsFreeHeaderLabel: Bool
    public let totalFullConversations: Int
    public let totalPartialConversations: Int // Should js be 0 but who knows
    public let maxDisplayLockCount: Int
    public let nextPage: Int
}

public struct conversation: Codable, Sendable {
    public let type: conversationType
    public let data: conversationData
}

public struct conversationData: Codable, Sendable {
    public let conversationId: String
    public let name: String
    public let participants: [conversationParticipant]
    public let lastActivityTimestamp: Int
    public let unreadCount: Int
    public let preview: conversationPreview
    public let muted: Bool
    public let pinned: Bool
    public let favorite: Bool
    public let context: Int?
    public let onlineUntil: Int? // Don't use this one
    public let translatable: Bool
    public let rightNow: rightNowType
    public let hasUnreadThrob: Bool
    public var dbCreatedAt: Date?
}

public struct conversationParticipant: Codable, Sendable {
    public let profileId: String
    public let primaryMediaHash: String
    public let lastOnline: String
    public let onlineUntil: String
    public let distanceMetres: Double
    public let position: [sexualPosition]
    public let isInAList: Bool
    public let hasDatingPotential: Bool
}

public struct conversationPreview: Codable, Sendable {
    public let conversationId: conversationIdObject
    public let messageId: String
    public let chat1MessageId: String // UUIDv4
    public let senderId: String
    public let type: messageType
    public let chat1Type: chat1MessageType
    public let text: String?
    public let url: String?
    public let lat: String?
    public let lon: String?
    public let albumId: String?
    public let albumContentId: String?
    public let albumContentReply: String?
    public let duration: String?
    public let imageHash: String?
    public let photoContentReply: String?
}

public struct conversationIdObject: Codable, Sendable {
    public let value: String
}
