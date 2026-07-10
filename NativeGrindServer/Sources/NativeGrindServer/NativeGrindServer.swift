//
//  NativeGrindServer.swift
//  NativeGrindServer
//
//  Created by Jay Brammeld on 02/07/2026.
//

import Foundation
import NativeGrindCore

@MainActor
public func registerBodySigner() {
    APIClient.bodySigner = signNativeBody
    registerWebSocketAppAttestHandler()
}

@MainActor
public func registerWebSocketAppAttestHandler() {
    WebSocketAttestManager.shared.start()
}
