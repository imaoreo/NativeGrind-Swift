import SwiftUI
import NativeGrindCore

@main
struct MyApp: App {
    @State private var router = NavigationRouter()
    
    init() {
        Task {
            await APIClient.shared.setup(
                timezone: "Europe/London",
                language: "en-gb",
                deviceId: "E812B63B-F645-4C58-8FAB-40F457BAF456"
            )
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .withToastOverlay()
                .environment(router)
        }
    }
}

struct ContentView: View {
    @StateObject private var sessionManager = SessionManager.shared
    @State private var currentProtectedTab: ProtectedRoute = .browse
    @State private var currentUnprotectedTab: UnprotectedRoute = .login
    
    @Environment(NavigationRouter.self) private var router
    
    var body: some View {
        @Bindable var router = router
        Group {
            if sessionManager.isAuthenticated {
                // ==========================================
                // PROTECTED FLOW
                // ==========================================
                TabView(selection: $router.selectedProtectedTab) {
                    
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
                    
                    NavigationStack(path: $router.protectedPath) {
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
                TabView(selection: $router.selectedUnprotectedTab) {
                    
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
                    
                    NavigationStack(path: $router.unprotectedPath) {
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
