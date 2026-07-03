//
//  endpointTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/07/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Suite("Endpoint Factory Tests")
struct endpointTests {
    
    @Test("Verifies fullURLString correctly appends path to the base URL")
    func testFullURLStringGeneration() {
        let testEndpoint: endpoint<[gender]> = .getGenders
        
        #expect(testEndpoint.fullURLString == "https://grindr.mobi/public/v2/genders")
        #expect(testEndpoint.method == .get)
        #expect(testEndpoint.isAuthedRoute == false)
    }
    
    @Test("Verifies dynamic path injection works for user profiles")
    func testProfilePathInjection() {
        let mockId = "98765-ABCDE"
        let testEndpoint: endpoint<profileResponse> = .getProfile(profileId: mockId)
        
        #expect(testEndpoint.path == "/v7/profiles/98765-ABCDE")
        #expect(testEndpoint.fullURLString == "https://grindr.mobi/v7/profiles/98765-ABCDE")
        #expect(testEndpoint.method == .get)
        #expect(testEndpoint.isAuthedRoute == true)
    }
    
    @Test("Verifies thirdPartyLogin configures correctly for Facebook")
    func testThirdPartyLoginFacebook() {
        let testEndpoint: endpoint<thirdPartyAuthResponse> = .thirdPartyLogin(token: "fb-mock-token", isFacebook: true)
        
        // Make sure facebook query was added
        #expect(testEndpoint.queryItems?["allowFacebookLimitedLogin"] == "true")
        
        // Also make sure facebooks vendorId was correct
        let vendorId = testEndpoint.body?["thirdPartyVendor"] as? Int
        #expect(vendorId == 1)
        #expect(testEndpoint.body?["thirdPartyToken"] as? String == "fb-mock-token")
    }
    
    @Test("Verifies thirdPartyLogin configures correctly for Apple/Google")
    func testThirdPartyLoginOther() {
        let testEndpoint: endpoint<thirdPartyAuthResponse> = .thirdPartyLogin(token: "apple-mock-token", isFacebook: false)
        
        // For non-facebook make sure it's nil
        #expect(testEndpoint.queryItems == nil)
        
        // For apple make sure it is 2
        let vendorId = testEndpoint.body?["thirdPartyVendor"] as? Int
        #expect(vendorId == 2)
    }
    
    @Test("Verifies getInbox completely removes nil values from the JSON body")
    func testGetInboxFiltersNils() {
        let testEndpoint: endpoint<inboxResponse> = .getInbox(
            page: nil,
            unreadOnly: true,
            chemistryOnly: nil,
            favoritesOnly: nil,
            rightNowOnly: nil,
            onlineNowOnly: nil,
            distanceMeters: 500.5,
            positions: nil
        )
        
        // Since page is nil this should be nil
        #expect(testEndpoint.queryItems == nil)
        
        let body = testEndpoint.body ?? [:]
        
        // unreadOnly and distanceMeters are the only 2 filters
        #expect(body.count == 2)
        #expect(body["unreadOnly"] as? Bool == true)
        #expect(body["distanceMeters"] as? Double == 500.5)
        
        // make sure that they don't contain others
        #expect(body.keys.contains("chemistryOnly") == false)
        #expect(body.keys.contains("favoritesOnly") == false)
    }
    
    @Test("Verifies getInbox maps the 'page' integer to a URL query string correctly")
    func testGetInboxPageMapping() {
        let testEndpoint: endpoint<inboxResponse> = .getInbox(page: 5)
        
        // Ensure that it is becoming a String
        #expect(testEndpoint.queryItems?["page"] == "5")
    }
    
    @Test("Verifies critical Authentication routes do not require a stored token")
    func testAuthRoutesAreNotAuthed() {
        let loginEndpoint: endpoint<authenticationResponse> = .login(email: "test@test.com", password: "password123")
        let refreshEndpoint: endpoint<authenticationResponse> = .refreshToken(email: "test@test.com", token: "old-token")
        
        #expect(loginEndpoint.isAuthedRoute == false)
        #expect(refreshEndpoint.isAuthedRoute == false)
    }
    
    @Test("Verifies challenge attestation and health endpoints configure correctly")
    func testNativeServerChallengeEndpoints() {
        let challengeEndpoint: endpoint<challengeResponse> = .getChallengeForCheck()
        let submitEndpoint: endpoint<challengeCheckedResponse> = .giveChallengeForCheck(
            keyId: "test-key-id",
            attestation: "test-attestation",
            challenge: "test-challenge"
        )
        let healthEndpoint: endpoint<challengeHealthResponse> = .checkChallengeHealth()
        
        #expect(challengeEndpoint.fullURLString == "https://nativeserver.imaoreo.dev/api/v1/challenge")
        #expect(challengeEndpoint.method == .get)
        #expect(challengeEndpoint.isAuthedRoute == false)
        
        #expect(submitEndpoint.fullURLString == "https://nativeserver.imaoreo.dev/api/v1/challenge")
        #expect(submitEndpoint.method == .post)
        #expect(submitEndpoint.body?["keyId"] as? String == "test-key-id")
        #expect(submitEndpoint.body?["attestation"] as? String == "test-attestation")
        #expect(submitEndpoint.body?["challenge"] as? String == "test-challenge")
        
        #expect(healthEndpoint.fullURLString == "https://nativeserver.imaoreo.dev/api/v1/challenge/health")
        #expect(healthEndpoint.method == .post)
        #expect(healthEndpoint.shouldSignBody == true)
    }
}
