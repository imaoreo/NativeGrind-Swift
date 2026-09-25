//
//  chatMediaDrawer.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
#if !os(tvOS)
import PhotosUI
#endif
import NativeGrindCore

struct chatMediaDrawer: View {
    let store: chatStore

    @Environment(\.dismiss) private var dismiss

    @State private var drawer: [drawerMedia] = []
    @State private var albums: [myAlbum] = []
    @State private var hasLoaded = false
    @State private var isUploading = false
    @State private var sending: drawerMedia? = nil
    @State private var sharing: myAlbum? = nil
    #if !os(tvOS)
    @State private var showPhotoPicker = false
    @State private var pickedItem: PhotosPickerItem? = nil
    @State private var showFileImporter = false
    #endif
    #if os(iOS)
    @State private var capturing: cameraCapture.captureMode? = nil
    #endif

    @State private var removing: drawerMedia? = nil

    @ScaledMetric(relativeTo: .title2) private var iconSize: CGFloat = 26
    @ScaledMetric(relativeTo: .caption) private var badgeSize: CGFloat = 15
    @ScaledMetric(relativeTo: .caption) private var dotSize: CGFloat = 10

    #if os(macOS)
    private let columns = [GridItem(.adaptive(minimum: 130, maximum: 180), spacing: 2)]
    #else
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    #endif

    var body: some View {
        container
            .task {
                await reload()
            }
            .confirmationDialog("Send this?", isPresented: isSendingBinding, titleVisibility: .visible, presenting: sending) { media in
                if media.isVideo {
                    Button("Send Video") { send(media, expiring: false) }
                } else {
                    Button("Send Photo") { send(media, expiring: false) }
                    Button("Send as View Once") { send(media, expiring: true) }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("How long can they see it?", isPresented: isSharingBinding, titleVisibility: .visible, presenting: sharing) { album in
                ForEach(albumExpiration.allCases, id: \.self) { expiration in
                    Button(expiration.title) {
                        Task { await store.shareAlbum(album, expiration: expiration) }
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Remove from Drawer?", isPresented: isRemovingBinding, titleVisibility: .visible, presenting: removing) { media in
                Button("Remove", role: .destructive) {
                    Task { await remove(media) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { media in
                Text(media.isVideo ? "You won't be able to send this video again from your drawer." : "You won't be able to send this photo again from your drawer.")
            }
            #if !os(tvOS)
            .photosPicker(isPresented: $showPhotoPicker, selection: $pickedItem, matching: .any(of: [.images, .videos]))
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                pickedItem = nil
                Task { await upload(await chatOutgoingMedia.load(from: item)) }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.image, .movie]) { result in
                guard case .success(let file) = result else { return }
                Task { await upload(await chatOutgoingMedia.loadPicked(file: file)) }
            }
            #endif
            #if os(iOS)
            .fullScreenCover(item: $capturing) { mode in
                cameraCapture(mode: mode) { media in
                    Task { await upload(media) }
                }
                .ignoresSafeArea()
            }
            #endif
    }

    @ViewBuilder
    private var container: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            HStack {
                Text("Drawer")
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

            grid
        }
        .frame(minWidth: 460, idealWidth: 580, minHeight: 520, idealHeight: 680)
        #else
        NavigationStack {
            grid
                .navigationTitle("Drawer")
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

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                actionTiles

                ForEach(albums) { album in
                    albumTile(album)
                }

                ForEach(drawer) { media in
                    mediaTile(media)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.separator)
            }
            .padding()

            if !hasLoaded {
                ProgressView()
            }
        }
    }

    private var isSendingBinding: Binding<Bool> {
        Binding(get: { sending != nil }, set: { if !$0 { sending = nil } })
    }

    private var isSharingBinding: Binding<Bool> {
        Binding(get: { sharing != nil }, set: { if !$0 { sharing = nil } })
    }

    private var isRemovingBinding: Binding<Bool> {
        Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })
    }

    @ViewBuilder
    private var actionTiles: some View {
        #if os(iOS)
        if cameraCapture.isAvailable {
            actionTile(systemImage: "camera", label: "Take Photo") { capturing = .photo }
            actionTile(systemImage: "video", label: "Record Video") { capturing = .video }
        }
        #endif
        #if !os(tvOS)
        if isUploading {
            tile {
                ProgressView()
            }
            .accessibilityLabel("Uploading")
        } else {
            Menu {
                Button {
                    showPhotoPicker = true
                } label: {
                    Label("Photo or Video", systemImage: "photo.on.rectangle")
                }
                Button {
                    showFileImporter = true
                } label: {
                    Label("Choose File…", systemImage: "folder")
                }
            } label: {
                tile {
                    actionIcon("square.and.arrow.up")
                }
            }
            .menuIndicator(.hidden)
            .menuStyle(.button)
            .buttonStyle(.plain)
            .modifier(tileHover())
            .help("Upload")
            .accessibilityLabel("Upload")
            .accessibilityHint("Adds a photo or video to your drawer")
        }
        #endif
    }

    private func actionTile(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            tile {
                actionIcon(systemImage)
            }
        }
        .buttonStyle(.plain)
        .modifier(tileHover())
        .help(label)
        .accessibilityLabel(label)
    }

    private func actionIcon(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize))
            .foregroundStyle(.secondary)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: badgeSize))
                    .foregroundStyle(.black, .yellow)
                    .offset(x: badgeSize / 2, y: badgeSize / 2.5)
            }
            .accessibilityHidden(true)
    }

    private func tile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        Rectangle()
            .fill(.quaternary)
            .aspectRatio(1, contentMode: .fit)
            .overlay { content() }
            .contentShape(Rectangle())
    }

    private func thumbnail(_ url: URL?) -> some View {
        Rectangle()
            .fill(.quaternary)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else if case .failure = phase {
                            Image(systemName: "photo").foregroundColor(.secondary)
                        }
                    }
                }
            }
            .clipped()
    }

    private func albumTile(_ album: myAlbum) -> some View {
        let cover = album.content.first.flatMap { ($0.thumbUrl ?? $0.coverUrl).flatMap(URL.init(string:)) }
        let name = album.albumName?.isEmpty == false ? album.albumName! : "Album"

        return Button {
            sharing = album
        } label: {
            thumbnail(cover)
                .blur(radius: 6)
                .overlay(Color.black.opacity(0.4))
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: iconSize))
                        Text(name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .padding(.horizontal, 6)
                    }
                    .foregroundColor(.white)
                }
                .clipped()
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(tileHover())
        .help("Share \(name)")
        .accessibilityLabel("Album, \(name)")
        .accessibilityHint("Shares this album in the chat")
    }

    private func mediaTile(_ media: drawerMedia) -> some View {
        Button {
            sending = media
        } label: {
            thumbnail(media.isVideo ? nil : media.url.flatMap(URL.init(string:)))
                .overlay {
                    if media.isVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: iconSize + 4))
                            .foregroundStyle(.white, .black.opacity(0.4))
                    } else if media.used {
                        Text("SENT")
                            .font(.caption.weight(.bold))
                            .kerning(2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.black.opacity(0.55), in: Capsule())
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if media.takenOnGrindr {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: dotSize, height: dotSize)
                            .shadow(radius: 2)
                            .padding(8)
                            .help("Taken on Grindr")
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(tileHover())
        #if !os(macOS)
        .overlay(alignment: .topLeading) {
            // Small ✕ like Grindr's, inside a full-size tap target
            Button {
                removing = media
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(.black.opacity(0.55), in: Circle())
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove from Drawer")
        }
        #endif
        .contextMenu {
            Button(role: .destructive) {
                removing = media
            } label: {
                Label("Remove from Drawer", systemImage: "trash")
            }
        }
        .accessibilityLabel(accessibilityLabel(for: media))
        .accessibilityHint("Sends this in the chat")
        .accessibilityAction(named: "Remove from Drawer") { removing = media }
    }

    private func accessibilityLabel(for media: drawerMedia) -> String {
        var parts = [media.isVideo ? "Video" : "Photo"]
        if media.used { parts.append("sent before") }
        if media.takenOnGrindr { parts.append("taken on Grindr") }
        return parts.joined(separator: ", ")
    }

    private func reload() async {
        async let drawerItems = conversationController.shared.drawer()
        async let myAlbums = albumController.shared.myAlbums()
        (drawer, albums) = await (drawerItems, myAlbums)
        hasLoaded = true
    }

    private func upload(_ media: chatOutgoingMedia?) async {
        guard let media else {
            toastManager.shared.show(style: .error, header: "Media", message: "Couldn't read that photo or video")
            return
        }
        isUploading = true
        defer {
            isUploading = false
            media.removeTemporaryFile()
        }

        if await conversationController.shared.uploadToDrawer(media.data, contentType: media.contentType, lengthMs: media.lengthMs) {
            drawer = await conversationController.shared.drawer()
        }
    }

    private func remove(_ media: drawerMedia) async {
        if await conversationController.shared.removeFromDrawer(mediaId: media.id) {
            drawer.removeAll { $0.id == media.id }
        }
    }

    private func send(_ media: drawerMedia, expiring: Bool) {
        Task { await store.sendFromDrawer(media, expiring: expiring) }
        dismiss()
    }
}

private struct tileHover: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .overlay {
                Rectangle()
                    .fill(Color.primary.opacity(isHovering ? 0.08 : 0))
                    .allowsHitTesting(false)
            }
            #if os(macOS)
            .onHover { isHovering = $0 }
            #endif
    }
}

extension albumExpiration {
    var title: String {
        switch self {
        case .indefinite: "Until I Unshare It"
        case .once: "View Once"
        case .tenMinutes: "For 10 Minutes"
        case .oneHour: "For 1 Hour"
        case .oneDay: "For 24 Hours"
        }
    }
}

#if os(iOS)
extension cameraCapture.captureMode: Identifiable {
    var id: Self { self }
}
#endif
