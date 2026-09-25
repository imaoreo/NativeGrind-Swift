//
//  dbProfileControllerTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/07/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Database Profile Controller Tests")
struct dbProfileControllerTests {
    
    // make a TestController
    private func makeTestController() throws -> dbProfileController {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("profileStoreTests-\(UUID().uuidString)", isDirectory: true)
        return dbProfileController(store: localStore(root: root))
    }

    @Test("Verifies fetching a non-existent profile returns nil safely")
    func testFetchMissingProfile() async throws {
        let controller = try makeTestController()
        
        let result = try await controller.fetchProfile(profileId: "does-not-exist")
        
        #expect(result == nil)
    }
    
    @Test("Verifies fetchProfiles() returns an empty array when the database is empty")
    func testFetchAllEmptyDatabase() async throws {
        let controller = try makeTestController()
        
        let results = try await controller.fetchProfiles()
        
        #expect(results != nil)
        #expect(results?.isEmpty == true)
    }

    @Test("Verifies inserting a brand new profile saves successfully")
    func testInsertNewProfile() async throws {
        let controller = try makeTestController()
        let testId = "profile-123"
        let newProfile = mockProfile(id: testId)
        
        try await controller.updateProfile(profileId: testId, profile: newProfile)
        
        let fetchedProfile = try await controller.fetchProfile(profileId: testId)
        
        #expect(fetchedProfile != nil)
        #expect(fetchedProfile?.profileId == testId)
    }
    
    @Test("Verifies fetching all profiles returns multiple saved records")
    func testFetchMultipleProfiles() async throws {
        let controller = try makeTestController()
        
        // Add 2 diffrent profiles
        try await controller.updateProfile(profileId: "user-A", profile: mockProfile(id: "user-A"))
        try await controller.updateProfile(profileId: "user-B", profile: mockProfile(id: "user-B"))
        
        let allProfiles = try await controller.fetchProfiles()
        
        #expect(allProfiles?.count == 2)
        
        let ids = allProfiles?.map { $0.profileId } ?? []
        #expect(ids.contains("user-A"))
        #expect(ids.contains("user-B"))
    }
    
    @Test("Verifies updating an existing profile modifies the main record and creates a diff")
    func testUpdateCreatesDiff() async throws {
        let controller = try makeTestController()
        let testId = "profile-diff-test"
        
        let v1Profile = mockProfile(id: testId)
        try await controller.updateProfile(profileId: testId, profile: v1Profile)
        
        var v2Profile = v1Profile
        v2Profile.dbCreatedAt = Date() // Mutating to force a JSON diff
        try await controller.updateProfile(profileId: testId, profile: v2Profile)
        
        let history = try await controller.fetchProfileDiffs(profileId: testId)
        
        #expect(history.count == 2)
        
        #expect(history.first?.profileId == testId)
        #expect(history.last?.profileId == testId)
    }
    
    @Test("Verifies fetchProfileDiffs returns an empty array if the profile doesn't exist")
    func testFetchDiffsForMissingProfile() async throws {
        let controller = try makeTestController()
        
        let history = try await controller.fetchProfileDiffs(profileId: "ghost-user")
        
        #expect(history.isEmpty == true)
    }
}
