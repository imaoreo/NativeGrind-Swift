//
//  syncController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Foundation
import Combine

struct syncEnvelope: Codable {
    let collection: storeCollection
    let key: String
    let deleted: Bool
    let changedAt: Date
    let value: Data?
}

public actor syncController {
    public static let shared = syncController()

    private let sources: [storeCollection: any syncSource] = Dictionary(uniqueKeysWithValues: ([
        conversationSyncSource(),
        grindrAccountSyncSource(),
        deviceLocationSyncSource(),
        uploadSigningKeySyncSource(),
        profileSyncSource(),
        profileHistorySyncSource()
    ] as [any syncSource]).map { ($0.collection, $0) })

    private let store: localStore
    private var isSyncing = false
    private var syncAgain = false
    private var started = false

    private static let interval: Duration = .seconds(60)
    private static let maxBatchItems = 50
    private static let maxBatchBytes = 4 * 1024 * 1024

    init(store: localStore = .shared) {
        self.store = store
    }

    public func start() async {
        guard !started else { return }
        started = true

        await MainActor.run {
            syncTriggers.shared.install()
        }

        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.interval)
                await syncNow()
            }
        }
    }

    public func syncNow() async {
        guard !isSyncing else {
            syncAgain = true
            return
        }

        guard await wsController.shared.isServerAuthorized,
              keychainManager.shared.getToken(type: .accountKey) != nil else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        repeat {
            syncAgain = false
            let profileId = await sessionManager.shared.profileId
            let prefixes = scopePrefixes(profileId: profileId)

            let isFirstAccountSync = await store.syncCursor(for: prefixes[.account]!) == nil

            for prefix in prefixes.values {
                await pull(prefix: prefix)
            }

            if isFirstAccountSync {
                await accountController.shared.queueAllForSync()
                await locationController.shared.queueForSync()
            }
            await push(prefixes: prefixes)
        } while syncAgain
    }

    private func scopePrefixes(profileId: Int?) -> [syncScope: String] {
        var prefixes: [syncScope: String] = [.account: "sync/account/"]
        if let profileId {
            prefixes[.profile] = "sync/\(profileId)/"
        }
        return prefixes
    }

    private func pull(prefix: String) async {
        var cursor = await store.syncCursor(for: prefix)
        var imported = Set<storeCollection>()

        while true {
            guard let response = await wsController.shared.sendAndWait(
                request: .syncPull(prefix: prefix, cursor: cursor),
                expectedEvent: .onSyncPulled
            ), response.status == .success else {
                break
            }

            for item in response.items ?? [] {
                if let collection = await apply(item) {
                    imported.insert(collection)
                }
            }

            cursor = response.cursor
            await store.saveSyncCursor(cursor, for: prefix)

            guard response.hasMore == true else { break }
        }

        for collection in imported {
            await sources[collection]?.finishImport()
        }
    }

    private func apply(_ item: nsSyncItem) async -> storeCollection? {
        guard let json = try? cryptoController.shared.decryptTextWithSharedKey(encryptedBase64: item.encryptedPayload),
              let envelope = try? syncCoding.decoder.decode(syncEnvelope.self, from: Data(json.utf8)),
              let source = sources[envelope.collection],
              !source.isPublic else {
            await errorManager.shared.warn("syncController", "Couldn't read \(item.location)")
            return nil
        }

        await source.importRecord(key: envelope.key, value: envelope.deleted ? nil : envelope.value, changedAt: envelope.changedAt)
        return envelope.collection
    }

    private func push(prefixes: [syncScope: String]) async {
        let pending = await store.pendingChanges()
        guard !pending.isEmpty else { return }

        var encrypted: [(change: storeChange, item: nsSyncItem)] = []

        for change in pending {
            guard let source = sources[change.collection] else {
                await store.markSynced([change])
                continue
            }

            guard let prefix = prefixes[source.scope] else { continue }

            if source.isPublic {
                if change.kind == .upsert {
                    await source.publish(key: change.key)
                }
                await store.markSynced([change])
            } else if let item = await encryptedItem(for: change, source: source, prefix: prefix) {
                encrypted.append((change, item))
            }
        }

        for batch in Self.batches(of: encrypted) {
            guard let response = await wsController.shared.sendAndWait(
                request: .syncPush(items: batch.map(\.item)),
                expectedEvent: .onSyncPushed
            ), response.status == .success else {
                return
            }
            await store.markSynced(batch.map(\.change))
        }
    }

    private func encryptedItem(for change: storeChange, source: any syncSource, prefix: String) async -> nsSyncItem? {
        let value = change.kind == .upsert ? await source.exportRecord(key: change.key) : nil

        let envelope = syncEnvelope(
            collection: change.collection,
            key: change.key,
            deleted: value == nil,
            changedAt: change.changedAt,
            value: value
        )

        guard let json = try? syncCoding.encoder.encode(envelope),
              let payload = try? cryptoController.shared.encryptTextWithSharedKey(text: String(decoding: json, as: UTF8.self)),
              let identifier = try? cryptoController.shared.syncIdentifier(for: "\(change.collection.rawValue)/\(change.key)") else {
            return nil
        }

        return nsSyncItem(location: "\(prefix)\(change.collection.rawValue)/\(identifier)", encryptedPayload: payload, updatedAt: nil)
    }

    private static func batches(of items: [(change: storeChange, item: nsSyncItem)]) -> [[(change: storeChange, item: nsSyncItem)]] {
        var batches: [[(change: storeChange, item: nsSyncItem)]] = []
        var current: [(change: storeChange, item: nsSyncItem)] = []
        var currentBytes = 0

        for entry in items {
            let size = entry.item.encryptedPayload.utf8.count
            if !current.isEmpty && (current.count >= maxBatchItems || currentBytes + size > maxBatchBytes) {
                batches.append(current)
                current = []
                currentBytes = 0
            }
            current.append(entry)
            currentBytes += size
        }
        if !current.isEmpty {
            batches.append(current)
        }
        return batches
    }
}

@MainActor
private final class syncTriggers {
    static let shared = syncTriggers()
    private var cancellables = Set<AnyCancellable>()

    func install() {
        guard cancellables.isEmpty else { return }

        wsController.shared.$isServerAuthorized
            .removeDuplicates()
            .filter { $0 }
            .map { _ in () }
            .merge(with: wsController.shared.publisher(for: .onSyncChanged).map { _ in () })
            .sink { _ in
                Task { await syncController.shared.syncNow() }
            }
            .store(in: &cancellables)
    }
}
