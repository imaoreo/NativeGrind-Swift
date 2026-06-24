//
//  loginWithToken.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 20/06/2026.
//

import SwiftUI
import NativeGrindCore

struct AdvancedLoginView: View {
    private enum loginTypes: String {
        case email
        case thirdparty
    }
    
    @State private var email = ""
    @State private var authToken = ""
    
    @State private var thirdPartyUserId = ""
    @State private var type: loginTypes = .email

    private var containerWidth: CGFloat {
        #if os(tvOS)
            return 700
        #else
            return 500
        #endif
    }

    private func handleEmailSignIn() {
        Task {
            await SessionManager.shared.authenticateWithAuthToken(token: authToken, email: email)
        }
    }
    
    private func handleTokenSignIn() {
        Task {
            await SessionManager.shared.authenticateWithThirdPartyToken(token: authToken, thirdPartyUserId: thirdPartyUserId)
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

                Text("Follow the guide below:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Link("Guide to use advanced login", destination: URL(string: "https://freegrinddocs.imaoreo.dev/guide/login")!)
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            
            Picker("Login Method", selection: $type) {
                Text("Email").tag(loginTypes.email)
                Text("Third Party").tag(loginTypes.thirdparty)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            VStack(spacing: 16) {
                if (type == .email) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .textContentType(.emailAddress)
                } else {
                    TextField("ThirdPartyUserID", text: $thirdPartyUserId)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                }
                
                TextField("Token", text: $authToken)
                    .textFieldStyle(.plain)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .textContentType(.none)
                    .autocorrectionDisabled()
            }

            if (type == .email) {
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
            } else {
                Button(action: {
                    handleTokenSignIn()
                }) {
                    Text("Third Party Login")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.orange)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }


            Spacer()
        }
        .padding(24)
        .frame(maxWidth: containerWidth, maxHeight: .infinity)
    }
}

#Preview {
    AdvancedLoginView()
}
