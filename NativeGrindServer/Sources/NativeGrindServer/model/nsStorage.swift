//
//  nsStorage.swift
//  NativeGrindServer
//
//  Created by Jay Brammeld on 31/07/2026.
//

import Foundation

public struct nsStorageLocation<T: Codable> {
    public let path: String
}

public extension nsStorageLocation {
    static var accounts: nsStorageLocation<nsAccountsStorage> {
        return nsStorageLocation<nsAccountsStorage>(path: "grindr_accounts")
    }
}

public struct nsAccountsStorage: Codable, Sendable {
    public var accounts: [nsAccount]
}

public struct nsAccount: Codable, Sendable {
    public var authToken: String
    public var sessionId: String
    public var isEmail: String
    public var data: Bool
}
