//
//  authModels.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

public struct thirdPartyAuthResponse: Decodable, Sendable {
    public let authenticationResponse: thirdPartyAuthenticationResponse
    public let registered: Bool
    public let profileId: String?
    public let thirdPartyUserInfo: String?
}

public struct thirdPartyAuthenticationResponse: Decodable, Sendable {
    public let profileId: String
    public let sessionId: SessionID
    public let xmppToken: String
    public let authToken: String
    public let thirdPartyUserId: String
    public let thirdPartyUserIdToShow: String
}

public struct authenticationResponse: Decodable, Sendable {
    public let profileId: String
    public let sessionId: SessionID
    public let xmppToken: String
    public let authToken: String
}
