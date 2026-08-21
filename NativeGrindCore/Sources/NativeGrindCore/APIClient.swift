//
//  APIClient.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 11/06/2026.
//

import Foundation

public enum HTTPMethod: String, Sendable, Codable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

func changeENUMSToRawValues(_ value: Any) -> Any {
    if let rawRepresentable = value as? any RawRepresentable {
        return changeENUMSToRawValues(rawRepresentable.rawValue)
    }
    
    switch value {
    case let array as [Any]:
        return array.map(changeENUMSToRawValues)
         
    case let dictionary as [String: Any]:
        return dictionary.mapValues(changeENUMSToRawValues)
         
    default:
        return value
    }
}

public actor APIClient {
    public static let shared = APIClient()
    
    init() {}
    
    var session: URLSession? = nil
    
    func buildAcceptLanguageHeader(for languageCode: String) -> String {
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
    func sendRequest(
        method: HTTPMethod,
        url: String,
        queryItems: [String: String]? = nil,
        body: [String: Any]? = nil,
        isAuthed: Bool = true
    ) async throws -> (Data, HTTPURLResponse) {
        
        // Translates the url string into a URL Type
        guard let sourceURL = URL(string: url), sourceURL.scheme != nil else {
            throw requestError.malformedURL
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
            throw requestError.invalidComponents
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
                keychainManager.shared.getToken(type: .sessionId)
            }
            
            if var validToken = token {
                validToken = "Grindr3 \(validToken)"
                request.setValue(validToken, forHTTPHeaderField: "Authorization")
            } else {
                // Route requires auth but there is no token stored
                throw requestError.uninitializedSession
            }
        } else {
            // clear header for unauthed routes
            request.setValue(nil, forHTTPHeaderField: "Authorization")
        }
            
            
        // Serialize the body into JSON if there is a body
        if let body = body {
            let sanitizedBody = changeENUMSToRawValues(body)
            request.httpBody = try JSONSerialization.data(withJSONObject: sanitizedBody, options: [])
        }
        
        // Check there is a active session
        guard let activeSession = session else {
            throw requestError.uninitializedSession
        }
            
        // make the network request
        let (data, response) = try await activeSession.data(for: request)

        // invalid http respones catcher
        guard let httpResponse = response as? HTTPURLResponse else {
            throw requestError.invalidResponse
        }
        
        return (data, httpResponse)
    }
    
    public func request<T: Decodable & Sendable>(_ endpoint: endpoint<T>, isRetry: Bool = false, shouldErrorMesssage: Bool = true) async throws -> T? {
        do {
            let (data, response) = try await sendRequest(
                method: endpoint.method,
                url: endpoint.fullURLString,
                queryItems: endpoint.queryItems,
                body: endpoint.body,
                isAuthed: endpoint.isAuthedRoute
            )
            
            if (200...299).contains(response.statusCode) {
                if T.self == Data.self {
                    return data as? T
                }
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                return try decoder.decode(T.self, from: data)
            }
            
            // the isRetry flag prevents a infinite loop
            if response.statusCode == 401, !isRetry, endpoint.shouldRetryOn401 {
                await sessionManager.shared.refreshToken()

                return try await request(endpoint, isRetry: true)
            }
            
            if shouldErrorMesssage {
                await handleNetworkError(data: data, statusCode: response.statusCode, endpoint: endpoint)
            }

            return nil
        } catch let error as URLError where error.code == .notConnectedToInternet {
            throw requestError.networkError
        } catch {
            throw error
        }

    }
    
    func handleNetworkError<T>(data: Data, statusCode: Int, endpoint: endpoint<T>) async {
        var handledByCustomHandler = false
        
        let serverJSON = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        
        for handler in endpoint.networkHandlers {
            let statusCodeMatches = (handler.code == statusCode)
            
            var jsonMatches = false
            if let location = handler.jsonLocation,
               let expectedValue = handler.jsonLocationValue,
               let actualValue = serverJSON[location] as? String {
                jsonMatches = actualValue.localizedCaseInsensitiveContains(expectedValue)
            }
            
            let isMatch: Bool
            switch handler.match {
                case .statusCodeOnly: isMatch = statusCodeMatches
                case .jsonContentOnly: isMatch = jsonMatches
                case .matchBoth: isMatch = statusCodeMatches && jsonMatches
                case .matchEither: isMatch = statusCodeMatches || jsonMatches
            }
            
            if isMatch {
                let style: toastStyle = handler.level == .error ? .error : .warn
                let header = handler.header
                let message = handler.message
                
                await MainActor.run {
                    toastManager.shared.show(style: style, header: header, message: message)
                }
                handledByCustomHandler = true
                break
            }
        }
        
        // Generic response if there is no custom handler that matches it
        if !handledByCustomHandler {
            let fallbackMsg = String(data: data, encoding: .utf8) ?? "Unknown server response profile."
            await MainActor.run {
                toastManager.shared.show(
                    style: .error,
                    header: "Error (\(statusCode))",
                    message: fallbackMsg
                )
            }
        }
    }
}
