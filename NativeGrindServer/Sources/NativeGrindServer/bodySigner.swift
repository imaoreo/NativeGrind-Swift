//
//  bodySigner.swift
//  NativeGrindServer
//
//  Created by Jay Brammeld on 10/07/2026.
//

import Foundation
import DeviceCheck
import CryptoKit
import NativeGrindCore

public func signNativeBody(_ bodyData: Data?, url: String) async throws -> deviceAssertion? {
    #if !os(macOS) && !targetEnvironment(simulator) && !targetEnvironment(macCatalyst)
    let service = DCAppAttestService.shared
    let keyId = await MainActor.run {
        keychainManager.shared.getToken(type: .keyId)
    }
    guard service.isSupported, let keyId = keyId else {
        return nil
    }
    
    guard let challengeResponse = try await APIClient.shared.request(.getChallengeForCheck()) else {
        return nil
    }
    let challenge = challengeResponse.challenge
    
    var clientData = Data()
    if let bodyData = bodyData {
        clientData.append(bodyData)
    }
    if let challengeData = challenge.data(using: .utf8) {
        clientData.append(challengeData)
    }
    let clientDataHash = Data(SHA256.hash(data: clientData))
    
    let assertion = try await service.generateAssertion(keyId, clientDataHash: clientDataHash)
    
    return deviceAssertion(
        assertion: assertion.base64EncodedString(),
        keyId: keyId,
        challenge: challenge
    )
    #endif
    
    return nil
}
