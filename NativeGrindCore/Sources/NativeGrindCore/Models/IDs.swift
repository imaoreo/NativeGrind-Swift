//
//  IDs.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

public struct ProfileID: Decodable, Equatable, Sendable {
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
    public func getDetails() async throws -> Profile? {
        
        let result = try await APIClient.shared.request(.getProfile(profileId: rawValue))
        
        return result?.profiles.first
    }
}
