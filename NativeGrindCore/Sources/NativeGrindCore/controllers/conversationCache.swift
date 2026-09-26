//
//  conversationCache.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Foundation

public struct cachedConversation: Codable, Sendable {
    public let messages: [chatMessage] // oldest first
    public let lastReadTimestamp: Int64?
    public let profile: conversationProfileMini?
    public let savedAt: Date
}

public actor conversationCache {
    public static let shared = conversationCache()

    public static let maxMessages = 300

    private let store: localStore

    public init(store: localStore = .shared) {
        self.store = store
    }

    public func load(conversationId: String) async -> cachedConversation? {
        guard let key = storeKey(for: conversationId) else { return nil }
        return await store.read(cachedConversation.self, from: .conversations, key: key)
    }

    public func save(conversationId: String, messages: [chatMessage], lastReadTimestamp: Int64?, profile: conversationProfileMini?) async {
        guard !appEnvironment.isTesting, let key = storeKey(for: conversationId) else { return }

        let conversation = cachedConversation(
            messages: Array(messages.suffix(Self.maxMessages)),
            lastReadTimestamp: lastReadTimestamp,
            profile: profile,
            savedAt: Date()
        )

        try? await store.write(conversation, to: .conversations, key: key)
    }

    public func remove(conversationId: String) async {
        guard let key = storeKey(for: conversationId) else { return }
        await store.delete(from: .conversations, key: key)
    }

    public func clearAll() async {
        await store.clear(.conversations)
    }

    public func mergeRemote(key: String, remote: cachedConversation) async {
        guard let local = await store.read(cachedConversation.self, from: .conversations, key: key) else {
            try? await store.write(remote, to: .conversations, key: key, recordChange: false)
            return
        }

        let (older, newer) = remote.savedAt > local.savedAt ? (local, remote) : (remote, local)

        var byId = Dictionary(older.messages.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for message in newer.messages {
            var updated = message
            if let old = byId[message.id] {
                updated = updated.preservingMediaKeys(from: old)
            }
            byId[message.id] = updated
        }

        let merged = cachedConversation(
            messages: Array(byId.values.sorted { $0.timestamp < $1.timestamp }.suffix(Self.maxMessages)),
            lastReadTimestamp: [local.lastReadTimestamp, remote.lastReadTimestamp].compactMap { $0 }.max(),
            profile: newer.profile ?? older.profile,
            savedAt: newer.savedAt
        )

        try? await store.write(merged, to: .conversations, key: key, recordChange: false)
    }

    public func removeRemote(key: String, deletedAt: Date) async {
        if let local = await store.read(cachedConversation.self, from: .conversations, key: key), local.savedAt > deletedAt {
            return
        }
        await store.delete(from: .conversations, key: key, recordChange: false)
    }

    private func storeKey(for conversationId: String) -> String? {
        guard conversationId.wholeMatch(of: /^[0-9]+:[0-9]+$/) != nil else { return nil }
        return conversationId.replacingOccurrences(of: ":", with: "_")
    }
}
