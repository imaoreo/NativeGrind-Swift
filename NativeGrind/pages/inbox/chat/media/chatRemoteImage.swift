//
//  chatRemoteImage.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

extension EnvironmentValues {
    @Entry var loadChatImage: @MainActor (chatMessage) async -> Data? = { _ in nil }
}

struct chatRemoteImage: View {
    let message: chatMessage
    let size: CGSize

    @Environment(\.loadChatImage) private var loadImage

    @State private var image: Image? = nil
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if failed {
                Image(systemName: "photo")
            } else {
                ProgressView()
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task(id: message.id) {
            guard image == nil else { return }
            guard let data = await loadImage(message), let platformImage = PlatformImage(data: data) else {
                failed = true
                return
            }
            #if canImport(UIKit)
            image = Image(uiImage: platformImage)
            #elseif canImport(AppKit)
            image = Image(nsImage: platformImage)
            #endif
        }
    }
}
