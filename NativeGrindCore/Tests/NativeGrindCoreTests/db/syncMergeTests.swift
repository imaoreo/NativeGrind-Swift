//
//  syncMergeTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Sync Merge Tests", .serialized)
struct syncMergeTests {

    private func makeStore() -> localStore {
        localStore(root: FileManager.default.temporaryDirectory.appendingPathComponent("syncMergeTests-\(UUID().uuidString)", isDirectory: true))
    }

    private func message(_ id: String, at timestamp: Int64, text: String) throws -> chatMessage {
        let json = """
        { "messageId": "\(id)", "conversationId": "1:2", "senderId": 1, "timestamp": \(timestamp),
          "unsent": false, "reactions": [], "type": "Text", "body": { "text": "\(text)" },
          "replyToMessage": null, "dynamic": false, "chat1Type": "text" }
        """
        return try JSONDecoder().decode(chatMessage.self, from: Data(json.utf8))
    }

    @Test("Pulled data is saved without being queued to push straight back")
    func testRemoteWritesArentQueued() async throws {
        let store = makeStore()
        let cache = conversationCache(store: store)
        let remote = cachedConversation(messages: [try message("a", at: 1, text: "hi")], lastReadTimestamp: nil, profile: nil, savedAt: Date())

        await cache.mergeRemote(key: "1_2", remote: remote)

        #expect(await store.read(cachedConversation.self, from: .conversations, key: "1_2")?.messages.count == 1)
        #expect(await store.pendingChanges().isEmpty)
    }

    @Test("Merging keeps messages from both devices and the newer copy wins on conflicts")
    func testMergeCombinesMessages() async throws {
        let store = makeStore()
        let cache = conversationCache(store: store)

        let local = cachedConversation(
            messages: [try message("a", at: 1, text: "old edit"), try message("b", at: 2, text: "only here")],
            lastReadTimestamp: 5, profile: nil, savedAt: Date(timeIntervalSince1970: 100)
        )
        try await store.write(local, to: .conversations, key: "1_2")

        let remote = cachedConversation(
            messages: [try message("a", at: 1, text: "new edit"), try message("c", at: 3, text: "only there")],
            lastReadTimestamp: 9, profile: nil, savedAt: Date(timeIntervalSince1970: 200)
        )
        await cache.mergeRemote(key: "1_2", remote: remote)

        let merged = try #require(await store.read(cachedConversation.self, from: .conversations, key: "1_2"))
        #expect(merged.messages.map(\.id) == ["a", "b", "c"])
        #expect(merged.messages.first?.body?.text == "new edit")
        #expect(merged.lastReadTimestamp == 9)

        // The local change is still waiting to be pushed, now with the merged messages
        #expect(await store.pendingChanges().map(\.key) == ["1_2"])
    }

    @Test("A delete from another device only wins if nothing changed here afterwards")
    func testRemoteDelete() async throws {
        let store = makeStore()
        let cache = conversationCache(store: store)
        let saved = cachedConversation(messages: [], lastReadTimestamp: nil, profile: nil, savedAt: Date(timeIntervalSince1970: 100))
        try await store.write(saved, to: .conversations, key: "1_2")

        await cache.removeRemote(key: "1_2", deletedAt: Date(timeIntervalSince1970: 50))
        #expect(await store.keys(in: .conversations) == ["1_2"])

        await cache.removeRemote(key: "1_2", deletedAt: Date(timeIntervalSince1970: 150))
        #expect(await store.keys(in: .conversations).isEmpty)
    }

    @Test("Sync identifiers are stable per account key and don't reveal the conversation id")
    func testSyncIdentifier() throws {
        keychainManager.shared.saveToken(cryptoController.shared.generateAccountKey(), type: .accountKey)
        defer { keychainManager.shared.deleteToken(type: .accountKey) }

        let first = try cryptoController.shared.syncIdentifier(for: "conversations/771038429_905366700")
        let again = try cryptoController.shared.syncIdentifier(for: "conversations/771038429_905366700")
        let other = try cryptoController.shared.syncIdentifier(for: "conversations/1_2")

        #expect(first == again)
        #expect(first != other)
        #expect(!first.contains("771038429"))
        #expect(first.wholeMatch(of: /^[A-Za-z0-9_-]{43}$/) != nil) // matches NativeServer's location rule

        keychainManager.shared.saveToken(cryptoController.shared.generateAccountKey(), type: .accountKey)
        #expect(try cryptoController.shared.syncIdentifier(for: "conversations/771038429_905366700") != first)
    }
}
