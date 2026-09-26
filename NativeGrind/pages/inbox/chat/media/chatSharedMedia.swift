//
//  chatSharedMedia.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import NativeGrindCore

struct chatSharedMedia: View {
    @ObservedObject var store: chatStore

    @Environment(\.dismiss) private var dismiss

    @State private var viewingPhoto: chatMessage? = nil
    @State private var viewingVideo: chatMessage? = nil
    @State private var confirmingVideo: chatMessage? = nil

    #if os(macOS)
    private let columns = [GridItem(.adaptive(minimum: 120, maximum: 180), spacing: 2)]
    #else
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    #endif

    private var months: [(title: String, media: [chatMessage])] {
        let calendar = Calendar.current
        var groups: [(title: String, media: [chatMessage])] = []
        var currentMonth: DateComponents? = nil

        for message in store.sharedMedia {
            let month = calendar.dateComponents([.year, .month], from: message.date)
            if month != currentMonth {
                currentMonth = month
                groups.append((message.date.formatted(.dateTime.month(.wide).year()), []))
            }
            groups[groups.count - 1].media.append(message)
        }
        return groups
    }

    var body: some View {
        container
            .sheet(item: $viewingPhoto) { message in
                chatPhotoViewer(message: message, loadImage: store.imageData)
            }
            .sheet(item: $viewingVideo) { message in
                chatVideoViewer(message: message, loadVideo: store.videoFile)
            }
            .confirmationDialog("Watch this video?", isPresented: isConfirmingBinding, titleVisibility: .visible, presenting: confirmingVideo) { message in
                Button("Watch Video") { viewingVideo = message }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("It can only be watched a limited number of times. Once it opens it's saved on this device.")
            }
    }

    private var isConfirmingBinding: Binding<Bool> {
        Binding(get: { confirmingVideo != nil }, set: { if !$0 { confirmingVideo = nil } })
    }

    @ViewBuilder
    private var container: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Text("Shared Media")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .help("Close")
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.bar)

            Divider()

            content
        }
        .frame(minWidth: 520, idealWidth: 640, minHeight: 520, idealHeight: 680)
        #else
        NavigationStack {
            content
                .navigationTitle("Shared Media")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if store.sharedMedia.isEmpty {
            emptyStateView("No Media Yet", systemImage: "photo.on.rectangle", description: Text("Photos and videos sent in this chat show up here."))
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2, pinnedViews: .sectionHeaders) {
                    ForEach(months, id: \.title) { month in
                        Section {
                            ForEach(month.media) { message in
                                sharedMediaTile(message: message) { open(message) }
                            }
                        } header: {
                            Text(month.title)
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                #if os(tvOS)
                                .background(.regularMaterial)
                                #else
                                .background(.bar)
                                #endif
                        }
                    }
                }
            }
        }
    }

    private func open(_ message: chatMessage) {
        guard message.isVideo else {
            viewingPhoto = message
            return
        }
        Task {
            var isSaved = false
            if let key = message.mediaCacheKey {
                isSaved = await chatMediaController.shared.localVideo(key: key) != nil
            }
            if message.isViewLimitedVideo && !isSaved {
                guard (message.body?.viewsRemaining ?? 1) > 0 else { return }
                confirmingVideo = message
            } else {
                viewingVideo = message
            }
        }
    }
}

private struct sharedMediaTile: View {
    let message: chatMessage
    let onOpen: () -> Void

    @Environment(\.loadChatImage) private var loadImage

    @State private var image: Image? = nil
    @State private var failed = false

    private var duration: String? {
        guard let length = message.body?.length, length > 0 else { return nil }
        let seconds = Int((length / 1000).rounded())
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        Button(action: onOpen) {
            Rectangle()
                .fill(message.isVideo ? AnyShapeStyle(Color.black.opacity(0.85)) : AnyShapeStyle(.quaternary))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if failed && !message.isVideo {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    } else if !message.isVideo {
                        ProgressView()
                    }
                }
                .overlay {
                    if message.isVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, .black.opacity(0.4))
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    badge
                }
                .clipped()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .task(id: message.id) {
            await loadPreview()
        }
    }

    @ViewBuilder
    private var badge: some View {
        let isLimited = message.type == .expiringImage || message.isViewLimitedVideo
        if isLimited || duration != nil {
            HStack(spacing: 3) {
                if isLimited {
                    Image(systemName: "timer")
                }
                if message.isVideo, let duration {
                    Text(duration).monospacedDigit()
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(.black.opacity(0.55), in: Capsule())
            .padding(5)
        }
    }

    private var accessibilityLabel: String {
        var parts = [message.isVideo ? "Video" : "Photo"]
        if message.type == .expiringImage || message.isViewLimitedVideo { parts.append("view once") }
        if message.isVideo, let duration { parts.append(duration) }
        parts.append(message.date.formatted(date: .abbreviated, time: .omitted))
        return parts.joined(separator: ", ")
    }

    private func loadPreview() async {
        guard image == nil else { return }
        if message.isVideo {
            guard let key = message.mediaCacheKey,
                  let file = await chatMediaController.shared.localVideo(key: key) else { return }
            image = await chatVideoBubble.firstFrame(of: file)
        } else if let data = await loadImage(message), let platformImage = PlatformImage(data: data) {
            image = Image(platformImage: platformImage)
        } else {
            failed = true
        }
    }
}
