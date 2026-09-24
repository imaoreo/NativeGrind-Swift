//
//  chatStore.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import CoreLocation
import NativeGrindCore

@MainActor
@Observable
final class chatStore {
    let conversationId: String
    let otherProfileId: Int

    private(set) var messages: [chatMessage] = []
    private(set) var lastReadTimestamp: Int64? = nil
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var hasMoreOlder = true
    private(set) var isSending = false
    private(set) var isOtherTyping = false
    private(set) var replyingTo: chatMessage? = nil
    private(set) var otherProfile: conversationProfileMini? = nil
    private(set) var jumpTargetId: String? = nil
    private(set) var highlightedMessageId: String? = nil

    private(set) var olderPageAnchorId: String? = nil

    private var isLoadingOlder = false
    @ObservationIgnored private let locationManager = deviceLocationManager()
    private var lastMarkedReadId: String? = nil

    init(conversationId: String, otherProfileId: Int) {
        self.conversationId = conversationId
        self.otherProfileId = otherProfileId
    }

    func isMine(_ message: chatMessage) -> Bool {
        message.senderId != otherProfileId
    }

    var lastReadOwnMessageId: String? {
        guard let lastReadTimestamp else { return nil }
        return messages.last { isMine($0) && $0.timestamp <= lastReadTimestamp }?.id
    }

    func consumeOlderPageAnchor() -> String? {
        defer { olderPageAnchorId = nil }
        return olderPageAnchorId
    }

    private func merge(_ incoming: [chatMessage]) {
        var byId = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        for message in incoming {
            byId[message.id] = message
        }
        messages = byId.values.sorted { $0.timestamp < $1.timestamp }
    }

    private func replace(_ message: chatMessage) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = message
        }
    }

    func receive(_ message: chatMessage) {
        guard message.conversationId?.value == conversationId else { return }
        if !isMine(message) {
            isOtherTyping = false
        }
        merge([message])
        Task { await markReadIfNeeded() }
    }

    func receive(_ event: conversationReadEvent) {
        guard event.conversationId.value == conversationId, event.profileId.matches(otherProfileId) else { return }
        lastReadTimestamp = max(lastReadTimestamp ?? 0, event.timestamp)
    }

    func receive(_ event: typingStatusEvent) {
        guard event.conversationId.value == conversationId, event.profileId.matches(otherProfileId) else { return }
        isOtherTyping = event.status == .typing
    }

    func loadInitial() async {
        guard !hasLoaded else { return }
        isLoading = true
        defer {
            isLoading = false
            hasLoaded = true
        }

        // profile=true also returns their name and photo hash for the header
        guard let page = await conversationController.shared.fetchMessages(conversationId: conversationId, includeProfile: true) else {
            return
        }

        merge(page.messages)
        lastReadTimestamp = page.lastReadTimestamp
        hasMoreOlder = page.hasMore
        otherProfile = page.profile
        await markReadIfNeeded()
    }

    func refreshLatest() async {
        guard let page = await conversationController.shared.fetchMessages(conversationId: conversationId) else {
            return
        }

        merge(page.messages)
        lastReadTimestamp = page.lastReadTimestamp
        await markReadIfNeeded()
    }

    /// Returns false if nothing was loaded (already loading or no more pages)
    @discardableResult
    func loadOlder(keepPosition: Bool = true) async -> Bool {
        guard !isLoadingOlder, hasMoreOlder, let pageKey = messages.first?.id else { return false }
        isLoadingOlder = true
        defer { isLoadingOlder = false }

        guard let page = await conversationController.shared.fetchMessages(conversationId: conversationId, before: pageKey) else {
            hasMoreOlder = false
            return false
        }

        let known = Set(messages.map(\.id))
        let fresh = page.messages.filter { !known.contains($0.id) }
        hasMoreOlder = !fresh.isEmpty
        if !fresh.isEmpty && keepPosition {
            olderPageAnchorId = pageKey
        }
        merge(fresh)
        return !fresh.isEmpty
    }

    private static let maxJumpPages = 10

    func jump(to messageId: String) async {
        var pagesLoaded = 0
        while !messages.contains(where: { $0.id == messageId }), hasMoreOlder, pagesLoaded < Self.maxJumpPages {
            if await loadOlder(keepPosition: false) {
                pagesLoaded += 1
            } else if isLoadingOlder {
                try? await Task.sleep(for: .milliseconds(100))
            } else {
                break
            }
        }

        guard messages.contains(where: { $0.id == messageId }) else {
            toastManager.shared.show(style: .warn, header: "Reply", message: "Couldn't find the original message")
            return
        }

        jumpTargetId = messageId
        highlightedMessageId = messageId

        try? await Task.sleep(for: .seconds(1.5))
        if highlightedMessageId == messageId {
            highlightedMessageId = nil
        }
    }

    func consumeJumpTarget() -> String? {
        defer { jumpTargetId = nil }
        return jumpTargetId
    }

    private func markReadIfNeeded() async {
        guard let newest = messages.last(where: { !isMine($0) }), newest.id != lastMarkedReadId else { return }
        if await conversationController.shared.markRead(conversationId: conversationId, messageId: newest.id) {
            lastMarkedReadId = newest.id
        }
    }

    func startReply(to message: chatMessage) {
        replyingTo = message
    }

    func cancelReply() {
        replyingTo = nil
    }

    func send(_ text: String) async -> Bool {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return false }
        isSending = true
        defer { isSending = false }

        let sent: chatMessage?
        if let replyingTo {
            sent = await conversationController.shared.sendReply(text, to: otherProfileId, replyingTo: replyingTo.id)
        } else {
            sent = await conversationController.shared.sendText(text, to: otherProfileId)
        }

        guard let sent else { return false }
        replyingTo = nil
        merge([sent])
        return true
    }

    func sendCurrentLocation() async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        let location: CLLocation
        do {
            location = try await locationManager.getCurrentLocation()
        } catch {
            toastManager.shared.show(style: .warn, header: "Location", message: "Couldn't get your location, check location access in Settings")
            return
        }

        if let sent = await conversationController.shared.sendLocation(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            to: otherProfileId
        ) {
            merge([sent])
        }
    }

    func sendAudio(_ data: Data, contentType: String, lengthMs: Int64) async {
        guard !isSending else { return }
        isSending = true
        defer { isSending = false }

        if let sent = await conversationController.shared.sendAudio(data, contentType: contentType, lengthMs: lengthMs, to: otherProfileId) {
            merge([sent])
        }
    }

    func setTyping(_ typing: Bool) async {
        await conversationController.shared.setTyping(conversationId: conversationId, typing ? .typing : .cleared)
    }

    func react(to message: chatMessage) async {
        if await conversationController.shared.react(conversationId: conversationId, messageId: message.id) {
            await refetch(message)
        }
    }

    func unsend(_ message: chatMessage) async {
        if await conversationController.shared.unsend(conversationId: conversationId, messageId: message.id) {
            await refetch(message)
        }
    }

    func delete(_ message: chatMessage) async {
        if await conversationController.shared.delete(conversationId: conversationId, messageId: message.id) {
            messages.removeAll { $0.id == message.id }
        }
    }

    func mediaURL(for message: chatMessage) async -> URL? {
        func link(_ message: chatMessage) -> URL? {
            (message.body?.url ?? message.body?.urlPath).flatMap(URL.init(string:))
        }

        let latest = messages.first { $0.id == message.id } ?? message
        let expiresAt = latest.body?.expiresAt.map { TimeInterval($0) / 1000 } ?? 0
        let isExpired = expiresAt > 0 && expiresAt < Date().timeIntervalSince1970 + 30

        if link(latest) == nil || isExpired {
            guard latest.type != .expiringImage,
                  let fresh = await conversationController.shared.fetchMessage(conversationId: conversationId, messageId: message.id) else {
                return nil
            }
            replace(fresh)
            return link(fresh)
        }

        return link(latest)
    }

    private func refetch(_ message: chatMessage) async {
        if let updated = await conversationController.shared.fetchMessage(conversationId: conversationId, messageId: message.id) {
            replace(updated)
        }
    }
}
