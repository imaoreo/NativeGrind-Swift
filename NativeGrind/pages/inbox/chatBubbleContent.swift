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
                if let urlString = body?.url, let url = URL(string: urlString) {
                    remoteImage(url: url)
                } else {
                    Text(message.type == .expiringImage ? "📷 Expiring Photo" : "📷 Photo")
                }

            case .giphy:
                if let urlString = body?.urlPath ?? body?.stillPath, let url = URL(string: urlString) {
                    remoteImage(url: url)
                } else {
                    Text("GIF")
                }

            case .location:
                if let lat = body?.lat, let lon = body?.lon,
                   let url = URL(string: "https://maps.apple.com/?ll=\(lat),\(lon)") {
                    Link("📍 Location", destination: url)
                        .foregroundColor(isMine ? .white : .blue)
                } else {
                    Text("📍 Location")
                }

            default:
                Text(message.summaryText)
            }
        }
    }

    private func remoteImage(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                Image(systemName: "photo")
                    .frame(width: 60, height: 60)
            default:
                ProgressView()
                    .frame(width: 60, height: 60)
            }
        }
        .frame(maxWidth: 220, maxHeight: 280)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
