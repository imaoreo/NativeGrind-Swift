//
//  chatBubble.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatBubble: View {
    let message: chatMessage
    let isMine: Bool
    let showRead: Bool
    var isHighlighted: Bool = false
    var replyAuthor: String = ""
    var onTapReply: (() -> Void)? = nil

    private var hasReactions: Bool {
        !(message.reactions?.isEmpty ?? true)
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if let reply = message.replyToMessage?.value {
                    chatReplyPreview(reply: reply, author: replyAuthor) {
                        onTapReply?()
                    }
                }

                chatBubbleContent(message: message, isMine: isMine)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isMine ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(isMine ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(alignment: isMine ? .bottomLeading : .bottomTrailing) {
                        if let reactions = message.reactions, !reactions.isEmpty {
                            Text(String(repeating: "🔥", count: min(reactions.count, 3)))
                                .font(.caption)
                                .padding(4)
                                .background(.thinMaterial, in: Capsule())
                                .offset(x: isMine ? -8 : 8, y: 10)
                        }
                    }

                HStack(spacing: 4) {
                    Text(message.date, style: .time)
                    if showRead {
                        Text("· Read")
                    }
                }
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .padding(.top, hasReactions ? 8 : 0)
            }

            if !isMine { Spacer(minLength: 48) }
        }
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(isHighlighted ? 0.18 : 0))
        )
        .animation(.easeInOut(duration: 0.3), value: isHighlighted)
    }
}
