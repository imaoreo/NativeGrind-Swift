//
//  APIClientTests.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 01/07/2026.
//

import Testing
import Foundation
@testable import NativeGrindCore

@Test("Verifies building of Accept-Language headers", arguments: [
        (input: "en-GB", expected: "en-GB,en;q=0.9"),
        (input: "en-US", expected: "en-US,en;q=0.9"),
        (input: "fr-CA", expected: "fr-CA,fr;q=0.9"),
        (input: "pt-BR", expected: "pt-BR,pt;q=0.9"),
        (input: "de-DE", expected: "de-DE,de;q=0.9"),
        (input: "es-ES", expected: "es-ES,es;q=0.9"),
        (input: "ja-JP", expected: "ja-JP,ja;q=0.9")
    ])
func testBuildingAcceptLanguageHeaders(input: String, expected: String) async {
    let result = await APIClient.shared.buildAcceptLanguageHeader(for: input)
    
    #expect(result == expected)
}

@Suite("APIClientSetupTest", .serialized) struct APIClientSetupTest {
    @Test("Verifies language hyphens are converted to underscores for L-Locale")
    func testLocaleFormatting() async {
        await APIClient.shared.setup(timezone: "Europe/London", language: "en-GB", deviceId: "mock-id")
        
        let headers = await APIClient.shared.session?.configuration.httpAdditionalHeaders
        let localeHeader = headers?["L-Locale"] as? String
        
        #expect(localeHeader == "en_GB")
    }
    
    @Test("Verifies L-Device-Info header matches the expected format")
    func testDeviceInfoComposition() async {
        let testDeviceId = "ABCDE-12345"
        
        await APIClient.shared.setup(timezone: "America/New_York", language: "en-US", deviceId: testDeviceId)
        
        let headers = await APIClient.shared.session?.configuration.httpAdditionalHeaders
        let deviceInfo = headers?["L-Device-Info"] as? String
        
        #expect(deviceInfo == "ABCDE-12345;appStore;2;8565768192;2796x1290")
    }
    
    @Test("Verifies standard static network headers are injected")
    @MainActor
    func testStaticHeaders() async {
        await APIClient.shared.setup(timezone: "Asia/Tokyo", language: "ja-JP", deviceId: "id")
        
        let headers = await APIClient.shared.session?.configuration.httpAdditionalHeaders
        
        #expect(headers?["Accept"] as? String == "application/json")
        #expect(headers?["Accept-Encoding"] as? String == "gzip, deflate, br")
        #expect(headers?["Connection"] as? String == "keep-alive")
        #expect(headers?["User-Agent"] as? String == "Grindr3/26.9.2.99239.060331878.99 (99239.060331878.99; iPhone99,11; iOS 26.1)")
    }
    
    @Test("Verifies edge-case timezones and languages map correctly", arguments: [
        (tz: "America/Los_Angeles", lang: "es-US", expectedLocale: "es_US"),
        (tz: "Australia/Sydney", lang: "en-AU", expectedLocale: "en_AU"),
        (tz: "Africa/Cairo", lang: "ar-EG", expectedLocale: "ar_EG")
    ])
    func testVariousConfigurations(tz: String, lang: String, expectedLocale: String) async {
        await APIClient.shared.setup(timezone: tz, language: lang, deviceId: "test-id")
        
        let headers = await APIClient.shared.session?.configuration.httpAdditionalHeaders
        
        #expect(headers?["L-Time-Zone"] as? String == tz)
        #expect(headers?["L-Locale"] as? String == expectedLocale)
    }
    
    @Test("Ensures the generated session is strictly ephemeral")
    func testSessionIsEphemeral() async {
        await APIClient.shared.setup(timezone: "Europe/Paris", language: "fr-FR", deviceId: "id")
        
        let config = await APIClient.shared.session?.configuration
        
        #expect(config?.urlCache?.diskCapacity == 0)
    }
}

@Suite("Send Request Tests")
@MainActor
struct SendRequestTests {
    @Test("Throws malformedURL error for broken URL strings", arguments: [
        "",
        "https://exam ple.com",
        "🔍"
    ])
    func testMalformedURLError(badURL: String) async throws {
        let client = APIClient()
        
        await #expect(throws: requestError.malformedURL) {
            try await client.sendRequest(method: .get, url: badURL, isAuthed: false)
        }
    }
}
