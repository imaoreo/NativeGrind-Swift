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
    
    static var onAccountInformation: wsEvent<nsAccountInformationResponse> {
        return wsEvent<nsAccountInformationResponse>(domain: .nativeServer, eventName: "get_account_info")
    }
    
    static var onDeviceAuth: wsEvent<nsDeviceAuthResponse> {
        return wsEvent<nsDeviceAuthResponse>(domain: .nativeServer, eventName: "device_authenticated")
    }
    
    static var onAccountCreated: wsEvent<nsAccountCreatedResponse> {
        return wsEvent<nsAccountCreatedResponse>(domain: .nativeServer, eventName: "create_account")
    }
    
    static var onAccountDeleted: wsEvent<nsResponse> {
        return wsEvent<nsResponse>(domain: .nativeServer, eventName: "delete_account")
    }
    
    static var onDeviceList: wsEvent<nsDeviceListResponse> {
        return wsEvent<nsDeviceListResponse>(domain: .nativeServer, eventName: "device_list")
    }
    
    static var onDeviceRemovedDevice: wsEvent<nsDeviceRemovedDeviceResponse> { // If this is call this is the device that was removed.
        return wsEvent<nsDeviceRemovedDeviceResponse>(domain: .nativeServer, eventName: "device_removed_device")
    }
    
    static var onDeviceRemoved: wsEvent<nsDeviceRemovedResponse> {
        return wsEvent<nsDeviceRemovedResponse>(domain: .nativeServer, eventName: "device_removed")
    }
    
    static var onCodeLinkGenerated: wsEvent<nsLinkCodeResponse> {
        return wsEvent<nsLinkCodeResponse>(domain: .nativeServer, eventName: "link_code_generated")
    }
    
    static var onDeviceAdded: wsEvent<nsDeviceAddedResponse> { // Added to a account called once the link is inputed
        return wsEvent<nsDeviceAddedResponse>(domain: .nativeServer, eventName: "device_connected")
    }

    static var onDeviceLinked: wsEvent<nsDeviceLinkedResponse> {
        return wsEvent<nsDeviceLinkedResponse>(domain: .nativeServer, eventName: "device_linked")
    }
    
    static var onDevicePublicKey: wsEvent<nsDevicePublicKeyResponse> {
        return wsEvent<nsDevicePublicKeyResponse>(domain: .nativeServer, eventName: "link_device_public_key")
    }
    
    static var onSyncPushed: wsEvent<nsSyncPushResponse> {
        return wsEvent<nsSyncPushResponse>(domain: .nativeServer, eventName: "sync_push")
    }

    static var onSyncPulled: wsEvent<nsSyncPullResponse> {
        return wsEvent<nsSyncPullResponse>(domain: .nativeServer, eventName: "sync_pull")
    }

    static var onSyncChanged: wsEvent<nsResponse> {
        return wsEvent<nsResponse>(domain: .nativeServer, eventName: "sync_changed")
    }

    static var onProfileSynced: wsEvent<nsSyncProfileResponse> {
        return wsEvent<nsSyncProfileResponse>(domain: .nativeServer, eventName: "sync_seen_profile")
    }

    static var onGridSynced: wsEvent<nsSyncGridResponse> {
        return wsEvent<nsSyncGridResponse>(domain: .nativeServer, eventName: "sync_grid")
    }

    static var onMediaUploaded: wsEvent<nsResponse> {
        return wsEvent<nsResponse>(domain: .nativeServer, eventName: "upload_media")
    }

    static var onChatMediaUploaded: wsEvent<nsResponse> {
        return wsEvent<nsResponse>(domain: .nativeServer, eventName: "upload_chat_media")
    }

    static var onProfileByImage: wsEvent<nsGetProfileByImageResponse> {
        return wsEvent<nsGetProfileByImageResponse>(domain: .nativeServer, eventName: "get_profile_by_image")
    }

    static var onTextMessageSent: wsEvent<chatMessage> {
        return wsEvent<chatMessage>(domain: .main, eventName: "chat.v1.message.send.response")
    }

    static var onTap: wsEvent<emptyResponse> {
        return wsEvent<emptyResponse>(domain: .main, eventName: "tap.v1.tap_sent")
    }

    static var onNewView: wsEvent<emptyResponse> {
        return wsEvent<emptyResponse>(domain: .main, eventName: "viewed_me.v1.new_view_received")
    }

    static var onChatMessage: wsEvent<chatMessage> {
        return wsEvent<chatMessage>(domain: .main, eventName: "chat.v1.message_sent")
    }

    static var onConversationRead: wsEvent<conversationReadEvent> {
        return wsEvent<conversationReadEvent>(domain: .main, eventName: "chat.v1.conversation_read")
    }

    static var onTypingStatus: wsEvent<typingStatusEvent> {
        return wsEvent<typingStatusEvent>(domain: .main, eventName: "chat.v1.typing_status")
    }

    /// Can be used to detect blocks
    static var onConversationsDeleted: wsEvent<conversationIdsEvent> {
        return wsEvent<conversationIdsEvent>(domain: .main, eventName: "chat.v1.conversation.delete")
    }

    static var onConversationsUpdated: wsEvent<conversationIdsEvent> {
        return wsEvent<conversationIdsEvent>(domain: .main, eventName: "chat.v1.conversation.update")
    }
}
