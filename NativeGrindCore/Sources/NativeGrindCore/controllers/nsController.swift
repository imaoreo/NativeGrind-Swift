//
//  nsController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/08/2026.
//

import Foundation
import DeviceCheck
import CryptoKit
import Combine

@MainActor
public func registerWebSocketAppAttestHandler() {
    webSocketAttestManager.shared.start()
}

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
                        errorManager.shared.error("Authorization", "Failed: \(error.localizedDescription)")
                    }
                }
            }
            .store(in: &cancellables)

        wsController.shared.publisher(for: .onDevicePublicKey)
            .sink { payload in
                Task {
                    do {
                        guard let accountKey = keychainManager.shared.getToken(type: .accountKey) else {
                            errorManager.shared.error("nsConnect", "Account Key not found in Keychain")
                            return
                        }
                        
                        guard let devicePublicKey = payload.publicKey else {
                            errorManager.shared.error("nsConnect", "Device Public Key not given")
                            return
                        }
                        
                        guard let code = payload.code else {
                            errorManager.shared.error("nsConnect", "Device Code not given")
                            return
                        }
                        
                        let encryptedKey = try cryptoController.shared.encryptWithPublicKey(
                            text: accountKey,
                            recipientPublicKeyBase64: devicePublicKey
                        )
                        
                        wsController.shared.send(request: .addDevice(code: code, key: encryptedKey))
                    } catch {
                        errorManager.shared.error("nsConnect", "Failed: \(error.localizedDescription)")
                    }
                }
            }
            .store(in: &cancellables)
        
        wsController.shared.publisher(for: .onDeviceAdded)
            .sink { payload in
                Task {
                    do {
                        guard let key = payload.key else {
                            errorManager.shared.error("nsConnect", "Key not given")
                            return
                        }
                        
                        let decodedKey = try await cryptoController.shared.decryptWithPrivateKey(encryptedBase64: key)
                        
                        keychainManager.shared.saveToken(decodedKey, type: .accountKey)
                        
                        try await accountController.shared.syncFromCloud()
                    } catch {
                        errorManager.shared.error("nsConnect", "Failed: \(error.localizedDescription)")
                    }
                }
            }
            .store(in: &cancellables)
            
        wsController.shared.publisher(for: .onAccountCreated)
            .sink { payload in
                Task {
                    do {
                        if payload.status == .success {
                            try await accountController.shared.syncToCloud()
                        }
                    } catch {
                        errorManager.shared.error("nsSetup", "Failed to sync after account creation: \(error.localizedDescription)")
                    }
                }
            }
            .store(in: &cancellables)
            
        wsController.shared.publisher(for: .onDeviceAuth)
            .sink { payload in
                Task {
                    if payload.status == .success {
                        await MainActor.run {
                            wsController.shared.isServerAuthorized = true
                        }
                        do {
                            try await accountController.shared.syncFromCloud()
                        } catch {
                            errorManager.shared.error("nsConnect", "Failed to sync after device auth: \(error.localizedDescription)")
                        }
                    } else {
                        await MainActor.run {
                            wsController.shared.isServerAuthorized = false
                        }
                    }
                }
            }
            .store(in: &cancellables)

        wsController.shared.publisher(for: .onDataSaved)
            .sink { payload in
                Task {
                    if payload.message != "Data updated by another device" {
                        return;
                    }
                    
                    if payload.location == "grindr_accounts" {
                        do {
                            try await accountController.shared.syncFromCloud()
                        } catch {
                            errorManager.shared.error("nsConnect", "Failed to sync after external account data update: \(error.localizedDescription)")
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
}
