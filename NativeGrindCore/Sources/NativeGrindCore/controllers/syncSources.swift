//
//  syncSources.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 24/09/2026.
//

import Foundation

public enum syncScope: Sendable {
    case account // per NativeServer account
    case profile // per grindr account
}

protocol syncSource: Sendable {
    var collection: storeCollection { get }
    var scope: syncScope { get }
    var isPublic: Bool { get }

    func exportRecord(key: String) async -> Data?
    func importRecord(key: String, value: Data?, changedAt: Date) async
    func finishImport() async
    func publish(key: String) async
}

extension syncSource {
    var isPublic: Bool { false }
    func finishImport() async {}
    func publish(key: String) async {}
    func exportRecord(key: String) async -> Data? { nil }
    func importRecord(key: String, value: Data?, changedAt: Date) async {}
}

struct conversationSyncSource: syncSource {
    let collection = storeCollection.conversations
    let scope = syncScope.profile

    func exportRecord(key: String) async -> Data? {
        guard let conversation = await localStore.shared.read(cachedConversation.self, from: .conversations, key: key) else { return nil }
        return try? syncCoding.encoder.encode(conversation)
    }

    func importRecord(key: String, value: Data?, changedAt: Date) async {
        if let value, let conversation = try? syncCoding.decoder.decode(cachedConversation.self, from: value) {
            await conversationCache.shared.mergeRemote(key: key, remote: conversation)
        } else if value == nil {
            await conversationCache.shared.removeRemote(key: key, deletedAt: changedAt)
        }
    }
}

struct grindrAccountSyncSource: syncSource {
    let collection = storeCollection.grindrAccounts
    let scope = syncScope.account

    func exportRecord(key: String) async -> Data? {
        await accountController.shared.exportForSync(key: key)
    }

    func importRecord(key: String, value: Data?, changedAt: Date) async {
        await accountController.shared.importFromSync(key: key, value: value)
    }

    func finishImport() async {
        await accountController.shared.reconcileAfterSync()
    }
}

struct deviceLocationSyncSource: syncSource {
    let collection = storeCollection.deviceLocation
    let scope = syncScope.account

    func exportRecord(key: String) async -> Data? {
        await locationController.shared.exportForSync()
    }

    func importRecord(key: String, value: Data?, changedAt: Date) async {
        await locationController.shared.importFromSync(value)
    }
}

struct profileSyncSource: syncSource {
    let collection = storeCollection.profiles
    let scope = syncScope.profile
    let isPublic = true

    func publish(key: String) async {
        guard let profile = await localStore.shared.read(NativeGrindCore.profile.self, from: .profiles, key: key) else { return }
        let geohash = await locationController.shared.currentGeohash
        await wsController.shared.send(request: .syncSeenProfile(profile: profile, geohash: geohash))

        try? await Task.sleep(for: .milliseconds(50))
    }
}

struct profileHistorySyncSource: syncSource {
    let collection = storeCollection.profileHistory
    let scope = syncScope.profile
    let isPublic = true
}

enum syncCoding {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
