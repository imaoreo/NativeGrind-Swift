//
//  ids.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

import Foundation

public struct profileId: Decodable, Equatable, Sendable {
    public let rawValue: String
    
    // This is for Decoder
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }
    
    // If creating manually
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    // Special ass shit
    public func getDetails() async throws -> profile? {
        
        let result = try await APIClient.shared.request(.getProfile(profileId: rawValue))
        
        return result?.profiles.first
    }
}

public struct SessionID: Decodable, Equatable, Sendable {
    public let rawValue: String
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(String.self)
    }
    
    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }
    
    /// Checks if the JWT is past its expiration date
    public var isExpired: Bool {
        guard let exp = timeClaim(for: "exp") else {
            return true // Treat as expired if we can't read the date safely
        }
        return Date() >= Date(timeIntervalSince1970: exp)
    }
    
    private func stringClaim(for key: String) -> String? {
        let segments = rawValue.components(separatedBy: ".")
        guard segments.count == 3,
              let payload = decodeJWTPart(from: segments[1]) else { return nil }
        
        return payload[key] as? String
    }
    
    private func timeClaim(for key: String) -> TimeInterval? {
        let segments = rawValue.components(separatedBy: ".")
        guard segments.count == 3,
              let payload = decodeJWTPart(from: segments[1]) else { return nil }
        
        return payload[key] as? TimeInterval
    }
    
    private func decodeJWTPart(from base64Url: String) -> [String: Any]? {
        // Transfer to base64 from base64URL
        var base64 = base64Url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding to make multiples of 4
        let length = Double(base64.lengthOfBytes(using: .utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = Int(requiredLength - length)
        if paddingLength > 0 {
            let padding = String(repeating: "=", count: paddingLength)
            base64 += padding
        }
        
        // Decode the base64 string into a JSON object
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
              let json = try? JSONSerialization.jsonObject(with: data, options: []),
              let payload = json as? [String: Any] else {
            return nil
        }
        
        return payload
    }
}
