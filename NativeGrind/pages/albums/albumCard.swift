//
//  albumCard.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import NativeGrindCore

enum albumAccess {
    case checking
    case viewable
    case backupOnly
    case locked

    var canOpen: Bool { self == .viewable || self == .backupOnly }

    static func resolve(albumId: String?, isViewable: Bool) async -> albumAccess {
        guard !isViewable else { return .viewable }
        guard let albumId else { return .locked }
        return await albumController.shared.hasBackup(albumId: albumId) ? .backupOnly : .locked
    }
}

struct chatAlbumBubble: View {
    let message: chatMessage

    @Environment(\.openAlbum) private var openAlbum
    @ObservedObject private var sockets = wsController.shared
    @State private var confirmViewOnce = false
    @State private var access: albumAccess = .checking

    private var isViewOnce: Bool { message.type == .expiringAlbumV2 }

    private var willBackUp: Bool {
        appEnvironment.isServerEnabled && sockets.isServerAuthorized
    }

    private var target: albumTarget? {
        guard let albumId = message.body?.albumId else { return nil }
        let owner = message.body?.ownerProfileId.map { String(Int64($0)) } ?? String(message.senderId)
        return albumTarget(albumId: String(albumId), ownerProfileId: owner)
    }

    var body: some View {
        albumCover(
            coverURL: message.body?.coverUrl.flatMap(URL.init(string:)),
            title: isViewOnce ? "View Once Album" : "Shared Album",
            subtitle: "Tap to view",
            access: access
        )
        .onTapGesture {
            guard access.canOpen, let target else { return }
            if isViewOnce && access == .viewable {
                confirmViewOnce = true
            } else {
                openAlbum(target)
            }
        }
        .confirmationDialog("Open View Once Album?", isPresented: $confirmViewOnce, titleVisibility: .visible) {
            Button("Open Album") {
                if let target { openAlbum(target) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(willBackUp
                 ? "This album can only be viewed once, but its contents will be backed up so you can view it again."
                 : "This album can only be viewed once.")
        }
        .task(id: message.id) {
            access = await albumAccess.resolve(albumId: target?.albumId, isViewable: message.body?.isViewable ?? true)
        }
    }
}

struct profileAlbumCard: View {
    let album: albumSummary
    let onOpen: () -> Void

    @State private var access: albumAccess = .checking

    private var subtitle: String {
        var parts: [String] = []
        if album.imageCount > 0 { parts.append(album.imageCount == 1 ? "1 photo" : "\(album.imageCount) photos") }
        if album.videoCount > 0 { parts.append(album.videoCount == 1 ? "1 video" : "\(album.videoCount) videos") }
        return parts.isEmpty ? "Tap to view" : parts.joined(separator: " · ")
    }

    var body: some View {
        albumCover(
            coverURL: album.cover?.coverUrl.flatMap(URL.init(string:)),
            title: "Album",
            subtitle: subtitle,
            access: access
        )
        .onTapGesture {
            if access.canOpen { onOpen() }
        }
        .task(id: album.albumId) {
            access = await albumAccess.resolve(albumId: album.albumId, isViewable: album.albumViewable)
        }
    }
}

private func albumCover(coverURL: URL?, title: String, subtitle: String, access: albumAccess) -> some View {
    ZStack {
        Color.gray.opacity(0.3)

        if let coverURL {
            AsyncImage(url: coverURL) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill).blur(radius: 8)
                }
            }
        }

        LinearGradient(colors: [.clear, .black.opacity(access == .locked ? 0.8 : 0.6)], startPoint: .top, endPoint: .bottom)

        VStack(spacing: 4) {
            Image(systemName: access == .locked ? "lock.fill" : "photo.on.rectangle.angled")
                .font(.title2)
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(access == .locked ? "Locked" : subtitle)
                .font(.caption)
                .opacity(0.8)
        }
        .foregroundColor(.white)
        .padding(8)
    }
    .frame(width: 200, height: 150)
    .overlay(alignment: .topTrailing) {
        if access == .backupOnly {
            Image(systemName: "server.rack")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(.black.opacity(0.55), in: Circle())
                .padding(8)
                .help("Only available through NativeServer")
        } else if access == .checking {
            ProgressView()
                .controlSize(.small)
                .tint(.white)
                .padding(8)
        }
    }
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .contentShape(RoundedRectangle(cornerRadius: 16))
}
