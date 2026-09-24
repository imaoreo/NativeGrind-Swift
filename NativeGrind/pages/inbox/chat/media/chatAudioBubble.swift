//
//  chatAudioBubble.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatAudioBubble: View {
    let message: chatMessage
    let isMine: Bool

    @Environment(chatAudioPlayer.self) private var player

    private var isCurrent: Bool { player.isCurrent(message) }

    private var totalSeconds: TimeInterval {
        isCurrent && player.duration > 0 ? player.duration : (message.body?.length ?? 0) / 1000
    }

    private var shownSeconds: TimeInterval {
        isCurrent && (player.isPlaying || player.elapsed > 0) ? player.elapsed : totalSeconds
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                Task { await player.toggle(message) }
            } label: {
                ZStack {
                    if isCurrent && player.isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.body.bold())
                    }
                }
                .frame(width: 32, height: 32)
                .background(isMine ? Color.white.opacity(0.25) : Color.blue.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)

            progressBar

            Text(format(shownSeconds))
                .font(.caption.monospacedDigit())
                .frame(minWidth: 34, alignment: .trailing)
        }
        .frame(width: 200)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(isMine ? Color.white.opacity(0.35) : Color.secondary.opacity(0.3))
                Capsule()
                    .fill(isMine ? Color.white : Color.blue)
                    .frame(width: geometry.size.width * (isCurrent ? player.progress : 0))
            }
        }
        .frame(height: 4)
    }

    private func format(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}
