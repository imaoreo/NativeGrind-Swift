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
}
