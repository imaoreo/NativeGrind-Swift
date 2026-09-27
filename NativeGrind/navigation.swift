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
    @Published var showingSettings = false
    
    @Published private var unprotectedPaths: [unprotectedRoute: [unprotectedRoute]] = [:]
    @Published private var protectedPaths: [protectedRoute: [protectedRoute]] = [:]

    func path(for tab: unprotectedRoute) -> Binding<[unprotectedRoute]> {
        Binding(get: { self.unprotectedPaths[tab] ?? [] }, set: { self.unprotectedPaths[tab] = $0 })
    }

    func path(for tab: protectedRoute) -> Binding<[protectedRoute]> {
        Binding(get: { self.protectedPaths[tab] ?? [] }, set: { self.protectedPaths[tab] = $0 })
    }

    func getCurrentUnprotected() -> unprotectedRoute? {
        unprotectedPaths[selectedUnprotectedTab]?.last
    }
    
    func getCurrentProtected() -> protectedRoute? {
        protectedPaths[selectedProtectedTab]?.last
    }
    
    func push(_ route: unprotectedRoute) {
        unprotectedPaths[selectedUnprotectedTab, default: []].append(route)
    }
    
    func push(_ route: protectedRoute) {
        protectedPaths[selectedProtectedTab, default: []].append(route)
    }
    
    func popUnprotected() {
        _ = unprotectedPaths[selectedUnprotectedTab]?.popLast()
    }
    
    func popProtected() {
        _ = protectedPaths[selectedProtectedTab]?.popLast()
    }
    
    func reset() {
        unprotectedPaths.removeAll()
        protectedPaths.removeAll()
        selectedUnprotectedTab = .login
        selectedProtectedTab = .browse
        showingSettings = false
    }
}
