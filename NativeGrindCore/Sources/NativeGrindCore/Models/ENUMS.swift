//
//  ENUMS.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

public func removeENUM<T: RawRepresentable>(from items: [T]?) -> [T.RawValue]? {
    return items?.map { $0.rawValue }
}

public enum sexualPosition: Int, Decodable, Sendable {
    case top = 1
    case bottom = 2
    case versatile = 3
    case versBottom = 4
    case versTop = 5
    case side = 6
}

public enum conversationType: String, Decodable, Sendable {
    case fullConversationV1 = "full_conversation_v1"
    case unknown

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)
        self = conversationType(rawValue: rawString) ?? .unknown
    }
}

public enum messageType: String, Decodable, Sendable {
    case album = "Album"
    case albumContentReaction = "AlbumContentReaction"
    case albumContentReply = "AlbumContentReply"
    case audio = "Audio"
    case expiringAlbum = "ExpiringAlbum"
    case expiringAlbumV2 = "ExpiringAlbumV2"
    case expiringImage = "ExpiringImage"
    case video = "Video"
    case gaymoji = "Gaymoji"
    case generative = "Generative"
    case giphy = "Giphy"
    case image = "Image"
    case location = "Location"
    case privateVideo = "PrivateVideo"
    case profileLink = "ProfileLink"
    case profilePhotoReply = "ProfilePhotoReply"
    case retract = "Retract"
    case text = "Text"
    case unknown = "Unknown"
    case nonExpiringVideo = "NonExpiringVideo"
    case videoCall = "VideoCall"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)
        self = messageType(rawValue: rawString) ?? .unknown
    }
}

public enum chat1MessageType: String, Decodable, Sendable {
    case map = "map"
    case image = "image"
    case expiringAlbum = "expiring_album"
    case expiringImage = "expiring_image"
    case privateVideo = "private_video"
    case expiringVideo = "expiring_video"
    case gaymoji = "gaymoji"
    case giphy = "giphy"
    case audio = "audio"
    case videoCall = "video_call"
    case videoCallV3 = "video_call_v3"
    case audioCall = "audio_call"
    case text = "text"
    case unknown = "unknown"
    case retracted = "retracted"
    case retractedLocation = "retracted_location"
    case albumShare = "album_share"
    case albumReact = "album_react"
    case albumContentReaction = "album_content_reaction"
    case albumContentReply = "album_content_reply"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)
        self = chat1MessageType(rawValue: rawString) ?? .unknown
    }
}

public enum rightNowStatus: String, Decodable, Sendable {
    case notActive = "NOT_ACTIVE"
    case hosting = "HOSTING"
    case notHosting = "NOT_HOSTING"
}

public enum viewSource: String, Decodable, Sendable {
    case discover = "DISCOVER"
    case forYou = "FOR_YOU"
    case unknown = "UNKOWN"
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawString = try container.decode(String.self)
        self = viewSource(rawValue: rawString) ?? .unknown
    }
}

public enum meetAt: Int, Decodable, Sendable {
    case myPlace = 1
    case yourPlace = 2
    case bar = 3
    case coffeeShop = 4
    case restaurant = 5
}

public enum vaccines: Int, Decodable, Sendable {
    case covid19 = 1
    case monkeyPox = 2
    case meningitis = 3
}

public enum NSFWPics: Int, Decodable, Sendable {
    case never = 1
    case notAtFirst = 2
    case yesPlease = 3
}

public enum ethnicity: Int, Decodable, Sendable {
    case asian = 1
    case black = 2
    case latino = 3
    case middleEastern = 4
    case mixed = 5
    case nativeAmerican = 6
    case white = 7
    case other = 8
    case southAsian = 9
}

public enum relationshipStatus: Int, Decodable, Sendable {
    case single = 1
    case dating = 2
    case exclusive = 3
    case committed = 4
    case partnered = 5
    case engaged = 6
    case married = 7
    case openRelationship = 8
}

public enum tribes: Int, Decodable, Sendable {
    case bear = 1
    case cleanCut = 2
    case daddy = 3
    case discreet = 4
    case geek = 5
    case jock = 6
    case leather = 7
    case otter = 8
    case poz = 9
    case rugged = 10
    case trans = 11
    case twink = 12
    case sober = 13
}

public enum lookingFor: Int, Decodable, Sendable {
    case chat = 2
    case dates = 3
    case friends = 4
    case networking = 5
    case relationship = 6
    case hookups = 7
}

public enum bodyType: Int, Decodable, Sendable {
    case toned = 1
    case average = 2
    case large = 3
    case muscular = 4
    case slim = 5
    case stocky = 6
}

public enum HIVStatus: Int, Decodable, Sendable {
    case negative = 1
    case negativeOnPrep = 2
    case positive = 3
    case positiveUndetectable = 4
}

public enum tapType: Int, Decodable, Sendable {
    case friendly = 0
    case hot = 1
    case looking = 2
}

public enum sexualHealth: Int, Decodable, Sendable {
    case condoms = 1
    case doxyPEP = 2
    case PrEP = 3
    case HIVUndetectable = 4
    case preferToDiscuss = 5
}
