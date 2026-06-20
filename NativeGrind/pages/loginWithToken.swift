//
//  loginWithToken.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 20/06/2026.
//

import SwiftUI
import NativeGrindCore

struct LoginWithTokenView: View {
    @State private var token = ""

    private var containerWidth: CGFloat {
        #if os(tvOS)
            return 700
        #else
            return 500
        #endif
    }

    private func handleTokenSignIn() {
        SessionManager.shared.authenticateWithToken(token: token)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 10) {
                Text("Login with Token")
                    .font(.system(.title, design: .rounded))
                    .bold()
                    .multilineTextAlignment(.center)

                Text("This method is a bit more advanced but can still be followed by anyone. You will need a valid grindr token to use this method. Look at this guide for more information on how to get a token:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Link("Guide to get a token", destination: URL(string: "https://freegrinddocs.imaoreo.dev/guide/login")!)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)

            VStack(spacing: 16) {
                TextField("Token", text: $token)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .textContentType(.emailAddress)
            }

            Button(action: {
                handleTokenSignIn()
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

            Spacer()
        }
        .padding(24)
        .frame(maxWidth: containerWidth, maxHeight: .infinity)
    }
}

#Preview {
    LoginWithTokenView()
}
