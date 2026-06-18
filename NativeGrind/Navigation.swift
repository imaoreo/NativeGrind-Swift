//
//  Navigation.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 10/06/2026.
//

import SwiftUI

enum UnprotectedRoute: Hashable {
    case login
    case loginWithToken
    case register
    case resetPassword
}

enum ProtectedRoute: Hashable {
    case browse
    case messages
}

extension UnprotectedRoute: View {
    var body: some View {
        switch self {
        case .login:
            LoginView()
        case .loginWithToken:
            Text("Login with token")
        case .register:
            Text("Register")
        case .resetPassword:
            Text("Reset Password")
        }
    }
}

extension ProtectedRoute: View {
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
    var selectedUnprotectedTab: UnprotectedRoute = .login
    var selectedProtectedTab: ProtectedRoute = .browse
    
    var unprotectedPath: [UnprotectedRoute] = []
    var protectedPath: [ProtectedRoute] = []
    
    func getCurrentUnprotected() -> UnprotectedRoute? {
        unprotectedPath.last
    }
    
    func getCurrentProtected() -> ProtectedRoute? {
        protectedPath.last
    }
    
    func push(_ route: UnprotectedRoute) {
        unprotectedPath.append(route)
    }
    
    func push(_ route: ProtectedRoute) {
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
