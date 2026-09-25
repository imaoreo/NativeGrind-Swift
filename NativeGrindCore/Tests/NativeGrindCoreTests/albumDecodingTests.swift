//
//  albumDecodingTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 25/09/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Album Decoding Tests")
struct albumDecodingTests {

    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test("Albums decode with numeric ids, photos and videos, and a broken item is skipped")
    func testAlbumDetails() throws {
        let album = try decode(albumDetails.self, """
        { "albumId": 852120758, "albumNumber": 1, "totalAlbumsShared": 1, "hasUnseenContent": true, "albumName": null,
          "profileId": 870944239, "albumViewable": true, "sharedCount": 3, "createdAt": "2026-03-27T20:39:00",
          "updatedAt": "2026-03-27T20:39:00", "isShareable": true,
          "content": [
            { "contentId": 111, "contentType": "image/jpeg", "coverUrl": "https://cdn/blur.jpg", "statusId": 1,
              "thumbUrl": "https://cdn/thumb.jpg", "url": "https://cdn/full.jpg", "processing": false, "rejectionId": null, "remainingViews": -1 },
            { "contentId": 222, "contentType": "video/mp4", "coverUrl": null, "thumbUrl": "https://cdn/poster.jpg",
              "url": "https://cdn/video.mp4", "processing": false },
            { "contentType": "image/jpeg" }
          ] }
        """)

        #expect(album.albumId == "852120758")
        #expect(album.profileId == "870944239")
        #expect(album.content.map(\.contentId) == ["111", "222"])
        #expect(album.content[0].isVideo == false)
        #expect(album.content[1].isVideo == true)
        #expect(album.content[0].remainingViews == -1)
    }

    @Test("Albums shared by a profile decode with their counts and cover")
    func testSharedAlbums() throws {
        let response = try decode(albumsSharedResponse.self, """
        { "albums": [
            { "albumId": 1, "profileId": 870944239, "albumViewable": true, "expiresAt": null, "expirationType": "INDEFINITE",
              "content": { "contentId": 5, "contentType": "image/jpeg", "coverUrl": "https://cdn/blur.jpg", "statusId": 1 },
              "contentCount": { "imageCount": 4, "videoCount": 1 } }
        ] }
        """)

        let album = try #require(response.albums.first)
        #expect(album.albumId == "1")
        #expect(album.imageCount == 4)
        #expect(album.videoCount == 1)
        #expect(album.cover?.coverUrl == "https://cdn/blur.jpg")
    }

    @Test("A real locked album (albumViewable false) decodes as not viewable")
    func testLockedSharedAlbum() throws {
        let response = try decode(albumsSharedResponse.self, """
        { "albums": [ {
            "albumId": 158913953, "albumName": null,
            "content": { "contentId": 1049238759, "contentType": "image/jpeg", "coverUrl": "https://d3w4wp6rol9nvz.cloudfront.net/x.cover", "statusId": 1 },
            "profileId": 895118754, "hasUnseenContent": true, "albumViewable": false, "albumNumber": 1, "totalAlbumsShared": 1,
            "contentCount": { "imageCount": 2, "videoCount": 0 }, "expiresAt": null, "expirationType": "INDEFINITE"
        } ] }
        """)

        let album = try #require(response.albums.first)
        #expect(album.albumId == "158913953")
        #expect(album.profileId == "895118754")
        #expect(album.albumViewable == false)
        #expect(album.imageCount == 2)
        #expect(album.cover?.contentId == "1049238759")
    }

    @Test("NativeServer's backup listing decodes")
    func testBackupListing() throws {
        let backup = try decode(nsAlbumBackup.self, """
        { "albumId": "852120758", "ownerProfileId": "870944239",
          "items": [ { "contentId": "111", "contentType": "image/jpeg", "url": "/public/cache/albums/852120758/111", "createdAt": 1790284174296 } ] }
        """)
        #expect(backup.items.first?.url == "/public/cache/albums/852120758/111")
    }
}
