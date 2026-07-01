//
//  dbInbox.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 29/06/2026.
//

import Foundation
import SwiftData

@Model
public final class dbInbox {
    @Attribute(.unique) public var conversationId: String
    public var json: String
    public var lastUpdatedAt: Date
    
    public init(conversationId: String, json: String, lastUpdatedAt: Date = Date()) {
        self.conversationId = conversationId
        self.json = json
        self.lastUpdatedAt = lastUpdatedAt
    }
}

@Model
public final class dbInboxDiff {
    public var conversationId: String
    public var createdAt: Date
    public var diffJson: String
    
    public init(conversationId: String, createdAt: Date = Date(), diffJson: String) {
        self.conversationId = conversationId
        self.createdAt = createdAt
        self.diffJson = diffJson
    }
}
