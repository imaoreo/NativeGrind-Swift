//
//  advancedLogin.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 26/09/2026.
//

import SwiftUI
import NativeGrindCore

struct advancedLoginView: View {
    private enum provider: String {
        case google
        case apple
    }

    @State private var type: provider = .google
    @State private var token = ""

    private var containerWidth: CGFloat {
        #if os(tvOS)
            return 700
        #else
            return 500
        #endif
    }

    private var trimmedToken: String {
        token.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func handleSignIn() {
        let token = trimmedToken
        let type = type
        Task {
            switch type {
                case .google:
                    await sessionManager.shared.authenticateWithGoogle(accessToken: token)
                case .apple:
                    await sessionManager.shared.authenticateWithApple(code: token)
            }
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Text("Advanced Login")
                    .font(.system(.title, design: .rounded))
                    .bold()
                    .multilineTextAlignment(.center)

                Text(type == .google
                     ? "Open the Grindr OAuth extension, pick Sign in with Google and paste the token here. The token expires in about an hour."
                     : "Open the Grindr OAuth extension, pick Sign in with Apple and paste the code here. The code works once and expires after 5 minutes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Link("Get the Grindr OAuth extension", destination: URL(string: "https://github.com/imaoreo/grindr-oauth-webextension")!)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)

            Picker("Login Method", selection: $type) {
                Text("Google").tag(provider.google)
                Text("Apple").tag(provider.apple)
            }
            .pickerStyle(.segmented)

            TextField(type == .google ? "Google token" : "Apple code", text: $token)
                .textFieldStyle(.plain)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(10)
                .textContentType(.none)
                .autocorrectionDisabled()

            Button(action: {
                handleSignIn()
            }) {
                Text(type == .google ? "Sign in with Google" : "Sign in with Apple")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.orange)
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(trimmedToken.isEmpty)

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: containerWidth, maxHeight: .infinity)
    }
}

#Preview {
    advancedLoginView()
}
