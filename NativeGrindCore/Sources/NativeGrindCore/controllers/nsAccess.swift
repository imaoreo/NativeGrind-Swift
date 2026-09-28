//
//  nsAccess.swift
//  NativeGrindCore
//

import Foundation

public enum nsAccess {
    public static let contributionWindow: TimeInterval = 7 * 24 * 60 * 60

    private static let lastContributionKey = "ns_last_grid_contribution"

    public static var lastContribution: Date? {
        UserDefaults.standard.object(forKey: lastContributionKey) as? Date
    }

    public static func recordContribution() {
        UserDefaults.standard.set(Date(), forKey: lastContributionKey)
    }

    public static var hasAccount: Bool {
        keychainManager.shared.getToken(type: .accountKey)?.isEmpty == false
    }

    public static var hasContributed: Bool {
        guard let lastContribution else { return false }
        return Date().timeIntervalSince(lastContribution) < contributionWindow
    }

    public static var canReadShared: Bool {
        appEnvironment.isServerEnabled && hasAccount && hasContributed
    }
}
