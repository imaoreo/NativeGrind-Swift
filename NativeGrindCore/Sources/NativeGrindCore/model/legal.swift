//
//  legal.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 26/09/2026.
//

import Foundation

public struct legalVersions: Codable, Sendable, Equatable {
    public let terms: String
    public let privacy: String
    public let termsUrl: String?
    public let privacyUrl: String?

    public init(terms: String, privacy: String, termsUrl: String? = nil, privacyUrl: String? = nil) {
        self.terms = terms
        self.privacy = privacy
        self.termsUrl = termsUrl
        self.privacyUrl = privacyUrl
    }
}

public struct legalAcceptance: Codable, Sendable, Equatable {
    public let terms: String
    public let privacy: String
    public let acceptedAt: Date
    public let confirmedAdult: Bool
}
