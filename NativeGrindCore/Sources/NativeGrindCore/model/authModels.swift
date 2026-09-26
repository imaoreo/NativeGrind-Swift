//
//  authModels.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

public enum thirdPartyVendor: Int, Sendable {
    case facebook = 1
    case google = 2
    case apple = 5
}

public struct thirdPartyAuthResponse: Codable, Sendable {
    public let authenticationResponse: thirdPartyAuthenticationResponse
    public let registered: Bool
    public let profileId: String?
    public let thirdPartyUserInfo: String?
}

public struct thirdPartyAuthenticationResponse: Codable, Sendable {
    public let profileId: String
    public let sessionId: sessionId
    public let xmppToken: String
    public let authToken: String
    public let thirdPartyUserId: String
    public let thirdPartyUserIdToShow: String
}

public struct authenticationResponse: Codable, Sendable {
    public let profileId: String
    public let sessionId: sessionId
    public let xmppToken: String
    public let authToken: String
}
