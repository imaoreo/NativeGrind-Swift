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

public struct nsCloudAccount: Codable, Sendable {
    public var authToken: String
    public var isEmail: String
    public var data: String
    
    public init(from account: nsAccount) {
        self.authToken = account.authToken
        self.isEmail = account.isEmail
        self.data = account.data
    }
    
    public func toAccount(sessionId: String = "") -> nsAccount {
        return nsAccount(authToken: authToken, sessionId: sessionId, isEmail: isEmail, data: data)
    }
}

public extension nsStorageLocation {
    static var accounts: nsStorageLocation<[nsCloudAccount]> {
        return nsStorageLocation<[nsCloudAccount]>(path: "grindr_accounts")
    }
}

public struct nsAccount: Codable, Sendable {
    public var authToken: String
    public var sessionId: String
    public var isEmail: String
    public var data: String
}
