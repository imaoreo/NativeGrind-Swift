//
//  nsStorage.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 31/07/2026.
//

import Foundation

public struct nsStorageLocation<T: Codable> {
    public let path: String
}

public extension nsStorageLocation {
    static var accounts: nsStorageLocation<[nsAccount]> {
        return nsStorageLocation<[nsAccount]>(path: "grindr_accounts")
    }
}

public struct nsAccount: Codable, Sendable {
    public var authToken: String
    public var sessionId: String
    public var isEmail: String
    public var data: String
}
