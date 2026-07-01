//
//  login.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 10/06/2026.
//

import SwiftUI
import NativeGrindCore
#if !os(tvOS) && !os(visionOS)
import GoogleSignIn
#endif
#if os(iOS)
import FacebookLogin
import FBSDKCoreKit
#endif

struct loginView: View {
    
    @State private var username = ""
    @State private var password = ""
    @Environment(navigationRouter.self) private var router

    private var containerWidth: CGFloat {
        #if os(tvOS)
            return 700
        #else
            return 500
        #endif
    }
    
    private var textSize: Font.TextStyle {
        #if os(tvOS)
            return .title3
        #else
            return .title
        #endif
    }

    #if !os(tvOS) && !os(visionOS)
    private func handleGoogleSignIn() {
        #if os(macOS)
            guard let presentingWindow = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? NSApplication.shared.windows.first else {
                return
            }

            let presentationAnchor = presentingWindow
        #else
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                return
            }

            let presentationAnchor = rootViewController
        #endif

        GIDSignIn.sharedInstance.signIn(withPresenting: presentationAnchor) { signInResult, error in
            if let error = error {
                Task {
                    await errorManager.shared.error("GoogleLogin", "Authentication failed: \(error.localizedDescription)")
                }
                return
            }

            guard let user = signInResult?.user else {
                Task {
                    await errorManager.shared.error("GoogleLogin", "Failed to get user")
                }
                return
            }

            let accessToken = user.accessToken.tokenString

            Task {
                await sessionManager.shared.authenticateWithGoogle(accessToken: accessToken)
            }
        }
    }
    #endif

    #if os(iOS)
    private func handleFacebookSignIn() {
        let loginManager = LoginManager()

        loginManager.logIn(permissions: ["public_profile", "email"], from: nil) { result, error in
            if let error = error {
                Task {
                    await errorManager.shared.error("FacebookLogin", "Authentication failed: \(error.localizedDescription)")
                }
                return
            }

            guard let result = result, !result.isCancelled else {
                Task {
                    await errorManager.shared.error("FacebookLogin", "Configuration flow cancelled")
                }
                return
            }
            
            guard let accessToken = result.authenticationToken?.tokenString else {
                Task {
                    await errorManager.shared.error("FacebookLogin", "Failed to get Facebook access token")
                }
                return
            }


            Task {
                await sessionManager.shared.authenticateWithFacebook(accessToken: accessToken)
            }
        }
    }
    #endif

    private func handleEmailSignIn() {
        Task {
            await sessionManager.shared.authenticateWithEmail(email: username, password: password)
        }
    }

    var body: some View {
        VStack(
            spacing: 24
        ) {
            Spacer()

            VStack(
                spacing: 10
            ) {
                Text("Please Login To NativeGrind")
                    .font(.system(textSize, design: .rounded))
                    .bold()
                    .multilineTextAlignment(.center)

                Text("Welcome Back! Please enter your credentials to access your account.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)

            VStack(
                spacing: 16
            ) {
                TextField("Email", text: $username)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .textContentType(.emailAddress)

                SecureField("Password", text: $password)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .textContentType(.password)
            }

            Button(action: {
                handleEmailSignIn()
            }) {
                Text("Login")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)

            HStack {
                VStack { Divider() }
                Text("OR")
                    .font(.caption)
                    .foregroundColor(.secondary)
                VStack { Divider() }
            }
            .padding(.vertical, 8)

            VStack(
                spacing: 12
            ) {
                Button(action: {
                    router.selectedUnprotectedTab = .advancedLogin
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 20))
                        Text("Sign in with Apple")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                #if !os(tvOS) && !os(visionOS)
                Button(action: {
                    handleGoogleSignIn()
                }) {
                    HStack(spacing: 12) {
                        Image("GoogleLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        Text("Sign in with Google")
                            .font(.headline)
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                #endif

                #if os(iOS)
                Button(action: {
                    handleFacebookSignIn()
                }) {
                    HStack(spacing: 12) {
                        Image("FacebookLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        Text("Sign in with Facebook")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(red: 9/255, green: 102/255, blue: 255/255))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                #endif
            }

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: containerWidth, maxHeight: .infinity)
    }
}

#Preview {
    loginView()
}
