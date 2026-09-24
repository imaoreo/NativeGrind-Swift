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

    public func load(conversationId: String) -> cachedConversation? {
        guard let url = fileURL(for: conversationId),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(cachedConversation.self, from: data)
    }

    public func save(conversationId: String, messages: [chatMessage], lastReadTimestamp: Int64?, profile: conversationProfileMini?) {
        guard !appEnvironment.isTesting, let url = fileURL(for: conversationId) else { return }

        let conversation = cachedConversation(
            messages: Array(messages.suffix(Self.maxMessages)),
            lastReadTimestamp: lastReadTimestamp,
            profile: profile,
            savedAt: Date()
        )

        guard let data = try? JSONEncoder().encode(conversation) else { return }
        try? data.write(to: url, options: [.atomic, .completeFileProtection])
    }

    public func remove(conversationId: String) {
        guard let url = fileURL(for: conversationId) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    public func clearAll() {
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }

    private var directory: URL? {
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let directory = support.appendingPathComponent("chats", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func fileURL(for conversationId: String) -> URL? {
        guard conversationId.wholeMatch(of: /^[0-9]+:[0-9]+$/) != nil else { return nil }
        return directory?.appendingPathComponent(conversationId.replacingOccurrences(of: ":", with: "_") + ".json")
    }
}
