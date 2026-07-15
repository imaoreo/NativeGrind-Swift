//
//  wsEvent.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 09/07/2026.
//

import Foundation

public struct wsEvent<Response: Decodable> {
    public let domain: wsDomain
    public let eventName: String
    
    public init(domain: wsDomain, eventName: String) {
        self.domain = domain
        self.eventName = eventName
    }
}

public extension wsEvent {
    static var onAuthChallenge: wsEvent<nsAuthChallengeResponse> {
        return wsEvent<nsAuthChallengeResponse>(domain: .nativeServer, eventName: "auth_challenge")
    }
    
    static var onAccountInfomation: wsEvent<nsAccountInfomationResponse> {
        return wsEvent<nsAccountInfomationResponse>(domain: .nativeServer, eventName: "get_account_info")
    }
}
