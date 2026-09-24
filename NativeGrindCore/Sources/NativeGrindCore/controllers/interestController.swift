//
//  interestController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 25/09/2026.
//

import Foundation

public actor interestController {
    public static let shared = interestController()

    public func fetchViews() async -> viewsResponseV7? {
        do {
            return try await APIClient.shared.request(.getViewsV7())
        } catch {
            await warnUnlessOffline("Failed to fetch views", error)
            return nil
        }
    }

    public func fetchTaps() async -> [tapProfileV2]? {
        do {
            let response = try await APIClient.shared.request(.getTapsV2())
            return response?.profiles.sorted { $0.timestamp > $1.timestamp }
        } catch {
            await warnUnlessOffline("Failed to fetch taps", error)
            return nil
        }
    }

    public func tap(profileId: String, type: tapType) async -> Bool? {
        do {
            return try await APIClient.shared.request(.tap(profileId: profileId, tapType: type))?.isMutual
        } catch {
            await warnUnlessOffline("Failed to tap", error)
            return nil
        }
    }

    private func warnUnlessOffline(_ message: String, _ error: Error) async {
        if (error as? requestError) != .networkError {
            await errorManager.shared.warn("interestController", "\(message): \(error)")
        }
    }
}
