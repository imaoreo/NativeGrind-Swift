//
//  conversationController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Foundation

public struct conversationPage: Sendable {
    public let messages: [chatMessage]
    public let lastReadTimestamp: Int64?
    public let profile: conversationProfileMini?
    public let hasMore: Bool

    public var olderPageKey: String? {
        messages.first?.messageId
    }
}

public actor conversationController {
    public static let shared = conversationController()

    private func run<T: Decodable & Sendable>(_ endpoint: sending endpoint<T>, _ action: String, shouldErrorMessage: Bool = true) async -> T? {
        do {
            return try await APIClient.shared.request(endpoint, shouldErrorMessage: shouldErrorMessage)
        } catch {
            if (error as? requestError) != .networkError {
                await errorManager.shared.warn("conversationController", "Failed to \(action): \(error)")
            }
            return nil
        }
    }

    public static func conversationId(between a: Int, and b: Int) -> String {
        "\(min(a, b)):\(max(a, b))"
    }

    public static func ownProfileId(conversationId: String, otherProfileId: Int) -> Int? {
        let ids = conversationId.split(separator: ":").compactMap { Int($0) }
        guard ids.count == 2 else { return nil }
        return ids.first { $0 != otherProfileId } ?? ids.first
    }

    public func fetchMessages(conversationId: String, before pageKey: String? = nil, includeProfile: Bool = false) async -> conversationPage? {
        guard let response = await run(
            .getMessages(conversationId: conversationId, pageKey: pageKey, includeProfile: includeProfile),
            "fetch messages"
        ) else {
            return nil
        }

        let sorted = response.messages.sorted { $0.timestamp < $1.timestamp }

        return conversationPage(
            messages: sorted,
            lastReadTimestamp: response.lastReadTimestamp,
            profile: response.profile,
            hasMore: !sorted.isEmpty
        )
    }

    public func fetchMessage(conversationId: String, messageId: String) async -> chatMessage? {
        await run(.getMessage(conversationId: conversationId, messageId: messageId), "fetch message")?.message
    }

    public func sendText(_ text: String, to profileId: Int) async -> chatMessage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return await run(.sendTextMessage(targetProfileId: profileId, text: trimmed), "send message")
    }

    @discardableResult
    public func markRead(conversationId: String, messageId: String) async -> Bool {
        await run(.markConversationRead(conversationId: conversationId, messageId: messageId), "mark read", shouldErrorMessage: false) != nil
    }

    @discardableResult
    public func unsend(conversationId: String, messageId: String) async -> Bool {
        await run(.unsendMessage(conversationId: conversationId, messageId: messageId), "unsend message") != nil
    }

    @discardableResult
    public func delete(conversationId: String, messageId: String) async -> Bool {
        await run(.deleteMessage(conversationId: conversationId, messageId: messageId), "delete message") != nil
    }

    @discardableResult
    public func react(conversationId: String, messageId: String, reactionType: Int = 1) async -> Bool {
        await run(.reactToMessage(conversationId: conversationId, messageId: messageId, reactionType: reactionType), "react to message") != nil
    }

    public func setTyping(conversationId: String, _ status: typingStatus) async {
        _ = await run(.sendTypingStatus(conversationId: conversationId, status: status), "send typing status", shouldErrorMessage: false)
    }

    @discardableResult
    public func setPinned(conversationId: String, pinned: Bool) async -> Bool {
        await run(.pinConversation(conversationId: conversationId, pinned: pinned), pinned ? "pin conversation" : "unpin conversation") != nil
    }

    @discardableResult
    public func deleteConversation(conversationId: String) async -> Bool {
        await run(.deleteConversation(conversationId: conversationId), "delete conversation") != nil
    }
}
