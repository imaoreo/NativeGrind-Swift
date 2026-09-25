import Foundation

public actor inboxController {
    public static let shared = inboxController()
    
    private func networkFetchInboxes(page: Int? = 1, unreadOnly: Bool? = nil, chemistryOnly: Bool? = nil, favoritesOnly: Bool? = nil, rightNowOnly: Bool? = nil, onlineNowOnly: Bool? = nil, distanceMeters: Double? = nil, positions: [sexualPosition]? = nil) async -> [conversationData]? {
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
                return nil
            }
            
            return conversations.map { $0.data }
        } catch {
            let isNetworkError = (error as? requestError) == .networkError
                
            if !isNetworkError {
                await errorManager.shared.warn("inboxController", "Failed to network fetch inbox: \(error)")
            }
            
            return nil
        }
    }
    
    // Fetches Inboxes
    // Bear in mind chemistryOnly doesn't seem to do anything
    public func fetchInboxes(depth: Int = 1, offset: Int = 0, unreadOnly: Bool? = nil, chemistryOnly: Bool? = nil, favoritesOnly: Bool? = nil, rightNowOnly: Bool? = nil, onlineNowOnly: Bool? = nil, distanceMeters: Double? = nil, positions: [sexualPosition]? = nil, minAge: Int? = nil, maxAge: Int? = nil, hideProfilesWithoutAge: Bool = false, pinnedAtTop: Bool? = true) async -> [(conversation: conversationData, profile: profile?)]? {
        
        var fetchedInboxes: [conversationData] = []
                
        await withTaskGroup(of: [conversationData]?.self) { group in
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
            
            for await pageInboxes in group {
                if let pageInboxes {
                    fetchedInboxes.append(contentsOf: pageInboxes)
                }
            }
        }

        
        guard let profiles = await profileController.shared.fetchProfiles() else {
            return []
        }
        
        let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.profileId, $0) })
                
        var results: [(conversation: conversationData, profile: profile?)] = []
        
        for inbox in fetchedInboxes {
            // get the other user
            guard let firstParticipant = inbox.participants.first else { continue }
            
            // Convo Filtering
            if let unreadOnly, unreadOnly == true {
                guard inbox.unreadCount > 0 else { continue }
            }
            
            if let favoritesOnly, favoritesOnly == true {
                guard inbox.favorite == true else { continue }
            }
            
            // match the user with a Profile
            if let matchedProfile = profileMap["\(firstParticipant.profileId)"] {
                if let onlineNowOnly, onlineNowOnly == true, let onlineUntil = matchedProfile.onlineUntil {
                    guard onlineUntil > Date().addingTimeInterval(-600) else { continue }
                }
                
                if let distanceMeters, let distance = matchedProfile.distance {
                    guard distance <= distanceMeters else { continue }
                }
                
                if let positions, let userPositions = matchedProfile.sexualPosition {
                    guard positions.contains(userPositions) else { continue }
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
            } else {
                results.append((conversation: inbox, profile: nil))
            }
        }
        
        let sortedResults = results.sorted { lhs, rhs in
            if let pinnedAtTop, pinnedAtTop == true {
                if lhs.conversation.pinned != rhs.conversation.pinned {
                    return lhs.conversation.pinned
                }
            }
            
            return lhs.conversation.lastActivityTimestamp > rhs.conversation.lastActivityTimestamp
        }
        
        return sortedResults
    }
}
