import Foundation
import SwiftData

public enum inboxSource {
    case inbox(conversationData)
    case id(String)
}

public actor inboxController {
    public static let shared = inboxController()
    public let dbController: dbInboxController
    
    private init() {
        let container = try! ModelContainer(for: dbProfile.self)
        self.dbController = dbInboxController(modelContainer: container)
    }
    
    private func networkFetchInbox(page: Int? = 1, unreadOnly: Bool? = nil, chemistryOnly: Bool? = nil, favoritesOnly: Bool? = nil, rightNowOnly: Bool? = nil, onlineNowOnly: Bool? = nil, distanceMeters: Double? = nil, positions: [sexualPosition]? = nil) async {
        do {
            let response = try await APIClient.shared.request(.getInbox(
                page: page,
                unreadOnly: unreadOnly,
                chemistryOnly: chemistryOnly,
                favoritesOnly: favoritesOnly,
                rightNowOnly: rightNowOnly,
                onlineNowOnly: onlineNowOnly,
                distanceMeters: distanceMeters,
                positions: positions
            ))
            
            guard let conversations = response?.entries, !conversations.isEmpty else {
                return
            }
            
            // Cache all
            for conversation in conversations {
                try await dbController.updateInbox(inbox: conversation.data)
            }
        } catch {
            await errorManager.shared.warn("inboxController", "Failed to network fetch profile: \(error)")
        }
    }
    
    // Fetches Inboxs
    // Bear in mind chemistryOnly doesn't seem to do anything
    public func fetchInbox(page: Int = 1, unreadOnly: Bool? = nil, chemistryOnly: Bool? = nil, favoritesOnly: Bool? = nil, rightNowOnly: Bool? = nil, onlineNowOnly: Bool? = nil, distanceMeters: Double? = nil, positions: [sexualPosition]? = nil) async -> [(conversation: conversationData, profile: profile)]? {
        do {
            await networkFetchInbox(
                page: page,
                unreadOnly: unreadOnly,
                chemistryOnly: chemistryOnly,
                favoritesOnly: favoritesOnly,
                rightNowOnly: rightNowOnly,
                onlineNowOnly: onlineNowOnly,
                distanceMeters: distanceMeters,
                positions: positions
            )
            
            guard let inboxs = try await dbController.fetchInboxs(),
                  let profiles = await profileController.shared.fetchProfiles() else {
                return []
            }
            
            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.profileId, $0) })
                    
            var results: [(conversation: conversationData, profile: profile)] = []
            
            for inbox in inboxs {
                // get the other user
                guard let firstParticipant = inbox.participants.first else { continue }
                
                // Convo Filtering
                if let unreadOnly, unreadOnly == true {
                    guard inbox.unreadCount > 0 else { continue }
                }
                
                if let favoritesOnly, favoritesOnly == true {
                    guard inbox.favorite == true else { continue }
                }
                
                if let rightNowOnly, rightNowOnly == true {
                    guard inbox.rightNow != .notHosting else { continue }
                }
                
                // match the user with a Profile
                if let matchedProfile = profileMap[firstParticipant.profileId] {
                    
                    // 3. Apply local filters if flags are passed
                    results.append((conversation: inbox, profile: matchedProfile))
                }
            }
            
            return results
        } catch {
            await errorManager.shared.error("inboxController", "Failed to fetch inbox: \(error)")
            return nil
        }
    }
    
    public func getHistroyForInbox(source: inboxSource) async -> [conversationData]? {
        do {
            var conversationId: String
            
            switch source {
                case .inbox(let inbox):
                    conversationId = inbox.conversationId
                case .id(let _conversationId):
                    conversationId = _conversationId
                    await networkFetchInbox(page: 1)
            }
            
            let profile = try await dbController.fetchInboxDiffs(conversationId: conversationId)

            return profile
        } catch {
            await errorManager.shared.error("profileController", "Failed to fetch or cache profile / profile history: \(error)")
            return nil
        }
        
    }
}
