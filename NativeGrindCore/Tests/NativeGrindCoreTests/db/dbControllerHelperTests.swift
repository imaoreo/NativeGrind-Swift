//
//  dbControllerHelperTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/07/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Database Controller Helper Tests")
struct dbControllerHelperTests {
    
    // Used for testing
    struct MockProfile: Codable, Equatable {
        var id: String
        var displayName: String
        var age: Int?
        var lastUpdated: Date?
    }
    
    @Test("Verifies the shared encoder deterministically sorts JSON keys")
    func testEncoderSortedKeys() throws {
        let profile = MockProfile(id: "123", displayName: "Jay", age: 16)
        
        let data = try dbControllerHelper.encoder.encode(profile)
        let jsonString = String(data: data, encoding: .utf8)!
        
        // Since keys are alphabetical it will be in this order
        let expectedPrefix = "{\"age\":16,\"displayName\":\"Jay\",\"id\":\"123\""
        #expect(jsonString.hasPrefix(expectedPrefix))
    }
    
    @Test("Verifies decodeRecord successfully decodes a valid string")
    func testDecodeRecordSuccess() throws {
        let jsonString = "{\"id\":\"456\", \"displayName\":\"Test User\"}"
        
        let result = try dbControllerHelper.decodeRecord(jsonString, as: MockProfile.self, domain: "TestDomain")
        
        #expect(result.id == "456")
        #expect(result.displayName == "Test User")
        #expect(result.age == nil) // make sure optional fields are nil
    }
    
    @Test("Verifies decodeRecord throws the correct error for corrupted strings")
    func testDecodeRecordFailure() {
        let badString = "{\"id\":\"456\", \"displayName\":" // cut halfway
        
        #expect(throws: DecodingError.self) {
            _ = try dbControllerHelper.decodeRecord(badString, as: MockProfile.self, domain: "TestDomain")
        }
    }
    
    @Test("Verifies generateDiff returns nil if objects are perfectly identical")
    func testGenerateDiffNoChanges() throws {
        let oldProfile = MockProfile(id: "1", displayName: "Jay", age: 16)
        let newProfile = MockProfile(id: "1", displayName: "Jay", age: 16)
        
        let oldData = try dbControllerHelper.encoder.encode(oldProfile)
        let newData = try dbControllerHelper.encoder.encode(newProfile)
        
        let diff = dbControllerHelper.generateDiff(from: oldData, to: newData)
        
        #expect(diff == nil)
    }
    
    @Test("Verifies generateDiff captures the OLD values when a property changes")
    func testGenerateDiffCapturesOldValues() throws {
        // The diff is the things needed to make the newProfile look like the oldProfile
        let oldProfile = MockProfile(id: "1", displayName: "Jay", age: 16)
        let newProfile = MockProfile(id: "1", displayName: "Jay B", age: 17)
        
        let oldData = try dbControllerHelper.encoder.encode(oldProfile)
        let newData = try dbControllerHelper.encoder.encode(newProfile)
        
        let diffString = dbControllerHelper.generateDiff(from: oldData, to: newData)!
        
        // Make sure it captured the oldName and age
        #expect(diffString.contains("\"displayName\":\"Jay\""))
        #expect(diffString.contains("\"age\":16"))
        
        // Make sure it didn't store id since it didn't change
        #expect(!diffString.contains("\"id\""))
    }
    
    @Test("Verifies generateDiff handles properties being added and removed")
    func testGenerateDiffAdditionsAndRemovals() throws {
        // no age, then add age
        let oldProfile = MockProfile(id: "1", displayName: "Jay", age: nil)
        let newProfile = MockProfile(id: "1", displayName: "Jay", age: 16)
        
        let oldData1 = try dbControllerHelper.encoder.encode(oldProfile)
        let newData1 = try dbControllerHelper.encoder.encode(newProfile)
        let diffStringAdded = dbControllerHelper.generateDiff(from: oldData1, to: newData1)!
        
        // Since age didn't exist in the old one it should be null
        #expect(diffStringAdded.contains("\"age\":null"))
        
        
        // start with age, and then remove age
        let oldData2 = try dbControllerHelper.encoder.encode(newProfile)
        let newData2 = try dbControllerHelper.encoder.encode(oldProfile)
        let diffStringRemoved = dbControllerHelper.generateDiff(from: oldData2, to: newData2)!
        
        // since if age 16 is added to newData2 you get oldData2
        #expect(diffStringRemoved.contains("\"age\":16"))
    }
    
    @Test("Verifies rebuildHistory accurately applies reverse diffs sequentially")
    func testRebuildHistory() throws {
        // Current Profile
        let currentModel = MockProfile(id: "1", displayName: "Jay v3", age: 18)
        
        // 2 diffrent versions to go back to
        let diffToV2 = "{\"displayName\":\"Jay v2\", \"age\":null}"
        let dateV2 = Date(timeIntervalSince1970: 1000)
    
        let diffToV1 = "{\"displayName\":\"Jay v1\"}"
        let dateV1 = Date(timeIntervalSince1970: 500)
        
        let diffStrings: [(Date, String)] = [
            (dateV2, diffToV2),
            (dateV1, diffToV1)
        ]
        
        // Rebuild
        let history = dbControllerHelper.rebuildHistory(
            currentModel: currentModel,
            diffStrings: diffStrings
        ) { model, date in
            model.lastUpdated = date
        }
        
        // [0] will be current
        #expect(history.count == 3)
        
        // First will be v2
        let stateV2 = history[1]
        #expect(stateV2.displayName == "Jay v2")
        #expect(stateV2.age == nil)
        #expect(stateV2.id == "1")
        #expect(stateV2.lastUpdated == dateV2)
        
        // Second will be v1
        let stateV1 = history[2]
        #expect(stateV1.displayName == "Jay v1")
        #expect(stateV1.age == nil) // Still nil from the previous iteration
        #expect(stateV1.id == "1")
        #expect(stateV1.lastUpdated == dateV1)
    }
}
