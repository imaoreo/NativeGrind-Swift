//
//  chatReplyPreview.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatReplyPreview: View {
    let reply: chatMessage
    let author: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.secondary.opacity(0.6))
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 1) {
                    Text(author)
                        .font(.caption2.bold())
                    Text(reply.summaryText)
                        .font(.caption)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .foregroundColor(.secondary)
    }
}
