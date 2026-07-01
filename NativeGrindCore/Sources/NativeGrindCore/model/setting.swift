//
//  setting.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 30/06/2026.
//

public struct preferenceSettingResponse: Codable, Sendable {
    public let profileId: String
    public let locationSearchOptOut: Bool // unclear what this is
    public let incognito: Bool
    public let hideViewedMe: Bool
    public let approximateDistance: Bool
    public let viewRightNowNsfw: Bool
    public let showOnMap: Bool
    public let mapLocationFuzzRadius: Int
}
