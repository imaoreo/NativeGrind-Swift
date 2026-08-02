//
//  browse.swift
//  NativeGrind
//
//  Created by Jay Brammeld on 15/06/2026.
//

import SwiftUI
import NativeGrindCore

struct browseView: View {
    
    var body: some View {
        VStack(
            spacing: 24
        ) {
            
            Spacer()
            
            #if DEBUG
            Button(action: {
                Task{
                    let profile = await profileController.shared.fetchProfile(profileId: "<profile_id>")
                    errorManager.shared.error("Test", profile?.profileId ?? "Test")
                }
                
            }) {
                Text("fetch profile")
                    .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.black)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            #endif
            
            Button(action: {
                Task {
                    await sessionManager.shared.refreshToken()
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
    browseView()
}
