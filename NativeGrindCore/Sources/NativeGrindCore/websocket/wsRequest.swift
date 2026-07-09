//
//  wsRequest.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 09/07/2026.
//

import Foundation

public struct wsRequest<Payload: Codable> {
    public let domain: wsDomain
    public let eventName: String
    public let payload: Payload?
    
    public init(domain: wsDomain, eventName: String, payload: Payload? = nil) {
        self.domain = domain
        self.eventName = eventName
        self.payload = payload
    }
    
    public func encode() throws -> Data {
        let currentMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let envelope = wsMessageEnvelope(event: eventName, payload: payload, clientTime: currentMillis)
        return try JSONEncoder().encode(envelope)
    }
}

public extension wsRequest {

     static func getChallenge() -> wsRequest<String> {
        return wsRequest<String>(
            domain: .nativeServer,
            eventName: "get_challenge",
            payload: nil
        )
    }

    static func verifyAttestation(keyId: String, attestation: String, challenge: String) -> wsRequest<deviceAssertion> {
        return wsRequest<deviceAssertion>(
            domain: .nativeServer,
            eventName: "verify_attestation",
            payload: deviceAssertion(assertion: attestation, keyId: keyId, challenge: challenge)
        )
    }

    static func assertIdentity(keyId: String, assertion: String, challenge: String) -> wsRequest<deviceAssertion> {
        return wsRequest<deviceAssertion>(
            domain: .nativeServer,
            eventName: "assert_identity",
            payload: deviceAssertion(assertion: assertion, keyId: keyId, challenge: challenge)
        )
    }

    static func auth(apiKey: String) -> wsRequest<[String: String]> {
        return wsRequest<[String: String]>(
            domain: .nativeServer,
            eventName: "auth",
            payload: ["apiKey": apiKey]
        )
    }

    static func initiatePairing(wantLogin: Bool) -> wsRequest<InitiatePairingRequest> {
        return wsRequest<InitiatePairingRequest>(
            domain: .nativeServer,
            eventName: "initiate_pairing",
            payload: InitiatePairingRequest(wantLogin: wantLogin)
        )
    }

    static func authorizeCompanion(sessionId: String, keyId: String? = nil, assertion: String? = nil, challenge: String? = nil) -> wsRequest<AuthorizeCompanionRequest> {
        return wsRequest<AuthorizeCompanionRequest>(
            domain: .nativeServer,
            eventName: "authorize_companion",
            payload: AuthorizeCompanionRequest(sessionId: sessionId, keyId: keyId, assertion: assertion, challenge: challenge)
        )
    }

    static func confirmAuthorization(
        sessionId: String,
        approved: Bool,
        clientSessionId: String? = nil,
        clientAuthToken: String? = nil,
        clientIsEmail: String? = nil,
        clientData: String? = nil,
        keyId: String? = nil,
        assertion: String? = nil,
        challenge: String? = nil
    ) -> wsRequest<ConfirmAuthorizationRequest> {
        return wsRequest<ConfirmAuthorizationRequest>(
            domain: .nativeServer,
            eventName: "confirm_authorization",
            payload: ConfirmAuthorizationRequest(
                sessionId: sessionId,
                approved: approved,
                clientSessionId: clientSessionId,
                clientAuthToken: clientAuthToken,
                clientIsEmail: clientIsEmail,
                clientData: clientData,
                keyId: keyId,
                assertion: assertion,
                challenge: challenge
            )
        )
    }

    static func getAuthStatus() -> wsRequest<String> {
        return wsRequest<String>(
            domain: .nativeServer,
            eventName: "get_auth_status",
            payload: nil
        )
    }
}
