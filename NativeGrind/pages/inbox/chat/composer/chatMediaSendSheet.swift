//
//  chatMediaSendSheet.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import AVKit

struct chatMediaSendSheet: View {
    let media: chatOutgoingMedia
    let onSend: (_ viewOnce: Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewOnce = false
    @State private var player: AVPlayer? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    #if !os(tvOS)
                    .keyboardShortcut(.cancelAction)
                    #endif
                Spacer()
                Text(media.isVideo ? "Send Video" : "Send Photo")
                    .font(.headline)
                Spacer()
                Button("Send") {
                    onSend(viewOnce)
                    dismiss()
                }
                .bold()
                #if !os(tvOS)
                .keyboardShortcut(.defaultAction)
                #endif
            }
            .padding()

            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)

            if !media.isVideo {
                Toggle(isOn: $viewOnce) {
                    Label("View Once", systemImage: "timer")
                }
                .padding()
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, idealWidth: 560, minHeight: 520, idealHeight: 640)
        #endif
    }

    @ViewBuilder
    private var preview: some View {
        switch media.kind {
        case .photo:
            if let image = PlatformImage(data: media.data) {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
            }
        case .video(let file, _):
            VideoPlayer(player: player)
                .onAppear {
                    if player == nil { player = AVPlayer(url: file) }
                }
                .onDisappear { player?.pause() }
        }
    }
}
