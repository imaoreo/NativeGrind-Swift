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
        if domain == .main {
            let token = keychainManager.shared.getToken(type: .sessionId) ?? ""
            let envelope = wsCommandEnvelope(type: eventName, ref: UUID().uuidString, token: token, payload: payload)

            return try JSONEncoder().encode(envelope)
        }

        let currentMillis = Int64(Date().timeIntervalSince1970 * 1000)
        let envelope = wsNSNotificationEnvelope(event: eventName, payload: payload, clientTime: currentMillis)
        return try JSONEncoder().encode(envelope)
    }
}

public extension wsRequest {

    // Grindr

    static func sendTextMessage(targetProfileId: Int, text: String, replyToMessageId: String? = nil) -> wsRequest<sendTextMessageCommand> {
        return wsRequest<sendTextMessageCommand>(
            domain: .main,
            eventName: "chat.v1.message.send",
            payload: sendTextMessageCommand(
                type: .text,
                target: messageTarget(type: .direct, targetId: targetProfileId),
                body: textMessageBody(text: text),
                replyToMessageId: replyToMessageId
            )
        )
    }

    // NativeServer

    // authorizes the current users device
    static func authorizeDevice(deviceId: String, deviceName: String?, publicKey: String, signature: String, challenge: String) -> wsRequest<nsAuthentication> {
        return wsRequest<nsAuthentication>(
            domain: .nativeServer,
            eventName: "authorize_device",
            payload: nsAuthentication(
                deviceId: deviceId,
                deviceName: deviceName,
                publicKey: publicKey,
                signature: signature,
                challenge: challenge
            )
        )
    }
    
    static func getAccountInfo() -> wsRequest<String> {
        return wsRequest<String>(
            domain: .nativeServer,
            eventName: "get_account_info",
            payload: ""
        )
    }
    
    static func createAccount() -> wsRequest<String> {
        return wsRequest<String>(
            domain: .nativeServer,
            eventName: "create_account",
            payload: ""
        )
    }
    
    static func deleteAccount() -> wsRequest<String> {
        return wsRequest<String>(
            domain: .nativeServer,
            eventName: "delete_account",
            payload: ""
        )
    }
    
    static func listDevices() -> wsRequest<String> {
        return wsRequest<String>(
            domain: .nativeServer,
            eventName: "list_devices",
            payload: ""
        )
    }
    
    static func removeDevice(deviceId: String) -> wsRequest<nsDeviceRemoved> {
        return wsRequest<nsDeviceRemoved>(
            domain: .nativeServer,
            eventName: "remove_device",
            payload: nsDeviceRemoved(
                deviceId: deviceId
            )
        )
    }
    
    static func generateLinkCode() -> wsRequest<String> {
        return wsRequest<String>(
            domain: .nativeServer,
            eventName: "generate_link_code",
            payload: ""
        )
    }
    
    static func addDevice(code: String, key: String) -> wsRequest<nsConnectDevice> {
        return wsRequest<nsConnectDevice>(
            domain: .nativeServer,
            eventName: "link_device_via_code",
            payload: nsConnectDevice(
                code: code,
                key: key
            )
        )
    }
    
    static func getPublicKey(code: String) -> wsRequest<nsDevicePublicKey> {
        return wsRequest<nsDevicePublicKey>(
            domain: .nativeServer,
            eventName: "link_device_get_public_key",
            payload: nsDevicePublicKey(
                code: code
            )
        )
    }
    
    static func syncPush(items: [nsSyncItem]) -> wsRequest<nsSyncPushRequest> {
        return wsRequest<nsSyncPushRequest>(
            domain: .nativeServer,
            eventName: "sync_push",
            payload: nsSyncPushRequest(items: items)
        )
    }

    static func syncPull(prefix: String, cursor: nsSyncCursor?) -> wsRequest<nsSyncPullRequest> {
        return wsRequest<nsSyncPullRequest>(
            domain: .nativeServer,
            eventName: "sync_pull",
            payload: nsSyncPullRequest(prefix: prefix, cursor: cursor)
        )
    }

    static func syncSeenProfile(profile: profile, geohash: String?) -> wsRequest<nsSyncProfileRequest> {
        return wsRequest<nsSyncProfileRequest>(
            domain: .nativeServer,
            eventName: "sync_seen_profile",
            payload: nsSyncProfileRequest(profile: profile, geohash: geohash)
        )
    }

    static func syncGrid(profiles: [CascadeResponseProfile], geohash: String?) -> wsRequest<nsSyncGridRequest> {
        return wsRequest<nsSyncGridRequest>(
            domain: .nativeServer,
            eventName: "sync_grid",
            payload: nsSyncGridRequest(profiles: profiles, geohash: geohash)
        )
    }

    static func uploadMedia(mediaHash: String, base64Data: String) -> wsRequest<nsUploadMedia> {
        return wsRequest<nsUploadMedia>(
            domain: .nativeServer,
            eventName: "upload_media",
            payload: nsUploadMedia(mediaHash: mediaHash, base64Data: base64Data)
        )
    }

    static func uploadAlbumMedia(albumId: String, contentId: String, ownerProfileId: String, base64Data: String) -> wsRequest<nsUploadAlbumMedia> {
        return wsRequest<nsUploadAlbumMedia>(
            domain: .nativeServer,
            eventName: "upload_album_media",
            payload: nsUploadAlbumMedia(albumId: albumId, contentId: contentId, ownerProfileId: ownerProfileId, base64Data: base64Data)
        )
    }

    static func uploadChatMedia(mediaHash: String, base64Data: String) -> wsRequest<nsUploadMedia> {
        return wsRequest<nsUploadMedia>(
            domain: .nativeServer,
            eventName: "upload_chat_media",
            payload: nsUploadMedia(mediaHash: mediaHash, base64Data: base64Data)
        )
    }

    static func getProfileByImage(mediaHash: String) -> wsRequest<nsGetProfileByImageRequest> {
        return wsRequest<nsGetProfileByImageRequest>(
            domain: .nativeServer,
            eventName: "get_profile_by_image",
            payload: nsGetProfileByImageRequest(mediaHash: mediaHash)
        )
    }
}
