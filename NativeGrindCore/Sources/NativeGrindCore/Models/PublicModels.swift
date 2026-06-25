//
//  PublicModels.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 15/06/2026.
//

public struct gender: Decodable, Sendable {
    public let genderId: Int
    public let gender: String // Man, Trans Man, Non-Binary
    public let displayGroup: Int
    public let sortProfile: Int?
    public let sortFilter: Int?
    public let genderPlural: String
    public let excludeOnProfileSelection: [Int]?
    public let excludeOnFilterSelection: [Int]?
    public let alsoClassifiedAs: [Int]
}


public struct pronoun: Decodable, Sendable {
    public let pronounId: Int
    public let pronoun: String // He/Him/His, etc.
}
