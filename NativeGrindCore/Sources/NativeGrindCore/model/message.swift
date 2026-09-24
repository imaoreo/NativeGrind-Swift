//
//  message.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Foundation

public struct conversationMessagesResponse: Codable, Sendable {
    public let lastReadTimestamp: Int64? // recipient's side in ms
    public let messages: [chatMessage]
    public let metadata: conversationMetadata?
    public let profile: conversationProfileMini?
}

public struct conversationMetadata: Codable, Sendable {
    public let translate: Bool?
    public let hasSharedAlbums: Bool?
    public let isInAList: Bool?
}

public struct conversationProfileMini: Codable, Sendable {
    public let profileId: Int
    public let name: String?
    public let mediaHash: String?
    public let onlineUntil: Int64?
    public let distance: Double?
    public let showDistance: Bool?
}

public struct singleMessageResponse: Codable, Sendable {
    public let message: chatMessage
}

public struct chatMessage: Codable, Sendable, Identifiable {
    public let messageId: String // "<timestampMs>:<UUIDv4>"
    public let conversationId: conversationIdObject?
    public let senderId: Int
    public let timestamp: Int64 // ms
    public let unsent: Bool?
    public let reactions: [messageReaction]?
    public let type: messageType
    public let body: messageBody?
    public let replyToMessage: indirectMessage?
    public let dynamic: Bool?
    public let chat1Type: chat1MessageType?

    public var id: String { messageId }

    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
    }
}

// This is to allow decoding of the replyToMessage.
public final class indirectMessage: Codable, Sendable {
    public let value: chatMessage

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode(chatMessage.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}

public struct messageReaction: Codable, Sendable {
    public let profileId: Int
    public let reactionType: Int // 1 is 🔥
}

public struct messageBody: Codable, Sendable {
    // Text
    public let text: String?

    // Image / ExpiringImage / ChatImage / Audio / Video
    public let mediaId: Double?
    public let mediaHash: String?
    public let url: String?
    public let imageHash: String?
    public let width: Int?
    public let height: Int?
    public let takenOnGrindr: Bool?
    public let viewsRemaining: Double?
    public let contentType: String?
    public let length: Double? // ms for audio
    public let expiresAt: Int64?

    // Location
    public let lat: Double?
    public let lon: Double?

    // Album
    public let albumId: Int64?
    public let albumContentId: Int64?
    public let albumContentReply: String?
    public let coverUrl: String?
    public let previewUrl: String?
    public let ownerProfileId: Double?
    public let isViewable: Bool?

    // Giphy
    public let urlPath: String?
    public let stillPath: String?
    public let previewPath: String?

    // ProfilePhotoReply
    public let photoContentReply: String?

    // VideoCall
    public let result: String?
    public let videoCallDuration: Double?

    // Retract
    public let targetMessageId: String?

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func field<T: Decodable>(_ key: CodingKeys) -> T? {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? nil
        }
        text = field(.text)
        mediaId = field(.mediaId)
        mediaHash = field(.mediaHash)
        url = field(.url)
        imageHash = field(.imageHash)
        width = field(.width)
        height = field(.height)
        takenOnGrindr = field(.takenOnGrindr)
        viewsRemaining = field(.viewsRemaining)
        contentType = field(.contentType)
        length = field(.length)
        expiresAt = field(.expiresAt)
        lat = field(.lat)
        lon = field(.lon)
        albumId = field(.albumId)
        albumContentId = field(.albumContentId)
        albumContentReply = field(.albumContentReply)
        coverUrl = field(.coverUrl)
        previewUrl = field(.previewUrl)
        ownerProfileId = field(.ownerProfileId)
        isViewable = field(.isViewable)
        urlPath = field(.urlPath)
        stillPath = field(.stillPath)
        previewPath = field(.previewPath)
        photoContentReply = field(.photoContentReply)
        result = field(.result)
        videoCallDuration = field(.videoCallDuration)
        targetMessageId = field(.targetMessageId)
    }
}

public enum typingStatus: String, Codable, Sendable {
    case typing = "Typing"
    case cleared = "Cleared"
    case sent = "Sent"
}

// Profile ids come through as either strings or numbers depending on the event
public struct flexibleId: Codable, Sendable, Equatable {
    public let value: String

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self.value = string
        } else {
            self.value = String(try container.decode(Int64.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public func matches(_ id: Int) -> Bool {
        value == String(id)
    }
}

public struct conversationReadEvent: Codable, Sendable {
    public let conversationId: conversationIdObject
    public let profileId: flexibleId
    public let timestamp: Int64
}

public struct typingStatusEvent: Codable, Sendable {
    public let conversationId: conversationIdObject
    public let profileId: flexibleId
    public let status: typingStatus
}

public struct conversationIdsEvent: Codable, Sendable {
    public let conversationIds: [conversationIdObject]
}

public enum messageTargetType: String, Codable, Sendable {
    case direct = "Direct"
    case group = "Group"
    case humanWingman = "HumanWingman"
}

public struct messageTarget: Codable, Sendable {
    public let type: messageTargetType
    public let targetId: Int
}

public struct textMessageBody: Codable, Sendable {
    public let text: String
}

public struct sendTextMessageCommand: Codable, Sendable {
    public let type: messageType
    public let target: messageTarget
    public let body: textMessageBody
    public let replyToMessageId: String?
}
