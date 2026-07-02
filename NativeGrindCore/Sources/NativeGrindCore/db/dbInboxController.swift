//
//  dbInboxController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 29/06/2026.
//

import Foundation
import SwiftData

@ModelActor
public actor dbInboxController {
    
    // fetch inboxes from the db
    public func fetchInboxes(conversationId: String) throws -> conversationData? {
        let context = modelContext
        
        // Setup the db requrest
        let predicate = #Predicate<dbInbox> { $0.conversationId == conversationId }
        var descriptor = FetchDescriptor<dbInbox>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        // fetch db, return nil if none
        guard let cachedRecord = try context.fetch(descriptor).first else {
            return nil
        }
        
        return try dbControllerHelper.decodeRecord(
            cachedRecord.json,
            as: conversationData.self,
            domain: "dbInboxControllerError"
        )
    }
    
    // fetch inboxes
    public func fetchInboxes() throws -> [conversationData]? {
        let context = modelContext
        
        // Setup the db requrest
        let descriptor = FetchDescriptor<dbInbox>()
        let cachedRecords = try context.fetch(descriptor)
        
        // If database is empty return []
        guard !cachedRecords.isEmpty else {
            return []
        }
        
        // Map through the records and decode each individual conversation
        let decodedInboxes = cachedRecords.compactMap { record in
            try? dbControllerHelper.decodeRecord(
                record.json,
                as: conversationData.self,
                domain: "dbInboxControllerError"
            )
        }
        
        return decodedInboxes
    }
    
    // fetch all snapshots of a inbox
    public func fetchInboxDiffs(conversationId: String) throws -> [conversationData] {
        let context = modelContext
        
        // get current profile
        guard let currentInbox = try fetchInboxes(conversationId: conversationId) else {
            return []
        }
        
        // fetch all changes newest to oldest
        let predicate = #Predicate<dbInboxDiff> { $0.conversationId == conversationId }
        let descriptor = FetchDescriptor<dbInboxDiff>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        let diffRecords = try context.fetch(descriptor)
                
        // Map the diffRecors into types
        let rawDiffs = diffRecords.map { (createdAt: $0.createdAt, jsonStr: $0.diffJson) }
        
        // Rebuild the history using the shared timeline processor
        return dbControllerHelper.rebuildHistory(
            currentModel: currentInbox,
            diffStrings: rawDiffs
        ) { historicInbox, timestamp in
            historicInbox.dbCreatedAt = timestamp
        }
    }
    
    // updates a inbox in the Cache
    public func updateInbox(inbox: conversationData) throws {
        let context = modelContext
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        
        let conversationId = inbox.conversationId
        
        let newJsonData = try encoder.encode(inbox)
        let newJsonString = String(data: newJsonData, encoding: .utf8) ?? ""
        
        // fetch existing cachedProfile, based on if the profileId matches
        let predicate = #Predicate<dbInbox> { $0.conversationId == conversationId }
        var descriptor = FetchDescriptor<dbInbox>(predicate: predicate)
        descriptor.fetchLimit = 1
        
        // Makes the request to database
        let existingInbox = try context.fetch(descriptor).first
        
        if let existingInbox {
            // Create a diff
            if let oldData = existingInbox.json.data(using: .utf8),
               let diff = dbControllerHelper.generateDiff(from: oldData, to: newJsonData) {
                
                // Save Changes to a diff log
                let diffRecord = dbInboxDiff(conversationId: conversationId, diffJson: diff)
                diffRecord.createdAt = Date()
                context.insert(diffRecord)
            }
            
            // update the main record
            existingInbox.json = newJsonString
            existingInbox.lastUpdatedAt = Date()
        } else {
            // create fresh master log
            let newProfile = dbInbox(conversationId: conversationId, json: newJsonString)
            context.insert(newProfile)
        }
        
        // commit changes
        try context.save()
    }
    
    func clearDatabase() throws {
        let context = modelContext
        try context.delete(model: dbInbox.self)
        try context.delete(model: dbInboxDiff.self)
        try context.save()
    }
}
