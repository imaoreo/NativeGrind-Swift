//
//  chatCacheTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Chat Cache Tests")
struct chatCacheTests {
    private let pageJSON = """
    {
      "lastReadTimestamp": 1788915686135,
      "messages": [
        {
          "messageId": "1788013514870:34808256-95a2-4241-bce8-dce598a86aca",
          "conversationId": "771038429:905366700",
          "senderId": 905366700,
          "timestamp": 1788013514870,
          "unsent": false,
          "reactions": [{ "profileId": 771038429, "reactionType": 1 }],
          "type": "Text",
          "body": { "text": "Same" },
          "replyToMessage": {
            "messageId": "1788013460246:c85028ff-6a64-4e07-a4c3-94a9a04bcba2",
            "conversationId": "771038429:905366700",
            "senderId": 771038429,
            "timestamp": 1788013460246,
            "unsent": false,
            "reactions": [],
            "type": "Text",
            "body": { "text": "I havent met anyone for a while" },
            "replyToMessage": null,
            "dynamic": false,
            "chat1Type": "text",
            "replyPreview": null
          },
          "dynamic": false,
          "chat1Type": "text",
          "replyPreview": null
        },
        {
          "messageId": "1788013600000:5ce01a7d-83e9-4a4d-8ae5-c784c30d0b4d",
          "conversationId": "771038429:905366700",
          "senderId": 771038429,
          "timestamp": 1788013600000,
          "unsent": false,
          "reactions": [],
          "type": "Image",
          "body": { "mediaId": 123, "width": 1080, "height": 1920, "url": "https://example.com/a.jpg", "imageHash": "a1b2c3d4e5f6", "takenOnGrindr": null, "createdAt": null },
          "replyToMessage": null,
          "dynamic": false,
          "chat1Type": "image",
          "replyPreview": null
        }
      ],
      "metadata": null,
      "profile": null
    }
    """

    @Test("Messages survive the encode / decode round trip used by the offline cache")
    func testMessageRoundTrip() throws {
        let page = try JSONDecoder().decode(conversationMessagesResponse.self, from: Data(pageJSON.utf8))
        let cached = cachedConversation(messages: page.messages, lastReadTimestamp: page.lastReadTimestamp, profile: nil, savedAt: Date())

        let decoded = try JSONDecoder().decode(cachedConversation.self, from: JSONEncoder().encode(cached))

        #expect(decoded.messages.count == 2)
        #expect(decoded.lastReadTimestamp == 1788915686135)

        let reply = decoded.messages[0]
        #expect(reply.conversationId?.value == "771038429:905366700")
        #expect(reply.body?.text == "Same")
        #expect(reply.reactions?.first?.reactionType == 1)
        #expect(reply.replyToMessage?.value.body?.text == "I havent met anyone for a while")

        let image = decoded.messages[1]
        #expect(image.type == .image)
        #expect(image.body?.imageHash == "a1b2c3d4e5f6")
        #expect(image.body?.width == 1080)
    }

    @Test("Media hashes that could escape the cache folder are rejected", arguments: [
        ("a1b2c3d4e5f60718293a4b5c6d7e8f9012345678", true),
        ("abc_DEF-123", true),
        ("../../etc/passwd", false),
        ("abc/def12345", false),
        ("short", false),
        ("", false)
    ])
    func testHashValidation(hash: String, isValid: Bool) {
        #expect(chatMediaController.isValidHash(hash) == isValid)
    }

    @Test("Photos are cached by imageHash, falling back to the media id when there's no hash")
    func testPhotoCacheKey() throws {
        func message(_ body: String) throws -> chatMessage {
            try JSONDecoder().decode(chatMessage.self, from: Data("""
            { "messageId": "1:a", "conversationId": "1:2", "senderId": 1, "timestamp": 1, "type": "ExpiringImage", "body": \(body) }
            """.utf8))
        }

        #expect(try message(#"{ "imageHash": "a1b2c3d4e5f6", "mediaId": 42 }"#).photoCacheKey == "a1b2c3d4e5f6")
        #expect(try message(#"{ "mediaId": 987654321, "url": null, "viewsRemaining": 1 }"#).photoCacheKey == "media-987654321")
        #expect(try message(#"{ "imageHash": "../bad", "mediaId": 7 }"#).photoCacheKey == "media-7")
        #expect(try message("null").photoCacheKey == nil)

        #expect(chatMediaController.isValidHash("media-7") == false)
        #expect(chatMediaController.isValidHash("media-987654321"))
    }
}
