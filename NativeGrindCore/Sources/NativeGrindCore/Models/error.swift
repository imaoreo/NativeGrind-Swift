//
//  error.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 26/06/2026.
//
import Foundation

public enum authenticationError: Error, LocalizedError {
    case invalidResponse
    case missing(itemName: String)
    case unknown
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The server returned an empty or invalid response."
        case .missing(let itemName): return "Missing Item: \(itemName)"
        case .unknown: return "An unknown authentication error occurred."
        }
    }
}

public enum requestError: LocalizedError {
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
