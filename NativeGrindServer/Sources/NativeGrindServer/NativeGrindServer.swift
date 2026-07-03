import Foundation
import DeviceCheck
import CryptoKit
import NativeGrindCore

public func signNativeBody(_ bodyData: Data?, url: String) async throws -> DeviceAssertion? {
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
    
    return DeviceAssertion(
        assertion: assertion.base64EncodedString(),
        keyId: keyId,
        challenge: challenge
    )
    #else
    return nil
    #endif
}

@MainActor
public func registerBodySigner() {
    APIClient.bodySigner = signNativeBody
}
