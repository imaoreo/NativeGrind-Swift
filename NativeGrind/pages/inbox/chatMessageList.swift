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
                            showRead: message.id == store.lastReadOwnMessageId
                        )
                        .id(message.id)
                        .contextMenu {
                            chatMessageMenu(message: message, store: store)
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
            .onChange(of: store.messages.last?.id) { _, newId in
                guard let newId else { return }
                withAnimation {
                    proxy.scrollTo(newId, anchor: .bottom)
                }
            }
            .onChange(of: store.messages.first?.id) { _, _ in
                guard let anchor = store.consumeOlderPageAnchor() else { return }
                proxy.scrollTo(anchor, anchor: .top)
            }
            .onChange(of: store.isOtherTyping) { _, typing in
                guard typing else { return }
                withAnimation {
                    proxy.scrollTo("typing", anchor: .bottom)
                }
            }
        }
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
