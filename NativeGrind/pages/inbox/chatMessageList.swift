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

                    ForEach(store.messages) { message in
                        chatBubble(
                            message: message,
                            isMine: store.isMine(message),
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
