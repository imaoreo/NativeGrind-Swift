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
              let profileId = await sessionManager.shared.profileId else {
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        repeat {
            syncAgain = false
            let prefix = "sync/\(profileId)/"
            await pull(prefix: prefix)
            await push(prefix: prefix)
        } while syncAgain
    }

    private func pull(prefix: String) async {
        var cursor = await store.syncCursor(for: prefix)

        while true {
            guard let response = await wsController.shared.sendAndWait(
                request: .syncPull(prefix: prefix, cursor: cursor),
                expectedEvent: .onSyncPulled
            ), response.status == .success else {
                return
            }

            for item in response.items ?? [] {
                await apply(item)
            }

            cursor = response.cursor
            await store.saveSyncCursor(cursor, for: prefix)

            guard response.hasMore == true else { return }
        }
    }

    private func apply(_ item: nsSyncItem) async {
        guard let json = try? cryptoController.shared.decryptTextWithSharedKey(encryptedBase64: item.encryptedPayload),
              let envelope = try? Self.decoder.decode(syncEnvelope.self, from: Data(json.utf8)) else {
            await errorManager.shared.warn("syncController", "Couldn't decrypt \(item.location)")
            return
        }

        switch envelope.collection {
        case .conversations:
            if envelope.deleted {
                await conversationCache.shared.removeRemote(key: envelope.key, deletedAt: envelope.changedAt)
            } else if let value = envelope.value,
                      let conversation = try? Self.decoder.decode(cachedConversation.self, from: value) {
                await conversationCache.shared.mergeRemote(key: envelope.key, remote: conversation)
            }
        case .profiles, .profileHistory:
            break
        }
    }

    private func push(prefix: String) async {
        let pending = await store.pendingChanges()
        guard !pending.isEmpty else { return }

        var encrypted: [(change: storeChange, item: nsSyncItem)] = []

        for change in pending {
            switch change.collection {
            case .profiles:
                await pushProfile(change)
            case .profileHistory:
                await store.markSynced([change])
            case .conversations:
                if let item = await encryptedItem(for: change, prefix: prefix) {
                    encrypted.append((change, item))
                }
            }
        }

        for batch in Self.batches(of: encrypted) {
            guard let response = await wsController.shared.sendAndWait(
                request: .syncPush(items: batch.map(\.item)),
                expectedEvent: .onSyncPushed
            ), response.status == .success else {
                return // left pending, tried again next sync
            }
            await store.markSynced(batch.map(\.change))
        }
    }

    private func pushProfile(_ change: storeChange) async {
        guard change.kind == .upsert,
              let profile = await store.read(NativeGrindCore.profile.self, from: .profiles, key: change.key) else {
            await store.markSynced([change])
            return
        }

        let geohash = await locationController.shared.currentGeohash
        await wsController.shared.send(request: .syncSeenProfile(profile: profile, geohash: geohash))
        await store.markSynced([change])

        try? await Task.sleep(for: .milliseconds(50))
    }

    private func encryptedItem(for change: storeChange, prefix: String) async -> nsSyncItem? {
        var value: Data? = nil
        if change.kind == .upsert {
            guard let record = await store.read(cachedConversation.self, from: change.collection, key: change.key) else {
                await store.markSynced([change])
                return nil
            }
            value = try? Self.encoder.encode(record)
        }

        let envelope = syncEnvelope(collection: change.collection, key: change.key, deleted: change.kind == .delete, changedAt: change.changedAt, value: value)

        guard let json = try? Self.encoder.encode(envelope),
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

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
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
