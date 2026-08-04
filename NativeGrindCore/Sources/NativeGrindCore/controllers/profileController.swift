import Foundation
import SwiftData

public enum profileSource {
    case profile(profile)
    case id(String)
}

public actor profileController {
    public static let shared = profileController()
    public let dbController: dbProfileController
    private var missingMediaHashesOnServer = Set<String>()
    
    private init() {
        do {
            let config = ModelConfiguration("profile", isStoredInMemoryOnly: appEnvironment.isTesting)
            let container = try ModelContainer(for: dbProfile.self, dbProfileDiff.self, configurations: config)
            self.dbController = dbProfileController(modelContainer: container)
        } catch {
            fatalError("Container failed: \(error)")
        }
    }
    
    public func proactiveSyncMissingMedias(_ hashes: [String]) async {
        for hash in hashes {
            missingMediaHashesOnServer.insert(hash)
            _ = await fetchProfileImage(size: .size1024, mediaHash: hash)
        }
    }
    
    private func networkFetchProfile(profileId: String) async {
        do {
            let response = try await APIClient.shared.request(.getProfile(profileId: profileId))
            
            guard let profile = response?.profiles.first else {
                return
            }
            
            try await dbController.updateProfile(profileId: profileId, profile: profile)
            
            if await wsController.shared.isServerAuthorized {
                let geohash = await locationController.shared.currentGeohash
                await wsController.shared.send(request: .syncSeenProfile(profile: profile, geohash: geohash))
            }
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
    
    private func getLocalImageURL(mediaHash: String) -> URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let cachesDirectory = paths[0]
        return cachesDirectory.appendingPathComponent("\(mediaHash).jpg")
    }

    private func getLocalImageData(mediaHash: String) -> Data? {
        let url = getLocalImageURL(mediaHash: mediaHash)
        return try? Data(contentsOf: url)
    }

    private func saveImageDataLocally(mediaHash: String, data: Data) {
        let url = getLocalImageURL(mediaHash: mediaHash)
        try? data.write(to: url)
    }
    
    public func fetchProfileImage(size: imageSizes, mediaHash: String) async -> Data? {
        if let cachedData = getLocalImageData(mediaHash: mediaHash) {
            if self.missingMediaHashesOnServer.contains(mediaHash) {
                let base64String = cachedData.base64EncodedString()
                if await wsController.shared.isServerAuthorized {
                    await wsController.shared.send(request: .uploadMedia(mediaHash: mediaHash, base64Data: base64String))
                }
                self.missingMediaHashesOnServer.remove(mediaHash)
            }
            return cachedData
        }

        do {
            let data = try await APIClient.shared.request(.getProfileImage(size: size, mediaHash: mediaHash))
            
            if let data {
                saveImageDataLocally(mediaHash: mediaHash, data: data)
                
                if self.missingMediaHashesOnServer.contains(mediaHash) {
                    let base64String = data.base64EncodedString()
                    if await wsController.shared.isServerAuthorized {
                        await wsController.shared.send(request: .uploadMedia(mediaHash: mediaHash, base64Data: base64String))
                    }
                    self.missingMediaHashesOnServer.remove(mediaHash)
                }
            }
            
            return data
        } catch {
            let isNetworkError = (error as? requestError) == .networkError
            if !isNetworkError {
                await errorManager.shared.warn("profileController", "Failed to fetch profile image: \(error)")
            }
            return nil
        }
    }

    public func getProfileIdByImage(mediaHash: String) async -> String? {
        guard await wsController.shared.isServerAuthorized else {
            return nil
        }
        let response = await wsController.shared.sendAndWait(
            request: .getProfileByImage(mediaHash: mediaHash),
            expectedEvent: .onProfileByImage
        )
        return response?.profileId
    }
}
