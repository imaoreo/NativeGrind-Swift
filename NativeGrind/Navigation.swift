//
//  Navigation.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 10/06/2026.
//

import SwiftUI

enum unprotectedRoute: Hashable {
    case login
    case advancedLogin
    case register
    case resetPassword
}

enum protectedRoute: Hashable {
    case browse
    case messages
}

extension unprotectedRoute: View {
    var body: some View {
        switch self {
        case .login:
            LoginView()
        case .advancedLogin:
            advancedLoginView()
        case .register:
            Text("Register")
        case .resetPassword:
            Text("Reset Password")
        }
    }
}

extension protectedRoute: View {
    var body: some View {
        switch self {
        case .browse:
            BrowseView()
        case .messages:
            Text("Messages")
        }
    }
}

@Observable
final class NavigationRouter {
    var selectedUnprotectedTab: unprotectedRoute = .login
    var selectedProtectedTab: protectedRoute = .browse
    
    var unprotectedPath: [unprotectedRoute] = []
    var protectedPath: [protectedRoute] = []
    
    func getCurrentUnprotected() -> unprotectedRoute? {
        unprotectedPath.last
    }
    
    func getCurrentProtected() -> protectedRoute? {
        protectedPath.last
    }
    
    func push(_ route: unprotectedRoute) {
        unprotectedPath.append(route)
    }
    
    func push(_ route: protectedRoute) {
        protectedPath.append(route)
    }
    
    func popUnprotected() {
        _ = unprotectedPath.popLast()
    }
    
    func popProtected() {
        _ = protectedPath.popLast()
    }
    
    func reset() {
        unprotectedPath.removeAll()
        protectedPath.removeAll()
        selectedUnprotectedTab = .login
        selectedProtectedTab = .browse
    }
}
