//
//  dbInboxControllerTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/07/2026.
//

import Testing
import SwiftData
import Foundation
@testable import NativeGrindCore

@Suite("Database Inbox Controller Tests")
struct dbInboxControllerTests {
    
    // make a TestController
    private func makeTestController() throws -> dbInboxController {
        // Register the SwiftData models used by this controller
        let schema = Schema([dbInbox.self, dbInboxDiff.self])
        
        // Force the database to exist ONLY in RAM (wiped instantly when the test finishes)
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        
        let container = try ModelContainer(for: schema, configurations: [config])
        return dbInboxController(modelContainer: container)
    }
    
    // Dummy Inbox
    private func mockConversation(id: String, text: String = "Hello") -> conversationData {
        return conversationData(
            conversationId: id,
            name: "Test",
            participants: [
                conversationParticipant(
                    profileId: "12345",
                    primaryMediaHash: "",
                    lastOnline: "0",
                    onlineUntil: "100",
                    distanceMetres: 10,
                    position: [.top],
                    isInAList: false,
                    hasDatingPotential: false
                )
            ],
            lastActivityTimestamp: 0,
            unreadCount: 0,
            preview:
                conversationPreview(
                    conversationId: conversationIdObject(value: "100:100"),
                    messageId: "1234",
                    chat1MessageId: "1234",
                    senderId: "12345",
                    type: .text,
                    chat1Type: .text,
                    text: text,
                    url: nil,
                    lat: nil,
                    lon: nil,
                    albumId: nil,
                    albumContentId: nil,
                    albumContentReply: "",
                    duration: nil,
                    imageHash: nil,
                    photoContentReply: nil,
                ),
            muted: true,
            pinned: false,
            favorite: true,
            context: 1,
            onlineUntil: 0,
            translatable: false,
            rightNow: .notActive,
            hasUnreadThrob: false
        )
    }

    @Test("Verifies fetching a non-existent inbox returns nil safely")
    func testFetchMissingInbox() async throws {
        let controller = try makeTestController()
        
        let result = try await controller.fetchInboxes(conversationId: "does-not-exist")
        
        #expect(result == nil)
    }
    
    @Test("Verifies fetchInboxes() returns an empty array when the database is empty")
    func testFetchAllEmptyDatabase() async throws {
        let controller = try makeTestController()
        
        let results = try await controller.fetchInboxes()
        
        // will return []
        #expect(results != nil)
        #expect(results?.isEmpty == true)
    }

    @Test("Verifies inserting a brand new inbox saves successfully")
    func testInsertNewInbox() async throws {
        let controller = try makeTestController()
        let newInbox = mockConversation(id: "chat-123")
        
        // Insert the Inbox
        try await controller.updateInbox(inbox: newInbox)
        
        let fetchedInbox = try await controller.fetchInboxes(conversationId: "chat-123")
        
        #expect(fetchedInbox != nil)
        #expect(fetchedInbox?.conversationId == "chat-123")
    }
    
    @Test("Verifies fetching all inboxes returns multiple saved records")
    func testFetchMultipleInboxes() async throws {
        let controller = try makeTestController()
        
        // Add 2 diffrent inboxs
        try await controller.updateInbox(inbox: mockConversation(id: "chat-A"))
        try await controller.updateInbox(inbox: mockConversation(id: "chat-B"))
        
        let allInboxes = try await controller.fetchInboxes()
        
        #expect(allInboxes?.count == 2)
        
        let ids = allInboxes?.map { $0.conversationId } ?? []
        #expect(ids.contains("chat-A"))
        #expect(ids.contains("chat-B"))
    }
    
    @Test("Verifies updating an existing inbox modifies the main record and creates a diff")
    func testUpdateCreatesDiff() async throws {
        let controller = try makeTestController()
        let chatId = "chat-diff-test"
        
        // make v1
        let v1Inbox = mockConversation(id: chatId)
        try await controller.updateInbox(inbox: v1Inbox)
        
        // The diffrence is the text
        let v2Inbox = mockConversation(id: chatId, text: "yas")
        try await controller.updateInbox(inbox: v2Inbox)
        
        // Fetch the DIFF
        let history = try await controller.fetchInboxDiffs(conversationId: chatId)
        
        // There will be 2, v1 and v2
        #expect(history.count == 2)
        
        // The ID should be the same
        #expect(history.first?.conversationId == chatId)
        #expect(history.last?.conversationId == chatId)
        
        // The first one is the newest, the last one is the oldest
        #expect(history.first?.preview.text == "yas")
        #expect(history.last?.preview.text == "Hello")
    }
    
    @Test("Verifies fetchInboxDiffs returns an empty array if the inbox doesn't exist")
    func testFetchDiffsForMissingInbox() async throws {
        let controller = try makeTestController()
        
        let history = try await controller.fetchInboxDiffs(conversationId: "ghost-chat")
        
        #expect(history.isEmpty == true)
    }
}
