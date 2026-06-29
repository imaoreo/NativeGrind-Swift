//
//  profile.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 29/06/2026.
//

import Foundation
import SwiftData

@Model
public final class dbProfile {
    @Attribute(.unique) public var profileId: String
    public var json: String
    public var lastUpdatedAt: Date
    
    public init(profileId: String, json: String, lastUpdatedAt: Date = Date()) {
        self.profileId = profileId
        self.json = json
        self.lastUpdatedAt = lastUpdatedAt
    }
}

@Model
public final class dbProfileDiff {
    public var profileId: String
    public var createdAt: Date
    public var diffJson: String
    
    public init(profileId: String, createdAt: Date = Date(), diffJson: String) {
        self.profileId = profileId
        self.createdAt = createdAt
        self.diffJson = diffJson
    }
}
