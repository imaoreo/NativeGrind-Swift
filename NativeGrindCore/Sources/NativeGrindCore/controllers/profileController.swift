import Foundation
import SwiftData

public enum profileSource {
    case profile(profile)
    case id(String)
}

public struct GridResponse: Codable, Sendable {
    public let profiles: [CascadeResponseProfile]
    public let nextPage: Int?
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
            _ = await fetchProfileImage(size: .size2048, mediaHash: hash)
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
    
    private func getLocalImageURL(mediaHash: String) -> URL? {
        guard let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cachesDirectory.appendingPathComponent("\(mediaHash).jpg")
    }

    private func getLocalImageData(mediaHash: String) -> Data? {
        guard let url = getLocalImageURL(mediaHash: mediaHash) else {
            return nil
        }
        return try? Data(contentsOf: url)
    }

    private func saveImageDataLocally(mediaHash: String, data: Data) {
        guard let url = getLocalImageURL(mediaHash: mediaHash) else {
            return
        }
        try? data.write(to: url)
    }

    private func isHighQuality(size: imageSizes) -> Bool {
        return size == .size1024 || size == .size2048
    }
    
    public func fetchProfileImage(size: imageSizes, mediaHash: String) async -> Data? {
        if isHighQuality(size: size) {
            if !appEnvironment.isTesting, let cachedData = getLocalImageData(mediaHash: mediaHash) {
                if self.missingMediaHashesOnServer.contains(mediaHash) {
                    let base64String = cachedData.base64EncodedString()
                    if await wsController.shared.isServerAuthorized {
                        await wsController.shared.send(request: .uploadMedia(mediaHash: mediaHash, base64Data: base64String))
                    }
                    self.missingMediaHashesOnServer.remove(mediaHash)
                }
                return cachedData
            }
        }

        do {
            var data: Data? = nil
            
            if size == .size2048 {
                do {
                    data = try await APIClient.shared.request(.getProfileImage(size: .size2048, mediaHash: mediaHash), shouldErrorMessage: false)
                } catch {

                }
                if data == nil {
                    data = try await APIClient.shared.request(.getProfileImage(size: .size1024, mediaHash: mediaHash))
                }
            } else {
                data = try await APIClient.shared.request(.getProfileImage(size: size, mediaHash: mediaHash))
            }
            
            if let data {
                if isHighQuality(size: size) {
                    if !appEnvironment.isTesting {
                        saveImageDataLocally(mediaHash: mediaHash, data: data)
                    }
                    
                    if self.missingMediaHashesOnServer.contains(mediaHash) {
                        let base64String = data.base64EncodedString()
                        if await wsController.shared.isServerAuthorized {
                            await wsController.shared.send(request: .uploadMedia(mediaHash: mediaHash, base64Data: base64String))
                        }
                        self.missingMediaHashesOnServer.remove(mediaHash)
                    }
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

    public func fetchGrid(
        geohash: String,
        filters: GridFilters = GridFilters()
    ) async -> GridResponse? {
        do {
            let response = try await APIClient.shared.request(
                .getGrid(geohash: geohash, filters: filters)
            )
            
            guard let response = response else {
                await errorManager.shared.error("profileController", "Failed to fetch grid: Empty or invalid response from server")
                return nil
            }

            var profiles: [CascadeResponseProfile] = []
            for item in response.items {
                if item.isProfile, let data = item.data {
                    profiles.append(data)
                }
            }

            let serverAuthorized = await wsController.shared.isServerAuthorized
            if serverAuthorized {
                Task {
                    let response = await wsController.shared.sendAndWait(
                        request: .syncGrid(profiles: profiles, geohash: geohash),
                        expectedEvent: .onGridSynced
                    )
                    if let missing = response?.missingMediaHashes, !missing.isEmpty {
                        await proactiveSyncMissingMedias(missing)
                    }
                }
            }

            return GridResponse(profiles: profiles, nextPage: response.nextPage)
        } catch {
            let isNetworkError = (error as? requestError) == .networkError
            if !isNetworkError {
                await errorManager.shared.warn("profileController", "Failed to fetch grid: \(error)")
            }
            await errorManager.shared.error("profileController", "Failed to fetch grid: \(error)")
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
