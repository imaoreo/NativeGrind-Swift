//
//  wsMessageEnvelope.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 09/07/2026.
//

public struct wsMessageEnvelope<T> {
    public let event: String
    public let payload: T?
    public let clientTime: Int64?
    
    public init(event: String, payload: T?, clientTime: Int64? = nil) {
        self.event = event
        self.payload = payload
        self.clientTime = clientTime
    }
    
    private enum CodingKeys: String, CodingKey {
        case event
        case payload
        case clientTime
    }
}

struct wsRawEnvelope: Decodable {
    let event: String
}

extension wsMessageEnvelope: Decodable where T: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.event = try container.decode(String.self, forKey: .event)
        self.payload = try container.decodeIfPresent(T.self, forKey: .payload)
        self.clientTime = try container.decodeIfPresent(Int64.self, forKey: .clientTime)
    }
}

extension wsMessageEnvelope: Encodable where T: Encodable {
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(event, forKey: .event)
        try container.encodeIfPresent(payload, forKey: .payload)
        try container.encodeIfPresent(clientTime, forKey: .clientTime)
    }
}
