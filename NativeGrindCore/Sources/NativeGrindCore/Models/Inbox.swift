//
//  Inbox.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

public struct InboxResponse: Decodable, Sendable {
    public let entries: [Conversation]
    public let showsFreeHeaderLabel: Bool
    public let totalFullConversations: Int
    public let totalPartialConversations: Int // Should js be 0 but who knows
    public let maxDisplayLockCount: Int
    public let nextPage: Int
}

public struct Conversation: Decodable, Sendable {
    public let type: ConversationType
    public let data: ConversationData
}

public struct ConversationData: Decodable, Sendable {
    public let conversationId: String
    public let name: String
    public let participants: [ConversationParticipant]
    public let lastActivityTimestamp: Int
    public let unreadCount: Int
    public let preview: ConversationPreview
    public let muted: Bool
    public let pinned: Bool
    public let favorite: Bool
    public let context: Int?
    public let onlineUntil: Int? // Don't use this one
    public let translatable: Bool
    public let rightNow: String // like "NOT_ACTIVE"
    public let hasUnreadThrob: Bool
}

public struct ConversationParticipant: Decodable, Sendable {
    public let profileId: ProfileID
    public let primaryMediaHash: String
    public let lastOnline: String
    public let onlineUntil: String
    public let distanceMetres: Double
    public let position: [SexualPosition]
    public let isInAList: Bool
    public let hasDatingPotential: Bool
}

public struct ConversationPreview: Decodable, Sendable {
    public let conversationId: conversationIdObject
    public let messageId: String
    public let chat1MessageId: String // UUIDv4
    public let senderId: String
    public let type: MessageType
    public let chat1Type: Chat1MessageType
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

public struct conversationIdObject: Decodable, Sendable {
    public let value: String
}
