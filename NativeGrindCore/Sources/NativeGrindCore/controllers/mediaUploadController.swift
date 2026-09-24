//
//  mediaUploadController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Foundation
import CryptoKit

public actor mediaUploadController {
    public static let shared = mediaUploadController()

    private var clockOffsetMs: Int64 = 0

    private static let maxAttempts = 3

    public func uploadChatMedia(_ data: Data, contentType: String, lengthMs: Int64? = nil) async -> mediaUploadResponse? {
        var hasReregistered = false

        for _ in 0..<Self.maxAttempts {
            guard let identity = await signingIdentity() else { return nil }

            let upload = endpoint<mediaUploadResponse>.uploadChatMediaSigned(
                data: data,
                contentType: contentType,
                lengthMs: lengthMs,
                signatureHeaders: signatureHeaders(for: data, identity: identity)
            )

            let result: (Data, HTTPURLResponse)
            do {
                result = try await APIClient.shared.rawRequest(upload)
            } catch {
                await fail("Upload failed: \(error.localizedDescription)", toast: "Couldn't upload, check your connection")
                return nil
            }

            let (body, response) = result

            if (200...299).contains(response.statusCode) {
                return try? JSONDecoder().decode(mediaUploadResponse.self, from: body)
            }

            if response.statusCode == 401 {
                await sessionManager.shared.refreshToken(showError: false)
                continue
            }

            if response.statusCode == 422 {
                await fail("Upload rejected by moderation", toast: "This media was rejected")
                return nil
            }

            let signingError = try? JSONDecoder().decode(uploadSigningErrorResponse.self, from: body)
            let errorType = signingError?.type ?? ""

            if errorType.contains("timestamp_drift") {
                syncClock(serverTime: signingError?.detail)
                continue
            }

            if errorType.contains("nonce_replayed") {
                continue
            }

            // Only a rejected key is worth registering a new one for, not a normal bad request
            let detail = (signingError?.detail ?? "").lowercased()
            let isKeyProblem = response.statusCode == 403 || errorType.contains("key") || errorType.contains("signature") || detail.contains("key") || detail.contains("signature")
            if isKeyProblem && !hasReregistered {
                hasReregistered = true
                resetKey()
                continue
            }

            await fail("Upload failed with status \(response.statusCode): \(String(decoding: body, as: UTF8.self))", toast: "Upload failed (\(response.statusCode))")
            return nil
        }

        await fail("Upload failed after \(Self.maxAttempts) attempts", toast: "Upload failed, try again")
        return nil
    }

    private struct identity {
        let key: P256.Signing.PrivateKey
        let keyId: String
        let userId: String
        let androidId: String
    }

    private func signatureHeaders(for body: Data, identity: identity) -> [String: String] {
        let nonce = Data((0..<32).map { _ in UInt8.random(in: .min ... .max) }).base64URLEncoded
        let timestamp = String(Int64(Date().timeIntervalSince1970 * 1000) + clockOffsetMs)
        let bodyHash = Data(SHA256.hash(data: body)).base64URLEncoded

        let message = [bodyHash, timestamp, identity.userId, identity.androidId, nonce].joined(separator: "|")

        return [
            "X-Key-Id": identity.keyId,
            "X-Sig": sign(message, with: identity.key),
            "X-Timestamp": timestamp,
            "X-Nonce": nonce
        ]
    }

    private func sign(_ message: String, with key: P256.Signing.PrivateKey) -> String {
        let signature = try? key.signature(for: Data(message.utf8))
        return signature?.derRepresentation.base64URLEncoded ?? ""
    }

    private func signingIdentity() async -> identity? {
        guard let profileId = await sessionManager.shared.profileId,
              let androidId = await APIClient.shared.getDeviceId() else {
            await fail("Missing profile id or device id for upload signing", toast: "Couldn't upload, try logging in again")
            return nil
        }

        let userId = String(profileId)
        let key = loadOrCreateKey()
        let publicKey = key.publicKey.derRepresentation.base64URLEncoded // SPKI DER
        let keyId = Data(SHA256.hash(data: key.publicKey.derRepresentation)).base64URLEncoded

        if keychainManager.shared.getToken(type: .uploadSigningKeyId) == keyId {
            return identity(key: key, keyId: keyId, userId: userId, androidId: androidId)
        }

        guard let challengeBody = await registrationCall(step: "challenge", { .getDeviceKeyChallenge() }) else {
            return nil
        }

        guard let challenge = try? JSONDecoder().decode(deviceKeyChallengeResponse.self, from: challengeBody) else {
            await fail("Device key challenge had an unexpected body: \(String(decoding: challengeBody, as: UTF8.self))", toast: "Couldn't set up uploads")
            return nil
        }

        let registration = [userId, keyId, publicKey, androidId, challenge.challenge].joined(separator: "|")
        let registrationSignature = sign(registration, with: key)

        guard let registerBody = await registrationCall(step: "register", {
            .registerDeviceKey(publicKey: publicKey, keyId: keyId, registrationSignature: registrationSignature)
        }) else {
            return nil
        }

        // A 2xx means it was accepted, only use the echoed keyId if there is one
        let acceptedKeyId = (try? JSONDecoder().decode(registerDeviceKeyResponse.self, from: registerBody))?.keyId ?? keyId
        if acceptedKeyId != keyId {
            await errorManager.shared.warn("mediaUploadController", "Server echoed a different keyId: \(acceptedKeyId)")
        }

        keychainManager.shared.saveToken(acceptedKeyId, type: .uploadSigningKeyId)
        return identity(key: key, keyId: acceptedKeyId, userId: userId, androidId: androidId)
    }

    /// Runs one step of key registration and returns the raw body on a 2xx, logging the status and body otherwise
    private func registrationCall<T>(step: String, _ makeRequest: () -> endpoint<T>) async -> Data? {
        for attempt in 0..<2 {
            do {
                let (body, response) = try await APIClient.shared.rawRequest(makeRequest())

                if response.statusCode == 401 && attempt == 0 {
                    await sessionManager.shared.refreshToken(showError: false)
                    continue
                }

                guard (200...299).contains(response.statusCode) else {
                    await fail("Device key \(step) failed with status \(response.statusCode): \(String(decoding: body, as: UTF8.self))", toast: "Couldn't set up uploads (\(response.statusCode))")
                    return nil
                }

                return body
            } catch {
                await fail("Device key \(step) failed: \(error.localizedDescription)", toast: "Couldn't set up uploads")
                return nil
            }
        }
        return nil
    }

    private func loadOrCreateKey() -> P256.Signing.PrivateKey {
        if let stored = keychainManager.shared.getData(type: .uploadSigningKey),
           let key = try? P256.Signing.PrivateKey(rawRepresentation: stored) {
            return key
        }

        let key = P256.Signing.PrivateKey()
        _ = keychainManager.shared.saveData(key.rawRepresentation, type: .uploadSigningKey)
        keychainManager.shared.deleteToken(type: .uploadSigningKeyId)
        return key
    }

    private func resetKey() {
        keychainManager.shared.deleteToken(type: .uploadSigningKey)
        keychainManager.shared.deleteToken(type: .uploadSigningKeyId)
    }

    private func syncClock(serverTime: String?) {
        guard let serverTime else { return }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = formatter.date(from: serverTime) ?? ISO8601DateFormatter().date(from: serverTime)

        guard let date else { return }
        clockOffsetMs = Int64((date.timeIntervalSince1970 - Date().timeIntervalSince1970) * 1000)
    }

    private func fail(_ log: String, toast: String) async {
        await errorManager.shared.warn("mediaUploadController", log)
        await MainActor.run {
            toastManager.shared.show(style: .error, header: "Upload Error", message: toast)
        }
    }
}

extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
