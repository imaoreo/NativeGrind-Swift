import Foundation
import SwiftData

public enum profileSource {
    case profile(profile)
    case id(String)
}

public actor profileController {
    public static let shared = profileController()
    public let dbController: dbProfileController
    
    private init() {
        let container = try! ModelContainer(for: dbProfile.self, dbProfileDiff.self)
        self.dbController = dbProfileController(modelContainer: container)
    }
    
    private func networkFetchProfile(profileId: String) async {
        do {
            let response = try await APIClient.shared.request(.getProfile(profileId: profileId))
            
            guard let profile = response?.profiles.first else {
                return
            }
            
            try await dbController.updateProfile(profileId: profileId, profile: profile)
        } catch {
            let isNetworkError = (error as? requestError) == .networkError
                
            if !isNetworkError {
                await errorManager.shared.warn("profileController", "Failed to network fetch profile: \(error)")
            }
        }
    }
    
    public func fetchProfile(profileId: String) async -> profile? {
        do {
            await networkFetchProfile(profileId: profileId)
            
            let profile = try await dbController.fetchProfile(profileId: profileId)

            return profile
        } catch {
            await errorManager.shared.error("profileController", "Failed to fetch or cache profile: \(error)")
            return nil
        }
    }
    
    public func fetchProfiles() async -> [profile]? {
        do {
            let profiles = try await dbController.fetchProfiles()

            return profiles
        } catch {
            await errorManager.shared.error("profileController", "Failed to fetch profiles: \(error)")
            return nil
        }
    }
    
    public func getHistoryFromProfile(source: profileSource) async -> [profile]? {
        do {
            var profileId: String
            
            switch source {
                case .profile(let profile):
                    profileId = profile.profileId
                case .id(let _profileId):
                    profileId = _profileId
                    await networkFetchProfile(profileId: profileId)
            }
            
            let profile = try await dbController.fetchProfileDiffs(profileId: profileId)

            return profile
        } catch {
            await errorManager.shared.error("profileController", "Failed to fetch or cache profile / profile history: \(error)")
            return nil
        }
        
    }
}
