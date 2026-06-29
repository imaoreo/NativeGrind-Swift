//
//  profileCache.swift
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
        
        // convert the string back into json
        guard let jsonData = cachedRecord.json.data(using: .utf8) else {
            throw NSError(domain: "ProfileCacheError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Corrupted string data in database"])
        }
        
        // Decode into profile
        let decoder = JSONDecoder()
        let decodedProfile = try decoder.decode(profile.self, from: jsonData)
        
        return decodedProfile
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
        
        // init the Encoder and Decoder
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Transfer Current Data into [String: Any]
        guard let currentProfileData = try? encoder.encode(currentProfile),
              var currentJsonDict = try? JSONSerialization.jsonObject(with: currentProfileData) as? [String: Any] else {
            return []
        }
        
        var history: [profile] = []
        
        // Go through every diffrence
        for record in diffRecords {
            // change the diffJson into [String: Any]
            guard let diffData = record.diffJson.data(using: .utf8),
                  let diffDict = try? JSONSerialization.jsonObject(with: diffData) as? [String: Any] else {
                continue
            }
            
            // Combine the diff into the main [String: Any]
            for (key, val) in diffDict {
                currentJsonDict[key] = val
            }
            
            // Transfer into JSON, and then into a profile struct
            if let combinedData = try? JSONSerialization.data(withJSONObject: currentJsonDict),
                var historicProfile = try? decoder.decode(profile.self, from: combinedData) {
                // add the createdAT then add to list
                historicProfile.dbCreatedAt = record.createdAt
                history.append(historicProfile)
            }
        }
        
        return history
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
               let diff = generateDiff(from: oldData, to: newJsonData) {
                
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
    
    /// Helper to compare two JSON objects and output a JSON delta string
    private func generateDiff(from oldData: Data, to newData: Data) -> String? {
        guard let oldDict = try? JSONSerialization.jsonObject(with: oldData) as? [String: Any],
              let newDict = try? JSONSerialization.jsonObject(with: newData) as? [String: Any] else {
            return nil
        }
        
        var diffDict: [String: Any] = [:]
        
        for (key, newValue) in newDict {
            if let oldValue = oldDict[key] {
                let oldObj = oldValue as? NSObject
                let newObj = newValue as? NSObject
                
                if oldObj != newObj {
                    diffDict[key] = newValue
                }
            } else {
                diffDict[key] = newValue
            }
        }
        
        guard !diffDict.isEmpty else { return nil }
        
        if let serializedDiff = try? JSONSerialization.data(withJSONObject: diffDict, options: []),
           let diffString = String(data: serializedDiff, encoding: .utf8) {
            return diffString
        }
        
        return nil
    }
}
