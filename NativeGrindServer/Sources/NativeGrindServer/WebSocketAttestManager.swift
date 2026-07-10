//
//  WebSocketAttestManager.swift
//  NativeGrindServer
//
//  Created by Jay Brammeld on 10/07/2026.
//

import Foundation
import DeviceCheck
import CryptoKit
import NativeGrindCore
import Combine

@MainActor
public final class WebSocketAttestManager {
    public static let shared = WebSocketAttestManager()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    public func start() {
        cancellables.removeAll()
        
        #if !os(macOS) && !targetEnvironment(simulator) && !targetEnvironment(macCatalyst)
        wsController.isAppAttestSupported = DCAppAttestService.shared.isSupported
        #else
        wsController.isAppAttestSupported = false
        #endif
        
        wsController.shared.publisher(for: .onChallenge)
            .sink { payload in
                Task { @MainActor in
                    await self.performWebSocketAppAttest(challenge: payload.challenge)
                }
            }
            .store(in: &cancellables)
            
        wsController.shared.publisher(for: .onAttestVerify)
            .sink { payload in
                Task { @MainActor in
                    if payload.status == "success" {
                        let keyIdToSave = payload.keyId ?? wsController.shared.pendingKeyId
                        if let key = keyIdToSave {
                            keychainManager.shared.saveToken(key, type: .keyId)
                        }
                        wsController.shared.pendingKeyId = nil
                        wsController.shared.setConnected(domain: .nativeServer, connected: true)
                        errorManager.shared.log("wsController", "App Attest attestation verified successfully!")
                    } else {
                        let errMsg = payload.error ?? "Unknown verification error"
                        errorManager.shared.log("wsController", "App Attest verification failed: \(errMsg)")
                        wsController.shared.pendingKeyId = nil
                    }
                }
            }
            .store(in: &cancellables)
            
        wsController.shared.publisher(for: .onIdentityVerify)
            .sink { payload in
                Task { @MainActor in
                    if payload.status == "success" {
                        wsController.shared.setConnected(domain: .nativeServer, connected: true)
                        errorManager.shared.log("wsController", "App Attest identity assertion verified successfully!")
                    } else {
                        let errMsg = payload.error ?? "Unknown assertion error"
                        errorManager.shared.log("wsController", "App Attest assertion failed: \(errMsg)")
                        keychainManager.shared.deleteToken(type: .keyId)
                    }
                }
            }
            .store(in: &cancellables)
            
        wsController.shared.publisher(for: .onCompanionNotification)
            .sink { payload in
                Task { @MainActor in
                    if let apiKey = payload.apiKey {
                        keychainManager.shared.saveToken(apiKey, type: .apiKey)
                        errorManager.shared.log("wsController", "Companion authorized: Saved API key successfully!")
                    }
                    if let sessionId = payload.clientSessionId, let authToken = payload.clientAuthToken, let isEmail = payload.clientIsEmail, let data = payload.clientData {
                        keychainManager.shared.saveToken(sessionId, type: .sessionId)
                        keychainManager.shared.saveToken(authToken, type: .authToken)
                        keychainManager.shared.saveToken(isEmail, type: .isEmail)
                        keychainManager.shared.saveToken(data, type: .data)

                        sessionManager.shared.setAuthenticated(true)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func performWebSocketAppAttest(challenge: String) async {
        #if !os(macOS) && !targetEnvironment(simulator) && !targetEnvironment(macCatalyst)
        let service = DCAppAttestService.shared
        guard service.isSupported else {
            return
        }
        
        let challengeHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        
        if let storedKeyId = keychainManager.shared.getToken(type: .keyId) {
            do {
                let assertionObject = try await service.generateAssertion(storedKeyId, clientDataHash: challengeHash)
                let request = wsRequest<deviceAssertion>.assertIdentity(
                    keyId: storedKeyId,
                    assertion: assertionObject.base64EncodedString(),
                    challenge: challenge
                )
                wsController.shared.send(request: request)
            } catch {
                keychainManager.shared.deleteToken(type: .keyId)
                await performWebSocketAttestNewKey(challenge: challenge, service: service, challengeHash: challengeHash)
            }
        } else {
            await performWebSocketAttestNewKey(challenge: challenge, service: service, challengeHash: challengeHash)
        }
        #endif
    }

    #if !os(macOS) && !targetEnvironment(simulator) && !targetEnvironment(macCatalyst)
    private func performWebSocketAttestNewKey(challenge: String, service: DCAppAttestService, challengeHash: Data) async {
        do {
            let keyId = try await service.generateKey()
            let attestationObject = try await service.attestKey(keyId, clientDataHash: challengeHash)
            
            let request = wsRequest<deviceAssertion>.verifyAttestation(
                keyId: keyId,
                attestation: attestationObject.base64EncodedString(),
                challenge: challenge
            )
            wsController.shared.pendingKeyId = keyId
            wsController.shared.send(request: request)
        } catch {
            errorManager.shared.warn("wsController", "App Attest key generation/attestation failed: \(error.localizedDescription)")
        }
    }
    #endif
}
