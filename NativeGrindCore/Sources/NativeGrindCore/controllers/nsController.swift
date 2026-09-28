//
//  nsController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/08/2026.
//

import Foundation
import CryptoKit
import Combine

@MainActor
public func registerNativeServerAuthHandler() {
    nsAuthManager.shared.start()
}

@MainActor
public final class nsAuthManager {
    public static let shared = nsAuthManager()
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

                        await syncController.shared.syncNow()
                    } catch {
                        errorManager.shared.error("nsConnect", "Failed: \(error.localizedDescription)")
                    }
                }
            }
            .store(in: &cancellables)
            
        wsController.shared.publisher(for: .onAccountCreated)
            .sink { payload in
                Task {
                    if payload.status == .success {
                        await accountController.shared.queueAllForSync()
                        await locationController.shared.queueForSync()
                        await syncController.shared.syncNow()
                    }
                }
            }
            .store(in: &cancellables)
            
        wsController.shared.publisher(for: .onDeviceAuth)
            .sink { payload in
                Task {
                    if payload.status == .success {
                        if payload.accountId == nil,
                           keychainManager.shared.getToken(type: .accountKey) != nil {
                            errorManager.shared.log("nsAuth", "Device is no longer associated with an account - clearing local account key")
                            keychainManager.shared.deleteToken(type: .accountKey)
                        }


                        await MainActor.run {
                            wsController.shared.isServerAuthorized = true
                        }
                    } else {
                        await MainActor.run {
                            wsController.shared.isServerAuthorized = false
                        }
                    }
                }
            }
            .store(in: &cancellables)

        wsController.shared.publisher(for: .onProfileSynced)
            .sink { payload in
                Task {
                    if let missing = payload.missingMediaHashes {
                        await profileController.shared.proactiveSyncMissingMedias(missing)
                    }
                }
            }
            .store(in: &cancellables)
    }
}
