//
//  chatBubbleContent.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatBubbleContent: View {
    let message: chatMessage
    let isMine: Bool

    @Environment(\.openChatPhoto) private var openPhoto

    var body: some View {
        let body = message.body

        if message.unsent == true {
            Text("This message was unsent")
                .italic()
        } else {
            switch message.type {
            case .text:
                Text(body?.text ?? "")
                    #if !os(tvOS)
                    .textSelection(.enabled)
                    #endif

            case .image, .expiringImage:
                if hasViewableImage {
                    chatRemoteImage(message: message, size: imageSize(width: body?.width, height: body?.height))
                        .onTapGesture {
                            if message.type == .image { openPhoto(message) }
                        }
                } else {
                    Text(message.type == .expiringImage ? "📷 Expiring Photo" : "📷 Photo")
                }

            case .giphy:
                if body?.urlPath != nil || body?.stillPath != nil {
                    chatRemoteImage(message: message, size: imageSize(width: body?.width, height: body?.height))
                        .onTapGesture { openPhoto(message) }
                } else {
                    Text("GIF")
                }

            case .audio:
                chatAudioBubble(message: message, isMine: isMine)

            case .location:
                if let lat = body?.lat, let lon = body?.lon {
                    chatLocationBubble(latitude: lat, longitude: lon)
                } else {
                    Text("📍 Location")
                }

            default:
                Text(message.summaryText)
            }
        }
    }

    private static let maxImageSize = CGSize(width: 220, height: 280)
    private static let fallbackImageSize = CGSize(width: 200, height: 200)

    private func imageSize(width: Int?, height: Int?) -> CGSize {
        guard let width, let height, width > 0, height > 0 else {
            return Self.fallbackImageSize
        }
        let scale = min(Self.maxImageSize.width / CGFloat(width), Self.maxImageSize.height / CGFloat(height))
        return CGSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
    }

    private var hasViewableImage: Bool {
        if message.body?.url != nil { return true }
        return message.type == .image && !(message.body?.imageHash ?? "").isEmpty
    }
}
