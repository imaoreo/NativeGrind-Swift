//
//  chatSharedMedia.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatSharedMedia: View {
    let store: chatStore

    @Environment(\.dismiss) private var dismiss

    @State private var viewingPhoto: chatMessage? = nil
    @State private var viewingVideo: chatMessage? = nil

    #if os(macOS)
    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 4)]
    #else
    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 160), spacing: 4)]
    #endif
    private let cellSize = CGSize(width: 120, height: 120)

    private var media: [chatMessage] {
        store.sharedMedia
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Shared Media")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    #if !os(tvOS)
                    .keyboardShortcut(.cancelAction)
                    #endif
            }
            .padding()

            Divider()

            if media.isEmpty {
                ContentUnavailableView("No Media Yet", systemImage: "photo.on.rectangle", description: Text("Photos and videos sent in this chat show up here."))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(media) { message in
                            cell(message)
                        }
                    }
                    .padding(4)
                }
            }
        }
        .environment(\.openChatVideo) { viewingVideo = $0 }
        .sheet(item: $viewingPhoto) { message in
            chatPhotoViewer(message: message, loadImage: store.imageData)
        }
        .sheet(item: $viewingVideo) { message in
            chatVideoViewer(message: message, loadVideo: store.videoFile)
        }
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 640, minHeight: 520, idealHeight: 640)
        #endif
    }

    @ViewBuilder
    private func cell(_ message: chatMessage) -> some View {
        switch message.type {
        case .video, .privateVideo, .nonExpiringVideo:
            chatVideoBubble(message: message, size: cellSize)
        default:
            chatRemoteImage(message: message, size: cellSize)
                .overlay(alignment: .topTrailing) {
                    if message.type == .expiringImage {
                        Image(systemName: "timer")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(5)
                            .background(.black.opacity(0.55), in: Circle())
                            .padding(5)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { viewingPhoto = message }
        }
    }
}
