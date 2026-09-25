//
//  localStoreTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Local Store Tests")
struct localStoreTests {

    private struct record: Codable, Equatable {
        let name: String
        let seenAt: Date
    }

    private func makeStore() -> localStore {
        localStore(root: FileManager.default.temporaryDirectory.appendingPathComponent("localStoreTests-\(UUID().uuidString)", isDirectory: true))
    }

    @Test("Records round trip through JSON, dates included")
    func testWriteAndRead() async throws {
        let store = makeStore()
        let saved = record(name: "Joey", seenAt: Date(timeIntervalSince1970: 1_788_013_514.870))

        try await store.write(saved, to: .profiles, key: "771038429")

        #expect(await store.read(record.self, from: .profiles, key: "771038429") == saved)
        #expect(await store.readAll(record.self, from: .profiles) == [saved])
        #expect(await store.read(record.self, from: .profiles, key: "missing") == nil)
    }

    @Test("Keys that could escape the store folder are rejected")
    func testInvalidKeys() async {
        let store = makeStore()
        let saved = record(name: "x", seenAt: Date())

        for key in ["../escape", "a/b", "771038429:905366700", ""] {
            await #expect(throws: storeError.self) {
                try await store.write(saved, to: .profiles, key: key)
            }
        }
    }

    @Test("Writes and deletes are queued for sync until marked synced")
    func testSyncLedger() async throws {
        let store = makeStore()
        try await store.write(record(name: "a", seenAt: Date()), to: .profiles, key: "1")
        try await store.write(record(name: "b", seenAt: Date()), to: .conversations, key: "1_2")
        await store.delete(from: .profiles, key: "1")

        let pending = await store.pendingChanges()
        #expect(pending.count == 2)
        #expect(pending.first { $0.collection == .profiles }?.kind == .delete)
        #expect(pending.first { $0.collection == .conversations }?.kind == .upsert)

        await store.markSynced(pending)
        #expect(await store.pendingChanges().isEmpty)
    }

    @Test("A key changed again during a sync stays pending")
    func testChangeDuringSync() async throws {
        let store = makeStore()
        try await store.write(record(name: "v1", seenAt: Date()), to: .profiles, key: "1")
        let syncing = await store.pendingChanges()

        try await Task.sleep(nanoseconds: 5_000_000)
        try await store.write(record(name: "v2", seenAt: Date()), to: .profiles, key: "1")
        await store.markSynced(syncing)

        #expect(await store.pendingChanges().count == 1)
    }

    @Test("Clearing a collection removes its records and pending changes only")
    func testClear() async throws {
        let store = makeStore()
        try await store.write(record(name: "a", seenAt: Date()), to: .profiles, key: "1")
        try await store.write(record(name: "b", seenAt: Date()), to: .conversations, key: "1_2")

        await store.clear(.conversations)

        #expect(await store.keys(in: .conversations).isEmpty)
        #expect(await store.keys(in: .profiles) == ["1"])
        #expect(await store.pendingChanges().map(\.collection) == [.profiles])
    }
}
