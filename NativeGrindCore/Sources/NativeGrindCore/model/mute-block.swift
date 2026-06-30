//
//  mute-block.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 30/06/2026.
//

///-MARK Mute Responses
public struct getMutedProfilesResponseV4: Codable, Sendable {
    public let profileIds: [String]
}

///-MARK Block Responses
public struct getBlockedProfilesResponseV31: Codable, Sendable {
    public let blocking: [blockedProfile]
}

public struct blockedProfile: Codable, Sendable {
    public let profileId: String
    public let blockedTime: Int // Seems to be 0 idk why
}
