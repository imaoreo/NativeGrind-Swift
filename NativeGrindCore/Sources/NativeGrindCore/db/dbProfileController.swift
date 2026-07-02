//
//  dbProfileController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 29/06/2026.
//

import Foundation
import SwiftData

@ModelActor
public actor dbProfileController {
    
    // fetch a profile from the db
    public func fetchProfile(profileId: String) throws -> profile? {
        let context = modelContext
        
        // Setup the db requrest
        let predicate = #Predicate<dbProfile> { $0.profileId == profileId }
        var descriptor = FetchDescriptor<dbProfile>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        // fetch db, return nil if none
        guard let cachedRecord = try context.fetch(descriptor).first else {
            return nil
        }
        
        return try dbControllerHelper.decodeRecord(
            cachedRecord.json,
            as: profile.self,
            domain: "dbProfileControllerError"
        )
    }
    
    // fetch profiles
    public func fetchProfiles() throws -> [profile]? {
        let context = modelContext
        
        // Setup the db requrest
        let descriptor = FetchDescriptor<dbProfile>()
        let cachedRecords = try context.fetch(descriptor)
        
        // If database is empty return []
        guard !cachedRecords.isEmpty else {
            return []
        }
        
        // Map through the records and decode each individual profile
        let decodedProfiles = cachedRecords.compactMap { record in
            try? dbControllerHelper.decodeRecord(
                record.json,
                as: profile.self,
                domain: "dbProfileControllerError"
            )
        }
        
        return decodedProfiles
    }
    
    // fetch all snapshots of a profile
    public func fetchProfileDiffs(profileId: String) throws -> [profile] {
        let context = modelContext
        
        // get current profile
        guard let currentProfile = try fetchProfile(profileId: profileId) else {
            return []
        }
        
        // fetch all changes newest to oldest
        let predicate = #Predicate<dbProfileDiff> { $0.profileId == profileId }
        var descriptor = FetchDescriptor<dbProfileDiff>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        let diffRecords = try context.fetch(descriptor)
        
        // Map the diffRecors into types
        let rawDiffs = diffRecords.map { (createdAt: $0.createdAt, jsonStr: $0.diffJson) }
        
        // Rebuild the history using the shared timeline processor
        return dbControllerHelper.rebuildHistory(
            currentModel: currentProfile,
            diffStrings: rawDiffs
        ) { historicProfile, timestamp in
            historicProfile.dbCreatedAt = timestamp
        }
    }
    
    // updates a profile in the Cache
    public func updateProfile(profileId: String, profile: profile) throws {
        let context = modelContext
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        
        let newJsonData = try encoder.encode(profile)
        let newJsonString = String(data: newJsonData, encoding: .utf8) ?? ""
        
        // fetch existing cachedProfile, based on if the profileId matches
        let predicate = #Predicate<dbProfile> { $0.profileId == profileId }
        var descriptor = FetchDescriptor<dbProfile>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        // Makes the request to database
        let existingProfile = try context.fetch(descriptor).first
        
        if let existingProfile {
            // Create a diff
            if let oldData = existingProfile.json.data(using: .utf8),
               let diff = dbControllerHelper.generateDiff(from: oldData, to: newJsonData) {
                
                // Save Changes to a diff log
                let diffRecord = dbProfileDiff(profileId: profileId, diffJson: diff)
                diffRecord.createdAt = Date()
                context.insert(diffRecord)
            }
            
            // update the main record
            existingProfile.json = newJsonString
            existingProfile.lastUpdatedAt = Date()
        } else {
            // create fresh master log
            let newProfile = dbProfile(profileId: profileId, json: newJsonString)
            context.insert(newProfile)
        }
        
        // commit changes
        try context.save()
    }
    
    public func clearDatabase() throws {
        let context = modelContext
        try context.delete(model: dbProfile.self)
        try context.delete(model: dbProfileDiff.self)
        try context.save()
    }
}
