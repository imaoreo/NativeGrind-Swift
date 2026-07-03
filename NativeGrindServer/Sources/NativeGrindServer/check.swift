//
//  check.swift
//  NativeGrindServer
//
//  Created by Jay Brammeld on 02/07/2026.
//

import Foundation
import DeviceCheck
import CryptoKit
import NativeGrindCore

public func performNativeServerChecks() async {
    #if os(macOS) || targetEnvironment(simulator) || targetEnvironment(macCatalyst)
    await errorManager.shared.warn("NativeGrindServer", "App Attest is not supported on this platform/environment")
    #else
    if ProcessInfo.processInfo.isiOSAppOnMac {
        await errorManager.shared.warn("NativeGrindServer", "App Attest is not supported on Mac")
        return
    }
    let service = DCAppAttestService.shared
    guard service.isSupported else {
        await errorManager.shared.warn("NativeGrindServer", "Client not supported")
        return
    }

    do {
        guard let challenge = try await APIClient.shared.request(.getChallengeForCheck()) else {
            await errorManager.shared.warn("NativeGrindServer", "Failed to retrieve challenge from backend")
            return
        }
        
        let keyId = try await service.generateKey()
        
        let challengeHash = Data(SHA256.hash(data: Data(challenge.challenge.utf8)))
        
        let attestationObject = try await service.attestKey(keyId, clientDataHash: challengeHash)
        
        guard let challenge = try await APIClient.shared.request(.giveChallengeForCheck(
            keyId: keyId,
            attestation: attestationObject.base64EncodedString(),
            challenge: challenge.challenge
        )) else {
            await errorManager.shared.warn("NativeGrindServer", "Failed device check")
            return
        }
        
        keychainManager.shared.saveToken(challenge.keyId, type: .keyId)
    } catch {
        await errorManager.shared.warn("NativeGrindServer", "Attestation failed: \(error)")
    }
    #endif
}
