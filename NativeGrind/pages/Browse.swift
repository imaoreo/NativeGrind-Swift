//
//  Browse.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 15/06/2026.
//

import SwiftUI
import NativeGrindCore

struct BrowseView: View {
    
    var body: some View {
        VStack(
            spacing: 24
        ) {
            
            Spacer()
            
            Button(action: {
                SessionManager.shared.logout()
            }) {
                Text("Log Out")
                    .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                Task {
                    await SessionManager.shared.refreshToken()
                }
                
            }) {
                Text("Refresh")
                    .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 700, maxHeight: .infinity)
        
    }
}

#Preview {
    BrowseView()
}
