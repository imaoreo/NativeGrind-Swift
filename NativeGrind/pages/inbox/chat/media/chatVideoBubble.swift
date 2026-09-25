//
//  chatVideoBubble.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import AVFoundation
import NativeGrindCore

extension EnvironmentValues {
    @Entry var openChatVideo: @MainActor (chatMessage) -> Void = { _ in }
    @Entry var loadChatVideo: @MainActor (chatMessage) async -> URL? = { _ in nil }
}

struct chatVideoBubble: View {
    let message: chatMessage
    let size: CGSize

    @Environment(\.openChatVideo) private var openVideo
    @Environment(\.loadChatVideo) private var loadVideo

    @State private var thumbnail: Image? = nil

    private var duration: String? {
        guard let length = message.body?.length, length > 0 else { return nil }
        let seconds = Int((length / 1000).rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)

            if let thumbnail {
                thumbnail
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }

            Image(systemName: "play.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.white, .black.opacity(0.4))
        }
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 4) {
                Image(systemName: message.type == .privateVideo ? "eye" : "video.fill")
                if let duration {
                    Text(duration).monospacedDigit()
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture { openVideo(message) }
        .task(id: message.id) {
            guard thumbnail == nil, let file = await loadVideo(message), file.isFileURL else { return }
            thumbnail = await Self.firstFrame(of: file)
        }
    }

    private static func firstFrame(of file: URL) async -> Image? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: file))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        guard let (frame, _) = try? await generator.image(at: .zero) else { return nil }
        #if os(macOS)
        return Image(nsImage: NSImage(cgImage: frame, size: .zero))
        #else
        return Image(uiImage: UIImage(cgImage: frame))
        #endif
    }
}
