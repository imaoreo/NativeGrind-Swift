//
//  legalControllerTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 26/09/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@MainActor
@Suite("Legal Acceptance Tests")
struct legalControllerTests {
    private func freshDefaults() -> UserDefaults {
        let name = "legalControllerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("Asks on first launch and not again once accepted")
    func firstLaunch() {
        let defaults = freshDefaults()
        let controller = legalController(defaults: defaults)
        #expect(controller.needsAcceptance)
        #expect(!controller.isUpdate)

        controller.accept(confirmedAdult: true)
        #expect(!controller.needsAcceptance)

        // Survives a relaunch
        #expect(!legalController(defaults: defaults).needsAcceptance)
    }

    @Test("A newer version on the server asks again")
    func newerServerVersion() {
        let controller = legalController(defaults: freshDefaults())
        controller.accept(confirmedAdult: true)

        controller.apply(server: legalVersions(terms: "2099-01-01", privacy: legalController.bundled.privacy))
        #expect(controller.needsAcceptance)
        #expect(controller.isUpdate)

        controller.accept(confirmedAdult: true)
        #expect(controller.accepted?.terms == "2099-01-01")
        #expect(!controller.needsAcceptance)
    }

    @Test("An older version on the server never lowers what's required")
    func olderServerVersion() {
        let controller = legalController(defaults: freshDefaults())
        controller.apply(server: legalVersions(terms: "2000-01-01", privacy: "2000-01-01"))
        #expect(controller.required.terms == legalController.bundled.terms)
        #expect(controller.required.privacy == legalController.bundled.privacy)
        #expect(controller.termsURL != nil)
    }
}
