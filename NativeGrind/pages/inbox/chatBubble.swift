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

    private var hasReactions: Bool {
        !(message.reactions?.isEmpty ?? true)
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 48) }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                if let reply = message.replyToMessage?.value {
                    Text(reply.summaryText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .padding(.horizontal, 8)
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
    }
}
