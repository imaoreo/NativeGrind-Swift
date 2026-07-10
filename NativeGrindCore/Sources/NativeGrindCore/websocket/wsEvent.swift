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
    static var onChallenge: wsEvent<challengeResponse> {
        return wsEvent<challengeResponse>(domain: .nativeServer, eventName: "challenge")
    }
    
    static var onAttestVerify: wsEvent<challengeCheckedResponse> {
        return wsEvent<challengeCheckedResponse>(domain: .nativeServer, eventName: "attestation_verified")
    }

    static var onIdentityVerify: wsEvent<challengeCheckedResponse> {
        return wsEvent<challengeCheckedResponse>(domain: .nativeServer, eventName: "identity_verified")
    }

    static var onPairingInitiated: wsEvent<pairingInitiatedResponse> {
        return wsEvent<pairingInitiatedResponse>(domain: .nativeServer, eventName: "pairing_initiated")
    }

    static var onAuthorizePrompt: wsEvent<authorizePromptResponse> {
        return wsEvent<authorizePromptResponse>(domain: .nativeServer, eventName: "authorize_prompt")
    }

    static var onCompanionAuthorized: wsEvent<companionAuthorizedResponse> {
        return wsEvent<companionAuthorizedResponse>(domain: .nativeServer, eventName: "companion_authorized")
    }

    static var onCompanionNotification: wsEvent<wsCompanionNotification> {
        return wsEvent<wsCompanionNotification>(domain: .nativeServer, eventName: "authorized")
    }

    static var onAuthStatus: wsEvent<wsAuthStatusResponse> {
        return wsEvent<wsAuthStatusResponse>(domain: .nativeServer, eventName: "auth_status")
    }

}
