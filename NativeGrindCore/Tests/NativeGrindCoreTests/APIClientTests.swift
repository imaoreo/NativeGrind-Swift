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

@Suite("APIClient State & Pre-Flight Tests")
struct APIClientStateTests {
    
    @Test("Throws uninitializedSession when sending a request before setup() is called")
    func testUninitializedSessionThrowsError() async {
        let client = APIClient()
        
        await #expect(throws: requestError.uninitializedSession) {
            _ = try await client.sendRequest(
                method: .get,
                url: "https://grindr.mobi/v1/test",
                isAuthed: false
            )
        }
    }
    
    @Test("Throws uninitializedSession if request isAuthed but keychain token is missing")
    @MainActor
    func testMissingAuthTokenThrowsError() async {
        keychainManager.shared.deleteToken(type: .sessionId)
        
        let client = APIClient()
        await client.setup(timezone: "Europe/London", language: "en-GB", deviceId: "test-id")
        
        await #expect(throws: requestError.uninitializedSession) {
            _ = try await client.sendRequest(
                method: .get,
                url: "https://grindr.mobi/v1/secure-data",
                isAuthed: true
            )
        }
    }}

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

@Suite("APIClient Request Formatting Tests", .serialized)
struct APIClientFormattingTests {
    
    // Helper to create a sessionClient
    private func createMockedClient() async -> APIClient {
        let client = APIClient()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        await client.setup(timezone: "UTC", language: "en-US", deviceId: "mock")
        
        // Override the default one
        await client.setMockSession(URLSession(configuration: config))
        return client
    }
    
    @Test("Verifies query parameters are correctly appended to the URL string")
    func testQueryParametersFormatting() async throws {
        let client = await createMockedClient()
        
        MockURLProtocol.shared.handler = { request in
            let urlString = request.url?.absoluteString ?? ""
            
            // Make sure the query was done correctly
            #expect(urlString.contains("limit=50"))
            #expect(urlString.contains("offset=10"))
            
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        _ = try await client.sendRequest(
            method: .get,
            url: "https://api.example.com/search",
            queryItems: ["limit": "50", "offset": "10"],
            isAuthed: false
        )
    }
    
    @Test("Verifies JSON body serialization and Content-Type header injection")
    func testJSONBodySerialization() async throws {
        let client = await createMockedClient()
        let requestBody: [String: Any] = ["username": "testUser", "age": 25]
        
        MockURLProtocol.shared.handler = { request in
            // Check the Content Header and Method
            #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
            #expect(request.httpMethod == "POST")
            
            // Extract the Body
            let bodyData: Data
            if let data = request.httpBody {
                bodyData = data
            } else if let stream = request.httpBodyStream {
                stream.open()
                let bufferSize = 1024
                let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
                var data = Data()
                while stream.hasBytesAvailable {
                    let read = stream.read(buffer, maxLength: bufferSize)
                    if read > 0 {
                        data.append(buffer, count: read)
                    } else {
                        break
                    }
                }
                buffer.deallocate()
                stream.close()
                bodyData = data
            } else {
                bodyData = Data()
            }

            let decodedBody = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            
            // Make sure the data is in the body
            #expect(decodedBody?["username"] as? String == "testUser")
            #expect(decodedBody?["age"] as? Int == 25)
            
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        _ = try await client.sendRequest(
            method: .post,
            url: "https://api.example.com/users",
            body: requestBody,
            isAuthed: false
        )
    }
}

// used for getting around session restrictions
extension APIClient {
    func setMockSession(_ mockSession: URLSession) {
        self.session = mockSession
    }
}
