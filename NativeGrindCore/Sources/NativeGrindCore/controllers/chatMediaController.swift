//
//  chatMediaController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Foundation
import CryptoKit    

public actor chatMediaController {
    public static let shared = chatMediaController()

    public static let maxBackupBytes = 50 * 1024 * 1024
    private var knownOnServer = Set<String>()
    private var videoDownloads: [String: Task<URL?, Never>] = [:]

    public static func isValidHash(_ hash: String) -> Bool {
        hash.wholeMatch(of: /^[A-Za-z0-9_-]{8,128}$/) != nil
    }

    public static func normalizeHash(_ hash: String) -> String {
        if hash.count == 43 { return hash }
        if hash.count == 64 {
            var data = Data()
            var startIndex = hash.startIndex
            var isHex = true
            while startIndex < hash.endIndex {
                let endIndex = hash.index(startIndex, offsetBy: 2, limitedBy: hash.endIndex) ?? hash.endIndex
                if let byte = UInt8(hash[startIndex..<endIndex], radix: 16) {
                    data.append(byte)
                } else {
                    isHex = false
                    break
                }
                startIndex = endIndex
            }
            if isHex {
                return data.base64EncodedString()
                    .replacingOccurrences(of: "+", with: "-")
                    .replacingOccurrences(of: "/", with: "_")
                    .replacingOccurrences(of: "=", with: "")
            }
        }
        
        let data = Data(hash.utf8)
        let sha256 = CryptoKit.SHA256.hash(data: data)
        return Data(sha256).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
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
        return await fetch(hash: hash, from: url, to: localURL(for: hash))
    }

    public func localVideo(key: String) -> URL? {
        guard let file = localURL(for: key, fileExtension: "mp4"),
              FileManager.default.fileExists(atPath: file.path) else {
            return nil
        }
        return file
    }

    public func loadVideo(key: String, from url: URL?) async -> URL? {
        if let local = localVideo(key: key) {
            return local
        }
        guard let file = localURL(for: key, fileExtension: "mp4") else { return nil }

        if let pending = videoDownloads[key] {
            return await pending.value
        }
        let download = Task { await self.fetch(hash: key, from: url, to: file) != nil ? file : nil }
        videoDownloads[key] = download
        defer { videoDownloads[key] = nil }
        let result = await download.value
        return result
    }

    public func keep(_ data: Data, key: String, isVideo: Bool) async {
        guard Self.isValidHash(key) else { return }
        save(data, to: localURL(for: key, fileExtension: isVideo ? "mp4" : nil))
        Task { await self.backUp(hash: key, data: data) }
    }

    private func fetch(hash: String, from url: URL?, to file: URL?) async -> Data? {
        if let url, let data = await download(url) {
            save(data, to: file)
            Task { await self.backUp(hash: hash, data: data) }
            return data
        }

        if let data = await downloadFromNativeServer(hash: hash) {
            knownOnServer.insert(hash)
            save(data, to: file)
            return data
        }

        return nil
    } 

    public func download(_ url: URL) async -> Data? {
        guard let (data, response) = try? await URLSession.shared.data(from: url),
              let http = response as? HTTPURLResponse else {
            await errorManager.shared.warn("chatMediaController", "download failed (network error) for: \(url.absoluteString)")
            return nil
        }
        
        guard (200...299).contains(http.statusCode), !data.isEmpty else {
            await errorManager.shared.warn("chatMediaController", "download failed (HTTP \(http.statusCode), size \(data.count)) for: \(url.absoluteString)")
            return nil
        }
        
        return data
    }

    private func downloadFromNativeServer(hash: String) async -> Data? {
        guard nsAccess.canReadShared else { return nil }
        guard let (data, response) = try? await APIClient.shared.rawRequest(.getNativeServerChatMedia(mediaHash: hash)),
              response.statusCode == 200,
              !data.isEmpty else {
            await errorManager.shared.warn("chatMediaController", "downloadFromNativeServer failed or returned empty for hash: \(hash)")
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

        if let (_, response) = try? await APIClient.shared.rawRequest(.getNativeServerChatMedia(mediaHash: hash, method: .head)),
           response.statusCode == 200 {
            knownOnServer.insert(hash)
            return
        }

        guard data.count <= Self.maxBackupBytes else {
            await errorManager.shared.warn("chatMediaController", "Chat media \(hash) not backed up, too large (\(data.count / 1_000_000) MB, max \(Self.maxBackupBytes / 1_000_000) MB)")
            return
        }

        knownOnServer.insert(hash)
        let response = await wsController.shared.sendAndWait(
            request: .uploadChatMedia(mediaHash: hash, base64Data: data.base64EncodedString()),
            expectedEvent: .onChatMediaUploaded,
            timeout: 120
        )
        if response?.status != .success {
            knownOnServer.remove(hash)
            await errorManager.shared.warn("chatMediaController", "Chat media \(hash) backup failed, \(response?.message ?? "no response from NativeServer")")
        }
    }

    public func isBackedUp(hash: String) async -> Bool {
        if knownOnServer.contains(hash) { 
            return true 
        }
        guard appEnvironment.isServerEnabled else { return false }
        if let (_, response) = try? await APIClient.shared.rawRequest(.getNativeServerChatMedia(mediaHash: hash, method: .head)) {
            let exists = response.statusCode == 200
            if exists { knownOnServer.insert(hash) }
            return exists
        }
        return false
    }

    private var directory: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let directory = caches.appendingPathComponent("chatMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func localURL(for hash: String, fileExtension: String? = nil) -> URL? {
        guard Self.isValidHash(hash) else { return nil }
        let file = directory?.appendingPathComponent(hash)
        guard let fileExtension else { return file }
        return file?.appendingPathExtension(fileExtension)
    }

    private func save(_ data: Data, to file: URL?) {
        guard !appEnvironment.isTesting, let file else { return }
        try? data.write(to: file, options: .atomic)
    }

    public func clearAll() {
        knownOnServer.removeAll()
        if let directory {
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

public extension chatMessage {
    static let unlimitedViews = Int(Int32.max)

    var isVideo: Bool {
        type == .video || type == .privateVideo || type == .nonExpiringVideo
    }

    var isViewLimitedVideo: Bool {
        guard isVideo, let maxViews = body?.maxViews else { return false }
        return maxViews < Self.unlimitedViews
    }

    var mediaCacheKey: String? {
        if let hash = body?.imageHash ?? body?.mediaHash {
            let normalized = chatMediaController.normalizeHash(hash)
            if chatMediaController.isValidHash(normalized) { return normalized }
        }
        if let urlStr = body?.url ?? body?.urlPath, let url = URL(string: urlStr) {
            let hash = (url.lastPathComponent as NSString).deletingPathExtension
            let normalized = chatMediaController.normalizeHash(hash)
            if chatMediaController.isValidHash(normalized) { return normalized }
        }
        if let mediaId = body?.mediaId {
            let hash = "media-\(Int64(mediaId))"
            return chatMediaController.normalizeHash(hash)
        }
        return nil
    }
}
