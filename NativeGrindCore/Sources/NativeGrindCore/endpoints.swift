//
//  endpoints.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 14/06/2026.
//

import Foundation

/// The generic container that binds a network route to a specific response model.
public struct endpoint<Response: Decodable> {
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [String: String]?
    public let body: [String: Any]?
    public let isAuthedRoute: Bool
    public let networkHandlers: [networkHandler]
    public let shouldRetryOn401: Bool
    public let baseURL: baseURL
    
    public var fullURLString: String {
        return baseURL.rawValue + path
    }
    
    public init(
        path: String,
        method: HTTPMethod,
        queryItems: [String: String]? = nil,
        body: [String: Any]? = nil,
        isAuthedRoute: Bool,
        networkHandlers: [networkHandler],
        shouldRetryOn401: Bool = true,
        baseURL: baseURL = .main
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.isAuthedRoute = isAuthedRoute
        self.networkHandlers = networkHandlers
        self.shouldRetryOn401 = shouldRetryOn401
        self.baseURL = baseURL
    }
}

/// Routes with their corresponding response models.
public extension endpoint {
    
    // Auth Routes
    static func login(email: String, password: String) -> endpoint<authenticationResponse> {
        return endpoint<authenticationResponse>(
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
                networkHandler(code: 403, jsonLocation: "message", jsonLocationValue: "Invalid input parameters", message: "Email or password are incorrect", header: "Login Error", level: .error, match: .matchBoth)
            ],
            shouldRetryOn401: false
        )
    }
    
    static func refreshToken(email: String, token: String) -> endpoint<authenticationResponse> {
        return endpoint<authenticationResponse>(
            path: "/v8/sessions",
            method: .post,
            queryItems: nil,
            body: [
                "email": email,
                "authToken": token,
            ],
            isAuthedRoute: false,
            networkHandlers: [
                networkHandler(code: 403, jsonLocation: "message", jsonLocationValue: "Invalid input parameters", message: "Issue refreshing", header: "Login Error", level: .error, match: .matchBoth)
            ],
            shouldRetryOn401: false
        )
    }
    
    static func refreshThirdParty(thirdPartyUserId: String, authToken: String) -> endpoint<thirdPartyAuthResponse> {
        return endpoint<thirdPartyAuthResponse>(
            path: "/v8/sessions/thirdparty",
            method: .post,
            queryItems: nil,
            body: [
                "thirdPartyUserId": thirdPartyUserId, // this is like google111659523269679641630, or facebook985658287553855
                "authToken": authToken,
            ],
            isAuthedRoute: false,
            networkHandlers: [],
            shouldRetryOn401: false
        )
    }
    
    static func thirdPartyLogin(token: String, isFacebook: Bool ) -> endpoint<thirdPartyAuthResponse> {
        return endpoint<thirdPartyAuthResponse>(
            path: "/v8/sessions/thirdparty",
            method: .post,
            queryItems: isFacebook ? ["allowFacebookLimitedLogin": "true"] : nil,
            body: [
                "thirdPartyToken": token,
                "thirdPartyVendor": isFacebook ? 1 : 2
            ],
            isAuthedRoute: false,
            networkHandlers: [],
            shouldRetryOn401: false
        )
    }
    
    // Public
    static var getGenders: endpoint<[gender]> {
        return endpoint<[gender]>(
            path: "/public/v2/genders",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: false,
            networkHandlers: []
        )
    }
    
    static var getPronouns: endpoint<[pronoun]> {
        return endpoint<[pronoun]>(
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
         positions: [sexualPosition]? = nil
    ) -> endpoint<inboxResponse> {
        
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
        var filteredBody: [String: Any]? = rawBody.compactMapValues { $0 }
        
        if filteredBody?.isEmpty == true {
            filteredBody = nil
        }
        
        return endpoint<inboxResponse>(
            path: "/v3/inbox",
            method: .post,
            queryItems: queryItems,
            body: filteredBody,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    // Profiles
    
    static func getProfile(profileId: String) -> endpoint<profileResponse> {
        return endpoint<profileResponse>(
            path: "/v7/profiles/\(profileId)",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    // Age Verification
    
    static func getAgeVerificationOptions()  -> endpoint<ageVerificationOptionsResponse> {
        return endpoint<ageVerificationOptionsResponse>(
            path: "/v1/age-verification/options",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    static func getAgeVerificationSession() -> endpoint<ageVerificationSessionResponse> {
        return endpoint<ageVerificationSessionResponse>(
            path: "/v1/age-verification/session",
            method: .post,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    // Voice Chat
    
    // Profile
    
    static func getPreferenceSettings() -> endpoint<preferenceSettingResponse> {
        return endpoint<preferenceSettingResponse>(
            path: "/v3/me/prefs/settings",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    // Views / Taps
    
    static func getViewV6() -> endpoint<viewResponseV6> {
        return endpoint<viewResponseV6>(
            path: "/v6/views/eyeball",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    static func getViewsV7() -> endpoint<viewsResponseV7> {
        return endpoint<viewsResponseV7>(
            path: "/v7/views/list",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    static func getTapsV2() -> endpoint<getTapsResponseV2> {
        return endpoint<getTapsResponseV2>(
            path: "/v2/taps/received",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    // Mutes / Blocks
    
    static func getMutedProfilesV4() -> endpoint<getMutedProfilesResponseV4> {
        return endpoint<getMutedProfilesResponseV4>(
            path: "/v4/me/muted-profiles",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    static func getBlockedProfilesV31() -> endpoint<getBlockedProfilesResponseV31> {
        return endpoint<getBlockedProfilesResponseV31>(
            path: "/v3.1/me/blocks",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    // Images
    
    static func getProfileImage(size: imageSizes, mediaHash: String) -> endpoint<Data> {
        return endpoint<Data>(
            path: "/images/profile/\(size.rawValue)/\(mediaHash)",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: false,
            networkHandlers: [],
            baseURL: .cdn
        )
    }
}
