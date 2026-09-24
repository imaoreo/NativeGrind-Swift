//
//  chatComposer.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatComposer: View {
    @Binding var draft: String
    let isSending: Bool
    let replyingTo: chatMessage?
    let onCancelReply: () -> Void
    let onSend: () -> Void

    private var canSend: Bool {
        !isSending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 6) {
            if let replyingTo {
                replyBanner(for: replyingTo)
            }
            inputRow
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func replyBanner(for message: chatMessage) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.blue)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(message.summaryText)
                    .font(.caption)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onCancelReply) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 32)
    }

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                #if !os(tvOS)
                .textFieldStyle(.roundedBorder)
                #endif
                .onSubmit {
                    if canSend { onSend() }
                }

            Button(action: onSend) {
                if isSending {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)
            .disabled(!canSend)
        }
    }
}
