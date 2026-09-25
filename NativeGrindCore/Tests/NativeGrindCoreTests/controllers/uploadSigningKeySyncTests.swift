//
//  uploadSigningKeySyncTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 25/09/2026.
//

import Testing
import Foundation
import CryptoKit
@testable import NativeGrindCore

@Suite("Upload Signing Key Sync Tests")
struct uploadSigningKeySyncTests {
    private func record(keyId: String?) throws -> Data {
        var json: [String: Any] = ["privateKey": P256.Signing.PrivateKey().rawRepresentation.base64EncodedString()]
        json["keyId"] = keyId
        return try JSONSerialization.data(withJSONObject: json)
    }

    @Test("A synced key is kept per profile and exported back unchanged")
    func roundTrip() async throws {
        try await TestSerializer.shared.run {
            keychainManager.shared.deleteToken(type: .uploadSigningKeys)
            let controller = mediaUploadController.shared
            let synced = try record(keyId: "key-1")

            await controller.importFromSync(profileId: "111", value: synced)

            let exported = try #require(await controller.exportForSync(profileId: "111"))
            let original = try JSONSerialization.jsonObject(with: synced) as? [String: String]
            let roundTripped = try JSONSerialization.jsonObject(with: exported) as? [String: String]
            #expect(original == roundTripped)
            #expect(await controller.exportForSync(profileId: "222") == nil)
        }
    }

    @Test("Deletes and unreadable keys from sync")
    func deletesAndRejects() async throws {
        try await TestSerializer.shared.run {
            keychainManager.shared.deleteToken(type: .uploadSigningKeys)
            let controller = mediaUploadController.shared

            await controller.importFromSync(profileId: "111", value: try record(keyId: "key-1"))
            await controller.importFromSync(profileId: "111", value: Data(#"{"privateKey":"bm9wZQ=="}"#.utf8))
            #expect(await controller.exportForSync(profileId: "111") != nil)

            await controller.importFromSync(profileId: "111", value: nil)
            #expect(await controller.exportForSync(profileId: "111") == nil)
        }
    }

    @Test("A key Grindr hasn't accepted yet isn't synced")
    func unregisteredNotExported() async throws {
        try await TestSerializer.shared.run {
            keychainManager.shared.deleteToken(type: .uploadSigningKeys)
            let controller = mediaUploadController.shared

            await controller.importFromSync(profileId: "111", value: try record(keyId: nil))
            #expect(await controller.exportForSync(profileId: "111") == nil)
        }
    }
}
