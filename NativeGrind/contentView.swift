import SwiftUI
import NativeGrindCore
#if os(iOS)
import FBSDKCoreKit
import UIKit
#endif

#if os(iOS)
final class appDelegate: NSObject, UIApplicationDelegate {
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
struct myApp: App {
    @State private var router = navigationRouter()
    #if os(iOS)
    @UIApplicationDelegateAdaptor(appDelegate.self) private var _appDelegate
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
            contentView()
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

struct contentView: View {
    @StateObject private var _sessionManager = sessionManager.shared
    
    @Environment(navigationRouter.self) private var router
    
    var body: some View {
        @Bindable var router = router
        Group {
            if _sessionManager.isAuthenticated {
                // ==========================================
                // PROTECTED FLOW
                // ==========================================
                TabView(selection: $router.selectedProtectedTab) {
                    
                    NavigationStack(path: $router.protectedPath) {
                        protectedRoute.browse
                            .navigationDestination(for: protectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Browse", systemImage: "safari")
                    }
                    .tag(protectedRoute.browse)
                    
                    NavigationStack(path: $router.protectedPath) {
                        protectedRoute.messages
                            .navigationDestination(for: protectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Messages", systemImage: "bubble.left.and.bubble.right")
                    }
                    .tag(protectedRoute.messages)
                }
                .accentColor(.blue) // Changes the active tab highlight color
                
            } else {
                // ==========================================
                // UNPROTECTED FLOW
                // ==========================================
                TabView(selection: $router.selectedUnprotectedTab) {
                    
                    NavigationStack(path: $router.unprotectedPath) {
                        unprotectedRoute.login
                            .navigationDestination(for: unprotectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Login", systemImage: "lock.shield")
                    }
                    .tag(unprotectedRoute.login)
                    
                    NavigationStack(path: $router.unprotectedPath) {
                        unprotectedRoute.advancedLogin
                            .navigationDestination(for: unprotectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Advanced Login", systemImage: "key")
                    }
                    .tag(unprotectedRoute.advancedLogin)
                    
                    NavigationStack(path: $router.unprotectedPath) {
                        unprotectedRoute.resetPassword
                            .navigationDestination(for: unprotectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Reset Password", systemImage: "person.badge.key")
                    }
                    .tag(unprotectedRoute.resetPassword)
                    
                    NavigationStack(path: $router.unprotectedPath) {
                        unprotectedRoute.register
                            .navigationDestination(for: unprotectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Register", systemImage: "person.badge.plus")
                    }
                    .tag(unprotectedRoute.register)
                }
            }
        }
        .environment(router)
    }
}

#Preview {
    contentView()
}
