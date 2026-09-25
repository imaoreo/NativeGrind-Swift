//
//  albumItemViewer.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import AVKit
import NativeGrindCore

struct albumItemViewer: View {
    let item: albumItem
    let albumId: String

    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer? = nil
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let url = item.bestURL {
                if item.isVideo {
                    VideoPlayer(player: player)
                        .onAppear {
                            let player = AVPlayer(url: url)
                            self.player = player
                            player.play()
                        }
                        .onDisappear { player?.pause() }
                } else {
                    photo(url)
                }
            } else {
                ContentUnavailableView("Not Available", systemImage: "photo")
                    .foregroundStyle(.white)
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.5), in: Circle())
            }
            .buttonStyle(.plain)
            #if !os(tvOS)
            .keyboardShortcut(.cancelAction)
            #endif
            .padding(16)
        }
        #if os(macOS)
        .frame(minWidth: 640, idealWidth: 900, minHeight: 520, idealHeight: 700)
        #endif
        .task {
            if item.fullURL != nil {
                _ = await albumController.shared.recordItemViewed(albumId: albumId, contentId: item.contentId)
            }
        }
    }

    private func photo(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    #if !os(tvOS)
                    .gesture(
                        MagnifyGesture()
                            .onChanged { scale = min(max(lastScale * $0.magnification, 1), 5) }
                            .onEnded { _ in lastScale = scale }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(duration: 0.3)) {
                            scale = scale > 1 ? 1 : 2.5
                            lastScale = scale
                        }
                    }
                    #endif
            case .failure:
                ContentUnavailableView("Couldn't Load Photo", systemImage: "photo")
                    .foregroundStyle(.white)
            default:
                ProgressView().tint(.white)
            }
        }
    }
}
