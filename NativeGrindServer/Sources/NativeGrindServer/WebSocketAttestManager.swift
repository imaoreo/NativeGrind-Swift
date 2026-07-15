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
public final class webSocketAttestManager {
    public static let shared = webSocketAttestManager()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    public func start() {
        cancellables.removeAll()
        
        wsController.shared.publisher(for: .onAuthChallenge)
            .sink { payload in
                Task {
                    do {
                        guard let deviceId = keychainManager.shared.getToken(type: .deviceId) else {
                            errorManager.shared.error("nsSetup", "Device ID not found")
                            return
                        }
                        
                        let challenge = payload.challenge
                        let signature = try cryptoController.shared.signChallenge(challenge: challenge)
                        let publicKey = try cryptoController.shared.getPublicKey()
                        let deviceName = getUniversalDeviceName()
                        
                        wsController.shared.send(request: .authorizeDevice(
                            deviceId: deviceId,
                            deviceName: deviceName,
                            publicKey: publicKey,
                            signature: signature,
                            challenge: challenge
                        ))
                    } catch {
                        print("Authorization failed: \(error.localizedDescription)")
                    }
                }
            }
            .store(in: &cancellables)
            
        /* How to do things like on login with QR response
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
         */
    }
}
