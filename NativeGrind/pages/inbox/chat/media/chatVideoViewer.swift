//
//  chatVideoViewer.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import AVKit
import NativeGrindCore

struct chatVideoViewer: View {
    let message: chatMessage
    let loadVideo: (chatMessage) async -> URL?

    @Environment(\.dismiss) private var dismiss

    @State private var player: AVPlayer? = nil
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
            } else if failed {
                emptyStateView("Couldn't Load Video", systemImage: "video.slash")
                    .foregroundStyle(.white)
            } else {
                ProgressView()
                    .tint(.white)
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
        .task {
            guard player == nil else { return }
            guard let url = await loadVideo(message) else {
                failed = true
                return
            }
            let player = AVPlayer(url: url)
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
        }
        #if os(macOS)
        .frame(minWidth: 640, idealWidth: 900, minHeight: 520, idealHeight: 700)
        #endif
    }
}
