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
    
    static var onDeviceAuth: wsEvent<nsDeviceAuthResponse> {
        return wsEvent<nsDeviceAuthResponse>(domain: .nativeServer, eventName: "device_authenticated")
    }
    
    static var onAccountCreated: wsEvent<nsAccountCreatedResponse> {
        return wsEvent<nsAccountCreatedResponse>(domain: .nativeServer, eventName: "create_account")
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

}
