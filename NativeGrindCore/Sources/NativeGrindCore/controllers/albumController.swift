//
//  albumController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 25/09/2026.
//

import Foundation

public struct albumItem: Identifiable, Sendable {
    public let contentId: String
    public let isVideo: Bool
    public let thumbURL: URL?
    public let fullURL: URL?
    public let backupURL: URL?
    public let remainingViews: Int?
    public let isProcessing: Bool

    public var id: String { contentId }

    public var isOnlyInBackup: Bool { fullURL == nil && backupURL != nil }
    public var previewURL: URL? { thumbURL ?? backupURL }
    public var bestURL: URL? { fullURL ?? backupURL }
}

public struct albumSnapshot: Sendable {
    public let albumId: String
    public let ownerProfileId: String?
    public let items: [albumItem]
    public let isFromBackupOnly: Bool
}

public actor albumController {
    public static let shared = albumController()

    private static let maxBackupBytes = 50 * 1024 * 1024
    private var backingUp = Set<String>() // "albumId/contentId" currently being uploaded

    public func sharedAlbums(profileId: String) async -> [albumSummary] {
        (try? await APIClient.shared.request(.getAlbumsShared(byProfileId: profileId), shouldErrorMessage: false))?.albums ?? []
    }

    public func loadAlbum(albumId: String, ownerProfileId: String?) async -> albumSnapshot? {
        async let grindrAlbum = try? APIClient.shared.request(.getAlbum(albumId: albumId), shouldErrorMessage: false)
        async let backup = fetchBackup(albumId: albumId)

        let (album, stored) = await (grindrAlbum ?? nil, backup)

        guard album != nil || stored != nil else { return nil }

        let backupURLs = Dictionary(
            (stored?.items ?? []).map { ($0.contentId, URL(string: baseURL.nativeServer.rawValue + $0.url)) },
            uniquingKeysWith: { first, _ in first }
        )

        var items: [albumItem] = (album?.content ?? []).map { content in
            albumItem(
                contentId: content.contentId,
                isVideo: content.isVideo,
                thumbURL: (content.thumbUrl ?? content.coverUrl).flatMap(URL.init(string:)),
                fullURL: content.url.flatMap(URL.init(string:)),
                backupURL: backupURLs[content.contentId] ?? nil,
                remainingViews: content.remainingViews,
                isProcessing: content.processing
            )
        }

        let onGrindr = Set(items.map(\.contentId))
        for stored in stored?.items ?? [] where !onGrindr.contains(stored.contentId) {
            items.append(albumItem(
                contentId: stored.contentId,
                isVideo: stored.contentType.hasPrefix("video"),
                thumbURL: nil,
                fullURL: nil,
                backupURL: backupURLs[stored.contentId] ?? nil,
                remainingViews: nil,
                isProcessing: false
            ))
        }

        let owner = album?.profileId ?? stored?.ownerProfileId ?? ownerProfileId

        if let album, let owner {
            let alreadyStored = Set(stored?.items.map(\.contentId) ?? [])
            let missing = album.content.filter { !alreadyStored.contains($0.contentId) && !$0.processing }
            if !missing.isEmpty {
                Task { await self.backUp(missing, albumId: albumId, ownerProfileId: owner) }
            }
        }

        return albumSnapshot(
            albumId: albumId,
            ownerProfileId: owner,
            items: items,
            isFromBackupOnly: album == nil
        )
    }

    private var knownBackups: [String: Bool] = [:]

    public func hasBackup(albumId: String) async -> Bool {
        if let known = knownBackups[albumId] { return known }
        let exists = await fetchBackup(albumId: albumId) != nil
        knownBackups[albumId] = exists
        return exists
    }

    private func fetchBackup(albumId: String) async -> nsAlbumBackup? {
        try? await APIClient.shared.request(.getNativeServerAlbum(albumId: albumId), shouldErrorMessage: false)
    }

    public func recordItemViewed(albumId: String, contentId: String) async -> Int? {
        (try? await APIClient.shared.request(.recordAlbumContentView(albumId: albumId, contentId: contentId), shouldErrorMessage: false))?.remainingViews
    }

    private func backUp(_ contents: [albumContent], albumId: String, ownerProfileId: String) async {
        guard !appEnvironment.isTesting, await wsController.shared.isServerAuthorized else { return }

        for content in contents {
            let key = "\(albumId)/\(content.contentId)"
            guard !backingUp.contains(key), let url = content.url.flatMap(URL.init(string:)) else { continue }
            backingUp.insert(key)
            defer { backingUp.remove(key) }

            guard let data = await chatMediaController.shared.download(url), data.count <= Self.maxBackupBytes else { continue }

            await wsController.shared.send(request: .uploadAlbumMedia(
                albumId: albumId,
                contentId: content.contentId,
                ownerProfileId: ownerProfileId,
                base64Data: data.base64EncodedString()
            ))

            try? await Task.sleep(for: .milliseconds(200))
        }
    }
}
