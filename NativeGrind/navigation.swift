//
//  navigation.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 10/06/2026.
//

import SwiftUI
import Combine

enum unprotectedRoute: Hashable {
    case login
    case advancedLogin
    case loginWQR
}

enum protectedRoute: Hashable {
    case browse
    case inbox
    case interest
    case settings
}

extension unprotectedRoute: View {
    var body: some View {
        switch self {
        case .login:
            loginView()
        case .advancedLogin:
            advancedLoginView()
        case .loginWQR:
            loginWithQRView()
        }
    }
}

extension protectedRoute: View {
    var body: some View {
        switch self {
        case .browse:
            browseView()
        case .inbox:
            inboxView()
        case .interest:
            interestView()
        case .settings:
            settingsView()
        }
    }
}

final class navigationRouter: ObservableObject {
    @Published var selectedUnprotectedTab: unprotectedRoute = .login
    @Published var selectedProtectedTab: protectedRoute = .browse
    
    @Published var unprotectedPath: [unprotectedRoute] = []
    @Published var protectedPath: [protectedRoute] = []
    
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
