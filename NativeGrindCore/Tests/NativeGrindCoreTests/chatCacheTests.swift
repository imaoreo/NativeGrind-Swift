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

    @Test("Videos Grindr limits to a number of views are recognised")
    func viewLimitedVideos() throws {
        func video(_ body: String) throws -> chatMessage {
            try JSONDecoder().decode(chatMessage.self, from: Data("""
            { "messageId": "1:a", "conversationId": "1:2", "senderId": 1, "timestamp": 1, "type": "Video", "body": \(body) }
            """.utf8))
        }

        let usedUp = try video(#"{ "mediaId": null, "url": null, "contentType": null, "length": 0, "viewsRemaining": 0, "expiresAt": null, "maxViews": 1, "looping": false }"#)
        #expect(usedUp.isViewLimitedVideo)
        #expect(usedUp.body?.viewsRemaining == 0)

        #expect(try video(#"{ "mediaId": 5, "maxViews": 2147483647, "looping": false }"#).isViewLimitedVideo == false)
        #expect(try video(#"{ "mediaId": 5 }"#).isViewLimitedVideo == false)
    }

    @Test("Photos are cached by imageHash, falling back to the media id when there's no hash")
    func testPhotoCacheKey() throws {
        func message(_ body: String) throws -> chatMessage {
            try JSONDecoder().decode(chatMessage.self, from: Data("""
            { "messageId": "1:a", "conversationId": "1:2", "senderId": 1, "timestamp": 1, "type": "ExpiringImage", "body": \(body) }
            """.utf8))
        }

        #expect(try message(#"{ "imageHash": "a1b2c3d4e5f6", "mediaId": 42 }"#).mediaCacheKey == "vegek4S3hI5XlR7DLHNERZIzI1v6UZ1zlq40BgFKBvQ")
        #expect(try message(#"{ "mediaId": 987654321, "url": null, "viewsRemaining": 1 }"#).mediaCacheKey == "beMSaWr3XWqqhnCJzvWsLlQjCTIQta3awhRVuUpQY9o")
        #expect(try message(#"{ "imageHash": "../bad", "mediaId": 7 }"#).mediaCacheKey == "I8h_x2a8pLyyLApV5AN3NkI8DuYMDhdcagQwb5Fpxh0")
        #expect(try message(#"{ "mediaHash": "v1d3ohash99", "mediaId": 5, "contentType": "video/mp4" }"#).mediaCacheKey == "XVqJQm1gcxZq4QqyHdq4ULH-JE2ds2QOe7p4-TYkjeo")
        #expect(try message("null").mediaCacheKey == nil)

        #expect(chatMediaController.isValidHash("media-7") == false)
        #expect(chatMediaController.isValidHash("media-987654321"))
    }

    @Test("Hex and base64url forms of the same hash give the same key, so a video is found under one name everywhere")
    func testHashNormalizing() throws {
        let hex = "3dbd3027c9fda69936c6be361cd8357482689679eaacc107c76d35703f4e4589"
        let base64url = "Pb0wJ8n9ppk2xr42HNg1dIJolnnqrMEHx201cD9ORYk"
        #expect(chatMediaController.normalizeHash(hex) == base64url)
        #expect(chatMediaController.normalizeHash(base64url) == base64url)
        #expect(chatMediaController.cacheKey(from: try #require(URL(string: "https://cdn.example/919781182/\(hex)?Expires=1"))) == base64url)
        #expect(chatMediaController.cacheKey(from: try #require(URL(string: "https://cdn.example/a/b.mp4"))) == nil)

        func video(_ body: String) throws -> chatMessage {
            try JSONDecoder().decode(chatMessage.self, from: Data("""
            { "messageId": "1:a", "conversationId": "1:2", "senderId": 1, "timestamp": 1, "type": "Video", "body": \(body) }
            """.utf8))
        }
        let opened = try video(#"{ "mediaId": 919781182, "url": "https://cdn.example/919781182/3dbd3027c9fda69936c6be361cd8357482689679eaacc107c76d35703f4e4589?Expires=1", "maxViews": 1, "viewsRemaining": 0 }"#)
        #expect(opened.mediaCacheKey == base64url)
    }
}
