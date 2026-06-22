//
//  APIClient.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 11/06/2026.
//

import Foundation

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

public enum RequestError: LocalizedError {
    case malformedURL
    case invalidComponents
    case invalidResponse
    case uninitializedSession
    
    public var errorDescription: String? {
        switch self {
        case .malformedURL: return "Malformed URL String"
        case .invalidComponents: return "Invalid URL components"
        case .invalidResponse: return "Invalid server response"
        case .uninitializedSession: return "Session is not initialized. Call setup() first."
        }
    }
}

public actor APIClient {
    public static let shared = APIClient()
    
    private init() {}
    
    private var session: URLSession? = nil
    
    private func buildAcceptLanguageHeader(for languageCode: String) -> String {
        // Split into components (e.g., "en-GB" -> ["en", "GB"])
        let components = languageCode.split(separator: "-")
        
        // Use the region code as the backup
        if components.count > 1 {
            let baseLanguage = components[0]
            return "\(languageCode),\(baseLanguage);q=0.9"
        }
        
        // Return fallback
        return languageCode
    }
    
    /// Setup the Request Agent
    /// - Parameters:
    ///  - timezone: The timezone of the use in the format "Continent/City" e.g., ("Europe/Madrid")
    ///  - language: The language of the user in the format "en-US"
    public func setup(timezone: String, language: String, deviceId: String) {
        // Convert "en-US" to "en_US"
        let locale = language.replacingOccurrences(of: "-", with: "_")
            
        // Explicitly configure an ephemeral session without default headers
        let configuration = URLSessionConfiguration.ephemeral
        
        let acceptLanguageHeader = buildAcceptLanguageHeader(for: language)
        
        let deviceInfoHeader = "\(deviceId);appStore;2;8565768192;2796x1290"
        
        let headers: [AnyHashable: String] = [
            "Accept": "application/json",
            "Accept-Encoding": "gzip, deflate, br",
            "Accept-Language": acceptLanguageHeader,
            "Connection": "keep-alive",
            "L-Device-Info": deviceInfoHeader,
            "L-Time-Zone": timezone,
            "User-Agent": "Grindr3/26.9.2.99239.060331878.99 (99239.060331878.99; iPhone99,11; iOS 26.1)",
            "L-Locale": locale,
        ]
        
        configuration.httpAdditionalHeaders = headers

        self.session = URLSession(configuration: configuration)
    }


    /// Executes a network request
    /// - Parameters:
    ///   - method: HTTP verb (GET, POST, etc.)
    ///   - path: The endpoint path (e.g., `/v1/auth/login`)
    ///   - queryItems: Key-value pairs for URL query parameters
    ///   - body: Optional dictionary to be serialized as JSON in the request body
    ///   - isAuthed: Optional boolean indicating if the request requires authentication (default is true)
    /// - Returns: A tuple containing the raw response data and the HTTPURLResponse object
    /// - Errors:
    ///   - Code -1: Invalid URL components
    ///   - Code -2: Invalid server response (non-HTTP response)
    ///   - Code -3 Malformed URL String
    ///   - Code -4 Session is not initialized. Call setup() first.
    public func sendRequest(
        method: HTTPMethod,
        url: String,
        queryItems: [String: String]? = nil,
        body: [String: Any]? = nil,
        isAuthed: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        
        // Translates the url string into a URL Type
        guard let sourceURL = URL(string: url) else {
            throw RequestError.malformedURL
        }
        
        // This ts just splits up the url into like https://, grindr.mobi, /v1/auth
        var urlComponents = URLComponents(
            url: sourceURL,
            resolvingAgainstBaseURL: false // treats the url as is
        )
        
        // Transfers the [String: String] into ?key=value&key2=value2 format
        if let queryItems = queryItems {
            urlComponents?.queryItems = queryItems.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        // Just checks that there is a url on the urlComponets
        guard let finalURL = urlComponents?.url else {
            throw RequestError.invalidComponents
        }
        
        // Transfer the finalURL into a URLRequest
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue
        
        // Content-Type if there is a body
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        if isAuthed {
            let token = await MainActor.run {
                KeychainManager.shared.getToken(type: .sessionId)
            }
            
            if var validToken = token {
                validToken = "Grindr3 \(validToken)"
                request.setValue(validToken, forHTTPHeaderField: "Authorization")
            } else {
                // Route requires auth but there is no token stored
                throw RequestError.uninitializedSession
            }
                
        } else {
            // clear header for unauthed routes
            request.setValue(nil, forHTTPHeaderField: "Authorization")
        }
            
            
        // Serialize the body into JSON if there is a body
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        }
        
        // Check there is a active session
        guard let activeSession = session else {
            throw RequestError.uninitializedSession
        }
            
        // make the network request
        let (data, response) = try await activeSession.data(for: request)

        // invalid http respones catcher
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RequestError.invalidResponse
        }
        
        return (data, httpResponse)
    }
    
    public func request<T: Decodable & Sendable>(_ endpoint: Endpoint<T>) async throws -> T? {
        do {
            let (data, response) = try await sendRequest(
                method: endpoint.method,
                url: endpoint.fullURLString,
                queryItems: endpoint.queryItems,
                body: endpoint.body,
                isAuthed: endpoint.isAuthedRoute
            )
            
            // Handle failure HTTP statuses (outside 200...299)
            guard (200...299).contains(response.statusCode) else {
                
                var handledByCustomHandler = false
                
                // Go through all the network handlers
                for handler in endpoint.networkHandlers {
                    let statusCodeMatches = (handler.code == response.statusCode)
                    
                    // extract the json and see if it matches
                    var jsonMatches = false
                    if let location = handler.jsonLocation,
                       let expectedValue = handler.jsonLocationValue,
                       let serverJSON = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let actualValue = serverJSON[location] as? String {
                        jsonMatches = actualValue.localizedCaseInsensitiveContains(expectedValue)
                    }
                    
                    // See if it's a match using the matching ruels
                    let isMatch: Bool
                    switch handler.match {
                        case .statusCodeOnly:
                            isMatch = statusCodeMatches
                        case .jsonContentOnly:
                            isMatch = jsonMatches
                        case .matchBoth:
                            isMatch = statusCodeMatches && jsonMatches
                        case .mathchEither:
                            isMatch = statusCodeMatches || jsonMatches
                    }
                    
                    if isMatch {
                        // Show Toast if match
                        let toastStyle = handler.level == .error ? ToastStyle.error : ToastStyle.warn
                        let toastHeader = handler.header
                        let toastMessage = handler.message
                        
                        await MainActor.run {
                            ToastManager.shared.show(
                                style: toastStyle,
                                header: toastHeader,
                                message: toastMessage
                            )
                        }
                        handledByCustomHandler = true
                        break
                    }
                }
                
                // Generic response if there is no custom handler that matches it
                if !handledByCustomHandler {
                    let fallbackMsg = String(data: data, encoding: .utf8) ?? "Unknown server response profile."
                    await MainActor.run {
                        ToastManager.shared.show(
                            style: .error,
                            header: "Error (\(response.statusCode))",
                            message: fallbackMsg
                        )
                    }
                }
                
                return nil;
            }
            
            let decoder = JSONDecoder()
            return try decoder.decode(T.self, from: data)
            
        } catch {
            throw error
        }
    }
}
