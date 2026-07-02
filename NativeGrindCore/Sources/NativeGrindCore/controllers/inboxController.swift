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
        do {
            let config = ModelConfiguration("inbox", isStoredInMemoryOnly: appEnvironment.isTesting)
            let container = try ModelContainer(for: dbInbox.self, dbInboxDiff.self, configurations: config)
            self.dbController = dbInboxController(modelContainer: container)
        } catch {
            fatalError("Container failed: \(error)")
        }
    }
    
    private func networkFetchInboxes(page: Int? = 1, unreadOnly: Bool? = nil, chemistryOnly: Bool? = nil, favoritesOnly: Bool? = nil, rightNowOnly: Bool? = nil, onlineNowOnly: Bool? = nil, distanceMeters: Double? = nil, positions: [sexualPosition]? = nil) async {
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
            let isNetworkError = (error as? requestError) == .networkError
                
            if !isNetworkError {
                await errorManager.shared.warn("inboxController", "Failed to network fetch inbox: \(error)")
            }
        }
    }
    
    // Fetches Inboxes
    // Bear in mind chemistryOnly doesn't seem to do anything
    public func fetchInboxes(depth: Int = 1, offset: Int = 0, unreadOnly: Bool? = nil, chemistryOnly: Bool? = nil, favoritesOnly: Bool? = nil, rightNowOnly: Bool? = nil, onlineNowOnly: Bool? = nil, distanceMeters: Double? = nil, positions: [sexualPosition]? = nil, minAge: Int? = nil, maxAge: Int? = nil, hideProfilesWithoutAge: Bool = false) async -> [(conversation: conversationData, profile: profile)]? {
        do {
            await withTaskGroup(of: Void.self) { group in
                guard depth > 0 else { return }
                
                for page in 1...depth {
                    group.addTask {
                        await self.networkFetchInboxes(
                            page: page + offset,
                            unreadOnly: unreadOnly,
                            chemistryOnly: chemistryOnly,
                            favoritesOnly: favoritesOnly,
                            rightNowOnly: rightNowOnly,
                            onlineNowOnly: onlineNowOnly,
                            distanceMeters: distanceMeters,
                            positions: positions
                        )
                    }
                }
            }

            
            guard let inboxes = try await dbController.fetchInboxes(),
                  let profiles = await profileController.shared.fetchProfiles() else {
                return []
            }
            
            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.profileId, $0) })
                    
            var results: [(conversation: conversationData, profile: profile)] = []
            
            for inbox in inboxes {
                // get the other user
                guard let firstParticipant = inbox.participants.first else { continue }
                
                // Convo Filtering
                if let unreadOnly, unreadOnly == true {
                    guard inbox.unreadCount > 0 else { continue }
                }
                
                if let favoritesOnly, favoritesOnly == true {
                    guard inbox.favorite == true else { continue }
                }
                
                if let rightNowOnly, rightNowOnly == true, let createdAt = inbox.dbCreatedAt {
                    if (createdAt > Date().addingTimeInterval(-600)) {
                        guard inbox.rightNow != .notHosting else { continue }
                    } else {
                        continue
                    }
                }
                
                // match the user with a Profile
                if let matchedProfile = profileMap[firstParticipant.profileId] {
                    if let onlineNowOnly, onlineNowOnly == true, let onlineUntil = matchedProfile.onlineUntil {
                        guard onlineUntil > Date().addingTimeInterval(-600) else { continue }
                    }
                    
                    if let distanceMeters, let distance = matchedProfile.distance {
                        guard distance <= distanceMeters else { continue }
                    }
                    
                    if let positions {
                        guard positions.contains(matchedProfile.sexualPosition) else { continue }
                    }
                    
                    if let minAge, let profileAge = matchedProfile.age {
                        guard profileAge > minAge else { continue }
                    }
                    
                    if let maxAge, let profileAge = matchedProfile.age {
                        guard profileAge < maxAge else { continue }
                    }
                    
                    if hideProfilesWithoutAge {
                        guard let age = matchedProfile.age, age > 0 else { continue }
                    }
                    
                    results.append((conversation: inbox, profile: matchedProfile))
                }
            }
            
            return results
        } catch {
            await errorManager.shared.error("inboxController", "Failed to fetch inbox: \(error)")
            return nil
        }
    }
    
    public func getHistoryForInbox(source: inboxSource) async -> [conversationData]? {
        do {
            var conversationId: String
            
            switch source {
                case .inbox(let inbox):
                    conversationId = inbox.conversationId
                case .id(let _conversationId):
                    conversationId = _conversationId
                    await networkFetchInboxes(page: 1)
            }
            
            let inbox = try await dbController.fetchInboxDiffs(conversationId: conversationId)

            return inbox
        } catch {
            await errorManager.shared.error("inboxController", "Failed to fetch or cache inbox / inbox history: \(error)")
            return nil
        }
        
    }
}
