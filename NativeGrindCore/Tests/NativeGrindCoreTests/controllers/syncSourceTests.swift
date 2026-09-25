//
//  syncSourceTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Sync Source Tests", .serialized)
struct syncSourceTests {

    private let account = nsAccount(authToken: "token1", sessionId: "sess1", isEmail: "true", data: "user1@example.com")

    @Test("Each login has a stable sync key that doesn't contain the email")
    func testAccountSyncKey() {
        let key = accountController.syncKey(for: account)
        let sameLoginNewSession = nsAccount(authToken: "other", sessionId: "other", isEmail: "true", data: "user1@example.com")

        #expect(key == accountController.syncKey(for: sameLoginNewSession))
        #expect(!key.contains("example"))
        #expect(key.wholeMatch(of: /^[0-9a-f]{64}$/) != nil)
    }

    @Test("Logins export without session ids and import keeping this device's session")
    func testAccountExportImport() async throws {
        try await TestSerializer.shared.run {
            let controller = accountController.shared
            await controller.clearAccounts()
            await controller.addAccount(account)
            let key = accountController.syncKey(for: account)

            let exported = try #require(await controller.exportForSync(key: key))
            #expect(!String(decoding: exported, as: UTF8.self).contains("sess1"))

            // Another device refreshed the token
            let updated = try JSONEncoder().encode(nsCloudAccount(from: nsAccount(authToken: "token2", sessionId: "", isEmail: "true", data: "user1@example.com")))
            await controller.importFromSync(key: key, value: updated)

            let accounts = await controller.getAccounts()
            #expect(accounts.count == 1)
            #expect(accounts.first?.authToken == "token2")
            #expect(accounts.first?.sessionId == "sess1")

            // Another device removed it
            await controller.importFromSync(key: key, value: nil)
            #expect(await controller.getAccounts().isEmpty)
        }
    }

    @Test("Adding and removing logins queues them for sync")
    func testAccountChangesAreQueued() async {
        await TestSerializer.shared.run {
            let controller = accountController.shared
            await controller.clearAccounts()
            let key = accountController.syncKey(for: account)

            await controller.addAccount(account)
            var queued = await localStore.shared.pendingChanges().filter { $0.collection == .grindrAccounts && $0.key == key }
            #expect(queued.first?.kind == .upsert)

            await controller.removeAccount(sessionId: "sess1")
            queued = await localStore.shared.pendingChanges().filter { $0.collection == .grindrAccounts && $0.key == key }
            #expect(queued.first?.kind == .delete)
        }
    }

    @Test("Location exports the geohash and imports without queueing it back")
    func testLocationExportImport() async throws {
        try await TestSerializer.shared.run {
            let controller = locationController.shared
            await controller.updateGeohash("gcpvj0duq5w0")
            let exported = try #require(await controller.exportForSync())
            #expect(try JSONDecoder().decode(String.self, from: exported) == "gcpvj0duq5w0")

            await localStore.shared.markSynced(collection: .deviceLocation, key: "current")
            await controller.importFromSync(try JSONEncoder().encode("u10hb5v5tqrf"))

            #expect(await controller.currentGeohash == "u10hb5v5tqrf")
            #expect(await localStore.shared.pendingChanges().contains { $0.collection == .deviceLocation } == false)
        }
    }
}
