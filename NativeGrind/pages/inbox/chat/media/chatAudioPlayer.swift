//
//  chatAudioPlayer.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 24/09/2026.
//

import SwiftUI
import AVFoundation
import NativeGrindCore

@MainActor
@Observable
final class chatAudioPlayer {
    private(set) var currentMessageId: String? = nil
    private(set) var isPlaying = false
    private(set) var isLoading = false
    private(set) var elapsed: TimeInterval = 0
    private(set) var duration: TimeInterval = 0

    @ObservationIgnored var resolveURL: (chatMessage) async -> URL? = { _ in nil }

    @ObservationIgnored private var player: AVPlayer? = nil
    @ObservationIgnored private var timeObserver: Any? = nil
    @ObservationIgnored private var endObserver: NSObjectProtocol? = nil
    @ObservationIgnored private var statusObservation: NSKeyValueObservation? = nil

    var progress: Double {
        duration > 0 ? min(elapsed / duration, 1) : 0
    }

    func isCurrent(_ message: chatMessage) -> Bool {
        currentMessageId == message.id
    }

    func toggle(_ message: chatMessage) async {
        if isCurrent(message), let player {
            if isPlaying {
                player.pause()
                isPlaying = false
            } else {
                if elapsed >= duration, duration > 0 {
                    await player.seek(to: .zero)
                    elapsed = 0
                }
                player.play()
                isPlaying = true
            }
            return
        }

        stop()
        currentMessageId = message.id
        duration = (message.body?.length ?? 0) / 1000
        isLoading = true

        let url = await resolveURL(message)

        // Another message may have been tapped while the URL was loading
        guard currentMessageId == message.id else { return }
        isLoading = false

        guard let url else {
            stop()
            toastManager.shared.show(style: .error, header: "Audio", message: "This voice message isn't available")
            return
        }

        start(url: url, messageId: message.id)
    }

    func stop() {
        player?.pause()
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        statusObservation?.invalidate()

        player = nil
        timeObserver = nil
        endObserver = nil
        statusObservation = nil
        currentMessageId = nil
        isPlaying = false
        isLoading = false
        elapsed = 0
        duration = 0
    }

    private func start(url: URL, messageId: String) {
        #if !os(macOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)

        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            MainActor.assumeIsolated {
                self?.update(time: time, item: item)
            }
        }

        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.isPlaying = false
                self.elapsed = self.duration
            }
        }

        statusObservation = item.observe(\.status) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor in
                guard let self, self.currentMessageId == messageId else { return }
                self.stop()
                toastManager.shared.show(style: .error, header: "Audio", message: "Couldn't play this voice message")
            }
        }

        self.player = player
        player.play()
        isPlaying = true
    }

    private func update(time: CMTime, item: AVPlayerItem) {
        let itemDuration = item.duration.seconds
        if itemDuration.isFinite, itemDuration > 0 {
            duration = itemDuration
        }
        if time.seconds.isFinite {
            elapsed = time.seconds
        }
    }
}
