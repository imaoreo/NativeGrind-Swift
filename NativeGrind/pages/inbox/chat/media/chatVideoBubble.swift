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
    @State private var isSaved = false
    @State private var confirmViewOnce = false

    private var isLimited: Bool { message.isViewLimitedVideo }

    private var isUsedUp: Bool {
        isLimited && !isSaved && (message.body?.viewsRemaining ?? 1) <= 0
    }

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

            if isUsedUp {
                VStack(spacing: 4) {
                    Image(systemName: "eye.slash")
                        .font(.title2)
                    Text("Video Expired")
                        .font(.caption.weight(.semibold))
                }
                .foregroundColor(.white.opacity(0.8))
            } else {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white, .black.opacity(0.4))
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 4) {
                Image(systemName: isLimited || message.type == .privateVideo ? "eye" : "video.fill")
                if isLimited && !isSaved {
                    Text(message.body?.maxViews == 1 ? "View Once" : "Limited Views")
                } else if let duration {
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
        .onTapGesture {
            if isUsedUp { return }
            if isLimited && !isSaved {
                confirmViewOnce = true
            } else {
                openVideo(message)
            }
        }
        .confirmationDialog("Watch this video?", isPresented: $confirmViewOnce, titleVisibility: .visible) {
            Button("Watch Video") { openVideo(message) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("It can only be watched a limited number of times. Once it opens it's saved on this device.")
        }
        .task(id: message.id) {
            guard thumbnail == nil, let file = await savedOrLoadedVideo(), file.isFileURL else { return }
            isSaved = true
            thumbnail = await Self.firstFrame(of: file)
        }
    }

    private func savedOrLoadedVideo() async -> URL? {
        guard isLimited else { return await loadVideo(message) }
        guard let key = message.mediaCacheKey else { return nil }
        return await chatMediaController.shared.localVideo(key: key)
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
