//
//  chatMediaController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Foundation

public actor chatMediaController {
    public static let shared = chatMediaController()

    private var knownOnServer = Set<String>()

    public static func isValidHash(_ hash: String) -> Bool {
        hash.wholeMatch(of: /^[A-Za-z0-9_-]{8,128}$/) != nil
    }

    public func localImage(hash: String) -> Data? {
        guard let url = localURL(for: hash) else { return nil }
        return try? Data(contentsOf: url)
    }

    public func loadImage(hash: String, from url: URL?) async -> Data? {
        guard Self.isValidHash(hash) else {
            if let url { return await download(url) }
            return nil
        }

        if let local = localImage(hash: hash) {
            return local
        }

        if let url, let data = await download(url) {
            saveLocally(hash: hash, data: data)
            await backUp(hash: hash, data: data)
            return data
        }

        if let data = await downloadFromNativeServer(hash: hash) {
            knownOnServer.insert(hash)
            saveLocally(hash: hash, data: data)
            return data
        }

        return nil
    }

    public func download(_ url: URL) async -> Data? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              !data.isEmpty else {
            return nil
        }
        return data
    }

    private func downloadFromNativeServer(hash: String) async -> Data? {
        guard let (data, response) = try? await APIClient.shared.rawRequest(.getNativeServerChatMedia(mediaHash: hash)),
              response.statusCode == 200,
              !data.isEmpty else {
            return nil
        }
        return data
    }

    private func backUp(hash: String, data: Data) async {
        guard !appEnvironment.isTesting,
              !knownOnServer.contains(hash),
              await wsController.shared.isServerAuthorized else {
            return
        }

        // Someone else may have already backed it up, a HEAD is cheaper than re-uploading
        if let (_, response) = try? await APIClient.shared.rawRequest(.getNativeServerChatMedia(mediaHash: hash, method: .head)),
           response.statusCode == 200 {
            knownOnServer.insert(hash)
            return
        }

        knownOnServer.insert(hash)
        await wsController.shared.send(request: .uploadChatMedia(mediaHash: hash, base64Data: data.base64EncodedString()))
    }

    private var directory: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let directory = caches.appendingPathComponent("chatMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func localURL(for hash: String) -> URL? {
        guard Self.isValidHash(hash) else { return nil }
        return directory?.appendingPathComponent(hash)
    }

    private func saveLocally(hash: String, data: Data) {
        guard !appEnvironment.isTesting, let url = localURL(for: hash) else { return }
        try? data.write(to: url, options: .atomic)
    }

    public func clearAll() {
        knownOnServer.removeAll()
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

public extension chatMessage {
    var photoCacheKey: String? {
        if let hash = body?.imageHash, chatMediaController.isValidHash(hash) {
            return hash
        }
        if let mediaId = body?.mediaId {
            return "media-\(Int64(mediaId))"
        }
        return nil
    }
}
