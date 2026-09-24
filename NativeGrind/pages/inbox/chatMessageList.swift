//
//  chatMessageList.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatMessageList: View {
    let store: chatStore
    let canReply: Bool
    let otherName: String

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if store.hasLoaded && store.hasMoreOlder && !store.messages.isEmpty {
                        ProgressView()
                            .padding(8)
                            .id("older-\(store.messages.first?.id ?? "")")
                            .onAppear {
                                Task { await store.loadOlder() }
                            }
                    }

                    if store.isLoading && store.messages.isEmpty {
                        ProgressView()
                            .padding(.top, 40)
                    } else if store.hasLoaded && store.messages.isEmpty {
                        Text("No messages yet")
                            .foregroundColor(.secondary)
                            .padding(.top, 40)
                    }

                    let messages = store.messages
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        let previous = index > 0 ? messages[index - 1] : nil
                        let next = index + 1 < messages.count ? messages[index + 1] : nil

                        if startsNewDay(message, after: previous) {
                            chatDateSeparator(date: message.date)
                                .id("date-\(message.id)")
                        }

                        chatBubble(
                            message: message,
                            isMine: store.isMine(message),
                            showTime: showsTime(message, before: next),
                            showRead: message.id == store.lastReadOwnMessageId,
                            isHighlighted: message.id == store.highlightedMessageId,
                            replyAuthor: replyAuthor(for: message),
                            onTapReply: {
                                guard let replyId = message.replyToMessage?.value.id else { return }
                                Task { await store.jump(to: replyId) }
                            }
                        )
                        .id(message.id)
                        .swipeToReply(isEnabled: canReply && message.unsent != true) {
                            store.startReply(to: message)
                        }
                        .contextMenu {
                            chatMessageMenu(message: message, store: store, canReply: canReply)
                        }
                    }

                    if store.isOtherTyping {
                        typingIndicator
                            .id("typing")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: store.messages.last?.id) { oldId, newId in
                guard let newId else { return }
                if oldId == nil {
                    proxy.scrollTo(newId, anchor: .bottom)
                } else {
                    withAnimation {
                        proxy.scrollTo(newId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: store.messages.first?.id) { _, _ in
                guard let anchor = store.consumeOlderPageAnchor() else { return }
                proxy.scrollTo(anchor, anchor: .top)
            }
            .onChange(of: store.jumpTargetId) { _, _ in
                guard let target = store.consumeJumpTarget() else { return }
                withAnimation {
                    proxy.scrollTo(target, anchor: .center)
                }
            }
            .onChange(of: store.isOtherTyping) { _, typing in
                guard typing else { return }
                withAnimation {
                    proxy.scrollTo("typing", anchor: .bottom)
                }
            }
        }
    }

    private static let timeGroupingMs: Int64 = 15 * 60 * 1000

    private func startsNewDay(_ message: chatMessage, after previous: chatMessage?) -> Bool {
        guard let previous else { return true }
        return !Calendar.current.isDate(message.date, inSameDayAs: previous.date)
    }

    /// Messages within 15 minutes of the next one only show the newest time
    private func showsTime(_ message: chatMessage, before next: chatMessage?) -> Bool {
        guard let next else { return true }
        return next.timestamp - message.timestamp > Self.timeGroupingMs || startsNewDay(next, after: message)
    }

    private func replyAuthor(for message: chatMessage) -> String {
        guard let reply = message.replyToMessage?.value else { return "" }
        return store.isMine(reply) ? "You" : otherName
    }

    private var typingIndicator: some View {
        HStack {
            Text("typing…")
                .font(.caption)
                .italic()
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.15), in: Capsule())
            Spacer()
        }
    }
}
