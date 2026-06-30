//
//  error.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 26/06/2026.
//
import Foundation

public enum authenticationError: Error, LocalizedError {
    case invalidResponse
    case missing
    case unknown
    case networkError
    
    public var errorDescription: String? {
        switch self {
            case .invalidResponse: return "The server returned an empty or invalid response."
            case .missing: return "Your session information is incomplete. Please sign in again."
            case .unknown: return "An unknown authentication error occurred."
            case .networkError: return "Not connected to the internet"
        }
    }
}

public enum requestError: LocalizedError {
    case malformedURL
    case invalidComponents
    case invalidResponse
    case uninitializedSession
    case networkError
    
    public var errorDescription: String? {
        switch self {
            case .malformedURL: return "Malformed URL String"
            case .invalidComponents: return "Invalid URL components"
            case .invalidResponse: return "Invalid server response"
            case .uninitializedSession: return "Session is not initialized. Call setup() first."
            case .networkError: return "Not connected to the internet"
        }
    }
}
