//
//  Endpoints.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 14/06/2026.
//

import Foundation

/// The generic container that binds a network route to a specific response model.
public struct Endpoint<Response: Decodable> {
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [String: String]?
    public let body: [String: Any]?
    public let isAuthedRoute: Bool
    public let networkHandlers: [networkHandler]
    
    private var baseURL: String {
        return "https://grindr.mobi"
    }
    
    public var fullURLString: String {
        return baseURL + path
    }
}

/// Routes with their corresponding response models.
public extension Endpoint {
    
    // Auth Routes
    static func login(email: String, password: String) -> Endpoint<AuthenticationResponse> {
        return Endpoint<AuthenticationResponse>(
            path: "/v8/sessions",
            method: .post,
            queryItems: nil,
            body: [
                "email": email,
                "password": password,
                "token": "" // This is for fcm Tokens
            ],
            isAuthedRoute: false,
            networkHandlers: [
                networkHandler(code: 403, jsonLocation: "message", jsonLocationValue: "Invalid input parameters", message: "Email or password are incorrect", header: "Loggin Error", level: .error, match: .matchBoth)
            ]
        )
    }
    
    static func refreshToken(email: String, token: String) -> Endpoint<AuthenticationResponse> {
        return Endpoint<AuthenticationResponse>(
            path: "/v8/sessions",
            method: .post,
            queryItems: nil,
            body: [
                "email": email,
                "authToken": token,
            ],
            isAuthedRoute: false,
            networkHandlers: [
                networkHandler(code: 403, jsonLocation: "message", jsonLocationValue: "Invalid input parameters", message: "Issue refreshing", header: "Loggin Error", level: .error, match: .matchBoth)
            ]
        )
    }
    
    static func refreshThirdParty(thirdPartyUserId: String, authToken: String) -> Endpoint<AuthenticationResponse> {
        return Endpoint<AuthenticationResponse>(
            path: "/v8/sessions/thirdparty",
            method: .post,
            queryItems: nil,
            body: [
                "thirdPartyUserId": thirdPartyUserId, // this is like google111659523269679641630, or facebook985658287553855
                "authToken": authToken,
            ],
            isAuthedRoute: false,
            networkHandlers: []
        )
    }
    
    static func thirdPartyLogin(token: String, isFacebook: Bool ) -> Endpoint<ThirdPartyAuthResponse> {
        return Endpoint<ThirdPartyAuthResponse>(
            path: "/v8/sessions/thirdparty",
            method: .post,
            queryItems: isFacebook ? ["allowFacebookLimitedLogin": "true"] : nil,
            body: [
                "thirdPartyToken": token,
                "thirdPartyVendor": isFacebook ? 1 : 2
            ],
            isAuthedRoute: false,
            networkHandlers: []
        )
    }
    
    // Public
    static var getGenders: Endpoint<[Gender]> {
        return Endpoint<[Gender]>(
            path: "/public/v2/genders",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: false,
            networkHandlers: []
        )
    }
    
    static var getPronouns: Endpoint<[Pronoun]> {
        return Endpoint<[Pronoun]>(
            path: "/public/v1/pronouns",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: false,
            networkHandlers: []
        )
    }
    
    // Inbox
    
    static func getInbox(
         page: Int? = nil,
         unreadOnly: Bool? = nil,
         chemistryOnly: Bool? = nil,
         favoritesOnly: Bool? = nil,
         rightNowOnly: Bool? = nil,
         onlineNowOnly: Bool? = nil,
         distanceMeters: Double? = nil,
         positions: [SexualPosition]? = nil
    ) -> Endpoint<InboxResponse> {
        
        let positionArray = removeENUM(from: positions)
        
        var queryItems: [String: String]? = nil
        if let page = page {
            queryItems = ["page": String(page)]
        }
        
        let rawBody: [String: Any?] = [
            "unreadOnly": unreadOnly,
            "chemistryOnly": chemistryOnly,
            "favoritesOnly": favoritesOnly,
            "rightNowOnly": rightNowOnly,
            "onlineNowOnly": onlineNowOnly,
            "distanceMeters": distanceMeters,
            "positions": positionArray
        ]
        
        // Removes ones that are nil
        let filteredBody = rawBody.compactMapValues { $0 }
        
        return Endpoint<InboxResponse>(
            path: "/v3/inbox",
            method: .post,
            queryItems: queryItems,
            body: filteredBody,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    // Profiles
    
    static func getProfile(profileId: String) -> Endpoint<ProfileResponse> {
        return Endpoint<ProfileResponse>(
            path: "/v7/profiles/\(profileId)",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
}
