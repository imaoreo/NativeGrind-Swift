import SwiftUI
import NativeGrindCore
#if os(iOS)
import FBSDKCoreKit
import UIKit
#endif

#if os(iOS)
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )

        Settings.shared.appID = Bundle.main.object(forInfoDictionaryKey: "FacebookAppID") as? String
        Settings.shared.clientToken = Bundle.main.object(forInfoDictionaryKey: "FacebookClientToken") as? String
        Settings.shared.displayName = Bundle.main.object(forInfoDictionaryKey: "FacebookDisplayName") as? String
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey : Any] = [:]
    ) -> Bool {
        ApplicationDelegate.shared.application(app, open: url, options: options)
    }
}
#endif

@main
struct MyApp: App {
    @State private var router = NavigationRouter()
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif
    
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
                #if os(iOS)
                .onOpenURL { url in
                    _ = ApplicationDelegate.shared.application(
                        UIApplication.shared,
                        open: url,
                        options: [:]
                    )
                }
                #endif
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
