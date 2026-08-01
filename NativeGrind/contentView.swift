import SwiftUI
import Combine
import NativeGrindCore

#if os(iOS)
import FBSDKCoreKit
import UIKit
#endif // os(iOS)

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
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
        #if INCLUDE_SERVER
            appEnvironment.isServerEnabled = true
            registerWebSocketAppAttestHandler()
            Task {
                try? await accountController.shared.syncFromCloud()
            }
        #endif
        
        Task {
            await APIClient.shared.setup(
                timezone: "Europe/London",
                language: "en-gb",
                deviceId: "E812B63B-F645-4C58-8FAB-40F457BAF456"
            )
        }
        
        Task { @MainActor in
            #if INCLUDE_SERVER
                wsController.shared.connect(to: .nativeServer)
            #endif
            
            for await isAuthenticated in sessionManager.shared.$isAuthenticated.values {
                if isAuthenticated {
                    wsController.shared.connect(to: .main)
                } else {
                    wsController.shared.disconnect(domain: .main)
                }
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            contentView()
                .withToastOverlay()
                .environment(router)
                .onOpenURL { url in
                    if let scheme = url.scheme, scheme.lowercased() == "nativegrind" {
                        let pathOrHost = url.host ?? url.path
                        if pathOrHost == "login" || pathOrHost == "/login" {
                            if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                               let queryItems = components.queryItems,
                               let code = queryItems.first(where: { $0.name == "code" })?.value {
                               wsController.shared.send(request: .getPublicKey(code: code))
                            }
                        }
                    } else {
                        #if os(iOS)
                        _ = ApplicationDelegate.shared.application(
                            UIApplication.shared,
                            open: url,
                            options: [:]
                        )
                        #endif
                    }
                }
        }
        #if os(macOS)
        Settings {
            if #available(macOS 15.0, *) {
                TabView {
                    #if INCLUDE_SERVER
                        Tab("NS Account", systemImage: "person.crop.circle.badge.checkmark") {
                            nsAccountSettingView()
                        }
                    #endif
                    Tab("Debug", systemImage: "ladybug") {
                        debugSettingView()
                    }
                    Tab("WebSockets", systemImage: "network") {
                        websocketsSettingView()
                    }
                    Tab("Privacy & Security", systemImage: "star") {
                        privacySettingView()
                    }
                }
                .frame(width: 450, height: 400)
                .fixedSize()
            } else {
                settingsView()
            }
        }
        .commands {
            CommandMenu("Account") {
                Button("Log Out") {
                    sessionManager.shared.logout()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
        #endif
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
                        protectedRoute.inbox
                            .navigationDestination(for: protectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Inbox", systemImage: "bubble.left.and.bubble.right")
                    }
                    .tag(protectedRoute.inbox)
                    
                    #if !os(macOS)
                    NavigationStack(path: $router.protectedPath) {
                        protectedRoute.settings
                            .navigationDestination(for: protectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(protectedRoute.settings)
                    #endif
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
                    
                    #if INCLUDE_SERVER
                    NavigationStack(path: $router.unprotectedPath) {
                        unprotectedRoute.loginWQR
                            .navigationDestination(for: unprotectedRoute.self) { route in
                                route
                            }
                    }
                    .tabItem {
                        Label("QR Login", systemImage: "key")
                    }
                    .tag(unprotectedRoute.loginWQR)
                    #endif
                }
            }
        }
        .environment(router)
    }
}

#Preview {
    contentView()
}
