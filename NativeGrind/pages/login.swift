//
//  login.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 10/06/2026.
//

import SwiftUI

struct LoginView: View {
    
    @State private var username = ""
    @State private var password = ""
    
    private var containerWidth: CGFloat {
        #if os(tvOS)
            return 700
        #else
            return 500
        #endif
    }
    
    var body: some View {
        VStack(
            spacing: 24
        ) {
            
            Spacer()
            
            VStack(
                spacing: 10
            ){
                Text("Please Login To NativeGrind")
                    .font(.system(.title, design: .rounded))
                    .bold()
                    .multilineTextAlignment(.center)
                
                Text("Welcome Back! Please enter your credentials to access your account.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            
            VStack(
                spacing: 10
            ) {
                
            }
            
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
                // Handle login logic here
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
            
            Divider()
            
            HStack() {
                Button(action: {
                    // Handle login logic here
                }) {
                    Image(systemName: "applelogo")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .padding()
                        .background(.black)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    // Handle login logic here
                }) {
                    Image(systemName: "applelogo")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .padding()
                        .background(.black)
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    // Handle login logic here
                }) {
                    Image(systemName: "applelogo")
                        .font(.title3)
                        .foregroundColor(.white)
                        .frame(width: 50, height: 50)
                        .padding()
                        .background(.black)
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
    LoginView()
}
