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

            case .image:
                if Self.hasViewableImage(message) {
                    chatRemoteImage(message: message, size: imageSize(width: body?.width, height: body?.height))
                        .onTapGesture { openPhoto(message) }
                } else {
                    Text("📷 Photo")
                }

            case .expiringImage:
                chatExpiringImage(message: message, size: imageSize(width: body?.width, height: body?.height))

            case .giphy:
                if body?.urlPath != nil || body?.stillPath != nil {
                    chatRemoteImage(message: message, size: imageSize(width: body?.width, height: body?.height))
                        .onTapGesture { openPhoto(message) }
                } else {
                    Text("GIF")
                }

            case .audio:
                chatAudioBubble(message: message, isMine: isMine)

            case .video, .privateVideo, .nonExpiringVideo:
                chatVideoBubble(message: message, size: imageSize(width: body?.width, height: body?.height))

            case .album, .expiringAlbum, .expiringAlbumV2:
                if body?.albumId != nil {
                    chatAlbumBubble(message: message)
                } else {
                    Text(message.summaryText)
                }

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
            return chatImageSizes.known[message.id] ?? Self.fallbackImageSize
        }
        return Self.fittedSize(CGSize(width: width, height: height))
    }
    static func fittedSize(_ natural: CGSize) -> CGSize {
        guard natural.width > 0, natural.height > 0 else { return fallbackImageSize }
        let scale = min(maxImageSize.width / natural.width, maxImageSize.height / natural.height)
        return CGSize(width: natural.width * scale, height: natural.height * scale)
    }

    private static func hasViewableImage(_ message: chatMessage) -> Bool {
        message.body?.url != nil || message.mediaCacheKey != nil
    }

    static func isBareMedia(_ message: chatMessage) -> Bool {
        guard message.unsent != true else { return false }
        let body = message.body

        switch message.type {
        case .image:
            return hasViewableImage(message)
        case .expiringImage, .video, .privateVideo, .nonExpiringVideo:
            return true
        case .giphy:
            return body?.urlPath != nil || body?.stillPath != nil
        case .location:
            return body?.lat != nil && body?.lon != nil
        case .album, .expiringAlbum, .expiringAlbumV2:
            return body?.albumId != nil
        default:
            return false
        }
    }
}

@MainActor
enum chatImageSizes {
    static var known: [String: CGSize] = [:]

    static func remember(_ image: PlatformImage, for messageId: String) -> CGSize {
        let fitted = chatBubbleContent.fittedSize(image.size)
        known[messageId] = fitted
        return fitted
    }
}
