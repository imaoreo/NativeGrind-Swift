//
//  demoModeTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 26/09/2026.
//

#if DEBUG
import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Demo Mode Tests")
struct demoModeTests {
    private func decode<T: Decodable>(_ type: T.Type, _ url: String) throws -> T {
        let (status, data, _) = demoResponses.response(for: URL(string: url)!)
        #expect(status == 200)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(T.self, from: data)
    }

    @Test("Every demo screen's data decodes into the real models")
    func responsesDecode() throws {
        let grid = try decode(CascadeResponse.self, "https://grindr.mobi/v3/cascade?nearbyGeoHash=gcvwr3")
        #expect(grid.items.count == demoMode.people.count)

        let profile = try decode(profileResponse.self, "https://grindr.mobi/v7/profiles/2000")
        #expect(profile.profiles.first?.displayName == "Alex")

        let inbox = try decode(inboxResponse.self, "https://grindr.mobi/v3/inbox?page=1")
        #expect(!inbox.entries.isEmpty)
        let laterPage = try decode(inboxResponse.self, "https://grindr.mobi/v3/inbox?page=2")
        #expect(laterPage.entries.isEmpty)

        let views = try decode(viewsResponseV7.self, "https://grindr.mobi/v7/views/list")
        #expect(!views.profiles.isEmpty)

        let taps = try decode(getTapsResponseV2.self, "https://grindr.mobi/v2/taps/received")
        #expect(!taps.profiles.isEmpty)

        let chat = try decode(conversationMessagesResponse.self, "https://grindr.mobi/v5/chat/conversation/1000:2000/message")
        #expect(chat.messages.count == 3)
    }

    @Test("Placeholder photos are real PNGs and nothing goes to NativeServer")
    func imagesAndServer() {
        let (status, data, type) = demoResponses.response(for: URL(string: "https://cdns.grindr.com/images/profile/2048x2048/demo-2000")!)
        #expect(status == 200)
        #expect(type == "image/png")
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))

        let (serverStatus, _, _) = demoResponses.response(for: URL(string: "https://nativeserver.imaoreo.dev/public/cache/pfp/demo-2000.jpg")!)
        #expect(serverStatus == 404)
    }
}
#endif
