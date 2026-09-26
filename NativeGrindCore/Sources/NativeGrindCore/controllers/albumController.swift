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

    private var backingUp = Set<String>() // "albumId/contentId" currently being uploaded

    public func sharedAlbums(profileId: String) async -> [albumSummary] {
        (try? await APIClient.shared.request(.getAlbumsShared(byProfileId: profileId), shouldErrorMessage: false))?.albums ?? []
    }

    public func myAlbums() async -> [myAlbum] {
        (try? await APIClient.shared.request(.getMyAlbums(), shouldErrorMessage: false))?.albums ?? []
    }

    public func share(albumId: String, with profileId: Int, expiration: albumExpiration) async -> Bool {
        do {
            _ = try await APIClient.shared.request(.shareAlbum(albumId: albumId, profileId: profileId, expiration: expiration))
        } catch {
            await errorManager.shared.warn("albumController", "Failed to share album \(albumId): \(error)")
            return false
        }

        let owner = await sessionManager.shared.profileId.map(String.init)
        Task { _ = await self.loadAlbum(albumId: albumId, ownerProfileId: owner) }
        return true
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
        guard appEnvironment.isServerEnabled else { return nil }
        return try? await APIClient.shared.request(.getNativeServerAlbum(albumId: albumId), shouldErrorMessage: false)
    }

    private func backUp(_ contents: [albumContent], albumId: String, ownerProfileId: String) async {
        guard !appEnvironment.isTesting else { return }
        guard await wsController.shared.isServerAuthorized else {
            await errorManager.shared.warn("albumController", "Album \(albumId): NativeServer not connected, \(contents.count) item(s) not backed up")
            return
        }

        let ordered = contents.sorted { isLimited($0) && !isLimited($1) }
        var saved = 0
        var failures: [String] = []

        for content in ordered {
            let key = "\(albumId)/\(content.contentId)"
            guard !backingUp.contains(key) else { continue }
            backingUp.insert(key)
            defer { backingUp.remove(key) }

            let kind = content.isVideo ? "video" : "photo"

            guard let url = content.url.flatMap(URL.init(string:)) else {
                failures.append("\(kind) \(content.contentId): Grindr gave no link")
                continue
            }
            guard let data = await chatMediaController.shared.download(url) else {
                failures.append("\(kind) \(content.contentId): download failed")
                continue
            }
            guard data.count <= chatMediaController.maxBackupBytes else {
                failures.append("\(kind) \(content.contentId): too large (\(data.count / 1_000_000) MB, max \(chatMediaController.maxBackupBytes / 1_000_000) MB)")
                continue
            }

            if let error = await upload(data, contentId: content.contentId, albumId: albumId, ownerProfileId: ownerProfileId) {
                failures.append("\(kind) \(content.contentId) (\(data.count / 1_000_000) MB): \(error)")
            } else {
                saved += 1
            }
        }

        await errorManager.shared.log("albumController", "Album \(albumId): backed up \(saved)/\(ordered.count)")
        for failure in failures {
            await errorManager.shared.warn("albumController", "Album \(albumId) backup failed, \(failure)")
        }
    }

    private func isLimited(_ content: albumContent) -> Bool {
        (content.remainingViews ?? -1) > 0
    }

    private func upload(_ data: Data, contentId: String, albumId: String, ownerProfileId: String) async -> String? {
        let base64 = data.base64EncodedString()
        let timeout = 10 + Double(data.count) / 1_000_000
        var lastError = "no response from NativeServer"

        for _ in 0..<2 {
            let response = await wsController.shared.sendAndWait(
                request: .uploadAlbumMedia(albumId: albumId, contentId: contentId, ownerProfileId: ownerProfileId, base64Data: base64),
                expectedEvent: .onAlbumMediaUploaded,
                timeout: timeout
            )
            if response?.status == .success {
                return nil
            }
            lastError = response?.message ?? "no response from NativeServer"
        }
        return lastError
    }
}
