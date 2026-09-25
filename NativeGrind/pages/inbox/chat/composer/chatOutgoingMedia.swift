//
//  chatOutgoingMedia.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 25/09/2026.
//

import SwiftUI
import AVFoundation
import ImageIO
import UniformTypeIdentifiers
import CoreTransferable
#if !os(tvOS)
import PhotosUI
#endif

struct chatOutgoingMedia: Identifiable {
    enum mediaKind {
        case photo
        case video(file: URL, lengthMs: Int64)
    }

    let id = UUID()
    let kind: mediaKind
    let data: Data
    let contentType: String

    var isVideo: Bool {
        if case .video = kind { return true }
        return false
    }

    private static let maxPhotoPixels = 2048

    static func photo(from data: Data) -> chatOutgoingMedia? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPhotoPixels
              ] as CFDictionary) else {
            return nil
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return chatOutgoingMedia(kind: .photo, data: output as Data, contentType: "image/jpeg")
    }

    static func video(from file: URL) async -> chatOutgoingMedia? {
        let asset = AVURLAsset(url: file)
        guard let duration = try? await asset.load(.duration),
              let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1280x720) else {
            return nil
        }

        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        do {
            try await session.export(to: output, as: .mp4)
        } catch {
            return nil
        }

        guard let data = try? Data(contentsOf: output) else { return nil }
        let lengthMs = Int64(duration.seconds * 1000)
        return chatOutgoingMedia(kind: .video(file: output, lengthMs: lengthMs), data: data, contentType: "video/mp4")
    }

    static func load(from file: URL) async -> chatOutgoingMedia? {
        let type = UTType(filenameExtension: file.pathExtension)
        if type?.conforms(to: .movie) == true || type?.conforms(to: .video) == true {
            return await video(from: file)
        }
        guard let data = try? Data(contentsOf: file) else { return nil }
        return photo(from: data)
    }

    #if !os(tvOS)
    static func load(from item: PhotosPickerItem) async -> chatOutgoingMedia? {
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
            guard let movie = try? await item.loadTransferable(type: pickedMovie.self) else { return nil }
            defer { try? FileManager.default.removeItem(at: movie.file) }
            return await video(from: movie.file)
        }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        return photo(from: data)
    }

    static func loadPicked(file: URL) async -> chatOutgoingMedia? {
        let accessing = file.startAccessingSecurityScopedResource()
        defer { if accessing { file.stopAccessingSecurityScopedResource() } }
        return await load(from: file)
    }
    #endif

    var lengthMs: Int64? {
        if case .video(_, let lengthMs) = kind { return lengthMs }
        return nil
    }

    func removeTemporaryFile() {
        if case .video(let file, _) = kind {
            try? FileManager.default.removeItem(at: file)
        }
    }
}

struct pickedMovie: Transferable {
    let file: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.file)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return pickedMovie(file: copy)
        }
    }
}
