//
//  APIRouter.swift
//  NativeGrindCore
//
//  Created by Jay Brammeld on 14/06/2026.
//

import Foundation

public enum APIRouter {
    // Auth Routes
    case login(email: String, password: String)
    
    // Public
    case getGenders
    case getPronouns
    
    // Inbox
    case getInbox(page: Int)
    
    // Profiles
    case getProfile(profileId: String)

    private var baseURL: String {
        return "https://grindr.mobi"
    }
    
    public var path: String {
        switch self {
            case .login:
                return "/v8/sessions"
            case .getGenders:
                return "/public/v2/genders"
            case .getPronouns:
                return "/public/v1/pronouns"
            case .getInbox:
                return "/v3/inbox"
            case .getProfile(let profileId):
                return "/v7/profiles/\(profileId)"
        }
    }
    
    public var method: HTTPMethod {
        switch self {
        case .login:
            return .post
        default:
            return .get
        }
    }
    
    public var queryItems: [String: String]? {
        switch self {
        case .getInbox(let page):
            return ["page": String(page)]
        case .login, .getProfile, .getGenders, .getPronouns:
            return nil
        }
    }
    
    public var body: [String: Any]? {
        switch self {
        case .login(let email, let password):
            let payload: [String: Any] = [
                "email": email,
                "password": password,
                "token": "",
            ]
            
            return payload
        default:
            return nil
        }
    }
    
    public var isAuthedRoute: Bool {
        switch self {
            case .login, .getGenders, .getPronouns:
                return false
            default:
                return true
        }
    }
    
    public var fullURLString: String {
        return baseURL + path
    }
    
    public func request<T: Decodable>(apiClient: APIClient, as type: T.Type) async throws -> T {
        return try await apiClient.request(self, as: type)
    }
}
