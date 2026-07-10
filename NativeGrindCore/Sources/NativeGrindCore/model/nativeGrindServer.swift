//
//  nativeGrindServer.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 02/07/2026.
//

import Foundation

public struct challengeResponse: Codable, Sendable {
    public let challenge: String
    public let ttl: Int
}

public struct challengeCheckedResponse: Codable, Sendable {
    public let status: String
    public let keyId: String?
    public let error: String?
}

public struct deviceAssertion: Codable, Sendable {
    public let assertion: String
    public let keyId: String
    public let challenge: String
    
    public init(assertion: String, keyId: String, challenge: String) {
        self.assertion = assertion
        self.keyId = keyId
        self.challenge = challenge
    }
}

public struct challengeHealthResponse: Codable, Sendable {
    public let status: String
    public let message: String
}

public struct initiatePairingRequest: Codable {
    public let wantLogin: Bool
    
    public init(wantLogin: Bool) {
        self.wantLogin = wantLogin
    }
}

public struct pairingInitiatedResponse: Codable {
    public let status: String
    public let sessionId: String
}

public struct authorizeCompanionRequest: Codable {
    public let sessionId: String
    public let keyId: String?
    public let assertion: String?
    public let challenge: String?
    
    public init(sessionId: String, keyId: String? = nil, assertion: String? = nil, challenge: String? = nil) {
        self.sessionId = sessionId
        self.keyId = keyId
        self.assertion = assertion
        self.challenge = challenge
    }
}

public struct authorizePromptResponse: Codable {
    public let sessionId: String
    public let message: String
}

public struct confirmAuthorizationRequest: Codable {
    public let sessionId: String
    public let approved: Bool
    public let clientSessionId: String?
    public let clientAuthToken: String?
    public let clientIsEmail: String?
    public let clientData: String?
    public let keyId: String?
    public let assertion: String?
    public let challenge: String?
    
    public init(
        sessionId: String,
        approved: Bool,
        clientSessionId: String? = nil,
        clientAuthToken: String? = nil,
        clientIsEmail: String? = nil,
        clientData: String? = nil,
        keyId: String? = nil,
        assertion: String? = nil,
        challenge: String? = nil
    ) {
        self.sessionId = sessionId
        self.approved = approved
        self.clientSessionId = clientSessionId
        self.clientAuthToken = clientAuthToken
        self.clientIsEmail = clientIsEmail
        self.clientData = clientData
        self.keyId = keyId
        self.assertion = assertion
        self.challenge = challenge
    }
}

public struct companionAuthorizedResponse: Codable {
    public let status: String
    public let apiKey: String
}

public struct wsCompanionNotification: Codable {
    public let type: String
    public let apiKey: String?
    public let clientSessionId: String?
    public let clientAuthToken: String?
    public let clientIsEmail: String?
    public let clientData: String?
}

public struct wsAuthStatusResponse: Codable, Sendable {
    public let isAuthed: Bool
    public let authType: String
}
