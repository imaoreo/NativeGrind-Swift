//
//  demoMode.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 26/09/2026.
//

#if DEBUG
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum demoMode {
    public static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-demo")
    }

    public static var startTab: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-demoTab"), args.indices.contains(index + 1) else { return nil }
        return args[index + 1]
    }

    public static let ownProfileId = 1_000
    public static let geohash = "gcvwr3"

    struct demoPerson {
        let id: Int
        let name: String
        let age: Int
        let distance: Int
        let online: Bool
        let about: String
        let hue: CGFloat

        var hash: String { "demo-\(id)" }
    }

    static let people: [demoPerson] = [
        demoPerson(id: 2000, name: "Alex", age: 29, distance: 350, online: true, about: "Coffee first, then conversation ☕️", hue: 0.08),
        demoPerson(id: 2001, name: "Sam", age: 31, distance: 620, online: true, about: "Climber, cook, terrible at karaoke.", hue: 0.55),
        demoPerson(id: 2002, name: "Jordan", age: 27, distance: 900, online: false, about: "New to the city, show me around?", hue: 0.75),
        demoPerson(id: 2003, name: "Theo", age: 34, distance: 1200, online: true, about: "Architect. Dog dad. Sunday runs.", hue: 0.33),
        demoPerson(id: 2004, name: "Luca", age: 25, distance: 1500, online: false, about: "Here for good chats and good food.", hue: 0.95),
        demoPerson(id: 2005, name: "Kai", age: 30, distance: 1800, online: true, about: "Photographer 📷", hue: 0.62),
        demoPerson(id: 2006, name: "Noah", age: 36, distance: 2100, online: false, about: "Books, board games and long walks.", hue: 0.12),
        demoPerson(id: 2007, name: "Ellis", age: 28, distance: 2400, online: true, about: "Music festivals all summer.", hue: 0.45),
        demoPerson(id: 2008, name: "Rory", age: 33, distance: 2800, online: false, about: "Nurse. Night owl.", hue: 0.85),
        demoPerson(id: 2009, name: "Finn", age: 24, distance: 3100, online: true, about: "Student, barista, occasional DJ.", hue: 0.02),
        demoPerson(id: 2010, name: "Jamie", age: 38, distance: 3500, online: false, about: "Gin and good company.", hue: 0.5),
        demoPerson(id: 2011, name: "Oscar", age: 26, distance: 3900, online: true, about: "Gym, then pizza. Balance.", hue: 0.68),
        demoPerson(id: 2012, name: "Leo", age: 32, distance: 4300, online: false, about: "Just moved from Glasgow.", hue: 0.18),
        demoPerson(id: 2013, name: "Remy", age: 29, distance: 4800, online: true, about: "Film nerd 🎬", hue: 0.9),
        demoPerson(id: 2014, name: "Ash", age: 35, distance: 5200, online: false, about: "Weekend hiker.", hue: 0.38),
    ]

    static func find(id: Int) -> demoPerson? {
        people.first { $0.id == id }
    }

    static var now: Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}

public final class demoURLProtocol: URLProtocol {
    public override class func canInit(with request: URLRequest) -> Bool { true }
    public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    public override func stopLoading() {}

    public override func startLoading() {
        guard let url = request.url else { return }
        let (status, data, type) = demoResponses.response(for: url)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": type])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
}

enum demoResponses {
    static func response(for url: URL) -> (Int, Data, String) {
        let path = url.path

        if url.host?.contains("cdns.grindr.com") == true {
            let id = Int(url.lastPathComponent.replacingOccurrences(of: "demo-", with: "")) ?? 0
            return (200, demoImages.avatar(hue: demoMode.find(id: id)?.hue ?? 0.6), "image/png")
        }
        if url.host?.contains("nativeserver") == true {
            return (404, Data(), "text/plain")
        }

        let body: Any
        if path == "/v3/cascade" {
            body = grid()
        } else if path.hasPrefix("/v7/profiles/"), let id = Int(url.lastPathComponent), let person = demoMode.find(id: id) {
            body = ["profiles": [profile(person)]]
        } else if path == "/v3/inbox" {
            let page = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "page" }?.value
            body = inbox(firstPage: page == nil || page == "1")
        } else if path == "/v7/views/list" {
            body = views()
        } else if path == "/v2/taps/received" {
            body = taps()
        } else if path.hasPrefix("/v5/chat/conversation/"), path.hasSuffix("/message") {
            let conversationId = path.split(separator: "/").dropLast().last.map(String.init) ?? ""
            body = messages(conversationId: conversationId)
        } else if path.hasPrefix("/v2/albums/shares/") {
            body = ["albums": []]
        } else {
            body = [String: Any]()
        }

        let data = (try? JSONSerialization.data(withJSONObject: body)) ?? Data()
        return (200, data, "application/json")
    }

    private static func grid() -> [String: Any] {
        let items: [[String: Any]] = demoMode.people.map { person in
            var data: [String: Any] = [
                "profileId": person.id,
                "displayName": person.name,
                "age": person.age,
                "distanceMeters": person.distance,
                "photoMediaHashes": [person.hash],
                "hasPhoto": true,
            ]
            if person.online {
                data["onlineUntil"] = demoMode.now + 600_000
            }
            return ["type": "full_profile_v1", "data": data]
        }
        return ["items": items]
    }

    private static func profile(_ person: demoMode.demoPerson) -> [String: Any] {
        [
            "profileId": String(person.id),
            "displayName": person.name,
            "age": person.age,
            "distance": Double(person.distance),
            "profileImageMediaHash": person.hash,
            "aboutMe": person.about,
            "isFavorite": false,
            "rightNow": "NOT_ACTIVE",
            "sexualPosition": 3,
            "showAge": true,
            "showDistance": true,
            "approximateDistance": false,
            "isNew": false,
            "lastUpdatedTime": Int(demoMode.now / 1000),
            "medias": [["mediaHash": person.hash, "type": 1, "state": 1]],
            "genders": [],
            "pronouns": [],
            "showTribes": false,
            "showPosition": true,
            "grindrTribes": [],
            "lookingFor": [],
            "height": 178.0,
            "weight": 74_000.0,
            "socialNetworks": [String: Any](),
            "hashtags": [],
            "profileTags": ["Coffee", "Hiking", "Films"],
            "tapped": false,
            "isTeleporting": false,
            "isRoaming": false,
            "sexualHealth": [],
            "isVisiting": false,
            "travelPlans": [],
            "isInAList": false,
            "showVipBadge": false,
        ]
    }

    private static let chats: [(id: Int, lines: [(mine: Bool, text: String)])] = [
        (2000, [(false, "Hey! How's your week going?"), (true, "Pretty good, just finished work 🙌"), (false, "Fancy grabbing a coffee later?")]),
        (2001, [(true, "That climbing wall looked brutal"), (false, "My arms still hurt 😂")]),
        (2003, [(false, "Morning! Did you make the run?"), (true, "Just about, see you Sunday")]),
        (2005, [(false, "Sent you the photos from Saturday")]),
        (2007, [(true, "Are you going this weekend?"), (false, "Wouldn't miss it")]),
        (2009, [(false, "Thanks for the playlist!")]),
    ]

    private static func conversationId(_ other: Int) -> String {
        "\(demoMode.ownProfileId):\(other)"
    }

    private static func inbox(firstPage: Bool) -> [String: Any] {
        let entries: [[String: Any]] = firstPage ? chats.enumerated().compactMap { index, chat in
            guard let person = demoMode.find(id: chat.id), let last = chat.lines.last else { return nil }
            let timestamp = demoMode.now - Int64(index) * 47 * 60_000
            let sender = last.mine ? demoMode.ownProfileId : person.id
            return [
                "type": "full_conversation_v1",
                "data": [
                    "conversationId": conversationId(person.id),
                    "name": person.name,
                    "participants": [[
                        "profileId": person.id,
                        "primaryMediaHash": person.hash,
                        "distanceMetres": Double(person.distance),
                        "isInAList": false,
                        "hasDatingPotential": false,
                    ]],
                    "lastActivityTimestamp": Int(timestamp),
                    "unreadCount": index == 1 || index == 3 ? 1 : 0,
                    "preview": [
                        "conversationId": conversationId(person.id),
                        "messageId": "\(timestamp):demo-\(person.id)",
                        "chat1MessageId": UUID().uuidString,
                        "senderId": sender,
                        "type": "Text",
                        "text": last.text,
                    ],
                    "muted": false,
                    "pinned": index == 0,
                    "favorite": false,
                    "translatable": false,
                    "rightNow": "NOT_ACTIVE",
                    "hasUnreadThrob": false,
                ] as [String: Any],
            ]
        } : []

        return [
            "entries": entries,
            "showsFreeHeaderLabel": false,
            "totalFullConversations": entries.count,
            "totalPartialConversations": 0,
            "maxDisplayLockCount": 0,
            "nextPage": 0,
        ]
    }

    private static func messages(conversationId: String) -> [String: Any] {
        let other = Int(conversationId.split(separator: ":").last ?? "") ?? 0
        let lines = chats.first { $0.id == other }?.lines ?? []
        let start = demoMode.now - Int64(lines.count) * 6 * 60_000

        let messages: [[String: Any]] = lines.enumerated().map { index, line in
            let timestamp = start + Int64(index) * 6 * 60_000
            return [
                "messageId": "\(timestamp):demo-\(other)-\(index)",
                "conversationId": conversationId,
                "senderId": line.mine ? demoMode.ownProfileId : other,
                "timestamp": timestamp,
                "unsent": false,
                "reactions": [],
                "type": "Text",
                "body": ["text": line.text],
            ]
        }

        var body: [String: Any] = ["messages": messages, "lastReadTimestamp": demoMode.now]
        if let person = demoMode.find(id: other) {
            body["profile"] = ["profileId": person.id, "name": person.name, "mediaHash": person.hash]
        }
        return body
    }

    private static func views() -> [String: Any] {
        let viewers = demoMode.people.dropFirst(3).prefix(8).enumerated().map { index, person -> [String: Any] in
            [
                "profileId": String(person.id),
                "displayName": person.name,
                "profileImageMediaHash": person.hash,
                "age": person.age,
                "showAge": true,
                "distance": Double(person.distance),
                "showDistance": true,
                "lastViewed": demoMode.now - Int64(index) * 25 * 60_000,
                "isNew": index < 2,
            ]
        }
        return ["totalViewers": viewers.count, "profiles": viewers, "previews": []]
    }

    private static func taps() -> [String: Any] {
        let tappers = demoMode.people.dropFirst(1).prefix(5).enumerated().map { index, person -> [String: Any] in
            [
                "profileId": person.id,
                "displayName": person.name,
                "profileImageMediaHash": person.hash,
                "distance": Double(person.distance),
                "timestamp": demoMode.now - Int64(index) * 40 * 60_000,
                "tapType": index % 3,
                "isMutual": index == 0,
            ]
        }
        return ["profiles": tappers]
    }
}

enum demoImages {
    nonisolated(unsafe) private static var cache: [CGFloat: Data] = [:]
    private static let lock = NSLock()

    static func avatar(hue: CGFloat) -> Data {
        lock.lock()
        defer { lock.unlock() }
        if let cached = cache[hue] { return cached }

        let size = 600
        let space = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return Data()
        }

        let top = color(hue: hue, saturation: 0.55, brightness: 0.9)
        let bottom = color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1), saturation: 0.75, brightness: 0.55)
        if let gradient = CGGradient(colorsSpace: space, colors: [top, bottom] as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
        }

        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.28))
        context.fillEllipse(in: CGRect(x: 205, y: 290, width: 190, height: 190))
        context.fillEllipse(in: CGRect(x: 110, y: -120, width: 380, height: 380))

        guard let image = context.makeImage() else { return Data() }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return Data() }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)

        let data = output as Data
        cache[hue] = data
        return data
    }

    private static func color(hue: CGFloat, saturation: CGFloat, brightness: CGFloat) -> CGColor {
        let i = Int(hue * 6) % 6
        let f = hue * 6 - CGFloat(Int(hue * 6))
        let p = brightness * (1 - saturation)
        let q = brightness * (1 - f * saturation)
        let t = brightness * (1 - (1 - f) * saturation)
        let (r, g, b): (CGFloat, CGFloat, CGFloat)
        switch i {
        case 0: (r, g, b) = (brightness, t, p)
        case 1: (r, g, b) = (q, brightness, p)
        case 2: (r, g, b) = (p, brightness, t)
        case 3: (r, g, b) = (p, q, brightness)
        case 4: (r, g, b) = (t, p, brightness)
        default: (r, g, b) = (brightness, p, q)
        }
        return CGColor(red: r, green: g, blue: b, alpha: 1)
    }
}
#endif
