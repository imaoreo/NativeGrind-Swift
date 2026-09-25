//
//  dbProfileController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 29/06/2026.
//

import Foundation

public struct profileHistoryEntry: Codable, Sendable {
    public let createdAt: Date
    public let diff: String
}

public actor dbProfileController {
    private let store: localStore

    public init(store: localStore = .shared) {
        self.store = store
    }

    public func fetchProfile(profileId: String) async throws -> profile? {
        return await store.read(profile.self, from: .profiles, key: profileId)
    }

    public func fetchProfiles() async throws -> [profile]? {
        return await store.readAll(profile.self, from: .profiles)
    }

    public func fetchProfileDiffs(profileId: String) async throws -> [profile] {
        guard let currentProfile = try await fetchProfile(profileId: profileId) else {
            return []
        }

        let entries = await store.read([profileHistoryEntry].self, from: .profileHistory, key: profileId) ?? []
        let newestFirst = entries
            .sorted { $0.createdAt > $1.createdAt }
            .map { (createdAt: $0.createdAt, jsonStr: $0.diff) }

        return dbControllerHelper.rebuildHistory(
            currentModel: currentProfile,
            diffStrings: newestFirst
        ) { historicProfile, timestamp in
            historicProfile.dbCreatedAt = timestamp
        }
    }

    // updates a profile
    public func updateProfile(profileId: String, profile: profile) async throws {

        let newJsonData = try dbControllerHelper.encoder.encode(profile)

        if let existingProfile = await store.read(NativeGrindCore.profile.self, from: .profiles, key: profileId),
           let oldData = try? dbControllerHelper.encoder.encode(existingProfile),
           let diff = dbControllerHelper.generateDiff(from: oldData, to: newJsonData) {

            var history = await store.read([profileHistoryEntry].self, from: .profileHistory, key: profileId) ?? []
            history.append(profileHistoryEntry(createdAt: Date(), diff: diff))
            try await store.write(history, to: .profileHistory, key: profileId)
        }

        try await store.write(profile, to: .profiles, key: profileId)
    }

    func clearDatabase() async throws {
        await store.clear(.profiles)
        await store.clear(.profileHistory)
    }
}
