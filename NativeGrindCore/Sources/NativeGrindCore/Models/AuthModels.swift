//
//  PublicModels.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

public struct ThirdPartyAuthResponse: Decodable, Sendable {
    public let authenticationResponse: AuthenticationResponse
    public let registered: Bool
    public let profileId: String?
    public let thirdPartyUserInfo: String?
}

public struct ThirdPartyAuthenticationResponse: Decodable, Sendable {
    public let profileId: String
    public let sessionId: String
    public let xmppToken: String
    public let authToken: String
    public let thirdPartyUserId: String
    public let thirdPartyUserIdToShow: String
}

public struct AuthenticationResponse: Decodable, Sendable {
    public let profileId: String
    public let sessionId: String
    public let xmppToken: String
    public let authToken: String
}
