import SwiftUI
import NativeGrindCore

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var router = NavigationRouter()
    @State private var isAuthenticated = false
    @State private var currentProtectedTab: ProtectedRoute = .browse
    @State private var currentUnprotectedTab: UnprotectedRoute = .login
    
    var body: some View {
        Group {
            if isAuthenticated {
                // ==========================================
                // PROTECTED FLOW
                // ==========================================
                TabView(selection: $currentProtectedTab) {
                    
                    NavigationStack(path: $router.protectedPath) {
                        ProtectedRoute.browse
                            .navigationDestination(for: ProtectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Browse", systemImage: "safari")
                    }
                    .tag(ProtectedRoute.browse)
                    
                    NavigationStack {
                        ProtectedRoute.messages
                            .navigationDestination(for: ProtectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Messages", systemImage: "bubble.left.and.bubble.right")
                    }
                    .tag(ProtectedRoute.messages)
                }
                .accentColor(.blue) // Changes the active tab highlight color
                
            } else {
                // ==========================================
                // UNPROTECTED FLOW
                // ==========================================
                TabView(selection: $currentUnprotectedTab) {
                    
                    NavigationStack(path: $router.unprotectedPath) {
                        UnprotectedRoute.login
                            .navigationDestination(for: UnprotectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Login", systemImage: "lock.shield")
                    }
                    .tag(UnprotectedRoute.login)
                    
                    NavigationStack(path: $router.unprotectedPath) {
                        UnprotectedRoute.loginWithToken
                            .navigationDestination(for: UnprotectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Token Login", systemImage: "key")
                    }
                    .tag(UnprotectedRoute.loginWithToken)
                    
                    NavigationStack(path: $router.unprotectedPath) {
                        UnprotectedRoute.resetPassword
                            .navigationDestination(for: UnprotectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Reset Password", systemImage: "person.badge.key")
                    }
                    .tag(UnprotectedRoute.loginWithToken)
                    
                    NavigationStack {
                        UnprotectedRoute.register
                            .navigationDestination(for: UnprotectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Register", systemImage: "person.badge.plus")
                    }
                    .tag(UnprotectedRoute.register)
                }
                .accentColor(.green) // Green accent color for auth states
            }
        }
        .environment(router)
    }
}

#Preview {
    ContentView()
}
