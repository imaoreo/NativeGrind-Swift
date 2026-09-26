//
//  legalController.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 26/09/2026.
//

import Foundation
import Combine

@MainActor
public final class legalController: ObservableObject {
    public static let shared = legalController()

    public static let bundled = legalVersions(
        terms: "2026-09-26",
        privacy: "2026-09-26",
        termsUrl: "https://nativegrind.imaoreo.dev/terms/",
        privacyUrl: "https://nativegrind.imaoreo.dev/privacy/"
    )

    @Published public private(set) var required: legalVersions
    @Published public private(set) var accepted: legalAcceptance?

    private let defaults: UserDefaults
    private static let storageKey = "legalAcceptance"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.required = Self.bundled
        self.accepted = defaults.data(forKey: Self.storageKey).flatMap { try? JSONDecoder().decode(legalAcceptance.self, from: $0) }
    }

    public var needsAcceptance: Bool {
        guard let accepted else { return true }
        return accepted.terms < required.terms || accepted.privacy < required.privacy
    }

    public var isUpdate: Bool {
        accepted != nil && needsAcceptance
    }

    public var termsURL: URL? { URL(string: required.termsUrl ?? Self.bundled.termsUrl ?? "") }
    public var privacyURL: URL? { URL(string: required.privacyUrl ?? Self.bundled.privacyUrl ?? "") }

    public func refresh() async {
        guard let server = try? await APIClient.shared.request(.getLegalVersions(), shouldErrorMessage: false) else { return }
        apply(server: server)
    }

    func apply(server: legalVersions) {
        required = legalVersions(
            terms: max(Self.bundled.terms, server.terms),
            privacy: max(Self.bundled.privacy, server.privacy),
            termsUrl: server.termsUrl ?? Self.bundled.termsUrl,
            privacyUrl: server.privacyUrl ?? Self.bundled.privacyUrl
        )
    }

    public func accept(confirmedAdult: Bool, at date: Date = Date()) {
        let acceptance = legalAcceptance(terms: required.terms, privacy: required.privacy, acceptedAt: date, confirmedAdult: confirmedAdult)
        if let data = try? JSONEncoder().encode(acceptance) {
            defaults.set(data, forKey: Self.storageKey)
        }
        accepted = acceptance
    }

    #if DEBUG
    public func resetForTesting() {
        defaults.removeObject(forKey: Self.storageKey)
        accepted = nil
    }
    #endif
}
