//
//  endpoints.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 14/06/2026.
//

import Foundation

public struct endpoint<Response: Decodable> {
    public let path: String
    public let method: HTTPMethod
    public let queryItems: [String: String]?
    public let body: [String: Any]?
    public let rawBody: Data?
    public let contentType: String?
    public let headers: [String: String]
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
        rawBody: Data? = nil,
        contentType: String? = nil,
        headers: [String: String] = [:],
        isAuthedRoute: Bool,
        networkHandlers: [networkHandler],
        shouldRetryOn401: Bool = true,
        baseURL: baseURL = .main
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.body = body
        self.rawBody = rawBody
        self.contentType = contentType
        self.headers = headers
        self.isAuthedRoute = isAuthedRoute
        self.networkHandlers = networkHandlers
        self.shouldRetryOn401 = shouldRetryOn401
        self.baseURL = baseURL
    }
}

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
    static func getGenders() -> endpoint<[gender]> {
        return endpoint<[gender]>(
            path: "/public/v2/genders",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: false,
            networkHandlers: []
        )
    }
    
    static func getPronouns() -> endpoint<[pronoun]> {
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
    
    // Conversations

    static func getMessages(conversationId: String, pageKey: String? = nil, includeProfile: Bool = false) -> endpoint<conversationMessagesResponse> {
        var queryItems: [String: String] = [:]
        if let pageKey {
            queryItems["pageKey"] = pageKey
        }
        if includeProfile {
            queryItems["profile"] = "true"
        }

        return endpoint<conversationMessagesResponse>(
            path: "/v5/chat/conversation/\(conversationId)/message",
            method: .get,
            queryItems: queryItems.isEmpty ? nil : queryItems,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: [
                networkHandler(code: 403, jsonLocation: nil, jsonLocationValue: nil, message: "This conversation is no longer available", header: "Chat Error", level: .warn, match: .statusCodeOnly)
            ]
        )
    }

    static func getMessage(conversationId: String, messageId: String) -> endpoint<singleMessageResponse> {
        return endpoint<singleMessageResponse>(
            path: "/v4/chat/conversation/\(conversationId)/message/\(messageId)",
            method: .get,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }

    static func sendTextMessage(targetProfileId: Int, text: String) -> endpoint<chatMessage> {
        return sendMessage(targetProfileId: targetProfileId, type: .text, body: ["text": text])
    }

    static func sendLocationMessage(targetProfileId: Int, latitude: Double, longitude: Double) -> endpoint<chatMessage> {
        return sendMessage(targetProfileId: targetProfileId, type: .location, body: ["lat": latitude, "lon": longitude])
    }

    static func sendAudioMessage(targetProfileId: Int, mediaId: Int64) -> endpoint<chatMessage> {
        return sendMessage(targetProfileId: targetProfileId, type: .audio, body: ["mediaId": mediaId])
    }

    static func sendMessage(targetProfileId: Int, type: messageType, body: [String: Any]) -> endpoint<chatMessage> {
        return endpoint<chatMessage>(
            path: "/v4/chat/message/send",
            method: .post,
            queryItems: nil,
            body: [
                "type": type,
                "target": [
                    "type": messageTargetType.direct,
                    "targetId": targetProfileId
                ],
                "body": body
            ],
            isAuthedRoute: true,
            networkHandlers: [
                networkHandler(code: 403, jsonLocation: nil, jsonLocationValue: nil, message: "You can't message this profile", header: "Chat Error", level: .warn, match: .statusCodeOnly)
            ]
        )
    }

    static func markConversationRead(conversationId: String, messageId: String) -> endpoint<emptyResponse> {
        return endpoint<emptyResponse>(
            path: "/v4/chat/conversation/\(conversationId)/read/\(messageId)",
            method: .post,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }

    static func unsendMessage(conversationId: String, messageId: String) -> endpoint<emptyResponse> {
        return endpoint<emptyResponse>(
            path: "/v4/chat/message/unsend",
            method: .post,
            queryItems: nil,
            body: [
                "conversationId": conversationId,
                "messageId": messageId
            ],
            isAuthedRoute: true,
            networkHandlers: [
                networkHandler(code: 500, jsonLocation: nil, jsonLocationValue: nil, message: "Message could not be unsent", header: "Chat Error", level: .warn, match: .statusCodeOnly)
            ]
        )
    }

    static func deleteMessage(conversationId: String, messageId: String) -> endpoint<emptyResponse> {
        return endpoint<emptyResponse>(
            path: "/v4/chat/message/delete",
            method: .post,
            queryItems: nil,
            body: [
                "conversationId": conversationId,
                "messageId": messageId
            ],
            isAuthedRoute: true,
            networkHandlers: [
                networkHandler(code: 500, jsonLocation: nil, jsonLocationValue: nil, message: "Message could not be deleted", header: "Chat Error", level: .warn, match: .statusCodeOnly)
            ]
        )
    }

    static func reactToMessage(conversationId: String, messageId: String, reactionType: Int = 1) -> endpoint<emptyResponse> {
        return endpoint<emptyResponse>(
            path: "/v4/chat/message/reaction",
            method: .post,
            queryItems: nil,
            body: [
                "conversationId": conversationId,
                "messageId": messageId,
                "reactionType": reactionType
            ],
            isAuthedRoute: true,
            networkHandlers: []
        )
    }

    static func sendTypingStatus(conversationId: String, status: typingStatus) -> endpoint<emptyResponse> {
        return endpoint<emptyResponse>(
            path: "/v4/chatstatus/typing",
            method: .post,
            queryItems: nil,
            body: [
                "conversationId": conversationId,
                "status": status
            ],
            isAuthedRoute: true,
            networkHandlers: []
        )
    }

    static func pinConversation(conversationId: String, pinned: Bool) -> endpoint<emptyResponse> {
        return endpoint<emptyResponse>(
            path: "/v4/chat/conversation/\(conversationId)/\(pinned ? "pin" : "unpin")",
            method: .post,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }

    static func deleteConversation(conversationId: String) -> endpoint<emptyResponse> {
        return endpoint<emptyResponse>(
            path: "/v4/chat/conversation/\(conversationId)",
            method: .delete,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }

    // Media

    static func getDeviceKeyChallenge() -> endpoint<deviceKeyChallengeResponse> {
        return endpoint<deviceKeyChallengeResponse>(
            path: "/v1/verification/device-keys/challenge",
            method: .post,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }

    static func registerDeviceKey(publicKey: String, keyId: String, registrationSignature: String) -> endpoint<registerDeviceKeyResponse> {
        return endpoint<registerDeviceKeyResponse>(
            path: "/v1/verification/device-keys",
            method: .post,
            queryItems: nil,
            body: [
                "publicKey": publicKey,
                "keyId": keyId,
                "registrationSignature": registrationSignature
            ],
            isAuthedRoute: true,
            networkHandlers: []
        )
    }

    static func uploadChatMediaSigned(data: Data, contentType: String, signatureHeaders: [String: String]) -> endpoint<mediaUploadResponse> {
        return endpoint<mediaUploadResponse>(
            path: "/v6/chat/media/upload",
            method: .post,
            queryItems: nil,
            rawBody: data,
            contentType: contentType,
            headers: signatureHeaders,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }

    // Profiles

    static func getGrid(
        geohash: String,
        filters: GridFilters = GridFilters()
    ) -> endpoint<CascadeResponse> {
        var queryItems: [String: String] = ["nearbyGeoHash": geohash]
        for item in filters.toQueryItems() {
            if let value = item.value {
                queryItems[item.name] = value
            }
        }
        return endpoint<CascadeResponse>(
            path: "/v3/cascade",
            method: .get,
            queryItems: queryItems,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }

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
    
    static func addFavorite(profileId: String) -> endpoint<emptyResponse> {
        return endpoint<emptyResponse>(
            path: "/v3/me/favorites/\(profileId)",
            method: .post,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    static func removeFavorite(profileId: String) -> endpoint<emptyResponse> {
        return endpoint<emptyResponse>(
            path: "/v3/me/favorites/\(profileId)",
            method: .delete,
            queryItems: nil,
            body: nil,
            isAuthedRoute: true,
            networkHandlers: []
        )
    }
    
    static func tap(profileId: String, tapType: tapType) -> endpoint<tapResponse> {
        return endpoint<tapResponse>(
            path: "/v2/taps/add",
            method: .post,
            queryItems: nil,
            body: [
                "recipientId": profileId,
                "tapType": tapType
            ],
            isAuthedRoute: true,
            networkHandlers: [
                networkHandler(
                    code: 400,
                    jsonLocation: nil,
                    jsonLocationValue: nil,
                    message: "User may already be tapped",
                    header: "Tap Error",
                    level: .warn,
                    match: .matchEither
                )
            ],
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
