//
//  interestDecodingTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 25/09/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Views & Taps Decoding Tests")
struct interestDecodingTests {

    // Same decoder APIClient uses
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(T.self, from: Data(json.utf8))
    }

    @Test("Viewers decode with ms timestamps, a single sexualPosition, newer rightNowStatus values and a broken entry skipped")
    func testViewsList() throws {
        let response = try decode(viewsResponseV7.self, """
        {
          "totalViewers": 3,
          "profiles": [
            { "profileId": "771038429", "displayName": "Joey", "profileImageMediaHash": "3df72e1c", "age": 24, "showAge": true,
              "distance": 1250.5, "showDistance": true, "lastViewed": 1788915686135, "seen": 1788915686135, "onlineUntil": 1788916286135,
              "isFavorite": true, "isNew": true, "isSecretAdmirer": false, "isIncognito": false, "foundVia": "DISCOVER",
              "sexualPosition": 3, "rightNow": "NOT_ACTIVE", "rightNowStatus": "ACTIVE",
              "viewedCount": { "totalCount": 4, "maxDisplayCount": 99 }, "unreadMessageCount": 0, "hasChatted": true,
              "medias": [], "boosting": false, "hasFaceRecognition": false, "lastUpdatedTime": 0 },
            { "displayName": "no profile id, should be skipped" }
          ],
          "previews": [
            { "profileImageMediaHash": "blurred1", "distance": 500, "lastViewed": 1788915000000, "isSecretAdmirer": true,
              "isFavorite": false, "isInBadNeighborhood": false, "isViewedMeFreshFace": false, "rightNow": "NOT_ACTIVE",
              "viewedCount": { "totalCount": 1, "maxDisplayCount": 99 } }
          ],
          "ttl": 300, "lastProfileId": null
        }
        """)

        #expect(response.totalViewers == 3)
        #expect(response.profiles.count == 1)
        #expect(response.previews.count == 1)

        let joey = try #require(response.profiles.first)
        #expect(joey.displayName == "Joey")
        #expect(joey.age == 24)
        #expect(joey.viewedCount?.totalCount == 4)
        // 1788915686135 ms is September 2026, seconds would put it in the year 58,000
        #expect(Calendar(identifier: .gregorian).component(.year, from: try #require(joey.lastViewedDate)) == 2026)
        #expect(response.previews.first?.isSecretAdmirer == true)
    }

    @Test("Real taps response: numeric profile ids, null names, photos and distances")
    func testRealTapsShape() throws {
        let response = try decode(getTapsResponseV2.self, """
        { "profiles": [
            { "profileId": 870944239, "displayName": null, "profileImageMediaHash": "675379342e9a23fa32c7928e341a2354b9a1514a",
              "distance": 1296424.3, "isFavorite": false, "timestamp": 1790284174296, "tapType": 1, "lastOnline": 1790289430000,
              "isBoosting": false, "isMutual": false, "rightNowType": "NOT_ACTIVE", "isViewable": true, "onlineUntil": null,
              "unreadMessageCount": 0, "hasChatted": false, "rightNowStatus": "NONE", "receivedDuringBoost": false },
            { "profileId": 919781182, "displayName": null, "profileImageMediaHash": null, "distance": null, "isFavorite": false,
              "timestamp": 1790212204420, "tapType": 1, "lastOnline": null, "isBoosting": false, "isMutual": false,
              "rightNowType": "NOT_ACTIVE", "isViewable": true, "onlineUntil": 1790292910000, "unreadMessageCount": 0,
              "hasChatted": true, "rightNowStatus": "NONE", "receivedDuringBoost": false }
        ] }
        """)

        #expect(response.profiles.count == 2)
        #expect(response.profiles.map(\.profileId) == ["870944239", "919781182"])
        #expect(response.profiles[0].displayName == nil)
        #expect(response.profiles[0].distance == 1296424.3)
        #expect(response.profiles[1].distance == nil)
        #expect(response.profiles[1].profileImageMediaHash == nil)
    }

    @Test("Viewers with numeric profile ids decode too")
    func testNumericViewerId() throws {
        let viewer = try decode(profileViewsResponseV7.self, #"{ "profileId": 771038429, "displayName": "Joey" }"#)
        #expect(viewer.profileId == "771038429")
    }

    @Test("A hidden age of 0 becomes nil")
    func testHiddenAge() throws {
        let viewer = try decode(profileViewsResponseV7.self, #"{ "profileId": "1", "age": 0, "showAge": false }"#)
        #expect(viewer.age == nil)
    }

    @Test("Taps decode every tap type, ms timestamps and unknown types fall back to none")
    func testTaps() throws {
        let response = try decode(getTapsResponseV2.self, """
        { "profiles": [
            { "profileId": "1", "displayName": "A", "timestamp": 1788915686135, "tapType": 0, "isMutual": false, "lastOnline": 1788915686135,
              "isBoosting": false, "rightNowType": "NOT_ACTIVE", "isViewable": true, "isFavorite": false, "hasChatted": false, "unreadMessageCount": 0 },
            { "profileId": "2", "timestamp": 1788915686136, "tapType": 2, "isMutual": true },
            { "profileId": "3", "timestamp": 1788915686137, "tapType": 9 }
        ] }
        """)

        #expect(response.profiles.map(\.tapType) == [.friendly, .looking, .none])
        #expect(response.profiles[1].isMutual)
        #expect(Calendar(identifier: .gregorian).component(.year, from: response.profiles[0].date) == 2026)
    }
}
